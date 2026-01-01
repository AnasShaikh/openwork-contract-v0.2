# Team Vesting Implementation Guide

**Date**: 28-Dec-2025
**Contract**: TeamVesting.sol
**Purpose**: Manage vesting of 200M team tokens (20% of total supply) unlocked through individual governance participation

---

## Overview

The TeamVesting contract implements a governance-based vesting schedule for team tokens where each team member must perform governance actions to unlock their allocated tokens.

### Key Features

- **Individual Tracking**: Each team member has their own allocation and governance action counter
- **Progressive Unlock**: Tokens unlock in 20% increments every 1000 governance actions
- **Flexible Management**: Owner can add/remove team members and update allocations (before claims)
- **Multi-DAO Integration**: Can receive governance action notifications from multiple contracts (MainDAO, NativeDAO, NativeAthena)
- **Secure Claiming**: Team members can only claim what they've unlocked through participation

---

## Unlock Schedule

| Governance Actions | Unlock Percentage | Cumulative Unlocked |
|-------------------|-------------------|---------------------|
| 0 - 999           | 0%                | 0%                  |
| 1,000 - 1,999     | 20%               | 20%                 |
| 2,000 - 2,999     | 40%               | 40%                 |
| 3,000 - 3,999     | 60%               | 60%                 |
| 4,000 - 4,999     | 80%               | 80%                 |
| 5,000+            | 100%              | 100% (Fully Vested) |

**Example**: If a team member has 100M tokens allocated:
- At 1,000 actions: 20M tokens unlocked
- At 2,500 actions: 40M tokens unlocked
- At 5,000 actions: 100M tokens unlocked (fully vested)

---

## Contract Architecture

### State Variables

```solidity
struct VestingSchedule {
    uint256 totalAllocation;      // Total tokens allocated to this team member
    uint256 governanceActions;     // Number of governance actions performed
    uint256 tokensClaimed;         // Tokens already claimed
    bool isActive;                 // Whether this team member is active
}

mapping(address => VestingSchedule) public vestingSchedules;
mapping(address => bool) public authorizedRecorders;  // Contracts that can record actions
address[] public teamMembers;
```

### Key Functions

#### Owner Functions

1. **addTeamMember(address _member, uint256 _allocation)**
   - Add a new team member with token allocation
   - Can be called anytime to add more team members

2. **removeTeamMember(address _member)**
   - Remove a team member (only if they haven't claimed any tokens yet)

3. **updateAllocation(address _member, uint256 _newAllocation)**
   - Update a team member's allocation (only if they haven't claimed yet)

4. **setAuthorizedRecorder(address _recorder, bool _status)**
   - Authorize contracts to record governance actions
   - Should authorize: MainDAO, NativeDAO, NativeAthena, etc.

#### Governance Tracking Functions

5. **recordGovernanceAction(address _member)**
   - Called by authorized contracts when team member performs governance action
   - Increments the member's governance action counter

6. **recordGovernanceActions(address _member, uint256 _count)**
   - Record multiple governance actions at once (batch)

#### Team Member Functions

7. **claimTokens()**
   - Called by team member to claim all unlocked tokens
   - Automatically calculates claimable amount

#### View Functions

8. **getUnlockedTokens(address _member)** → uint256
   - Calculate total unlocked tokens based on governance actions

9. **getClaimableTokens(address _member)** → uint256
   - Calculate tokens available to claim right now (unlocked - claimed)

10. **getVestingInfo(address _member)**
    - Get complete vesting information for a team member
    - Returns: allocation, actions, unlocked, claimed, claimable, percentage

11. **getNextMilestoneInfo(address _member)**
    - Get info about next unlock milestone
    - Returns: actions needed, next unlock %, next unlock amount

---

## Deployment Steps

### 1. Deploy TeamVesting Contract

Deploy on **Main Chain (Ethereum Mainnet)** where the OpenWork token resides.

```bash
# Deploy TeamVesting
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/team-vesting.sol:TeamVesting" \
  --constructor-args $OPENWORK_TOKEN

# Export address
export TEAM_VESTING="<deployed_address>"
```

### 2. Fund the Contract

Transfer 200M OpenWork tokens to the TeamVesting contract:

