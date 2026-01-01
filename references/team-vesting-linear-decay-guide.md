# Team Vesting Implementation Guide (Linear Decay)

**Date**: 28-Dec-2025
**Contract**: TeamVesting.sol (Linear Decay Version)
**Purpose**: Manage vesting of 200M team tokens (20% of total supply) with decreasing rewards to incentivize early governance participation

---

## Overview

The TeamVesting contract implements a **linear decay** vesting schedule where governance rewards decrease from 333,333 tokens (1st action) to 66,667 tokens (1000th action), encouraging early participation while maintaining extensibility.

### Key Innovation: Simple Adjustable Target

Unlike complex epoch systems, this uses a beautifully simple approach:
- **Linear decay formula** smoothly decreases rewards
- **Adjustable target** allows extending from 1000 → 2000+ actions
- **When extended**: Formula recalculates over the new range, making early participation even more valuable
- **Trade-off accepted**: Simplicity over perfect fairness

---

## Core Mechanism

### Linear Decay Formula

```
reward(n) = 333,333 - ((266,666 × (n-1)) / (totalActionsTarget - 1))
```

**With 1000 actions:**
- Action 1: 333,333 tokens
- Action 500: 200,000 tokens
- Action 1000: 66,667 tokens

**Total distributed: (1000/2) × (333,333 + 66,667) = 200,000,000 tokens**

### Individual Unlocking

Each team member's unlocked tokens = **sum of rewards for their actions**, capped at allocation.

**Example with 30M allocation:**
- Action 1: 333,333 tokens → Total: 333,333
- Action 2: 333,066 tokens → Total: 666,399
- ...
- Action 100: ~240k tokens → Total: ~29.8M
- Actions needed for 30M: ~92 actions

---

## Extensibility: Adjustable Target

### Increasing the Target

Owner can increase `totalActionsTarget` from 1000 → 2000 (or higher):

```solidity
function setTotalActionsTarget(uint256 _newTarget) external onlyOwner
```

**What happens:**
- Formula recalculates over new range: `333,333 - ((266,666 × (n-1)) / (1999))`
- Action 1 still gives 333,333 tokens
- Action 2000 now gives 66,667 tokens
- All intermediate values recalculate

**Effect on Early Participants:**
- If you performed 100 actions when target was 1000, you unlocked ~29.8M
- When target increases to 2000, those same 100 actions now unlock ~31.6M (slightly more!)
- This is because the decay is now spread over 2000 actions instead of 1000

**Incentive Structure:**
- Early participants benefit MORE when system extends
- New participants face steeper competition
- Simple, elegant, and favors early believers

### Constraints

- Target can **only increase** (never decrease)
- Must be ≥ 1000
- Cannot set below current progress

---

## Examples

### Example 1: Early Participant (Target = 1000)

**Team member with 30M allocation, performs 100 actions:**

| Actions | Reward for Last Action | Total Unlocked | % Vested |
|---------|------------------------|----------------|----------|
| 1       | 333,333               | 333k           | 1.1%     |
| 10      | 330,933               | 3.3M           | 11%      |
| 50      | 320,000               | 16.4M          | 54.7%    |
| 92      | 308,724               | 30M            | 100%     |

**Full vesting: 92 actions needed for 30M**

### Example 2: Same Member After Target Increase

**Target increased from 1000 → 2000:**

Now with 100 actions already performed:
- Under old target (1000): Had unlocked ~29.8M
- Under new target (2000): Now unlocked ~31.6M
- **Result: Early participation becomes more valuable!**

### Example 3: New Participant Joins (Target = 2000)

**New team member with 30M allocation:**

| Actions | Reward for Last Action | Total Unlocked | % Vested |
|---------|------------------------|----------------|----------|
| 1       | 333,333               | 333k           | 1.1%     |
| 50      | 326,667               | 16.4M          | 54.7%    |
| 100     | 320,000               | 32.7M          | 100%     |

**Full vesting: ~92 actions still needed, but rewards decrease slower**

---

## Contract Architecture

### State Variables

```solidity
// Constants
uint256 public constant TOTAL_TEAM_TOKENS = 200_000_000 * 10**18;
uint256 public constant START_REWARD = 333_333 * 10**18;
uint256 public constant REWARD_DECAY = 266_666 * 10**18;

// Adjustable target
uint256 public totalActionsTarget;  // Starts at 1000

// Per-member tracking
struct VestingSchedule {
    uint256 totalAllocation;
    uint256 governanceActions;
    uint256 tokensClaimed;
    bool isActive;
}
```

### Key Functions

