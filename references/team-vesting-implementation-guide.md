# Team Vesting Implementation Guide (UUPS Upgradeable)

**Date**: 29-Dec-2025
**Contract**: TeamVesting.sol (UUPS Upgradeable - Reads from Main Rewards)
**Purpose**: Manage vesting of 200M team tokens (20% of total supply) unlocked through governance participation

---

## Overview

The TeamVesting contract implements a **UUPS upgradeable** governance-based vesting schedule that reads action counts from the existing **Main Rewards contract**, eliminating the need for independent action tracking or DAO modifications.

### Key Simplification

**Instead of:**
- Maintaining its own governance action counters
- Requiring DAO contracts to call `recordGovernanceAction()`
- Adding cross-chain messaging for team vesting
- Managing authorized recorders

**TeamVesting now:**
- Reads action counts directly from Main Rewards
- Requires zero integration work (no DAO modifications)
- Reuses existing cross-chain governance tracking
- Only manages allocations and claiming

### Key Mechanism

**Unlock Rate:**
- Total team tokens: **200M**
- Total actions for full unlock: **1000**
- **Tokens per action: 200M / 1000 = 200,000 tokens**

**Individual Unlocking:**
- Each team member has an allocation (e.g., 30M, 50M, 100M tokens)
- TeamVesting reads their action count from Main Rewards
- Each governance action unlocks **200,000 tokens** for them
- Formula: `Claimable = min(actions × 200k, allocation) - already_claimed`

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Main Rewards (Ethereum)                    │
│  - Tracks governance actions from all chains                 │
│  - Already receives cross-chain action updates               │
│  - Function: getGovernanceActions(address) → uint256         │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ READ ONLY
                   ↓
┌─────────────────────────────────────────────────────────────┐
│                  Team Vesting (Ethereum)                     │
│  - Holds 200M team tokens                                    │
│  - Stores member allocations                                 │
│  - Tracks tokens claimed                                     │
│  - Reads actions from Main Rewards                           │
│  - Calculates: unlocked = actions × 200k (capped)           │
│  - Transfers tokens when team members claim                  │
└─────────────────────────────────────────────────────────────┘
```

**Flow when team member claims:**
1. Team member calls `TeamVesting.claimTokens()`
2. TeamVesting calls `MainRewards.getGovernanceActions(member)` (read-only)
3. Calculates: `unlocked = actions × 200k` (capped at allocation)
4. Calculates: `claimable = unlocked - already_claimed`
5. Transfers OpenWork tokens to team member
6. Updates `tokensClaimed` for that member

---

## Examples

### Example 1: Team Member with 50M Allocation

| Actions | Unlocked | Can Claim | % Vested |
|---------|----------|-----------|----------|
| 0 | 0 | 0 | 0% |
| 50 | 10M | 10M | 20% |
| 100 | 20M | 20M | 40% |
| 150 | 30M | 30M | 60% |
| 200 | 40M | 40M | 80% |
| 250 | 50M | 50M | 100% (Fully vested) |
| 300+ | 50M | 50M | 100% (Capped at allocation) |

**Full vesting:** 250 actions needed (50M / 200k)

### Example 2: Team Member with 30M Allocation

| Actions | Unlocked | % Vested |
|---------|----------|----------|
| 0 | 0 | 0% |
| 50 | 10M | 33% |
| 100 | 20M | 67% |
| 150 | 30M | 100% (Fully vested) |

**Full vesting:** 150 actions needed (30M / 200k)

### Example 3: Two Initial Team Members (15% each = 30M each)

**Setup:**
- Member A: 30M tokens allocated
- Member B: 30M tokens allocated

**After 100 actions each (tracked in Main Rewards):**
- Member A: 100 actions → unlocked 20M tokens (67% vested)
- Member B: 100 actions → unlocked 20M tokens (67% vested)

**After 150 actions each:**
- Member A: 150 actions → unlocked 30M tokens (100% vested)
- Member B: 150 actions → unlocked 30M tokens (100% vested)

---

## Contract Architecture

### Core Formula

```solidity
TOKENS_PER_ACTION = 200_000_000 * 10^18 / 1000 = 200_000 * 10^18

