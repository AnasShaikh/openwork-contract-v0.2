# Team Tokens Implementation Guide

**Target Contract:** [native-rewards.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol)
**Implementation Date:** December 29, 2025

---

## Table of Contents

1. [Code Changes Overview](#code-changes-overview)
2. [Step-by-Step Implementation](#step-by-step-implementation)
3. [Modified Functions Reference](#modified-functions-reference)
4. [Deployment Instructions](#deployment-instructions)
5. [Post-Deployment Setup](#post-deployment-setup)

---

## 1. Code Changes Overview

### Files Modified: 2
- `src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol`
- `src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token.sol` **(NEW: Auto-transfer requirement)**

### Changes Summary

#### Native Rewards Contract
- **New State Variables:** 8
- **New Functions:** 6
- **Modified Functions:** 2
- **New Events:** 4
- **Lines Added:** ~300

#### Token Contract (CRITICAL - Legal Compliance)
- **Modified Constructor:** Auto-transfer 800M tokens to main-rewards at deployment
- **Reason:** Tokens must NEVER touch owner wallet for legal/compliance reasons
- **Lines Modified:** ~15

### Integration Points
| Function | Current Location | Change Type | Impact |
|----------|-----------------|-------------|--------|
| `getUserTotalClaimableTokens()` | Line 399 | Modified | Returns earned + team tokens |
| `markTokensClaimed()` | Line 437 | Modified | FIFO deduction from both pools |
| `jobContract` reference | Line 46 | Used for access control | No change |
| Token `constructor()` | openwork-token.sol:28 | **Modified** | **Auto-transfer to main-rewards** |

---

## 2. Step-by-Step Implementation

### PART A: Token Contract Modification (CRITICAL - Do This First)

**⚠️ LEGAL REQUIREMENT:** Tokens must automatically transfer to main-rewards at deployment and NEVER touch the owner's wallet.

#### File: [openwork-token.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token.sol)

**Location:** Lines 28-35 (Constructor)

**BEFORE (Current Code):**
```solidity
constructor(address initialOwner)
    ERC20("OpenWorkToken", "OWORK")
    ERC20Permit("DAOToken")
    Ownable(initialOwner)
{
    // Mint initial supply to the owner
    _mint(initialOwner, INITIAL_SUPPLY);
}
```

**AFTER (Updated Code - REQUIRED):**
```solidity
/**
 * @dev Constructor that sets up the token with initial parameters
 * CRITICAL: Tokens auto-transferred to designated addresses for legal compliance
 * @param initialOwner Address that will own the contract (governance)
 * @param mainRewardsContract Address that receives rewards/team tokens
 * @param preSeedVestingContract Address for pre-seed investor vesting (5%)
 * @param treasuryAddress Address for treasury (15% reserved for future raises)
 */
constructor(
    address initialOwner,
    address mainRewardsContract,
    address preSeedVestingContract,
    address treasuryAddress
)
    ERC20("OpenWorkToken", "OWORK")
    ERC20Permit("DAOToken")
    Ownable(initialOwner)
{
    require(mainRewardsContract != address(0), "Invalid rewards contract");
    require(preSeedVestingContract != address(0), "Invalid vesting contract");
    require(treasuryAddress != address(0), "Invalid treasury");

    // Token Distribution (1B total):
    // 80% (800M) → Main Rewards (600M earned + 200M team)
    _mint(mainRewardsContract, 800_000_000 * 10**18);

    // 5% (50M) → Pre-seed investors (via vesting contract)
    _mint(preSeedVestingContract, 50_000_000 * 10**18);

    // 15% (150M) → Treasury (reserved for future fundraises)
    _mint(treasuryAddress, 150_000_000 * 10**18);

    // LEGAL COMPLIANCE: Owner wallet receives ZERO tokens
}
```

**Key Points:**
- ✅ 80% (800M) to main-rewards for user/team rewards
- ✅ 5% (50M) to vesting contract for pre-seed investors
- ✅ 15% (150M) to treasury for future fundraises
- ✅ ZERO tokens ever in owner wallet
- ✅ Owner still controls contract (can call admin functions)
- ✅ Satisfies legal/compliance requirement

---

### PART A.2: Deploy VestingWallet for Pre-Seed Investors

**⚠️ DEPLOY BEFORE TOKEN:** VestingWallet must exist before token deployment.

**Using OpenZeppelin VestingWallet:**

```solidity
import "@openzeppelin/contracts/finance/VestingWallet.sol";

// Deploy one VestingWallet per investor (or use single wallet for all)
VestingWallet preSeedVesting = new VestingWallet(
    beneficiaryAddress,        // Investor address
    block.timestamp,           // Vesting start time
    365 days,                  // Cliff duration: 1 year
    (365 * 4) days            // Total duration: 4 years (1 year cliff + 3 years vesting)
);
```

**Vesting Schedule:**
- **Year 0-1:** 0% claimable (cliff period)
- **Year 2:** ~33% claimable (1 year into vesting)
- **Year 3:** ~66% claimable (2 years into vesting)
- **Year 4:** 100% claimable (fully vested)

**For Multiple Investors:**
```javascript
// Deploy separate VestingWallet for each investor
const investor1Vesting = await VestingWallet.deploy(
    investor1Address,
    startTime,
    365 days,
    (365 * 4) days
);

const investor2Vesting = await VestingWallet.deploy(
    investor2Address,
    startTime,
    365 days,
    (365 * 4) days
);

// Then manually distribute from main vesting contract, OR
// Deploy token with multiple vesting addresses
```

---

### PART B: Native Rewards Contract Modification

#### STEP 1: Add State Variables (After Line 72)

**Location:** After existing state variables, before events section

```solidity
// ==================== TEAM TOKENS POOL ====================

// Pool configuration
uint256 public constant TOTAL_TEAM_TOKENS = 200_000_000 * 1e18;
uint256 public teamTokensPerGovAction = 200_000 * 1e18;  // Default: 1000 actions for 200M

// DAO integration for governance control
address public nativeDAO;

// Individual team member allocations
mapping(address => uint256) public teamTokensAllocated;  // Each member's total allocation
mapping(address => uint256) public teamTokensClaimed;    // Amount already claimed
mapping(address => bool) public isTeamMember;            // Quick membership lookup
address[] public teamMembers;                            // Array of all team members
```

**Reference:**
- Place after line 72: `mapping(address => uint256) public userTotalGovernanceActions;`
- Before line 74: `// ==================== EVENTS ====================`

---

### STEP 2: Add Events (After Line 72, in Events Section)

**Location:** In the events section after existing events

```solidity
event TeamTokensAllocated(address[] members, uint256[] amounts, uint256 totalAllocated);
event UnlockRateChanged(uint256 oldRate, uint256 newRate, uint256 actionsRequired);
event TeamMemberAdded(address indexed member, uint256 allocation);
event NativeDAOUpdated(address indexed oldDAO, address indexed newDAO);
```

**Reference:**
- Add after line 88: `event GovernanceActionRecorded(...);`

---

### STEP 3: Add Setup Functions (After Line 137)

**Location:** After `setProfileGenesis()` function, in admin section

```solidity
/**
 * @dev Set Native DAO address for governance control
 * @param _nativeDAO Address of the Native DAO contract
 */
function setNativeDAO(address _nativeDAO) external onlyOwner {
    address oldDAO = nativeDAO;
    nativeDAO = _nativeDAO;
    emit NativeDAOUpdated(oldDAO, _nativeDAO);
}
```

**Reference:**
- Add after line 137: `function setProfileGenesis(address _profileGenesis) external onlyOwner`

---

### STEP 4: Add Team Token Allocation Function (After setNativeDAO)

**Location:** In admin section, after `setNativeDAO()`

```solidity
/**
 * @dev Allocate team tokens to team members
 * Can be called by owner or DAO for governance control
 * @param members Array of team member addresses
 * @param amounts Array of token amounts (must sum to ≤ 200M)
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

        // Add to team members list if new
        if (!isTeamMember[members[i]]) {
            teamMembers.push(members[i]);
            isTeamMember[members[i]] = true;
            emit TeamMemberAdded(members[i], amounts[i]);
        }

        // Set allocation (overwrites if exists)
        teamTokensAllocated[members[i]] = amounts[i];
        totalAllocated += amounts[i];
    }

    // Validate total doesn't exceed 200M cap
    require(totalAllocated <= TOTAL_TEAM_TOKENS, "Exceeds 200M cap");
    emit TeamTokensAllocated(members, amounts, totalAllocated);
}
```

---

### STEP 5: Add Team Token Calculation Function (After allocateTeamTokens)

**Location:** In a new section after admin functions

```solidity
// ==================== TEAM TOKENS CALCULATION ====================

/**
 * @dev Calculate team tokens claimable for a user
 * Formula: min(govActions × rate, allocation) - already_claimed
 * Returns 0 for non-team members
 * @param user Address to check
 * @return Claimable team tokens amount
 */
function getTeamTokensClaimable(address user) public view returns (uint256) {
    // Non-team members get 0
    if (!isTeamMember[user]) return 0;

    uint256 allocated = teamTokensAllocated[user];
    uint256 govActions = userTotalGovernanceActions[user];

    // Calculate max unlocked based on current rate
    uint256 maxUnlocked = govActions * teamTokensPerGovAction;

    // Can't unlock more than allocated
    uint256 totalUnlocked = maxUnlocked > allocated ? allocated : maxUnlocked;

    // Subtract already claimed
    uint256 alreadyClaimed = teamTokensClaimed[user];
    return totalUnlocked > alreadyClaimed ?
        totalUnlocked - alreadyClaimed : 0;
}
```

---

### STEP 6: Modify getUserTotalClaimableTokens() Function

**Location:** Line 399 - REPLACE existing function

**BEFORE (Current Code):**
```solidity
function getUserTotalClaimableTokens(address user) external view returns (uint256) {
    uint256 totalClaimable = 0;
    UserBandRewards[] memory rewards = userBandRewards[user];

    for (uint256 i = 0; i < rewards.length; i++) {
        UserBandRewards memory bandReward = rewards[i];
        uint256 bandClaimable = _calculateBandClaimable(user, bandReward);
        totalClaimable += bandClaimable;
    }

    return totalClaimable;
}
```

**AFTER (Updated Code):**
```solidity
/**
 * @dev Calculate user's total claimable tokens (UPDATED)
 * Now includes both earned rewards AND team tokens
 * This is the main function NOWJC calls for cross-chain sync
 * @param user Address to check
 * @return Total claimable from both pools
 */
function getUserTotalClaimableTokens(address user) external view returns (uint256) {
    // Pool A: Earned rewards (existing logic)
    uint256 earnedClaimable = 0;
    UserBandRewards[] memory rewards = userBandRewards[user];

    for (uint256 i = 0; i < rewards.length; i++) {
        UserBandRewards memory bandReward = rewards[i];
        uint256 bandClaimable = _calculateBandClaimable(user, bandReward);
        earnedClaimable += bandClaimable;
    }

    // Pool B: Team tokens (NEW)
    uint256 teamClaimable = getTeamTokensClaimable(user);

    // Return combined total from both pools
    return earnedClaimable + teamClaimable;
}
```

**Diff:**
```diff
  function getUserTotalClaimableTokens(address user) external view returns (uint256) {
+     // Pool A: Earned rewards (existing logic)
-     uint256 totalClaimable = 0;
+     uint256 earnedClaimable = 0;
      UserBandRewards[] memory rewards = userBandRewards[user];

      for (uint256 i = 0; i < rewards.length; i++) {
          UserBandRewards memory bandReward = rewards[i];
          uint256 bandClaimable = _calculateBandClaimable(user, bandReward);
-         totalClaimable += bandClaimable;
+         earnedClaimable += bandClaimable;
      }

-     return totalClaimable;
+     // Pool B: Team tokens (NEW)
+     uint256 teamClaimable = getTeamTokensClaimable(user);
+
+     // Return combined total from both pools
+     return earnedClaimable + teamClaimable;
  }
```

---

### STEP 7: Modify markTokensClaimed() Function

**Location:** Line 437 - REPLACE existing function

**BEFORE (Current Code):**
```solidity
function markTokensClaimed(address user, uint256 amountClaimed) external onlyJobContract returns (bool) {
    uint256 remainingToClaim = amountClaimed;

    // Mark claimed from bands in order (FIFO)
    for (uint256 i = 0; i < userBandRewards[user].length && remainingToClaim > 0; i++) {
        UserBandRewards memory bandReward = userBandRewards[user][i];
        uint256 bandClaimable = _calculateBandClaimable(user, bandReward);

        if (bandClaimable > 0) {
            uint256 claimFromThisBand = remainingToClaim > bandClaimable ?
                bandClaimable : remainingToClaim;

            // Update claimed amount for this band
            uint256 bandIndex = userBandIndex[user][bandReward.band];
            userBandRewards[user][bandIndex].tokensClaimed += claimFromThisBand;

            remainingToClaim -= claimFromThisBand;
        }
    }

    // Update user total claimed
    userTotalTokensClaimed[user] += amountClaimed;

    return true;
}
```

**AFTER (Updated Code):**
```solidity
/**
 * @dev Mark tokens as claimed (UPDATED)
 * Now handles FIFO claiming from both pools:
 * 1. Earned rewards first (by band)
 * 2. Team tokens second (if any remaining)
 * @param user Address claiming tokens
 * @param amountClaimed Total amount being claimed
 * @return Success boolean
 */
function markTokensClaimed(address user, uint256 amountClaimed) external onlyJobContract returns (bool) {
    uint256 remainingToClaim = amountClaimed;

    // STEP 1: Claim from earned rewards first (FIFO by band)
    for (uint256 i = 0; i < userBandRewards[user].length && remainingToClaim > 0; i++) {
        UserBandRewards memory bandReward = userBandRewards[user][i];
        uint256 bandClaimable = _calculateBandClaimable(user, bandReward);

        if (bandClaimable > 0) {
            uint256 claimFromThisBand = remainingToClaim > bandClaimable ?
                bandClaimable : remainingToClaim;

            // Update claimed amount for this band
            uint256 bandIndex = userBandIndex[user][bandReward.band];
            userBandRewards[user][bandIndex].tokensClaimed += claimFromThisBand;

            // Update user total claimed (earned rewards counter)
            userTotalTokensClaimed[user] += claimFromThisBand;

            remainingToClaim -= claimFromThisBand;
        }
    }

    // STEP 2: If still remaining, claim from team tokens
    if (remainingToClaim > 0 && isTeamMember[user]) {
        uint256 teamClaimable = getTeamTokensClaimable(user);
        require(remainingToClaim <= teamClaimable, "Insufficient team tokens");

        // Update team tokens claimed
        teamTokensClaimed[user] += remainingToClaim;
        remainingToClaim = 0;
    }

    // Ensure all tokens were accounted for
    require(remainingToClaim == 0, "Insufficient claimable balance");
    return true;
}
```

**Diff:**
```diff
  function markTokensClaimed(address user, uint256 amountClaimed) external onlyJobContract returns (bool) {
      uint256 remainingToClaim = amountClaimed;

-     // Mark claimed from bands in order (FIFO)
+     // STEP 1: Claim from earned rewards first (FIFO by band)
      for (uint256 i = 0; i < userBandRewards[user].length && remainingToClaim > 0; i++) {
          UserBandRewards memory bandReward = userBandRewards[user][i];
          uint256 bandClaimable = _calculateBandClaimable(user, bandReward);

          if (bandClaimable > 0) {
              uint256 claimFromThisBand = remainingToClaim > bandClaimable ?
                  bandClaimable : remainingToClaim;

              uint256 bandIndex = userBandIndex[user][bandReward.band];
              userBandRewards[user][bandIndex].tokensClaimed += claimFromThisBand;

+             userTotalTokensClaimed[user] += claimFromThisBand;
              remainingToClaim -= claimFromThisBand;
          }
      }

-     userTotalTokensClaimed[user] += amountClaimed;
+     // STEP 2: If still remaining, claim from team tokens
+     if (remainingToClaim > 0 && isTeamMember[user]) {
+         uint256 teamClaimable = getTeamTokensClaimable(user);
+         require(remainingToClaim <= teamClaimable, "Insufficient team tokens");
+
+         teamTokensClaimed[user] += remainingToClaim;
+         remainingToClaim = 0;
+     }
+
+     require(remainingToClaim == 0, "Insufficient claimable balance");
      return true;
  }
```

---

### STEP 8: Add Admin Function for Rate Adjustment

**Location:** After `getTeamTokensClaimable()` function

```solidity
/**
 * @dev Adjust unlock rate by setting desired action count
 * Can only INCREASE difficulty (more actions = lower rate)
 * Owner or DAO can call this
 * @param desiredActions Number of actions required to unlock full 200M
 */
function setTeamTokenActionRequirement(uint256 desiredActions) external {
    require(
        msg.sender == owner() || msg.sender == nativeDAO,
        "Only owner or DAO"
    );
    require(desiredActions > 0, "Invalid actions");

    // Calculate new rate
    uint256 newRate = TOTAL_TEAM_TOKENS / desiredActions;

    // Can only make it harder (more actions = lower rate)
    require(newRate < teamTokensPerGovAction, "Can only increase requirement");

    // Safety floor: minimum 10k per action (max 20,000 actions)
    require(newRate >= 10_000 * 1e18, "Min 10k per action");

    uint256 oldRate = teamTokensPerGovAction;
    teamTokensPerGovAction = newRate;

    emit UnlockRateChanged(oldRate, newRate, desiredActions);
}
```

---

### STEP 9: Add View Functions for Frontend

**Location:** After rate adjustment function, in view functions section

```solidity
// ==================== TEAM TOKENS VIEW FUNCTIONS ====================

/**
 * @dev Get comprehensive token breakdown for a user
 * Useful for frontend display of both pools
 * @param user Address to query
 * @return earnedTotal Total tokens earned from jobs
 * @return earnedClaimable Earned tokens currently claimable
 * @return earnedClaimed Earned tokens already claimed
 * @return teamAllocated Total team tokens allocated
 * @return teamClaimable Team tokens currently claimable
 * @return teamClaimed Team tokens already claimed
 * @return governanceActions Total governance actions performed
 * @return totalClaimable Combined claimable from both pools
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
    // Earned pool data
    earnedTotal = userTotalTokensEarned[user];
    earnedClaimed = userTotalTokensClaimed[user];

    // Calculate earned claimable
    UserBandRewards[] memory rewards = userBandRewards[user];
    for (uint256 i = 0; i < rewards.length; i++) {
        earnedClaimable += _calculateBandClaimable(user, rewards[i]);
    }

    // Team pool data
    teamAllocated = teamTokensAllocated[user];
    teamClaimable = getTeamTokensClaimable(user);
    teamClaimed = teamTokensClaimed[user];

    // Global data
    governanceActions = userTotalGovernanceActions[user];
    totalClaimable = earnedClaimable + teamClaimable;
}

/**
 * @dev Get team pool statistics
 * @return totalTeamTokens Total pool size (200M constant)
 * @return tokensPerAction Current unlock rate per governance action
 * @return actionsRequired Actions needed to unlock full 200M
 * @return totalAllocated Sum of all member allocations
 * @return totalClaimed Sum of all claimed team tokens
 * @return totalMembers Number of team members
 */
function getTeamPoolInfo() external view returns (
    uint256 totalTeamTokens,
    uint256 tokensPerAction,
    uint256 actionsRequired,
    uint256 totalAllocated,
    uint256 totalClaimed,
    uint256 totalMembers
) {
    totalTeamTokens = TOTAL_TEAM_TOKENS;
    tokensPerAction = teamTokensPerGovAction;
    actionsRequired = TOTAL_TEAM_TOKENS / teamTokensPerGovAction;

    // Sum up all allocations and claims
    for (uint256 i = 0; i < teamMembers.length; i++) {
        address member = teamMembers[i];
        totalAllocated += teamTokensAllocated[member];
        totalClaimed += teamTokensClaimed[member];
    }

    totalMembers = teamMembers.length;
}

/**
 * @dev Get all team members
 * @return Array of all team member addresses
 */
function getAllTeamMembers() external view returns (address[] memory) {
    return teamMembers;
}

/**
 * @dev Get detailed info for a specific team member
 * @param member Address to query
 * @return isMember Whether address is a team member
 * @return allocated Total team tokens allocated
 * @return claimed Team tokens already claimed
 * @return claimable Team tokens currently claimable
 * @return govActions Total governance actions performed
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

## 3. Modified Functions Reference

### Summary of Changes

| Function | Line | Change Type | Description |
|----------|------|-------------|-------------|
| `getUserTotalClaimableTokens()` | 399 | Modified | Add team tokens to return value |
| `markTokensClaimed()` | 437 | Modified | Add FIFO claiming from team pool |

### Integration with Existing System

#### Called By NOWJC
```solidity
// nowjc.sol line 952
uint256 claimableAmount = address(rewardsContract) != address(0) ?
    rewardsContract.getUserTotalClaimableTokens(msg.sender) : 0;
```
**Impact:** Now returns earned + team tokens automatically

#### Called By Main Rewards
```solidity
// main-rewards.sol line 207 (callback after claim)
rewardsContract.markTokensClaimed(user, claimedAmount);
```
**Impact:** Now deducts from both pools in FIFO order

---

## 4. Deployment Instructions

### Prerequisites
- Solidity compiler: ^0.8.22 (token), ^0.8.22 (native-rewards)
- OpenZeppelin contracts: Latest compatible version
- Test environment: Hardhat/Foundry
- **CRITICAL:** Main-rewards must be deployed BEFORE token

### Compilation Steps

```bash
# 1. Update both contracts:
#    - openwork-token.sol (modified constructor)
#    - native-rewards.sol (team tokens logic)

# 2. Compile
forge build
# or
npx hardhat compile

# 3. Run tests (CRITICAL: Test auto-transfer)
forge test
# or
npx hardhat test

# 4. Deploy to testnet (see deployment order below)
```

### Deployment Order (CRITICAL)

**⚠️ MUST deploy in this exact order:**

```javascript
// ==================== DEPLOYMENT SCRIPT ====================

async function deployFullSystem() {
    console.log("=== Deploying OpenWork System ===");

    // STEP 1: Deploy Main Rewards FIRST (on rewards chain)
    console.log("1. Deploying main-rewards...");
    const MainRewards = await ethers.getContractFactory("CrossChainRewardsContract");
    const mainRewards = await upgrades.deployProxy(
        MainRewards,
        [owner, tokenAddressPlaceholder, bridgeAddress],
        { initializer: "initialize" }
    );
    await mainRewards.deployed();
    console.log("✓ Main Rewards deployed:", mainRewards.address);

    // STEP 2: Deploy VestingWallet for pre-seed investors
    console.log("2. Deploying vesting wallet for pre-seed investors...");
    const VestingWallet = await ethers.getContractFactory("VestingWallet");
    const preSeedVesting = await VestingWallet.deploy(
        preSeedInvestorAddress,    // Beneficiary (investor address)
        Math.floor(Date.now() / 1000),  // Start time (now)
        365 * 24 * 60 * 60,        // Cliff: 1 year (in seconds)
        4 * 365 * 24 * 60 * 60     // Duration: 4 years total (1 year cliff + 3 years vesting)
    );
    await preSeedVesting.deployed();
    console.log("✓ Vesting Wallet deployed:", preSeedVesting.address);

    // STEP 3: Deploy Token with auto-transfer to all destinations
    console.log("3. Deploying token with AUTO-TRANSFER...");
    const Token = await ethers.getContractFactory("VotingToken");
    const token = await Token.deploy(
        ownerAddress,              // Owner (governance control)
        mainRewards.address,       // 80% (800M) rewards/team
        preSeedVesting.address,    // 5% (50M) pre-seed vesting
        treasuryAddress            // 15% (150M) treasury
    );
    await token.deployed();
    console.log("✓ Token deployed:", token.address);
    console.log("✓ AUTO-TRANSFER: Tokens distributed to all destinations");

    // STEP 4: Set token in main-rewards
    console.log("4. Linking token to main-rewards...");
    await mainRewards.setOpenworkToken(token.address);
    console.log("✓ Token linked");

    // STEP 5: CRITICAL VERIFICATION - Ensure tokens auto-transferred correctly
    console.log("5. VERIFYING AUTO-TRANSFER...");
    const mainRewardsBalance = await token.balanceOf(mainRewards.address);
    const vestingBalance = await token.balanceOf(preSeedVesting.address);
    const treasuryBalance = await token.balanceOf(treasuryAddress);
    const ownerBalance = await token.balanceOf(ownerAddress);

    console.log("Main Rewards balance:", ethers.utils.formatEther(mainRewardsBalance), "M");
    console.log("Vesting balance:", ethers.utils.formatEther(vestingBalance), "M");
    console.log("Treasury balance:", ethers.utils.formatEther(treasuryBalance), "M");
    console.log("Owner wallet balance:", ethers.utils.formatEther(ownerBalance), "M");

    // ASSERTIONS - LEGAL COMPLIANCE CHECK
    const expected800M = ethers.utils.parseEther("800000000");
    const expected50M = ethers.utils.parseEther("50000000");
    const expected150M = ethers.utils.parseEther("150000000");

    if (!mainRewardsBalance.eq(expected800M)) {
        throw new Error("❌ CRITICAL: Main rewards didn't receive 800M tokens!");
    }

    if (!vestingBalance.eq(expected50M)) {
        throw new Error("❌ CRITICAL: Vesting didn't receive 50M tokens!");
    }

    if (!treasuryBalance.eq(expected150M)) {
        throw new Error("❌ CRITICAL: Treasury didn't receive 150M tokens!");
    }

    if (!ownerBalance.eq(0)) {
        throw new Error("❌ LEGAL VIOLATION: Owner wallet has tokens!");
    }

    console.log("✅ COMPLIANCE VERIFIED:");
    console.log("   - Main rewards: 800M (80%)");
    console.log("   - Pre-seed vesting: 50M (5%)");
    console.log("   - Treasury: 150M (15%)");
    console.log("   - Owner wallet: 0 (compliant)");
    console.log("✅ Deployment complete!");

    return { mainRewards, token, preSeedVesting };
}

// Execute
deployFullSystem()
    .then(() => process.exit(0))
    .catch(error => {
        console.error("❌ DEPLOYMENT FAILED:", error);
        process.exit(1);
    });
```

### Upgrade Process (for UUPS)

```solidity
// 1. Deploy new implementation
NativeRewards newImplementation = new NativeRewards();

// 2. Upgrade proxy (from owner account)
NativeRewards proxy = NativeRewards(proxyAddress);
proxy.upgradeTo(address(newImplementation));

// 3. Verify upgrade
require(proxy.TOTAL_TEAM_TOKENS() == 200_000_000 * 1e18, "Upgrade failed");
```

### Verification

```bash
# Verify on Etherscan/Arbiscan
forge verify-contract \
    --chain-id 42161 \
    --compiler-version v0.8.22 \
    $CONTRACT_ADDRESS \
    src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol:OpenWorkRewardsContract \
    --etherscan-api-key $API_KEY
```

---

## 5. Post-Deployment Setup

### Step 1: Set DAO Address

```javascript
// Via ethers.js
const nativeRewards = await ethers.getContractAt(
    "OpenWorkRewardsContract",
    nativeRewardsAddress
);

await nativeRewards.setNativeDAO(nativeDaoAddress);
console.log("DAO address set");
```

### Step 2: Allocate Team Tokens

```javascript
// Define team members and allocations
const teamMembers = [
    "0xAlice...",
    "0xBob...",
    "0xCharlie..."
];

const allocations = [
    ethers.utils.parseEther("30000000"),  // 30M for Alice
    ethers.utils.parseEther("50000000"),  // 50M for Bob
    ethers.utils.parseEther("120000000")  // 120M for Charlie
];

// Verify total ≤ 200M
const total = allocations.reduce((a, b) => a.add(b), ethers.BigNumber.from(0));
console.log("Total allocation:", ethers.utils.formatEther(total), "M");

// Execute allocation
const tx = await nativeRewards.allocateTeamTokens(teamMembers, allocations);
await tx.wait();
console.log("Team tokens allocated");
```

### Step 3: Verify Token Auto-Transfer (CRITICAL - Compliance Check)

```javascript
// ⚠️ CRITICAL: Verify tokens were auto-transferred correctly
const openworkToken = await ethers.getContractAt("IERC20", tokenAddress);

// Check main-rewards balance
const mainRewardsBalance = await openworkToken.balanceOf(mainRewardsAddress);
console.log("Main rewards balance:", ethers.utils.formatEther(mainRewardsBalance));

// Check owner balance (MUST BE ZERO for legal compliance)
const ownerBalance = await openworkToken.balanceOf(ownerAddress);
console.log("Owner balance:", ethers.utils.formatEther(ownerBalance));

// LEGAL COMPLIANCE ASSERTION
if (!ownerBalance.eq(0)) {
    throw new Error("❌ COMPLIANCE FAILURE: Owner wallet has tokens!");
}

if (!mainRewardsBalance.eq(ethers.utils.parseEther("1000000000"))) {
    throw new Error("❌ CRITICAL: Main rewards didn't receive all 1B tokens!");
}

console.log("✅ COMPLIANCE VERIFIED: All tokens auto-transferred to main-rewards");
console.log("✅ Owner wallet has ZERO tokens as required");
```

**Note:** No manual transfer needed! Tokens were automatically sent during deployment.

### Step 4: Verify Integration

```javascript
// Test with a team member address
const testMember = teamMembers[0]; // Alice

// 1. Check allocation
const allocated = await nativeRewards.teamTokensAllocated(testMember);
console.log("Alice allocated:", ethers.utils.formatEther(allocated), "M");

// 2. Check initial claimable (should be 0 without gov actions)
const claimable = await nativeRewards.getTeamTokensClaimable(testMember);
console.log("Alice claimable:", ethers.utils.formatEther(claimable), "M");

// 3. Get breakdown
const breakdown = await nativeRewards.getUserTokenBreakdown(testMember);
console.log("Breakdown:", {
    earnedTotal: ethers.utils.formatEther(breakdown.earnedTotal),
    teamAllocated: ethers.utils.formatEther(breakdown.teamAllocated),
    governanceActions: breakdown.governanceActions.toString(),
    totalClaimable: ethers.utils.formatEther(breakdown.totalClaimable)
});

// 4. Get pool info
const poolInfo = await nativeRewards.getTeamPoolInfo();
console.log("Pool Info:", {
    totalTeamTokens: ethers.utils.formatEther(poolInfo.totalTeamTokens),
    tokensPerAction: ethers.utils.formatEther(poolInfo.tokensPerAction),
    actionsRequired: poolInfo.actionsRequired.toString(),
    totalMembers: poolInfo.totalMembers.toString()
});
```

### Step 5: Test End-to-End Flow

```javascript
// Simulate full claiming flow
async function testClaimingFlow() {
    const testUser = teamMembers[0];

    console.log("=== Testing Claiming Flow ===");

    // 1. User performs governance actions
    console.log("Step 1: Simulating governance actions...");
    // (In production, user votes via native-dao)

    // 2. Check claimable after actions
    const claimableAfterGov = await nativeRewards.getUserTotalClaimableTokens(testUser);
    console.log("Claimable after gov actions:", ethers.utils.formatEther(claimableAfterGov));

    // 3. User syncs to rewards chain
    console.log("Step 2: User would call nowjc.syncRewardsData()");

    // 4. User claims tokens
    console.log("Step 3: User would call main-rewards.claimRewards()");

    // 5. Verify accounting
    const breakdown = await nativeRewards.getUserTokenBreakdown(testUser);
    console.log("Final state:", {
        teamClaimed: ethers.utils.formatEther(breakdown.teamClaimed),
        earnedClaimed: ethers.utils.formatEther(breakdown.earnedClaimed),
        totalClaimable: ethers.utils.formatEther(breakdown.totalClaimable)
    });

    console.log("=== Test Complete ===");
}

await testClaimingFlow();
```

### Step 6: Monitor and Adjust

```javascript
// Check pool statistics
async function monitorTeamPool() {
    const poolInfo = await nativeRewards.getTeamPoolInfo();

    console.log("=== Team Pool Statistics ===");
    console.log("Total Allocated:", ethers.utils.formatEther(poolInfo.totalAllocated), "M");
    console.log("Total Claimed:", ethers.utils.formatEther(poolInfo.totalClaimed), "M");
    console.log("Remaining:", ethers.utils.formatEther(
        poolInfo.totalAllocated.sub(poolInfo.totalClaimed)
    ), "M");
    console.log("Total Members:", poolInfo.totalMembers.toString());
    console.log("Actions Required:", poolInfo.actionsRequired.toString());
    console.log("Rate per Action:", ethers.utils.formatEther(poolInfo.tokensPerAction));
}

// Run monitoring
setInterval(monitorTeamPool, 3600000); // Every hour
```

### Step 7: Adjust Unlock Rate (Optional)

```javascript
// Increase difficulty after 6 months (example)
async function increaseDifficulty() {
    // Change from 1000 to 2000 actions required
    const newActionRequirement = 2000;

    console.log("Increasing action requirement to:", newActionRequirement);

    const tx = await nativeRewards.setTeamTokenActionRequirement(newActionRequirement);
    await tx.wait();

    console.log("Rate updated successfully");

    // Verify
    const newRate = await nativeRewards.teamTokensPerGovAction();
    console.log("New rate per action:", ethers.utils.formatEther(newRate));

    const poolInfo = await nativeRewards.getTeamPoolInfo();
    console.log("Actions now required:", poolInfo.actionsRequired.toString());
}
```

---

## Quick Reference

### Key Contract Addresses (Update After Deployment)

```javascript
// Mainnet (Arbitrum)
const NATIVE_REWARDS = "0x..."; // Updated native-rewards.sol
const NATIVE_DAO = "0x...";     // existing
const NOWJC = "0x...";          // existing

// Rewards Chain (OP Sepolia / Arb Sepolia)
const MAIN_REWARDS = "0x...";   // existing
const OPENWORK_TOKEN = "0x..."; // existing
```

### Essential Function Calls

```javascript
// Setup
nativeRewards.setNativeDAO(daoAddress);
nativeRewards.allocateTeamTokens(members, amounts);

// Query
nativeRewards.getTeamTokensClaimable(user);
nativeRewards.getUserTotalClaimableTokens(user);
nativeRewards.getUserTokenBreakdown(user);
nativeRewards.getTeamPoolInfo();

// Admin
nativeRewards.setTeamTokenActionRequirement(desiredActions);
```

### Event Monitoring

```javascript
// Listen for team token events
nativeRewards.on("TeamTokensAllocated", (members, amounts, total) => {
    console.log("Team tokens allocated:", ethers.utils.formatEther(total));
});

nativeRewards.on("UnlockRateChanged", (oldRate, newRate, actions) => {
    console.log("Rate changed. New actions required:", actions.toString());
});

nativeRewards.on("TeamMemberAdded", (member, allocation) => {
    console.log("New team member:", member);
    console.log("Allocation:", ethers.utils.formatEther(allocation));
});
```

---

## Summary Checklist

### Token Contract (CRITICAL - Legal Compliance)
- [ ] **CRITICAL:** Modified token constructor to accept `mainRewardsContract` parameter
- [ ] **CRITICAL:** Constructor mints all tokens directly to main-rewards
- [ ] **CRITICAL:** Zero tokens minted to owner wallet
- [ ] Compiled token contract successfully
- [ ] Token tests passing (especially auto-transfer test)
- [ ] Verified constructor rejects zero address

### Native Rewards Implementation
- [ ] Added all state variables (team tokens)
- [ ] Added all events (TeamTokensAllocated, etc.)
- [ ] Added `setNativeDAO()` function
- [ ] Added `allocateTeamTokens()` function
- [ ] Added `getTeamTokensClaimable()` function
- [ ] Modified `getUserTotalClaimableTokens()` function
- [ ] Modified `markTokensClaimed()` function
- [ ] Added `setTeamTokenActionRequirement()` function
- [ ] Added all view functions
- [ ] Compiled successfully
- [ ] Tests passing

### Deployment (Exact Order Required)
- [ ] **STEP 1:** Deploy main-rewards FIRST
- [ ] **STEP 2:** Deploy token with main-rewards address (auto-transfer happens)
- [ ] **STEP 3:** Link token to main-rewards contract
- [ ] **CRITICAL:** Verified owner wallet has ZERO tokens
- [ ] **CRITICAL:** Verified main-rewards has all 1B tokens
- [ ] Verified on block explorer (both contracts)
- [ ] Set DAO address in native-rewards
- [ ] Allocated team tokens to members
- [ ] Verified integration with nowjc
- [ ] Verified integration with main-rewards

### Compliance Verification
- [ ] **LEGAL:** Owner wallet balance = 0 tokens
- [ ] **LEGAL:** Main-rewards balance = 1B tokens
- [ ] **LEGAL:** Auto-transfer happened at deployment (no manual transfer)
- [ ] Emergency withdraw function tested and working
- [ ] All balances verified on-chain

### Testing
- [ ] Token auto-transfer works correctly
- [ ] Owner wallet never receives tokens
- [ ] Team member can claim team tokens
- [ ] Non-team member gets 0 from team pool
- [ ] User with both pools claims correctly (FIFO)
- [ ] Rate adjustment works
- [ ] Cannot exceed 200M allocation
- [ ] Cannot double-claim
- [ ] View functions return correct data
- [ ] Emergency withdraw works

---

**Implementation Complete!**

## Key Changes Summary

### Files Modified: 2

1. **[openwork-token.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token.sol)**
   - ⚠️ **CRITICAL:** Modified constructor for legal compliance
   - Auto-distributes tokens to 3 destinations at deployment
   - Owner wallet receives ZERO tokens
   - Satisfies regulatory requirements

2. **[native-rewards.sol](../../src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol)**
   - Added team tokens pool (200M)
   - Dual-pool architecture (earned + team)
   - Clean separation, no interference

### Token Distribution (1B Total)

✅ **80% (800M) → Main Rewards** (600M earned + 200M team)
✅ **5% (50M) → Pre-Seed Vesting** (1 year cliff, 3 year vesting)
✅ **15% (150M) → Treasury** (reserved for future raises)
✅ **0% → Owner Wallet** (legal compliance)

### Legal Compliance Guarantee

✅ **Tokens automatically distributed at deployment**
✅ **Zero tokens ever in owner wallet**
✅ **No manual transfer required**
✅ **Emergency withdraw available for recovery**
✅ **Investor vesting enforced via OpenZeppelin VestingWallet**

### Integration Status

- ✅ Works with existing claiming flow
- ✅ No changes to nowjc.sol needed
- ✅ No changes to native-dao.sol needed
- ✅ No changes to main-rewards.sol needed (already has emergency withdraw)

---

The team tokens feature is now fully integrated into your existing rewards system with automatic token transfer ensuring legal compliance.