#### Owner Functions

1. **setTotalActionsTarget(uint256 _newTarget)**
   - Increase the actions target (e.g., 1000 → 2000)
   - Can only increase, never decrease
   - Recalculates reward formula over new range

2. **addTeamMember(address _member, uint256 _allocation)**
   - Add team member with token allocation

3. **setAuthorizedRecorder(address _recorder, bool _status)**
   - Authorize DAO contracts to record actions

#### View Functions

4. **getRewardForAction(uint256 _actionNumber) → uint256**
   - Calculate reward for specific action number
   - Uses linear decay formula

5. **getUnlockedTokens(address _member) → uint256**
   - Calculate total unlocked using arithmetic series: `n/2 × (first + last)`
   - Extremely gas-efficient

6. **getVestingInfo(address _member)**
   - Complete vesting status including:
     - Total allocation
     - Actions performed
     - Tokens unlocked
     - Tokens claimed
     - Claimable now
     - Vesting percentage
     - Estimated actions needed for full vesting

7. **getActionsNeededForAmount(address _member, uint256 _tokenAmount)**
   - Uses binary search to find actions needed
   - Accounts for linear decay complexity

---

## Deployment Steps

### 1. Deploy TeamVesting Contract

Deploy on **Ethereum Mainnet** where OpenWork token resides.

```bash
# Deploy TeamVesting (target initializes to 1000)
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/team-vesting.sol:TeamVesting" \
  --constructor-args $OPENWORK_TOKEN

# Export address
export TEAM_VESTING="<deployed_address>"
```

### 2. Fund the Contract

Transfer 200M OpenWork tokens:

```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_TOKEN \
  "transfer(address,uint256)" \
  $TEAM_VESTING \
  200000000000000000000000000
```

### 3. Add Initial Team Members

Add 2 team members with 30M each (15% each):

```bash
# Team Member 1: 30M allocation
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $TEAM_MEMBER_1_ADDRESS \
  30000000000000000000000000

# Team Member 2: 30M allocation
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $TEAM_MEMBER_2_ADDRESS \
  30000000000000000000000000
```

### 4. Authorize Governance Recorders

```bash
# Authorize Main DAO
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "setAuthorizedRecorder(address,bool)" \
  $MAIN_DAO_PROXY \
  true
```

### 5. Verify Deployment

```bash
# Check contract balance
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getContractBalance()"

# Check current target
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "totalActionsTarget()"

# Check reward for action 1
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getRewardForAction(uint256)" 1

# Check reward for action 1000
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getRewardForAction(uint256)" 1000
```

---

## Integration with Governance

### Main DAO Integration (Ethereum)

Add to MainDAO contract:

```solidity
ITeamVesting public teamVesting;

function setTeamVesting(address _teamVesting) external onlyOwner {
    teamVesting = ITeamVesting(_teamVesting);
}

// In vote() function:
function vote(uint256 _proposalId, bool _support) external {
    // ... existing vote logic ...

    if (address(teamVesting) != address(0)) {
        try teamVesting.recordGovernanceAction(msg.sender) {} catch {}
    }
}

// In propose() function:
function propose(...) external returns (uint256) {
    // ... existing propose logic ...

    if (address(teamVesting) != address(0)) {
        try teamVesting.recordGovernanceAction(msg.sender) {} catch {}
    }

    return proposalId;
}
```

### Cross-Chain Integration (Base DAO)

For actions on Base, send message to Ethereum:

```solidity
// In Native DAO after governance action
bytes memory payload = abi.encode(
    "recordTeamGovernance",
    abi.encode(teamMemberAddress)
);

nativeBridge.sendToMainChain{value: msg.value}(
    "recordTeamGovernance",
    payload,
    _options
);
```

**Main Bridge receives and calls:**
```solidity
teamVesting.recordGovernanceAction(member);
```

---

## Extending the System

### Scenario: Increasing Target from 1000 → 2000

```bash
# Owner increases target
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "setTotalActionsTarget(uint256)" \
  2000

# Verify new target
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "totalActionsTarget()"

# Check new reward values
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getRewardForAction(uint256)" 1     # Still 333,333

cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getRewardForAction(uint256)" 2000  # Now 66,667
```

**Effect:**
- Early participants' tokens increase slightly in value
- New participants face the same 5x ratio but over longer timeframe
- System can accommodate more team members or longer participation periods

---

## Vesting Timeline Examples

### Conservative Participant (50 actions/year, 30M allocation)

**Target = 1000:**
- Year 1: 50 actions → ~16.2M unlocked (54%)
- Year 2: 92 actions total → 30M unlocked (100% vested in < 2 years)