// Read from Main Rewards
governanceActions = mainRewards.getGovernanceActions(member);

unlockedTokens = min(
    governanceActions × TOKENS_PER_ACTION,
    totalAllocation
)

claimableTokens = unlockedTokens - tokensClaimed
```

### State Variables

```solidity
IERC20 public immutable openworkToken;   // OpenWork token contract
IMainRewards public mainRewards;         // Main Rewards contract (read-only)

struct VestingSchedule {
    uint256 totalAllocation;      // Total tokens allocated (e.g., 30M, 50M)
    uint256 tokensClaimed;         // Tokens already claimed
    bool isActive;                 // Whether this team member is active
}

mapping(address => VestingSchedule) public vestingSchedules;
address[] public teamMembers;
```

**Notice:** No `governanceActions` field in the struct - we read it from Main Rewards!

### Key Functions

#### Owner Functions

1. **addTeamMember(address _member, uint256 _allocation)**
   - Add a new team member with token allocation
   - Example: `addTeamMember(0x123..., 30000000 * 10^18)` for 30M tokens

2. **setMainRewards(address _mainRewards)**
   - Set/update Main Rewards contract address
   - Required during deployment

3. **removeTeamMember(address _member)**
   - Remove team member (only if they haven't claimed any tokens yet)

4. **updateAllocation(address _member, uint256 _newAllocation)**
   - Update allocation (only before any claims)

#### Claiming

5. **claimTokens()**
   - Team member claims all their unlocked tokens
   - Reads action count from Main Rewards
   - Can be called anytime to claim accumulated unlocked tokens

#### View Functions

6. **getUnlockedTokens(address _member)** → uint256
   - Reads actions from Main Rewards
   - Calculate total unlocked: `min(actions × 200k, allocation)`

7. **getClaimableTokens(address _member)** → uint256
   - Calculate claimable now: `unlocked - claimed`

8. **getGovernanceActions(address _member)** → uint256
   - Helper function to read actions from Main Rewards

9. **getVestingInfo(address _member)**
   - Complete vesting status including:
     - Total allocation
     - Actions performed (from Main Rewards)
     - Tokens unlocked
     - Tokens claimed
     - Claimable now
     - Vesting percentage
     - Actions needed for full vesting

10. **getAllMembersSummary()**
    - Get summary of all team members at once

---

## Deployment Steps (UUPS 3-Step Pattern)

### 1. Deploy TeamVesting Implementation

Deploy on **Ethereum Mainnet** where OpenWork token and Main Rewards reside.

```bash
# Set environment variables
export OPENWORK_TOKEN="<openwork_token_address>"
export MAIN_REWARDS="<main_rewards_proxy_address>"
export DEPLOYER_ADDRESS="<your_deployer_address>"

# Step 1: Deploy Implementation Contract
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/team-vesting.sol:TeamVesting"

# Export implementation address
export TEAM_VESTING_IMPL="<deployed_implementation_address>"
```

### 2. Deploy ERC1967 Proxy

```bash
# Step 2: Deploy ERC1967 Proxy pointing to implementation
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy" \
  --constructor-args $TEAM_VESTING_IMPL 0x

# Export proxy address (THIS is the main address to use)
export TEAM_VESTING="<deployed_proxy_address>"
```

### 3. Initialize the Proxy

```bash
# Step 3: Call initialize through the proxy
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "initialize(address,address,address)" \
  $DEPLOYER_ADDRESS \
  $OPENWORK_TOKEN \
  $MAIN_REWARDS
```

### 4. Fund the Contract

Transfer 200M OpenWork tokens to the TeamVesting **proxy**:

```bash
# Transfer 200M tokens (200,000,000 * 10^18)
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_TOKEN \
  "transfer(address,uint256)" \
  $TEAM_VESTING \
  200000000000000000000000000
