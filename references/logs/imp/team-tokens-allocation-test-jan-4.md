# Team Token Allocation Test - January 4, 2026

## Overview
Testing team token allocation and voting power integration on Arbitrum Sepolia.

## Contracts
- **Native Rewards (Proxy):** `0x15CCa7C81A46059A46E794e6d0114c8cd9856715`
- **NOWJC (Proxy):** `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`
- **NativeDAO (Proxy):** `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357`
- **Test Address:** `0xfD08836eeE6242092a9c869237a8d122275b024A`

---

## Step 1: Initialize Team Tokens Pool

**Issue Found:** Team token storage variables were 0 (not initialized in upgradeable contract).

### Set Pool Size (150M tokens)
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "setTeamTokensPool(uint256)" "150000000000000000000000000" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX Hash:** `0x8a79dd7483050b727860ff4405cc04eea4941d687921fd5d37ac94157315de4f`

### Set Unlock Rate (1000 actions for full pool = 150k tokens per action)
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "setTeamTokenActionRequirement(uint256)" "1000" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX Hash:** `0x62adb6e55a7bc66fe8690b1290e819fbd79e927cef0734c051c517c77920bada`

---

## Step 2: Allocate Team Tokens

### Allocate 1M tokens to deployer
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "allocateTeamTokens(address[],uint256[])" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" "[1000000000000000000000000]" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX Hash:** `0xd8b972271e3d2fce2b7d52284251b9694fcd199236a3bb4f12c8bca087f5d678`

### Verify Allocation
```bash
source .env && cast call 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "getTeamMemberInfo(address)(bool,uint256,uint256,uint256,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:**
- isMember: true
- allocated: 1,000,000 tokens (1e24)
- claimed: 0
- claimable: 0
- govActions: 0

---

## Step 3: Fix NOWJC Missing Function

**Issue Found:** NativeDAO calls `nowjContract.teamTokensAllocated(address)` but NOWJC didn't have this function.

### Backup Original
```bash
cp src/suites/openwork-full-contract-suite-1-Jan-version/nowjc.sol \
   src/suites/openwork-full-contract-suite-1-Jan-version/nowjc-backup-before-team-tokens-view.sol
```

### Added to NOWJC Interface (IOpenWorkRewards)
```solidity
function teamTokensAllocated(address user) external view returns (uint256);
```

### Added to NOWJC Contract
```solidity
function teamTokensAllocated(address user) external view returns (uint256) {
    if (address(rewardsContract) != address(0)) {
        return rewardsContract.teamTokensAllocated(user);
    }
    return 0;
}
```

### Deploy New Implementation
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/nowjc.sol:NativeOpenWorkJobContract"
```
**New Implementation:** `0xb56133D6af7e90083b6d0DdB210e51B0Cd17D805`
**TX Hash:** `0xbf058d7a31add6f46c925595c3dc60a5b8215fd5f44811f9f48d04bb7f768178`

### Upgrade Proxy
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "upgradeToAndCall(address,bytes)" 0xb56133D6af7e90083b6d0DdB210e51B0Cd17D805 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX Hash:** `0xe5b3e884a9512e55caebca8a5c9ff16c744938ebb43e73730d58497fbe5bb17f`

---

## Step 4: Verify Voting Power

### Test teamTokensAllocated on NOWJC
```bash
source .env && cast call 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "teamTokensAllocated(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** 1,000,000 tokens (1e24)

### Test getVotingPower on NativeDAO
```bash
source .env && cast call 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "getVotingPower(address)(uint256,uint256,uint256,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:**
- own: 0
- delegated: 0
- reward: ~1,000,267 tokens (earned + team)
- total: ~1,000,267 tokens

---

## Summary

| Step | Action | TX Hash |
|------|--------|---------|
| 1 | Set team pool (150M) | `0x8a79dd...` |
| 2 | Set unlock rate (1000 actions) | `0x62adb6...` |
| 3 | Allocate 1M to deployer | `0xd8b972...` |
| 4 | Deploy NOWJC implementation | `0xbf058d...` |
| 5 | Upgrade NOWJC proxy | `0xe5b3e8...` |

**New NOWJC Implementation:** `0xb56133D6af7e90083b6d0DdB210e51B0Cd17D805`
**Previous Implementation:** `0xD9B0Ddd08aDde13ea582e3a4f367B0D7307093f3`

## Notes
- Team tokens require governance actions to unlock (150k tokens per action)
- Claimable = min(allocated, govActions * 150k) - claimed
- Voting power now includes: stake power + delegated + earned tokens + team tokens