```bash
# Transfer 200M tokens (200,000,000 * 10^18)
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_TOKEN \
  "transfer(address,uint256)" \
  $TEAM_VESTING \
  200000000000000000000000000
```

### 3. Add Initial Team Members

Add the 2 initial team members with their allocations:

```bash
# Example: Allocate 100M tokens to Team Member 1
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $TEAM_MEMBER_1_ADDRESS \
  100000000000000000000000000

# Example: Allocate 100M tokens to Team Member 2
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $TEAM_MEMBER_2_ADDRESS \
  100000000000000000000000000
```

### 4. Authorize Governance Recorders

Authorize the DAO contracts to record governance actions:

```bash
# Authorize Main DAO Proxy
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "setAuthorizedRecorder(address,bool)" \
  $MAIN_DAO_PROXY \
  true

# Note: Native DAO and Native Athena are on Base, so they'll need
# to send cross-chain messages to record actions
```

### 5. Verify Deployment

```bash
# Check contract balance
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getContractBalance()"

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

## Integration with Existing System

### Cross-Chain Governance Action Recording

Since governance happens on multiple chains (Ethereum for Main DAO, Base for Native DAO/Athena), you need to set up cross-chain communication.

#### Option 1: Main DAO Records Directly

Main DAO on Ethereum can call TeamVesting directly:

**MainDAO.sol** modification needed:

```solidity
// Add TeamVesting reference
ITeamVesting public teamVesting;

function setTeamVesting(address _teamVesting) external onlyOwner {
    teamVesting = ITeamVesting(_teamVesting);
}

// In vote() function, after recording vote:
if (address(teamVesting) != address(0)) {
    teamVesting.recordGovernanceAction(msg.sender);
}

// In propose() function, after creating proposal:
if (address(teamVesting) != address(0)) {
    teamVesting.recordGovernanceAction(msg.sender);
}
```

#### Option 2: Cross-Chain Messages from Native Chain

For Native DAO and Native Athena on Base, send cross-chain messages:

**Native DAO/Athena** → **Main Bridge** → **TeamVesting**

This requires:
1. Main Bridge to recognize `recordTeamGovernance` message type
2. Main Bridge to call TeamVesting when receiving this message

**MainBridge.sol** modification needed:

```solidity
ITeamVesting public teamVesting;

function setTeamVesting(address _teamVesting) external onlyOwner {
    teamVesting = ITeamVesting(_teamVesting);
}

// In _lzReceive(), add new message type:
function _lzReceive(
    Origin calldata _origin,
    bytes32 _guid,
    bytes calldata _payload,
    address _executor,
    bytes calldata _extraData
) internal override {
    (string memory action, bytes memory data) = abi.decode(_payload, (string, bytes));

    if (keccak256(bytes(action)) == keccak256(bytes("recordTeamGovernance"))) {
        address member = abi.decode(data, (address));
        if (address(teamVesting) != address(0)) {
            teamVesting.recordGovernanceAction(member);
        }
    }
    // ... existing message handlers
}
```

**Native Bridge** → sends message:

```solidity
// In Native DAO/Athena after governance action
bytes memory payload = abi.encode("recordTeamGovernance", abi.encode(teamMemberAddress));
bridge.sendToMainChain{value: msg.value}("recordTeamGovernance", payload, _options);
```

---

## Usage Scenarios

### Scenario 1: Team Member Performing Governance

1. Team member votes on Main DAO proposal
2. Main DAO calls `teamVesting.recordGovernanceAction(teamMember)`
3. Team member's governance action counter increments
4. After 1000 actions, 20% of their allocation is unlocked

### Scenario 2: Team Member Claiming Tokens

```bash
# Team member checks their claimable amount
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING \
  "getClaimableTokens(address)" \
  $TEAM_MEMBER_ADDRESS

# Team member claims
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $TEAM_MEMBER_PRIVATE_KEY \
  $TEAM_VESTING \
  "claimTokens()"
```

### Scenario 3: Adding New Team Member Later

```bash
# Owner adds new team member with 50M token allocation
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $TEAM_VESTING \
  "addTeamMember(address,uint256)" \
  $NEW_TEAM_MEMBER_ADDRESS \
  50000000000000000000000000