```

### 5. Add Initial Team Members

Add the 2 initial team members with their allocations (15% each = 30M each):

```bash
# Allocate 30M tokens to Team Member 1
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $TEAM_MEMBER_1_ADDRESS \
  30000000000000000000000000

# Allocate 30M tokens to Team Member 2
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $TEAM_MEMBER_2_ADDRESS \
  30000000000000000000000000
```

### 6. Verify Deployment

```bash
# Check contract balance (through proxy)
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getContractBalance()"

# Check Main Rewards address is set correctly
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "mainRewards()"

# Check owner is correct
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "owner()"

# Check total allocated
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTotalAllocatedTokens()"

# Check team member count
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTeamMemberCount()"

# Check specific team member info
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING \
  "getVestingInfo(address)" \
  $TEAM_MEMBER_1_ADDRESS
```

---

## Upgrading TeamVesting (UUPS Pattern)

If you need to upgrade the logic after deployment:

### 1. Deploy New Implementation

```bash
# Deploy new implementation with fixes/features
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/team-vesting.sol:TeamVesting"

# Export new implementation address
export TEAM_VESTING_IMPL_V2="<new_implementation_address>"
```

### 2. Upgrade Proxy to New Implementation

```bash
# Upgrade proxy to new implementation (0x = no initialization data)
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "upgradeToAndCall(address,bytes)" \
  $TEAM_VESTING_IMPL_V2 \
  0x
```

### 3. Verify Upgrade

```bash
# Check that functions work as expected
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getContractBalance()"

# All state is preserved (team members, allocations, claims)
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTeamMemberCount()"
```

**Important Notes:**
- Proxy address ($TEAM_VESTING) never changes
- All state is preserved across upgrades
- Only owner can upgrade (via `_authorizeUpgrade`)
- Test implementation thoroughly before upgrading mainnet

---

## Integration with Existing System

### Zero Integration Required!

**The beauty of this simplified approach:**

✅ **No DAO modifications needed** - Main DAO already tracks actions in Main Rewards
✅ **No bridge modifications needed** - Cross-chain messages already sync to Main Rewards
✅ **No additional gas costs** - No extra cross-chain messages needed
✅ **No new infrastructure** - Reuses existing governance tracking

**What already exists:**
1. Main DAO on Ethereum records actions → Main Rewards
2. Native DAO on Base records actions → sends cross-chain → Main Rewards
3. Native Athena on Base records actions → sends cross-chain → Main Rewards
4. Main Rewards already has `getGovernanceActions(address)` function

**What TeamVesting does:**
- Simply reads from Main Rewards when calculating unlocked tokens
- That's it!

---

## Usage Scenarios

### Scenario 1: Team Member Votes on Main DAO

**On Main Chain (Ethereum):**
1. Team member calls `MainDAO.vote(proposalId, true)`
2. Vote is recorded
3. MainDAO updates action count in Main Rewards (existing logic)
4. Team member's action counter in Main Rewards: 50 → 51
5. **No additional steps needed for team vesting!**

**When team member wants to claim:**
1. Team member calls `TeamVesting.claimTokens()`
2. TeamVesting reads: `actions = MainRewards.getGovernanceActions(member)` = 51
3. Calculates: `unlocked = 51 × 200k = 10.2M`
4. Calculates: `claimable = 10.2M - already_claimed`
5. Transfers tokens to team member

### Scenario 2: Team Member Votes on Native DAO

**On Native Chain (Base):**
1. Team member calls `NativeDAO.vote(proposalId, true)`
2. Vote is recorded on Base
3. NativeDAO sends cross-chain message to Main Bridge (existing logic)
4. Main Bridge updates action count in Main Rewards (existing logic)
5. Team member's action counter in Main Rewards: 51 → 52
6. **No additional steps needed for team vesting!**

**When team member wants to claim:**
- Same as Scenario 1 - TeamVesting reads from Main Rewards

### Scenario 3: Team Member Claims Tokens

```bash
# Check claimable amount
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING \
  "getClaimableTokens(address)" \
  $TEAM_MEMBER_ADDRESS