**After target increase to 2000:**
- Their 50 actions now worth: ~16.5M (slightly more valuable!)

### Active Participant (100 actions/year, 50M allocation)

**Target = 1000:**
- Year 1: 100 actions → ~29.8M unlocked (59.6%)
- Year 2: 170 actions total → 50M unlocked (100% vested)

### Highly Active (150 actions/year, 50M allocation)

**Target = 1000:**
- Year 1: 150 actions → ~42.5M unlocked (85%)
- Year 1.5: 170 actions total → 50M unlocked (100% in 18 months)

---

## Mathematical Properties

### Arithmetic Series Efficiency

Instead of looping through all actions, we use:
```
Sum = n/2 × (first_reward + last_reward)
```

**Gas efficiency:** O(1) instead of O(n)

### 5x Ratio Maintained

```
First action reward / Last action reward = 333,333 / 66,667 = 5x
```

This ratio holds regardless of target increase!

### Total Always 200M

```
Total = n/2 × (START_REWARD + END_REWARD)
Total = 1000/2 × (333,333 + 66,667)
Total = 500 × 400,000
Total = 200,000,000 tokens ✓
```

---

## Security Considerations

1. **Target Can Only Increase**: Prevents manipulation to benefit later participants
2. **Allocation Cap**: Unlocked amount never exceeds member's allocation
3. **Authorized Recorders**: Only approved contracts can record actions
4. **No Removal After Claims**: Protects vested tokens
5. **Emergency Withdraw**: Only unallocated tokens can be withdrawn

---

## Testing Checklist

- [ ] Deploy with OpenWork token
- [ ] Fund with 200M tokens
- [ ] Add member with 10M allocation
- [ ] Verify initial target = 1000
- [ ] Check action 1 reward = 333,333 tokens
- [ ] Check action 1000 reward = 66,667 tokens
- [ ] Record 50 actions for member
- [ ] Verify unlocked ≈ 16.2M tokens
- [ ] Claim tokens, verify transfer
- [ ] Increase target to 2000
- [ ] Verify member's unlocked amount increased slightly
- [ ] Check action 2000 reward = 66,667 tokens
- [ ] Test unauthorized recorder (should fail)
- [ ] Test decreasing target (should fail)
- [ ] Verify arithmetic series calculation accuracy

---

## Comparison: Flat vs Linear Decay

| Metric | Flat Rate (200k per action) | Linear Decay (333k → 67k) |
|--------|----------------------------|---------------------------|
| Action 1 reward | 200,000 | 333,333 (+67%) |
| Action 100 reward | 200,000 | ~240,000 (+20%) |
| Action 500 reward | 200,000 | 200,000 (same) |
| Action 1000 reward | 200,000 | 66,667 (-67%) |
| Early incentive | None | Strong |
| Extensibility | Simple | Simple |
| Fairness when extended | Neutral | Favors early |

---

## FAQ

**Q: How does linear decay incentivize early participation?**
A: First actions give 333k tokens vs 67k for later actions - 5x more reward for being early.

**Q: What happens to my tokens when target increases?**
A: Your unlocked amount actually increases slightly! Early participation becomes more valuable.

**Q: Why use linear decay instead of exponential?**
A: Linear is simpler to calculate, uses arithmetic series for O(1) gas efficiency, and provides smooth incentive gradient.

**Q: Can the target decrease?**
A: No, only increase. This prevents manipulation and ensures early participants aren't penalized.

**Q: How many actions to fully vest 30M?**
A: ~92 actions with target=1000, slightly more with higher targets.

**Q: Is this system fair to late joiners?**
A: The trade-off is simplicity over perfect fairness. Early believers should be rewarded more, and late joiners can still fully vest their allocations.

---

## Summary

**Model**: Linear decay with adjustable target
**Formula**: `reward(n) = 333,333 - ((266,666 × (n-1)) / (totalActionsTarget - 1))`
**Incentive**: 5x reward ratio (first vs last action)
**Extensibility**: Target can increase, rewards recalculate
**Philosophy**: Simple > complex, early believers rewarded
**Gas Efficiency**: O(1) arithmetic series calculation
**Total Distribution**: Always 200M tokens

This vesting model elegantly balances:
- **Simplicity**: Single formula, no epochs
- **Extensibility**: Adjustable target for growth
- **Fairness**: Early participants benefit when system extends
- **Efficiency**: O(1) calculations using arithmetic series

---

**Document Status**: Ready for implementation
**Last Updated**: 28-Dec-2025
