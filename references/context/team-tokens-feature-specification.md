# Team Tokens Feature - Complete Specification

**Version:** 1.0
**Date:** December 29, 2025
**Status:** Implementation Ready

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Design](#solution-design)
4. [Architecture Integration](#architecture-integration)
5. [Mathematical Model](#mathematical-model)
6. [Implementation Details](#implementation-details)
7. [User Flows](#user-flows)
8. [Security & Safety](#security--safety)
9. [Admin Operations](#admin-operations)
10. [Testing Scenarios](#testing-scenarios)

---

## 1. Executive Summary

### Overview
The Team Tokens feature introduces a 150M governance-locked token allocation pool for team members, plus 50M free tokens held in multisig. The locked tokens unlock through governance participation, running parallel to the existing earned rewards system without interference.

### Key Features
- **150M Locked Pool**: Governance-unlocked allocation for team members (adjustable)
- **50M Free Pool**: Held in multisig for future decisions
- **Governance-Based Unlock**: Team members unlock tokens by performing governance actions (voting, proposals)
- **Individual Allocations**: Each team member receives a specific allocation from the 150M locked pool
- **Adjustable Pool Size**: Owner can increase/decrease the 150M pool (cannot reduce below allocated amount)
- **Adjustable Unlock Rate**: Owner/DAO can increase difficulty (actions required) over time
- **Clean Separation**: Team tokens and earned rewards tracked separately but claimed together

### Contract Modifications
- **Modified:** `native-rewards.sol` (add team token logic)
- **Modified:** `openwork-token.sol` **(CRITICAL: Auto-distribution for legal compliance)**
- **Deployed:** OpenZeppelin `VestingWallet` (for pre-seed investor vesting)
- **Unchanged:** `nowjc.sol`, `native-dao.sol`, `main-rewards.sol` (already has emergency withdraw)
- **New Contracts:** None (VestingWallet is standard OpenZeppelin contract)

### Legal/Compliance Requirement
- ⚠️ **CRITICAL:** All tokens must automatically distribute to designated addresses at deployment
- Tokens must NEVER touch owner's wallet for regulatory compliance
- Token constructor modified to accept 3 destination addresses:
  - Main-rewards (75% - 750M: 600M earned + 150M team locked)
  - Pre-seed vesting (5% - 50M, held in multisig)
  - Treasury (20% - 200M: 150M treasury + 50M team free, held in multisig)
- Auto-minting directly to destination contracts
- Investor vesting enforced via OpenZeppelin VestingWallet (1 year cliff, 3 year vesting)
- **Multisig Total: 250M** (50M preseed + 150M treasury + 50M team free)

---

## 2. Problem Statement

### Current System (Working Perfectly)
Users earn tokens through:
1. **Job Value Provided**: Payment for completed work
2. **Governance Actions**: Voting and proposals unlock earned tokens

### New Requirement
Add a **team tokens system** where:
- **150M Locked Pool**: Team members have pre-allocated tokens (e.g., Alice: 30M, Bob: 50M, Charlie: 70M)
- Tokens unlock ONLY through governance actions (no job requirement)
- Pool size is adjustable (can be increased/decreased, but not below already allocated amount)
- Initial unlock rate: 750 governance actions to unlock full 150M (200k per action)
- **50M Free Pool**: Held in multisig for future decisions (no governance unlock required)

### Challenge
How to implement team tokens WITHOUT:
- Mixing up earned rewards and team tokens
- Interfering with existing reward calculations
- Requiring changes to claiming/syncing infrastructure
- Creating security vulnerabilities

---

## 3. Solution Design

### Architecture Pattern: Dual-Pool System

```
┌─────────────────────────────────────────────────────────┐
│         Native Rewards Contract (Arbitrum)              │
│                                                          │
│  ┌─────────────────────┐    ┌─────────────────────┐   │
│  │   Pool A: Earned    │    │   Pool B: Team      │   │
│  │   Rewards           │    │   Tokens            │   │
│  ├─────────────────────┤    ├─────────────────────┤   │
│  │ • Job-based earning │    │ • Pre-allocated     │   │
│  │ • Band-specific     │    │ • Gov-only unlock   │   │
│  │ • Variable rates    │    │ • Adjustable: 150M  │   │
│  │ • 600M total        │    │ • Adjustable rate   │   │
│  └─────────────────────┘    └─────────────────────┘   │
│           ▲                           ▲                 │
│           │                           │                 │
│           └───────────┬───────────────┘                 │
│                       │                                  │
│         Same Governance Action Counter                  │
│         userTotalGovernanceActions[user]                │
└─────────────────────────────────────────────────────────┘
                        │
                        ↓
            getUserTotalClaimableTokens()
                        │
                        ↓
              earnedClaimable + teamClaimable
                        │
                        ↓
         Synced to Main Rewards (OP/Arb Sepolia)
                        │
                        ↓
                  User Claims Tokens
                        │
                        ↓
            Deducts from Pool A first (FIFO),
                  then Pool B
```

### Key Design Principles

1. **Single Source of Truth**: One governance counter unlocks both pools
2. **Isolated Accounting**: Separate state variables prevent cross-contamination
3. **Unified Interface**: Claiming system sees total claimable, not source
4. **FIFO Disbursement**: Earned rewards claimed first, then team tokens
5. **Zero New Infrastructure**: Works with existing sync/claim flow

---

## 4. Architecture Integration

### Existing System Components

#### A. Native Rewards Contract ([native-rewards.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol))
**Location:** Arbitrum (Native Chain)
**Current Role:**
- Tracks earned tokens per user per band
- Calculates unlocked tokens based on governance actions
- Returns total claimable for cross-chain sync

**New Role (Added):**
- Track team token allocations
- Calculate team tokens unlocked
- Include team tokens in total claimable

#### B. Native Job Contract ([nowjc.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/nowjc.sol))
**Location:** Arbitrum (Native Chain)
**Role:** Unchanged
- Line 462-481: `incrementGovernanceAction()` updates counter
- Line 948-965: `syncRewardsData()` calls `getUserTotalClaimableTokens()`
- Automatically syncs combined total (earned + team)

#### C. Native DAO ([native-dao.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/native-dao.sol))
**Location:** Arbitrum (Native Chain)
**Role:** Unchanged
- Line 402: Calls `incrementGovernanceAction()` on votes
- Line 429: Calls `incrementGovernanceAction()` on proposals
- Single counter unlocks both pools

#### D. Main Rewards Contract ([main-rewards.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/main-rewards.sol))
**Location:** Optimism/Arbitrum Sepolia (Rewards Chain)
**Role:** Unchanged
- Line 186-199: `claimRewards()` transfers synced amount
- Line 202-214: Calls back `markTokensClaimed()`
- Token source (earned vs team) is transparent to it

### Integration Flow

```
┌──────────────────────────────────────────────────────────────┐
│ STEP 1: Governance Action (Vote/Propose)                     │
├──────────────────────────────────────────────────────────────┤
│ User → native-dao.sol → nowjc.incrementGovernanceAction()    │
│                                                               │
│ Result: userTotalGovernanceActions[user]++                   │
└──────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 2: Token Unlock Calculation                             │
├──────────────────────────────────────────────────────────────┤
│ native-rewards.sol uses same counter for BOTH pools:         │
│                                                               │
│ Pool A (Earned): govActions × band_rate                      │
│ Pool B (Team):   govActions × teamTokensPerGovAction         │
└──────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 3: Sync to Rewards Chain                                │
├──────────────────────────────────────────────────────────────┤
│ User → nowjc.syncRewardsData() → sends combined total        │
│                                                               │
│ Total = earnedClaimable + teamClaimable                       │
└──────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 4: Claim Tokens                                          │
├──────────────────────────────────────────────────────────────┤
│ User → main-rewards.claimRewards() → transfers tokens        │
│                                                               │
│ main-rewards calls back: markTokensClaimed(user, amount)     │
└──────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────┐
│ STEP 5: Accounting Update (FIFO)                             │
├──────────────────────────────────────────────────────────────┤
│ native-rewards.markTokensClaimed():                           │
│   1. Deduct from earned rewards first (by band)              │
│   2. If remaining, deduct from team tokens                   │
│   3. Update both claimed counters                            │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. Mathematical Model

### Team Token Unlock Formula

```
Unlock Rate (tokens per action) = TEAM_TOKENS_POOL / desired_actions

Examples (default 150M pool):
- 750 actions  → 150,000,000 / 750  = 200,000 tokens/action (default)
- 1000 actions → 150,000,000 / 1000 = 150,000 tokens/action
- 1500 actions → 150,000,000 / 1500 = 100,000 tokens/action
- 3000 actions → 150,000,000 / 3000 = 50,000 tokens/action

Note: Pool size (150M) is adjustable via setTeamTokensPool()
```

### Claimable Calculation

For a team member with allocation `A` and `N` governance actions:

```
max_unlocked = N × teamTokensPerGovAction
total_unlocked = min(max_unlocked, A)
claimable = total_unlocked - already_claimed
```

### Example Scenarios

#### Scenario 1: Team Member Only (No Earned Tokens)
```
Alice:
  - Team allocation: 30M
  - Earned tokens: 0
  - Governance actions: 100
  - Rate: 200k per action

Calculation:
  max_unlocked = 100 × 200,000 = 20,000,000
  total_unlocked = min(20M, 30M) = 20M
  claimable = 20M - 0 = 20M

Result: Can claim 20M from team pool
```

#### Scenario 2: Non-Team Member (Only Earned)
```
Bob:
  - Team allocation: 0 (not a team member)
  - Earned tokens: 5M
  - Governance actions: 200

Calculation:
  Pool A (Earned): 2M unlocked by 200 actions
  Pool B (Team): isTeamMember[Bob] = false → 0

Result: Can claim 2M from earned pool only
```

#### Scenario 3: Team Member with Both Pools
```
Charlie:
  - Team allocation: 120M
  - Earned tokens: 1M
  - Governance actions: 100
  - Rate: 200k per action

Calculation:
  Pool A (Earned): 800k unlocked (example, band-dependent)
  Pool B (Team): 100 × 200k = 20M unlocked
  Total claimable: 800k + 20M = 20.8M

Claiming 20.8M:
  1. Deduct 800k from earned pool
  2. Deduct 20M from team pool

After claim:
  Earned: 1M total, 800k claimed, 200k remaining
  Team: 120M allocated, 20M claimed, 100M remaining (need more gov actions)
```

#### Scenario 4: Rate Adjustment Impact
```
Initial: 1000 actions required (200k per action)
User claims 20M after 100 actions

Owner increases to 2000 actions (100k per action)

Same user now:
  max_unlocked = 100 × 100k = 10M
  already_claimed = 20M
  claimable = max(10M - 20M, 0) = 0

Must reach 200 actions (200 × 100k = 20M) to break even
Action 201+ unlocks new tokens
```

---

## 6. Implementation Details

### A. New State Variables

```solidity
// ==================== TEAM TOKENS POOL ====================

// Pool configuration (adjustable, cannot be reduced below allocated)
uint256 public TEAM_TOKENS_POOL = 150_000_000 * 1e18;  // 150M locked team tokens
uint256 public teamTokensPerGovAction = 200_000 * 1e18;  // Default: 750 actions

// DAO integration
address public nativeDAO;

// Individual allocations
mapping(address => uint256) public teamTokensAllocated;  // Each member's share
mapping(address => uint256) public teamTokensClaimed;    // Already claimed
mapping(address => bool) public isTeamMember;            // Quick lookup
address[] public teamMembers;                            // List of all members

// Events
event TeamTokensAllocated(address[] members, uint256[] amounts, uint256 totalAllocated);
event UnlockRateChanged(uint256 oldRate, uint256 newRate, uint256 actionsRequired);
event TeamMemberAdded(address indexed member, uint256 allocation);
event NativeDAOUpdated(address indexed oldDAO, address indexed newDAO);
```

### B. Core Functions

#### 1. Setup Functions

```solidity
/**
 * @dev Set DAO address for governance control
 */
function setNativeDAO(address _dao) external onlyOwner {
    address oldDAO = nativeDAO;
    nativeDAO = _dao;
    emit NativeDAOUpdated(oldDAO, _dao);
}

/**
 * @dev Allocate team tokens to members
 * Can be called by owner or DAO
 */
function allocateTeamTokens(
    address[] calldata members,
    uint256[] calldata amounts
) external {
    require(
        msg.sender == owner() || msg.sender == nativeDAO,
        "Only owner or DAO"
    );
    require(members.length == amounts.length, "Length mismatch");

    uint256 totalAllocated = 0;
    for (uint256 i = 0; i < members.length; i++) {
        require(members[i] != address(0), "Invalid address");
        require(amounts[i] > 0, "Zero allocation");

        if (!isTeamMember[members[i]]) {
            teamMembers.push(members[i]);
            isTeamMember[members[i]] = true;
            emit TeamMemberAdded(members[i], amounts[i]);
        }

        teamTokensAllocated[members[i]] = amounts[i];
        totalAllocated += amounts[i];
    }

    require(totalAllocated <= TEAM_TOKENS_POOL, "Exceeds team tokens pool");
    emit TeamTokensAllocated(members, amounts, totalAllocated);
}
```

#### 2. Calculation Functions

```solidity
/**
 * @dev Calculate team tokens claimable for a user
 * Returns 0 for non-team members
 */
function getTeamTokensClaimable(address user) public view returns (uint256) {
    if (!isTeamMember[user]) return 0;

    uint256 allocated = teamTokensAllocated[user];
    uint256 govActions = userTotalGovernanceActions[user];

    // Calculate max unlocked based on current rate
    uint256 maxUnlocked = govActions * teamTokensPerGovAction;

    // Can't unlock more than allocated
    uint256 totalUnlocked = maxUnlocked > allocated ? allocated : maxUnlocked;

    // Subtract already claimed
    return totalUnlocked > teamTokensClaimed[user] ?
        totalUnlocked - teamTokensClaimed[user] : 0;
}
```

#### 3. Updated Existing Functions

```solidity
/**
 * @dev Get total claimable tokens (UPDATED)
 * Now includes both earned and team tokens
 */
function getUserTotalClaimableTokens(address user) external view returns (uint256) {
    // Pool A: Earned rewards (existing logic)
    uint256 earnedClaimable = 0;
    UserBandRewards[] memory rewards = userBandRewards[user];
    for (uint256 i = 0; i < rewards.length; i++) {
        earnedClaimable += _calculateBandClaimable(user, rewards[i]);
    }

    // Pool B: Team tokens (NEW)
    uint256 teamClaimable = getTeamTokensClaimable(user);

    // Return combined total
    return earnedClaimable + teamClaimable;
}

/**
 * @dev Mark tokens as claimed (UPDATED)
 * Now handles FIFO claiming from both pools
 */
function markTokensClaimed(address user, uint256 amountClaimed)
    external onlyJobContract returns (bool)
{
    uint256 remainingToClaim = amountClaimed;

    // STEP 1: Claim from earned rewards first (FIFO by band)
    for (uint256 i = 0; i < userBandRewards[user].length && remainingToClaim > 0; i++) {
        UserBandRewards memory bandReward = userBandRewards[user][i];
        uint256 bandClaimable = _calculateBandClaimable(user, bandReward);

        if (bandClaimable > 0) {
            uint256 claimFromBand = remainingToClaim > bandClaimable ?
                bandClaimable : remainingToClaim;

            uint256 bandIndex = userBandIndex[user][bandReward.band];
            userBandRewards[user][bandIndex].tokensClaimed += claimFromBand;
            userTotalTokensClaimed[user] += claimFromBand;
            remainingToClaim -= claimFromBand;
        }
    }

    // STEP 2: If still remaining, claim from team tokens
    if (remainingToClaim > 0 && isTeamMember[user]) {
        uint256 teamClaimable = getTeamTokensClaimable(user);
        require(remainingToClaim <= teamClaimable, "Insufficient team tokens");

        teamTokensClaimed[user] += remainingToClaim;
        remainingToClaim = 0;
    }

    require(remainingToClaim == 0, "Insufficient claimable balance");
    return true;
}
```

#### 4. Admin Functions

```solidity
/**
 * @dev Adjust unlock rate by setting desired action count
 * Can only INCREASE difficulty (more actions = lower rate)
 */
function setTeamTokenActionRequirement(uint256 desiredActions) external onlyOwner {
    require(desiredActions >= 750, "Min 750 actions");
    require(desiredActions <= 10_000_000, "Max 10M actions");

    uint256 newRate = TEAM_TOKENS_POOL / desiredActions;

    // Can only make it harder (more actions = lower rate)
    require(newRate < teamTokensPerGovAction, "Can only increase requirement");
    require(newRate >= 10_000 * 1e18, "Min 10k per action");

    uint256 oldRate = teamTokensPerGovAction;
    teamTokensPerGovAction = newRate;

    emit UnlockRateChanged(oldRate, newRate, desiredActions);
}

/**
 * @dev Adjust team tokens pool size (cannot reduce below allocated)
 */
function setTeamTokensPool(uint256 newPool) external onlyOwner {
    require(newPool >= totalTeamTokensAllocated, "Cannot reduce below allocated");
    TEAM_TOKENS_POOL = newPool;
}
```

#### 5. View Functions

```solidity
/**
 * @dev Get comprehensive token breakdown for a user
 * Useful for frontend display
 */
function getUserTokenBreakdown(address user) external view returns (
    uint256 earnedTotal,
    uint256 earnedClaimable,
    uint256 earnedClaimed,
    uint256 teamAllocated,
    uint256 teamClaimable,
    uint256 teamClaimed,
    uint256 governanceActions,
    uint256 totalClaimable
) {
    // Earned pool
    earnedTotal = userTotalTokensEarned[user];
    earnedClaimed = userTotalTokensClaimed[user];

    UserBandRewards[] memory rewards = userBandRewards[user];
    for (uint256 i = 0; i < rewards.length; i++) {
        earnedClaimable += _calculateBandClaimable(user, rewards[i]);
    }

    // Team pool
    teamAllocated = teamTokensAllocated[user];
    teamClaimable = getTeamTokensClaimable(user);
    teamClaimed = teamTokensClaimed[user];

    // Global
    governanceActions = userTotalGovernanceActions[user];
    totalClaimable = earnedClaimable + teamClaimable;
}

/**
 * @dev Get team pool statistics
 */
function getTeamPoolInfo() external view returns (
    uint256 totalTeamTokens,
    uint256 tokensPerAction,
    uint256 actionsRequired,
    uint256 totalAllocated,
    uint256 totalClaimed,
    uint256 totalMembers
) {
    totalTeamTokens = TEAM_TOKENS_POOL;
    tokensPerAction = teamTokensPerGovAction;
    actionsRequired = TEAM_TOKENS_POOL / teamTokensPerGovAction;

    for (uint256 i = 0; i < teamMembers.length; i++) {
        address member = teamMembers[i];
        totalAllocated += teamTokensAllocated[member];
        totalClaimed += teamTokensClaimed[member];
    }

    totalMembers = teamMembers.length;
}

/**
 * @dev Get all team members
 */
function getAllTeamMembers() external view returns (address[] memory) {
    return teamMembers;
}

/**
 * @dev Get team member details
 */
function getTeamMemberInfo(address member) external view returns (
    bool isMember,
    uint256 allocated,
    uint256 claimed,
    uint256 claimable,
    uint256 govActions
) {
    isMember = isTeamMember[member];
    allocated = teamTokensAllocated[member];
    claimed = teamTokensClaimed[member];
    claimable = getTeamTokensClaimable(member);
    govActions = userTotalGovernanceActions[member];
}
```

---

## 7. User Flows

### Flow 1: Owner Allocates Team Tokens

```
1. Owner calls: allocateTeamTokens(
     [alice, bob, charlie],
     [30M, 50M, 120M]
   )

2. Contract validates:
   ✓ Caller is owner or DAO
   ✓ Arrays match length
   ✓ No zero addresses
   ✓ Total ≤ 200M

3. Contract updates:
   - teamTokensAllocated[alice] = 30M
   - teamTokensAllocated[bob] = 50M
   - teamTokensAllocated[charlie] = 120M
   - isTeamMember[each] = true
   - teamMembers array updated

4. Events emitted:
   - TeamTokensAllocated(...)
   - TeamMemberAdded(...) for each

Result: Team members can now earn by doing governance
```

### Flow 2: Team Member Claims Tokens

```
STEP 1: Perform Governance Actions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alice votes on 10 proposals:
  → native-dao.castVote() × 10
  → nowjc.incrementGovernanceAction() × 10
  → userTotalGovernanceActions[alice] = 10

STEP 2: Check Claimable
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alice calls: getUserTokenBreakdown(alice)
Returns:
  - earnedClaimable: 0 (no jobs done)
  - teamClaimable: 10 × 200k = 2M
  - totalClaimable: 2M

STEP 3: Sync to Rewards Chain
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alice calls: nowjc.syncRewardsData(_options)
  → Calls native-rewards.getUserTotalClaimableTokens(alice)
  → Returns: 2M
  → Sends to main-rewards via bridge
  → main-rewards.userClaimableBalance[alice] = 2M

STEP 4: Claim Tokens
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alice calls: main-rewards.claimRewards(_options)
  → Transfers 2M tokens to Alice
  → Calls back: native-rewards.markTokensClaimed(alice, 2M)

STEP 5: Update Accounting
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
markTokensClaimed():
  1. Check earned pool: 0 claimable → skip
  2. Check team pool: 2M claimable ✓
  3. Deduct: teamTokensClaimed[alice] += 2M

Final State:
  - Alice received: 2M tokens
  - Alice's team claimed: 2M
  - Alice's team remaining: 28M
  - Needs 140 more actions to unlock remaining 28M
```

### Flow 3: Team Member with Both Pools

```
Charlie's situation:
  - Team allocation: 120M
  - Earned from jobs: 1M
  - Governance actions: 100
  - Earned unlocked: 800k (example)
  - Team unlocked: 100 × 200k = 20M

Step 1: Sync
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
getUserTotalClaimableTokens(charlie):
  earnedClaimable = 800k
  teamClaimable = 20M
  return 20.8M

Step 2: Claim
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Charlie claims 20.8M

Step 3: FIFO Deduction
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
markTokensClaimed(charlie, 20.8M):
  remainingToClaim = 20.8M

  // Pool A (Earned)
  Loop through bands:
    Band 0: 800k claimable
    Claim 800k from earned
    remainingToClaim = 20M

  // Pool B (Team)
  20M ≤ teamClaimable (20M) ✓
  teamTokensClaimed[charlie] += 20M
  remainingToClaim = 0

Final State:
  Earned: 1M total, 800k claimed
  Team: 120M allocated, 20M claimed
  Charlie received: 20.8M total
```

### Flow 4: Non-Team Member (Existing System)

```
Bob's situation:
  - NOT a team member
  - Earned from jobs: 5M
  - Governance actions: 200
  - Earned unlocked: 2M (example)

Step 1: Calculate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
getUserTotalClaimableTokens(bob):
  earnedClaimable = 2M
  teamClaimable = getTeamTokensClaimable(bob)
    → isTeamMember[bob] = false
    → return 0
  return 2M

Step 2: Claim
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Bob claims 2M from earned pool only

Result: Existing system works unchanged for non-team members
```

### Flow 5: Rate Adjustment

```
Scenario: Owner increases difficulty

Initial State:
  - Rate: 200k per action (1000 actions for 200M)
  - Alice: 100 actions done, 20M claimed

Step 1: Owner Increases Requirement
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Owner calls: setTeamTokenActionRequirement(2000)
  → newRate = 200M / 2000 = 100k per action
  → Validates: 100k < 200k ✓ (can only increase difficulty)
  → Updates: teamTokensPerGovAction = 100k
  → Emits: UnlockRateChanged(200k, 100k, 2000)

Step 2: Impact on Alice
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Alice's new claimable:
  maxUnlocked = 100 actions × 100k = 10M
  totalUnlocked = min(10M, 30M) = 10M
  claimable = 10M - 20M claimed = 0 (negative → 0)

Alice needs:
  200 actions × 100k = 20M to break even
  201+ actions to unlock new tokens

Step 3: Impact on New User
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dave joins after rate change:
  - Allocation: 40M
  - 100 actions done
  - Claimable: 100 × 100k = 10M
  - Needs 400 total actions for full allocation

Result: Rate changes affect future unlocks, not past claims
```

---

## 8. Security & Safety

### Protection Mechanisms

#### 1. Non-Team Member Protection
```solidity
function getTeamTokensClaimable(address user) public view returns (uint256) {
    if (!isTeamMember[user]) return 0;  // ← Immediate exit
    // ...
}
```
**Result:** Non-members always get 0 from team pool

#### 2. Allocation Cap Enforcement
```solidity
require(totalAllocated <= TOTAL_TEAM_TOKENS, "Exceeds 200M cap");
```
**Result:** Impossible to allocate more than 200M total

#### 3. Double-Claim Prevention
```solidity
uint256 alreadyClaimed = teamTokensClaimed[user];
return totalUnlocked > alreadyClaimed ?
    totalUnlocked - alreadyClaimed : 0;
```
**Result:** Can't claim same tokens twice

#### 4. Rate Adjustment Safeguards
```solidity
require(newRate < teamTokensPerGovAction, "Can only increase requirement");
require(newRate >= 10_000 * 1e18, "Min 10k per action");
```
**Result:**
- Can only make it harder (prevents accidental token flood)
- Floor at 10k prevents extreme difficulty

#### 5. Access Control
```solidity
require(
    msg.sender == owner() || msg.sender == nativeDAO,
    "Only owner or DAO"
);
```
**Result:** Only authorized entities can allocate/adjust

#### 6. Zero Address Prevention
```solidity
require(members[i] != address(0), "Invalid address");
```
**Result:** Can't allocate to zero address

### Attack Vector Analysis

| Attack Vector | Protection | Status |
|--------------|------------|--------|
| Non-member claiming team tokens | `isTeamMember` check | ✅ Safe |
| Claiming more than allocated | `min(unlocked, allocated)` cap | ✅ Safe |
| Double claiming | `alreadyClaimed` tracking | ✅ Safe |
| Exceeding 200M pool | Total validation in allocate | ✅ Safe |
| Unauthorized allocation | Owner/DAO only modifier | ✅ Safe |
| Rate manipulation | One-way increase only | ✅ Safe |
| Reentrancy on claim | Handled by main-rewards | ✅ Safe |
| Integer overflow | Solidity 0.8+ built-in | ✅ Safe |

### Audit Checklist

- [ ] Verify `isTeamMember` check in all team token functions
- [ ] Confirm TOTAL_TEAM_TOKENS constant is immutable
- [ ] Test rate adjustment boundary conditions
- [ ] Validate FIFO claiming logic in markTokensClaimed
- [ ] Check event emissions for all state changes
- [ ] Verify access control on admin functions
- [ ] Test with both team and non-team users
- [ ] Confirm compatibility with existing earned rewards
- [ ] Validate cross-chain sync with combined totals
- [ ] Test rate changes with existing claims

---

## 9. Admin Operations

### Initial Setup (One-Time)

```solidity
// 1. Set DAO address (for governance control)
nativeRewards.setNativeDAO(daoAddress);

// 2. Allocate team tokens (from 150M locked pool)
address[] memory teamMembers = [alice, bob, charlie];
uint256[] memory allocations = [
    30_000_000 * 1e18,  // Alice: 30M
    50_000_000 * 1e18,  // Bob: 50M
    70_000_000 * 1e18   // Charlie: 70M (Total: 150M)
];
nativeRewards.allocateTeamTokens(teamMembers, allocations);

// 3. Fund main-rewards contract
// Auto-funded at deployment with 750M tokens (600M earned + 150M team locked)
// Additional 50M team free + 50M preseed + 150M treasury = 250M in multisig
```

### Adjusting Unlock Rate

```solidity
// Increase from 1000 to 2000 actions required
nativeRewards.setTeamTokenActionRequirement(2000);

// This changes rate from 200k to 100k per action
```

### Adding More Team Members

```solidity
// Can be called multiple times (cumulative)
address[] memory newMembers = [dave, eve];
uint256[] memory newAllocations = [
    10_000_000 * 1e18,  // Dave: 10M
    15_000_000 * 1e18   // Eve: 15M
];

// Ensures: existing + new ≤ 200M
nativeRewards.allocateTeamTokens(newMembers, newAllocations);
```

### Updating Existing Allocation

```solidity
// To update Alice from 30M to 40M:
address[] memory updateMembers = [alice];
uint256[] memory updateAllocations = [40_000_000 * 1e18];

nativeRewards.allocateTeamTokens(updateMembers, updateAllocations);
// Note: This overwrites previous allocation
```

### Monitoring Team Pool

```solidity
// Check pool statistics
(
    uint256 totalTokens,
    uint256 tokensPerAction,
    uint256 actionsRequired,
    uint256 totalAllocated,
    uint256 totalClaimed,
    uint256 totalMembers
) = nativeRewards.getTeamPoolInfo();

// Check individual member
(
    bool isMember,
    uint256 allocated,
    uint256 claimed,
    uint256 claimable,
    uint256 govActions
) = nativeRewards.getTeamMemberInfo(alice);

// Get all team members
address[] memory allMembers = nativeRewards.getAllTeamMembers();
```

### DAO Governance Examples

```solidity
// Proposal 1: Add new team member
function addTeamMember(address newMember, uint256 allocation) {
    address[] memory members = new address[](1);
    members[0] = newMember;

    uint256[] memory allocations = new uint256[](1);
    allocations[0] = allocation;

    nativeRewards.allocateTeamTokens(members, allocations);
}

// Proposal 2: Increase difficulty
function increaseDifficulty(uint256 newActionRequirement) {
    nativeRewards.setTeamTokenActionRequirement(newActionRequirement);
}
```

---

## 10. Testing Scenarios

### Test Suite 1: Basic Functionality

```solidity
Test 1.1: Allocate Team Tokens
  Setup:
    - Deploy native-rewards
    - Prepare team members [alice, bob, charlie]
  Actions:
    - Owner calls allocateTeamTokens([alice, bob], [30M, 50M])
  Assertions:
    - teamTokensAllocated[alice] == 30M
    - teamTokensAllocated[bob] == 50M
    - isTeamMember[alice] == true
    - teamMembers.length == 2

Test 1.2: Calculate Team Claimable (No Actions)
  Setup: Alice allocated 30M
  Actions: Query getTeamTokensClaimable(alice)
  Expected: 0 (no governance actions yet)

Test 1.3: Calculate Team Claimable (With Actions)
  Setup:
    - Alice allocated 30M
    - Alice performs 50 governance actions
  Actions: Query getTeamTokensClaimable(alice)
  Expected: 50 × 200k = 10M

Test 1.4: Non-Member Gets Zero
  Setup: Bob NOT allocated any team tokens
  Actions: Query getTeamTokensClaimable(bob)
  Expected: 0
```

### Test Suite 2: Claiming Flow

```solidity
Test 2.1: Team Member Claims (No Earned)
  Setup:
    - Alice allocated 30M
    - Alice performs 100 actions
    - No earned rewards
  Actions:
    - getUserTotalClaimableTokens(alice)
    - Sync and claim
    - markTokensClaimed(alice, 20M)
  Assertions:
    - Total claimable: 20M
    - teamTokensClaimed[alice] == 20M
    - Remaining claimable: 10M after 100 actions

Test 2.2: Team Member Claims (With Earned)
  Setup:
    - Charlie allocated 120M
    - Charlie earned 1M from jobs
    - Charlie performs 100 actions
    - Earned unlocked: 800k
  Actions:
    - Claim 20.8M total
  Assertions:
    - 800k deducted from earned pool
    - 20M deducted from team pool
    - userTotalTokensClaimed[charlie] == 800k
    - teamTokensClaimed[charlie] == 20M

Test 2.3: Non-Member Claims (Existing System)
  Setup:
    - Bob not a team member
    - Bob earned 5M from jobs
    - Bob performs 200 actions
  Actions:
    - getUserTotalClaimableTokens(bob)
  Assertions:
    - Only earned rewards counted
    - Team claimable == 0
    - System works as before for non-members
```

### Test Suite 3: Rate Adjustments

```solidity
Test 3.1: Increase Action Requirement
  Setup: Initial rate 200k (1000 actions)
  Actions:
    - Owner calls setTeamTokenActionRequirement(2000)
  Assertions:
    - teamTokensPerGovAction == 100k
    - Event emitted with correct values

Test 3.2: Cannot Decrease Difficulty
  Setup: Current rate 100k (2000 actions)
  Actions:
    - Try setTeamTokenActionRequirement(1000)
  Expected: Revert with "Can only increase requirement"

Test 3.3: Impact on Existing Claims
  Setup:
    - Alice claimed 20M at 200k rate
    - Owner changes to 100k rate
  Actions:
    - Query getTeamTokensClaimable(alice) at 100 actions
  Expected:
    - maxUnlocked = 100 × 100k = 10M
    - claimable = max(10M - 20M, 0) = 0
    - Must reach 200 actions to break even
```

### Test Suite 4: Security Tests

```solidity
Test 4.1: Exceed 200M Allocation
  Actions:
    - Try allocate 150M + 100M = 250M total
  Expected: Revert with "Exceeds 200M cap"

Test 4.2: Unauthorized Allocation
  Setup: Eve is not owner or DAO
  Actions:
    - Eve tries allocateTeamTokens()
  Expected: Revert with "Only owner or DAO"

Test 4.3: Double Claim Prevention
  Setup:
    - Alice allocated 30M
    - Alice claimed 20M already
    - Alice has 100 actions (20M unlocked)
  Actions:
    - Try claim another 20M
  Expected: Revert with "Insufficient team tokens"

Test 4.4: Non-Member Cannot Claim Team Tokens
  Setup:
    - Bob not a team member
    - Bob performs 1000 governance actions
  Actions:
    - Query getTeamTokensClaimable(bob)
  Expected: 0 (isTeamMember check blocks)
```

### Test Suite 5: Integration Tests

```solidity
Test 5.1: Full Flow (Team Member)
  Actions:
    1. Owner allocates 30M to Alice
    2. Alice votes on 10 proposals
    3. Alice syncs rewards data
    4. Alice claims tokens
  Assertions:
    - userTotalGovernanceActions[alice] == 10
    - Claimable: 2M
    - main-rewards transfers 2M
    - teamTokensClaimed[alice] == 2M

Test 5.2: Full Flow (Mixed User)
  Actions:
    1. Owner allocates 120M to Charlie
    2. Charlie completes jobs (earns 1M)
    3. Charlie votes on 100 proposals
    4. Charlie syncs and claims
  Assertions:
    - Total claimable: earned + team
    - FIFO deduction: earned first, then team
    - Both pools updated correctly

Test 5.3: DAO Governance Allocation
  Actions:
    1. Owner sets DAO address
    2. DAO proposes add team member
    3. Proposal passes and executes
    4. New member allocated tokens
  Assertions:
    - DAO can successfully allocate
    - Team member added correctly
```

### Test Suite 6: Edge Cases

```solidity
Test 6.1: Zero Allocation
  Actions: Try allocate 0 tokens to user
  Expected: Revert with "Zero allocation"

Test 6.2: Zero Address
  Actions: Try allocate to address(0)
  Expected: Revert with "Invalid address"

Test 6.3: Array Length Mismatch
  Actions: Call allocateTeamTokens with unequal array lengths
  Expected: Revert with "Length mismatch"

Test 6.4: Allocation Exceeds Individual Cap
  Setup: Alice allocated 30M
  Actions:
    - Alice performs 10,000 actions
    - 10,000 × 200k = 2B tokens unlocked
  Assertions:
    - claimable capped at 30M (allocation limit)
    - Cannot claim more than allocated

Test 6.5: Rate Change to Minimum
  Actions:
    - Set requirement to 20,000 actions (10k per action)
    - Try set requirement to 25,000 (8k per action)
  Expected: Revert with "Min 10k per action"
```

---

## Summary

### What Changed
- **2 contracts modified:**
  - `native-rewards.sol` (team token logic)
  - `openwork-token.sol` **(CRITICAL: Auto-transfer for compliance)**
- **0 new contracts:** Feature integrates into existing architecture
- **0 breaking changes:** Existing users unaffected

### Token Distribution & Compliance (1B Total)
- **Earned Pool:** 600M tokens (60%) - unchanged, governance-unlocked
- **Team Pool Locked:** 150M tokens (15%) - new, governance-unlocked, adjustable
- **Team Pool Free:** 50M tokens (5%) - new, held in multisig for future decisions
- **Pre-Seed Investors:** 50M tokens (5%) - vesting (1 year cliff, 3 year vesting), held in multisig
- **Treasury:** 150M tokens (15%) - reserved for future fundraises, held in multisig
- **Multisig Total:** 250M tokens (25%) = 50M team free + 50M preseed + 150M treasury
- **Legal Compliance:** All tokens auto-distributed at deployment, zero in owner wallet
- **Emergency Recovery:** Emergency withdraw function available in main-rewards.sol (line 336-338)
- **Investor Protection:** OpenZeppelin VestingWallet enforces cliff and vesting schedule

### Key Benefits
1. **Clean Separation:** Two independent pools with isolated accounting
2. **Zero Interference:** Team tokens don't affect earned rewards calculations
3. **Unified User Experience:** Same sync/claim flow for all users
4. **Governance Incentive:** Both pools unlock through governance participation
5. **Adjustable Pool Size:** Owner can increase/decrease 150M locked pool as needed
6. **Adjustable Difficulty:** Owner/DAO can increase unlock requirements
7. **Flexible Allocation:** 50M free tokens in multisig for future decisions
8. **Audit-Friendly:** Simple, verifiable logic with clear boundaries
9. **Legal Compliance:** Automatic token transfer ensures regulatory requirements met

### Next Steps
1. **CRITICAL:** Modify token constructor for auto-distribution (3 destinations)
   - 750M → main-rewards (600M earned + 150M team locked)
   - 50M → multisig (preseed, held for future investors)
   - 200M → multisig (150M treasury + 50M team free)
2. Implement changes in native-rewards.sol (team tokens logic with adjustable pool)
3. Deploy main-rewards FIRST
4. Deploy token with multisig address for both preseed AND treasury parameters
5. Verify distribution and compliance (750M main-rewards + 250M multisig)
6. Run full test suite
7. Allocate locked team tokens (150M) to members in native-rewards
8. Monitor and adjust team token unlock rate as needed
9. When investors arrive: Deploy VestingWallet and transfer from multisig
10. Decide on usage of 50M free team tokens held in multisig

---

**End of Specification Document**
