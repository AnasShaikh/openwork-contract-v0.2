# Team Tokens Feature - Complete Deployment & Testing Guide

**Feature:** Team Tokens (150M governance-unlocked allocation)
**Date:** December 31, 2025
**Status:** Ready for Deployment
**Version:** 1.0

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Feature Overview](#feature-overview)
3. [Prerequisites](#prerequisites)
4. [Deployment Steps](#deployment-steps)
5. [Configuration](#configuration)
6. [Testing Scenarios](#testing-scenarios)
7. [Verification Commands](#verification-commands)
8. [Troubleshooting](#troubleshooting)
9. [Session Tracking](#session-tracking)

---

## Quick Reference

### Modified Contracts
- ✅ `openwork-token-v2.sol` - Auto-distributes 750M to main-rewards, 250M to DAO
- ✅ `native-rewards-team-tokens-clean.sol` - Original + team tokens functionality

### Key Features
- **150M Team Tokens Pool** (adjustable)
- **150k per governance action** (adjustable, default = 1000 actions for full pool)
- **Owner OR DAO can allocate** team tokens
- **FIFO claiming**: Earned rewards first, then team tokens
- **Zero breaking changes** to existing system

---

## Feature Overview

### Token Distribution (1B Total)

```
┌─────────────────────────────────────────────────┐
│ Token Distribution at Deployment                │
├─────────────────────────────────────────────────┤
│ Main Rewards: 750M (75%)                        │
│   ├─ Earned Rewards: 600M (governance-unlocked) │
│   └─ Team Tokens: 150M (governance-unlocked)    │
│                                                  │
│ DAO Treasury: 250M (25%)                        │
│   ├─ Pre-seed: 50M                              │
│   ├─ Treasury: 150M                             │
│   └─ Team Free: 50M                             │
│                                                  │
│ Owner Wallet: 0 (legal compliance)              │
└─────────────────────────────────────────────────┘
```

### How Team Tokens Work

1. **Allocation**: Owner/DAO allocates specific amounts to team members
   - Example: Alice: 30M, Bob: 50M, Charlie: 70M

2. **Unlocking**: Users perform governance actions (vote/propose)
   - Each action unlocks: 150k tokens (default)
   - Based on TOTAL governance actions (not per-band)

3. **Claiming**: Same flow as earned rewards
   - User syncs via `nowjc.syncRewardsData()`
   - User claims via `main-rewards.claimRewards()`
   - FIFO order: Earned tokens first, then team tokens

4. **Adjustability**:
   - Pool size can be changed (default 150M)
   - Unlock rate can be changed (default 150k/action)
   - Both adjustable by Owner or DAO

---

## Prerequisites

### Environment Setup

```bash
# Load environment variables
source .env

# Required variables:
# - BASE_MAINNET_RPC_URL (for native chain)
# - ETHEREUM_MAINNET_RPC_URL (for main chain)
# - DEPLOYER_PRIVATE_KEY
```

### Existing Deployments Required

- ✅ Native DAO (Base)
- ✅ NOWJC (Base)
- ✅ Main Rewards (Ethereum/Sepolia)
- ✅ Genesis contracts
- ✅ Bridge infrastructure

### Files to Deploy

1. **`openwork-token-v2.sol`** (Main Chain)
   - Location: `src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token-v2.sol`
   - Type: Non-UUPS (regular contract)

2. **`native-rewards-team-tokens-clean.sol`** (Native Chain)
   - Location: `src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards-team-tokens-clean.sol`
   - Type: UUPS (upgradeable)

---

## Deployment Steps

### STEP 1: Deploy Main Rewards (if not already deployed)

**Location:** Ethereum/Optimism Sepolia (rewards chain)

```bash
# 1.1 Deploy Implementation
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/main-rewards.sol:CrossChainRewardsContract"

# Save implementation address
MAIN_REWARDS_IMPL=0x...
```

```bash
# 1.2 Deploy Proxy
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $MAIN_REWARDS_IMPL 0x

# Save proxy address (THIS IS YOUR MAIN REWARDS ADDRESS)
MAIN_REWARDS_PROXY=0x...
```

```bash
# 1.3 Initialize Proxy
# Note: You'll set token address later, use zero address for now
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_REWARDS_PROXY \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0x0000000000000000000000000000000000000000 \
  0xYourMainDAOAddress
```

**✅ Checkpoint 1**: Main Rewards deployed and initialized
- Implementation: `______________________________`
- Proxy: `______________________________`

---

### STEP 2: Deploy OpenWork Token v2

**Location:** Same chain as Main Rewards

**CRITICAL**: This contract auto-distributes tokens at deployment!

```bash
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token-v2.sol:VotingToken" \
  --constructor-args 0xYourMultisigAddress $MAIN_REWARDS_PROXY 0xYourDAOAddress
```

**Constructor Parameters:**
- `initialOwner`: Your multisig address (governance control only)
- `mainRewardsContract`: Main Rewards Proxy address from Step 1
- `daoAddress`: DAO treasury address (receives 250M)

**What Happens Automatically:**
- ✅ 750M tokens → Main Rewards
- ✅ 250M tokens → DAO Treasury
- ✅ 0 tokens → Owner wallet

```bash
# Save token address
TOKEN_ADDRESS=0x...
```

**✅ Checkpoint 2**: Token deployed and auto-distributed
- Token Address: `______________________________`
- Main Rewards Balance: Should be 750M
- DAO Balance: Should be 250M
- Owner Balance: Should be 0

---

### STEP 3: Link Token to Main Rewards

```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_REWARDS_PROXY \
  "setOpenworkToken(address)" \
  $TOKEN_ADDRESS
```

**✅ Checkpoint 3**: Token linked to Main Rewards

---

### STEP 4: Deploy Native Rewards with Team Tokens

**Location:** Base (native chain)

```bash
# 4.1 Deploy Implementation
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards-team-tokens-clean.sol:OpenWorkRewardsContract"

# Save implementation address
NATIVE_REWARDS_IMPL=0x...
```

```bash
# 4.2 Deploy Proxy
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $NATIVE_REWARDS_IMPL 0x

# Save proxy address
NATIVE_REWARDS_PROXY=0x...
```

```bash
# 4.3 Initialize Proxy
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0xYourNOWJCProxyAddress \
  0xYourGenesisProxyAddress
```

**✅ Checkpoint 4**: Native Rewards deployed
- Implementation: `______________________________`
- Proxy: `______________________________`

---

### STEP 5: Update NOWJC to Use New Native Rewards

```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress \
  "setRewardsContract(address)" \
  $NATIVE_REWARDS_PROXY
```

**✅ Checkpoint 5**: NOWJC linked to new Native Rewards

---

## Configuration

### Set Native DAO Address (Enables DAO Allocations)

```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY \
  "setNativeDAO(address)" \
  0xYourNativeDAOProxyAddress
```

**✅ Checkpoint 6**: DAO can now allocate team tokens

---

### Allocate Team Tokens

**Option A: Owner Allocates Directly**

```bash
# Example: Allocate to 3 team members
# Alice: 30M, Bob: 50M, Charlie: 70M (Total: 150M)

cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY \
  "allocateTeamTokens(address[],uint256[])" \
  "[0xAliceAddress,0xBobAddress,0xCharlieAddress]" \
  "[30000000000000000000000000,50000000000000000000000000,70000000000000000000000000]"
```

**Option B: DAO Allocates via Proposal**

1. Create proposal in Native DAO
2. Proposal calls `native-rewards.allocateTeamTokens()`
3. Members vote
4. Execute proposal

**✅ Checkpoint 7**: Team tokens allocated
- Alice: `______________________________` (30M)
- Bob: `______________________________` (50M)
- Charlie: `______________________________` (70M)
- Total Allocated: 150M

---

## Testing Scenarios

### Test 1: Verify Token Distribution

```bash
# Check Main Rewards balance
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $MAIN_REWARDS_PROXY

# Expected: 750000000000000000000000000 (750M with 18 decimals)
```

```bash
# Check DAO balance
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  0xYourDAOAddress

# Expected: 250000000000000000000000000 (250M with 18 decimals)
```

```bash
# Check Owner balance (MUST BE ZERO)
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  0xYourMultisigAddress

# Expected: 0
```

**✅ Test 1 Result:** ________________

---

### Test 2: Check Team Token Configuration

```bash
# Check team tokens pool size
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "TEAM_TOKENS_POOL()(uint256)"

# Expected: 150000000000000000000000000 (150M)
```

```bash
# Check unlock rate
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "teamTokensPerGovAction()(uint256)"

# Expected: 150000000000000000000000 (150k)
```

```bash
# Check DAO address
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "nativeDAO()(address)"

# Expected: Your Native DAO Proxy Address
```

**✅ Test 2 Result:** ________________

---

### Test 3: Verify Team Member Allocation

```bash
# Check Alice's allocation
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getTeamMemberInfo(address)(bool,uint256,uint256,uint256,uint256)" \
  0xAliceAddress

# Expected:
# - isMember: true
# - allocated: 30000000000000000000000000 (30M)
# - claimed: 0
# - claimable: 0 (no governance actions yet)
# - govActions: 0
```

**✅ Test 3 Result:** ________________

---

### Test 4: Complete End-to-End Flow (Alice)

**Step 4.1: Alice performs governance actions**

```bash
# Simulate: Alice votes on 10 proposals
# This would normally happen through Native DAO
# For testing, you can manually call (if you have test functions):
# native-rewards.recordGovernanceAction(alice) x10
```

**Step 4.2: Check Alice's claimable amount**

```bash
# After 10 governance actions:
# Expected: 10 × 150k = 1.5M tokens claimable

cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getTeamTokensClaimable(address)(uint256)" \
  0xAliceAddress

# Expected: 1500000000000000000000000 (1.5M)
```

```bash
# Check total claimable (earned + team)
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getUserTotalClaimableTokens(address)(uint256)" \
  0xAliceAddress

# Expected: 1.5M (team only, assuming no earned tokens)
```

**Step 4.3: Alice syncs to main rewards**

```bash
# Alice calls nowjc.syncRewardsData()
# This sends her claimable amount (1.5M) to main-rewards via bridge
```

**Step 4.4: Alice claims tokens**

```bash
# Alice calls main-rewards.claimRewards()
# She receives 1.5M tokens
# Callback marks them as claimed in native-rewards
```

**Step 4.5: Verify claimed amount**

```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "teamTokensClaimed(address)(uint256)" \
  0xAliceAddress

# Expected: 1500000000000000000000000 (1.5M)
```

```bash
# Check remaining claimable
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getTeamTokensClaimable(address)(uint256)" \
  0xAliceAddress

# Expected: 0 (all 1.5M claimed, needs more gov actions to unlock more)
```

**✅ Test 4 Result:** ________________

---

### Test 5: Non-Team Member (Should Get 0)

```bash
# Check claimable for non-team member
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getTeamTokensClaimable(address)(uint256)" \
  0xRandomUserAddress

# Expected: 0
```

**✅ Test 5 Result:** ________________

---

### Test 6: Adjust Pool Size

```bash
# Increase pool from 150M to 200M
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY \
  "setTeamTokensPool(uint256)" \
  200000000000000000000000000
```

```bash
# Verify new pool size
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "TEAM_TOKENS_POOL()(uint256)"

# Expected: 200000000000000000000000000 (200M)
```

**✅ Test 6 Result:** ________________

---

### Test 7: Adjust Unlock Rate

```bash
# Change from 1000 actions to 1500 actions required
# New rate = 150M / 1500 = 100k per action

cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY \
  "setTeamTokenActionRequirement(uint256)" \
  1500
```

```bash
# Verify new rate
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "teamTokensPerGovAction()(uint256)"

# Expected: 100000000000000000000000 (100k)
```

```bash
# Check impact on Alice (who has 10 actions, already claimed 1.5M):
# With new rate: 10 × 100k = 1M unlocked
# Already claimed: 1.5M
# New claimable: 0 (needs 15 actions to break even)

cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getTeamTokensClaimable(address)(uint256)" \
  0xAliceAddress

# Expected: 0
```

**✅ Test 7 Result:** ________________

---

### Test 8: Get Pool Statistics

```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getTeamPoolInfo()(uint256,uint256,uint256,uint256,uint256,uint256)"

# Expected returns:
# 1. totalPool: 150000000000000000000000000 (150M)
# 2. tokensPerAction: 150000000000000000000000 (150k)
# 3. actionsRequired: 1000
# 4. totalAllocated: 150000000000000000000000000 (150M)
# 5. totalClaimed: (sum of all claimed)
# 6. memberCount: 3
```

**✅ Test 8 Result:** ________________

---

## Verification Commands

### Check Deployment Addresses

```bash
# Token
echo "Token: $TOKEN_ADDRESS"

# Main Rewards
echo "Main Rewards: $MAIN_REWARDS_PROXY"

# Native Rewards
echo "Native Rewards: $NATIVE_REWARDS_PROXY"
```

### Verify Contract Links

```bash
# Verify NOWJC → Native Rewards
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  0xYourNOWJCProxyAddress \
  "rewardsContract()(address)"

# Verify Native Rewards → NOWJC
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "jobContract()(address)"

# Verify Main Rewards → Token
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $MAIN_REWARDS_PROXY \
  "openworkToken()(address)"
```

### Get User Breakdown

```bash
# Get complete breakdown for a user
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getUserTokenBreakdown(address)(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)" \
  0xUserAddress

# Returns:
# 1. earnedTotal
# 2. earnedClaimable
# 3. earnedClaimed
# 4. teamAllocated
# 5. teamClaimable
# 6. teamClaimed
# 7. governanceActions
# 8. totalClaimable (earned + team)
```

---

## Troubleshooting

### Issue 1: Token not auto-distributed

**Symptoms:** Main Rewards balance is 0

**Check:**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  $TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $MAIN_REWARDS_PROXY
```

**Solution:** Token must be deployed with correct constructor parameters. Redeploy token if needed.

---

### Issue 2: Team tokens not claimable

**Symptoms:** `getTeamTokensClaimable()` returns 0

**Checklist:**
1. Is user a team member? `isTeamMember[user]` should be true
2. Has user been allocated tokens? `teamTokensAllocated[user]` > 0
3. Has user performed governance actions? `userTotalGovernanceActions[user]` > 0
4. Already claimed all unlocked? `teamTokensClaimed[user]` < unlocked amount

---

### Issue 3: Cannot allocate team tokens

**Symptoms:** "Only owner or DAO" error

**Check:**
```bash
# Verify caller is owner
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "owner()(address)"

# Verify DAO is set
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "nativeDAO()(address)"
```

**Solution:** Ensure you're calling from owner or DAO address, or set DAO address if not set.

---

### Issue 4: Claiming fails with "Insufficient claimable balance"

**Symptoms:** `markTokensClaimed()` reverts

**Check:**
```bash
# Verify claimable amount matches claim amount
cast call --rpc-url $BASE_MAINNET_RPC_URL \
  $NATIVE_REWARDS_PROXY \
  "getUserTotalClaimableTokens(address)(uint256)" \
  0xUserAddress
```

**Solution:** User can only claim up to their claimable amount. Check both earned and team claimable separately.

---

## Session Tracking

### Deployment Session Log

**Session 1: Initial Deployment**
- Date: ________________
- Deployer: ________________
- Network: ________________
- Status: ________________

**Deployed Contracts:**
- Token: `______________________________`
- Main Rewards: `______________________________`
- Native Rewards: `______________________________`

**Configuration Status:**
- [ ] Token linked to Main Rewards
- [ ] NOWJC linked to Native Rewards
- [ ] DAO address set
- [ ] Team tokens allocated

---

**Session 2: Testing & Verification**
- Date: ________________
- Tester: ________________
- Status: ________________

**Test Results:**
- [ ] Test 1: Token Distribution ✅/❌
- [ ] Test 2: Configuration ✅/❌
- [ ] Test 3: Allocation ✅/❌
- [ ] Test 4: End-to-End Flow ✅/❌
- [ ] Test 5: Non-Member Check ✅/❌
- [ ] Test 6: Pool Adjustment ✅/❌
- [ ] Test 7: Rate Adjustment ✅/❌
- [ ] Test 8: Pool Statistics ✅/❌

---

**Session 3: Production Deployment**
- Date: ________________
- Network: Mainnet
- Status: ________________

**Final Addresses:**
- Token: `______________________________`
- Main Rewards: `______________________________`
- Native Rewards: `______________________________`

**Team Allocations:**
- Member 1: `______________` - `______________` tokens
- Member 2: `______________` - `______________` tokens
- Member 3: `______________` - `______________` tokens

---

## Quick Commands Reference

```bash
# Check team member info
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_REWARDS_PROXY \
  "getTeamMemberInfo(address)(bool,uint256,uint256,uint256,uint256)" <ADDRESS>

# Check team claimable
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_REWARDS_PROXY \
  "getTeamTokensClaimable(address)(uint256)" <ADDRESS>

# Check total claimable
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_REWARDS_PROXY \
  "getUserTotalClaimableTokens(address)(uint256)" <ADDRESS>

# Allocate team tokens
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY "allocateTeamTokens(address[],uint256[])" \
  "[<ADDR1>,<ADDR2>]" "[<AMT1>,<AMT2>]"

# Adjust pool size
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY "setTeamTokensPool(uint256)" <NEW_POOL_SIZE>

# Adjust unlock rate
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY "setTeamTokenActionRequirement(uint256)" <DESIRED_ACTIONS>
```

---

**End of Guide**

For issues or questions, refer to:
- [Deployment Command Templates](../main-net-deployment/DEPLOYMENT_COMMAND_TEMPLATES.md)
- [Feature Specification](../context/team-tokens-feature-specification.md)
- OpenWork team support