```

---

## Security Considerations

### Access Control

1. **Owner Controls**:
   - Only owner can add/remove team members
   - Only owner can authorize recorder contracts
   - Owner can only withdraw unallocated tokens (safety)

2. **Authorized Recorders**:
   - Only authorized contracts can record governance actions
   - Prevents manipulation of unlock progress

3. **Immutable Token Reference**:
   - OpenWork token address set at deployment, cannot change
   - Prevents token address manipulation

### Immutability Rules

1. **Cannot Remove After Claims**:
   - Team members who have claimed tokens cannot be removed
   - Prevents disruption of vesting

2. **Cannot Update Allocation After Claims**:
   - Allocations locked once claiming begins
   - Protects team member rights

3. **Emergency Withdraw Protection**:
   - Owner can only withdraw tokens not allocated to team members
   - Prevents theft of team allocations

---

## Monitoring and Analytics

### Key Metrics to Track

```bash
# Total team tokens allocated
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTotalAllocatedTokens()"

# Total team tokens claimed
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getTotalClaimedTokens()"

# Individual team member progress
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING \
  "getVestingInfo(address)" \
  $TEAM_MEMBER_ADDRESS

# Contract token balance
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TEAM_VESTING "getContractBalance()"
```

### Event Monitoring

Monitor these events for analytics:

- `TeamMemberAdded`: Track new team members
- `GovernanceActionRecorded`: Track participation
- `TokensClaimed`: Track claim activity
- `AllocationUpdated`: Track allocation changes

---

## Testing Checklist

Before mainnet deployment, test:

- [ ] Deploy contract with OpenWork token address
- [ ] Fund contract with test tokens
- [ ] Add team members with allocations
- [ ] Authorize recorder contracts
- [ ] Record governance actions
- [ ] Verify unlock calculations at each milestone (0, 1000, 2000, 3000, 4000, 5000 actions)
- [ ] Test claiming with various unlock percentages
- [ ] Test adding new team members
- [ ] Test emergency withdraw (should fail if tokens allocated)
- [ ] Test removal of team member before claims
- [ ] Test that removal fails after claims
- [ ] Verify cross-chain governance recording (if implemented)
- [ ] Test transfer ownership
- [ ] Test unauthorized access (should fail)

---

## Upgrade Path

Since this is not a UUPS contract, to upgrade:

1. Deploy new TeamVesting contract
2. Transfer remaining tokens from old contract to new
3. Update authorized recorder contracts with new address
4. Notify team members of new contract address

**Recommendation**: Consider making this UUPS upgradeable in v2 if flexibility is needed.

---

## FAQ

**Q: What happens if a team member never performs governance actions?**
A: Their tokens remain locked indefinitely. They must participate to unlock.

**Q: Can team members lose unlocked tokens?**
A: No. Once unlocked, tokens remain claimable. The unlock percentage can only increase.

**Q: What if team member reaches 10,000 governance actions?**
A: Contract caps at 5,000 actions (100% unlock). Additional actions don't increase unlock.

**Q: Can owner change allocations after team member has claimed?**
A: No. Allocations are locked once claiming begins to protect team member rights.

**Q: What happens to unallocated tokens?**
A: Owner can withdraw unallocated tokens using `emergencyWithdraw()`. Allocated tokens cannot be withdrawn.

**Q: Can the same person be added twice?**
A: No. Each address can only be added once. Attempting to re-add will fail.

**Q: How are governance actions counted from different chains?**
A: All actions count equally, whether from Main DAO (Ethereum) or Native DAO/Athena (Base). They increment the same counter.

---

## Summary

**Team Token Allocation**: 200M tokens (20% of 1B supply)
**Unlock Mechanism**: Per-member governance participation
**Unlock Rate**: 20% per 1,000 governance actions
**Full Vesting**: 5,000 governance actions
**Deployment Chain**: Ethereum Mainnet (same as OpenWork token)
**Integration**: Requires modifications to Main DAO and bridges for cross-chain tracking

This vesting model ensures team members are actively participating in governance to unlock their tokens, aligning their interests with platform growth and decentralization.

---

**Document Status**: Ready for review and implementation
**Last Updated**: 28-Dec-2025