# Team member claims (using their private key)
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $TEAM_MEMBER_PRIVATE_KEY \
  $TEAM_VESTING \
  "claimTokens()"
```

### Scenario 4: Adding New Team Member

```bash
# Owner adds new team member with 50M token allocation
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $NEW_TEAM_MEMBER_ADDRESS \
  50000000000000000000000000

# This new member will need 250 actions to fully vest (50M / 200k = 250)
```

---

## Vesting Timeline Examples

### Conservative Team Member (50 actions/year)

**Allocation: 30M tokens**
- Year 1: 50 actions → 10M unlocked (33%)
- Year 2: 100 actions total → 20M unlocked (67%)
- Year 3: 150 actions total → 30M unlocked (100% vested)

### Active Team Member (100 actions/year)

**Allocation: 50M tokens**
- Year 1: 100 actions → 20M unlocked (40%)
- Year 2: 200 actions total → 40M unlocked (80%)
- Year 3: 250 actions total → 50M unlocked (100% vested)

### Highly Active Team Member (150 actions/year)

**Allocation: 50M tokens**
- Year 1: 150 actions → 30M unlocked (60%)
- Year 2: 250 actions total → 50M unlocked (100% vested in < 2 years)

---

## Security Considerations

### Access Control

1. **Owner Controls**:
   - Only owner can add/remove team members
   - Only owner can update Main Rewards address
   - Only owner can update allocations (before claims)
   - Owner can only withdraw unallocated tokens

2. **Read-Only Integration**:
   - TeamVesting only reads from Main Rewards (cannot write)
   - No risk of manipulation through TeamVesting
   - Main Rewards security model protects action counts

3. **Immutable Token**:
   - OpenWork token address set at deployment, cannot change

### Safety Features

1. **Allocation Cap**: Tokens can never exceed allocated amount
2. **Cannot Remove After Claims**: Protects vested tokens
3. **Cannot Update After Claims**: Prevents allocation manipulation
4. **Emergency Withdraw Protection**: Only unallocated tokens can be withdrawn
5. **Main Rewards Dependency**: If Main Rewards is upgraded, owner can update address

---

## Monitoring and Analytics

### Key Metrics

```bash
# Total allocated
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTotalAllocatedTokens()"

# Total unlocked (reads from Main Rewards for all members)
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTotalUnlockedTokens()"

# Total claimed
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTotalClaimedTokens()"

# All members summary
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getAllMembersSummary()"
```

### Events to Monitor

- `TeamMemberAdded`: Track new team members
- `TokensClaimed`: Track claim activity
- `AllocationUpdated`: Track allocation changes
- `MainRewardsUpdated`: Track Main Rewards address changes

---

## Testing Checklist

### UUPS Deployment
- [ ] Deploy implementation contract
- [ ] Deploy ERC1967 proxy pointing to implementation
- [ ] Initialize proxy with owner, token, and Main Rewards addresses
- [ ] Verify initialization (cannot initialize twice)
- [ ] Fund proxy with 200M test tokens

### Core Functionality
- [ ] Add team member with 10M allocation
- [ ] Verify Main Rewards address is set correctly
- [ ] Record 50 governance actions in Main Rewards (using existing system)
- [ ] Verify TeamVesting reads 50 actions from Main Rewards
- [ ] Verify unlocked = 50 × 200k = 10M tokens
- [ ] Claim 10M tokens
- [ ] Verify claimed balance
- [ ] Record 50 more actions in Main Rewards (100 total)
- [ ] Verify TeamVesting reads 100 actions
- [ ] Verify unlocked capped at 10M allocation

### Edge Cases
- [ ] Test with 30M allocation (150 actions for full vest)
- [ ] Test with 50M allocation (250 actions for full vest)
- [ ] Test emergency withdraw (should only allow unallocated)
- [ ] Test removal before claims (should succeed)
- [ ] Test removal after claims (should fail)
- [ ] Test Main Rewards address update

### UUPS Upgrade
- [ ] Deploy new implementation version
- [ ] Upgrade proxy to new implementation (only owner can)
- [ ] Verify all state preserved after upgrade
- [ ] Verify new/changed functions work correctly
- [ ] Test that non-owner cannot upgrade (should fail)

---

## Advantages of Simplified Approach

### Before (Complex):
- ❌ TeamVesting tracks its own action counters
- ❌ Every DAO needs to call `TeamVesting.recordGovernanceAction()`
- ❌ Requires modifications to Main DAO, Native DAO, Native Athena
- ❌ Requires additional cross-chain messages for team vesting
- ❌ More gas costs for recording actions
- ❌ More complex integration and testing

### After (Simplified):
- ✅ TeamVesting reads from Main Rewards
- ✅ Zero modifications to DAOs or bridges
- ✅ Reuses existing governance tracking infrastructure
- ✅ No additional cross-chain messages
- ✅ No extra gas costs
- ✅ Simple integration - just deploy and fund
- ✅ Same functionality, much simpler implementation

---

## Constants Reference

```solidity
TOTAL_TEAM_TOKENS = 200,000,000 × 10^18
TOTAL_ACTIONS_FOR_FULL_UNLOCK = 1000
TOKENS_PER_ACTION = 200,000 × 10^18
```

**Actions needed for full vesting:**
- 30M allocation: 150 actions
- 50M allocation: 250 actions
- 100M allocation: 500 actions
- 200M allocation: 1000 actions

---

## FAQ

**Q: How does TeamVesting track governance actions?**
A: It doesn't! It reads them from Main Rewards contract using `getGovernanceActions(address)`.

**Q: Do I need to modify my DAOs to integrate team vesting?**
A: No! Your DAOs already update Main Rewards, and TeamVesting reads from there.

**Q: How many actions does it take to fully vest 30M tokens?**
A: 30M / 200k = 150 actions

**Q: If I have 50M allocated and perform 1000 actions, how much can I claim?**
A: min(1000 × 200k, 50M) = min(200M, 50M) = 50M tokens (capped at your allocation)

**Q: Do actions from different chains count the same?**
A: Yes. Whether you vote on Main DAO (Ethereum) or Native DAO (Base), Main Rewards tracks it the same way, and TeamVesting reads that count.

**Q: Can I claim multiple times?**
A: Yes. You can claim anytime. The contract tracks how much you've already claimed and only gives you newly unlocked tokens.

**Q: What happens if I stop participating in governance?**
A: Your tokens remain locked until you resume participation. No time-based vesting - only action-based.

**Q: Can allocations be changed after deployment?**
A: Yes, but only before that team member has claimed any tokens. Once they've claimed, their allocation is locked.

**Q: What if Main Rewards contract is upgraded?**
A: Owner can call `setMainRewards()` to update the address TeamVesting reads from.

---

## Summary

**Team Token Allocation**: 200M tokens (20% of 1B supply)
**Unlock Mechanism**: Individual governance participation (tracked in Main Rewards)
**Unlock Rate**: 200,000 tokens per governance action
**Full Vesting**: Varies by allocation (e.g., 150 actions for 30M, 250 actions for 50M)
**Deployment Chain**: Ethereum Mainnet
**Contract Pattern**: UUPS Upgradeable (consistent with OpenWork system)
**Integration**: Zero - reads from existing Main Rewards contract
**Key Innovation**: Reuses existing infrastructure instead of building parallel system
**Upgradeability**: Can upgrade logic if needed while preserving state

This UUPS upgradeable vesting model ensures team members actively participate in governance to unlock their tokens, while requiring zero additional integration work. It's elegant, simple, upgradeable, and leverages infrastructure that already exists.

---

**Document Status**: Ready for implementation
**Last Updated**: 29-Dec-2025
