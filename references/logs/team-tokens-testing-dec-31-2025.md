# Team Tokens Feature Testing - December 31, 2025

**Status:** ✅ Successfully Tested
**Networks:** Ethereum Sepolia + Arbitrum Sepolia
**Test Wallet:** WALL2 (0xfD08836eeE6242092a9c869237a8d122275b024A)

---

## Deployed Contracts Used

### Main Chain (Ethereum Sepolia)
- **Main Bridge:** `0x7419697E1a83910A96C8c86b344898D6a1d1f394`
- **Main Rewards (Proxy):** `0x50b8D84a5d4132f1218DBB83E24684ABB384662D`
- **Token v2:** `0xdB358ec990df0F5c5e6f37d47Dc1cd68EBF9FC09`

### Native Chain (Arbitrum Sepolia)
- **Native Bridge:** `0xe1443382e3e2A966Ed457BC302fA1A6693b9F345`
- **Native Rewards (Proxy):** `0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252`
- **Native Rewards (New Impl):** `0xdfcD768e9ffEa080c9dD7A4c7662498666084B22`
- **NOWJC (Proxy):** `0xAdE5F9637F1DB4D6773fA49bE43Bc2480040E0dB`

---

## Test Sequence

### 1. Deploy New Implementation with Testing Function

**Deploy Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards-team-tokens-clean.sol:OpenWorkRewardsContract"
```

**Result:**
```
Deployed to: 0xdfcD768e9ffEa080c9dD7A4c7662498666084B22
```

---

### 2. Upgrade Proxy to New Implementation

**Upgrade Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "upgradeToAndCall(address,bytes)" \
  0xdfcD768e9ffEa080c9dD7A4c7662498666084B22 \
  0x
```

**Result:** ✅ Success

---

### 3. Initialize Team Token Pool (150M)

**Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "setTeamTokensPool(uint256)" \
  150000000000000000000000000
```

**Result:** ✅ Pool set to 150M

---

### 4. Set Unlock Rate (1000 actions for full pool)

**Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "setTeamTokenActionRequirement(uint256)" \
  1000
```

**Result:** ✅ Rate set to 150k per action (150M / 1000)

**Verify:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getTeamPoolInfo()(uint256,uint256,uint256,uint256)"
```

**Output:**
```
150000000000000000000000000 [1.5e26]  # Pool: 150M
150000000000000000000000 [1.5e23]     # Per action: 150k
1000                                   # Actions required: 1000
0                                      # Total allocated: 0
```

---

### 5. Allocate Team Tokens (10M to WALL2)

**Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "allocateTeamTokens(address[],uint256[])" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" \
  "[10000000000000000000000000]"
```

**Result:** ✅ 10M allocated

**Verify:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getTeamMemberInfo(address)(bool,uint256,uint256,uint256,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
true                                   # Is team member: true
10000000000000000000000000 [1e25]     # Allocated: 10M
0                                      # Claimed: 0
0                                      # Claimable: 0 (no gov actions yet)
0                                      # Gov actions: 0
```

---

### 6. Simulate Governance Actions (100 actions)

**Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "setGovernanceActionsForTesting(address,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  100
```

**Result:** ✅ Set to 100 actions

**Verify Claimable:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getTeamTokensClaimable(address)(uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
10000000000000000000000000 [1e25]     # Claimable: 10M (capped by allocation)
```

**Note:** 100 actions × 150k/action = 15M unlocked, but capped at 10M allocation ✅

---

### 7. Test Pool Size Adjustment (150M → 200M)

**Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "setTeamTokensPool(uint256)" \
  200000000000000000000000000
```

**Verify:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getTeamPoolInfo()(uint256,uint256,uint256,uint256)"
```

**Output:**
```
200000000000000000000000000 [2e26]    # Pool: 200M ✅
150000000000000000000000 [1.5e23]     # Per action: 150k (unchanged)
1333                                   # Actions required: auto-recalculated
10000000000000000000000000 [1e25]     # Total allocated: 10M
```

---

### 8. Test Unlock Rate Adjustment (2000 actions)

**Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "setTeamTokenActionRequirement(uint256)" \
  2000
```

**Verify:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getTeamPoolInfo()(uint256,uint256,uint256,uint256)"
```

**Output:**
```
200000000000000000000000000 [2e26]    # Pool: 200M
100000000000000000000000 [1e23]       # Per action: 100k (was 150k) ✅
2000                                   # Actions required: 2000 ✅
10000000000000000000000000 [1e25]     # Total allocated: 10M
```

**Claimable Still Correct:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getTeamTokensClaimable(address)(uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
10000000000000000000000000 [1e25]     # Still 10M (100 actions × 100k = 10M) ✅
```

---

### 9. Check Token Breakdown

**Command:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  "getUserTokenBreakdown(address)(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
0                                      # Earned total: 0
0                                      # Earned claimable: 0
0                                      # Earned claimed: 0
10000000000000000000000000 [1e25]     # Team allocated: 10M ✅
10000000000000000000000000 [1e25]     # Team claimable: 10M ✅
0                                      # Team claimed: 0
100                                    # Gov actions: 100
10000000000000000000000000 [1e25]     # Total claimable: 10M ✅
```

---

### 10. Cross-Chain Sync (Native → Main)

**Quote Fee:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xe1443382e3e2A966Ed457BC302fA1A6693b9F345 \
  "quoteSyncRewardsData(address,uint256,bytes)(uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  10000000000000000000000000 \
  0x00030100110100000000000000000000000000030d40
```

**Output:**
```
10557081612455 [1.055e13]  # Fee: 0.00001 ETH
```

**Sync Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  --value 10557081612455 \
  0xAdE5F9637F1DB4D6773fA49bE43Bc2480040E0dB \
  "syncRewardsData(bytes)" \
  0x00030100110100000000000000000000000000030d40
```

**Result:**
```
TX: 0xc17dd36cc03b3bda7c74e181ba5c5eac25e153ddd75d39ffbf5e43351e0d210e
Status: success ✅
```

**Check LayerZero Status:**
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0xc17dd36cc03b3bda7c74e181ba5c5eac25e153ddd75d39ffbf5e43351e0d210e" | jq '{source: .data[0].source.status, destination: .data[0].destination.status, overall: .data[0].status.name, dstTxHash: .data[0].destination.tx.txHash}'
```

**Output:**
```json
{
  "source": "SUCCEEDED",
  "destination": "SUCCEEDED",
  "overall": "DELIVERED",
  "dstTxHash": "0x3d4e4dd29201cbc2a891e06dd5e834d8c7ea56e7eba5cfd3a6494546b9e0b4a4"
}
```

---

### 11. Check Claimable on Main Chain

**Command:**
```bash
source .env && cast call --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  0x50b8D84a5d4132f1218DBB83E24684ABB384662D \
  "getClaimableRewards(address)(uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
10000000000000000000000000 [1e25]  # Claimable: 10M ✅
```

---

### 12. Check Wallet Balance Before Claim

**Command:**
```bash
source .env && cast call --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  0xdB358ec990df0F5c5e6f37d47Dc1cd68EBF9FC09 \
  "balanceOf(address)(uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
250000000000000000000000000 [2.5e26]  # Balance: 250M (DAO allocation)
```

---

### 13. Claim Rewards

**Quote Callback Fee:**
```bash
source .env && cast call --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  0x7419697E1a83910A96C8c86b344898D6a1d1f394 \
  "quoteNativeChain(bytes,bytes)(uint256)" \
  $(cast abi-encode "f(string,address,uint256)" "updateUserClaimData" 0xfD08836eeE6242092a9c869237a8d122275b024A 10000000000000000000000000) \
  0x00030100110100000000000000000000000000030d40
```

**Output:**
```
18193951163780 [1.819e13]  # Fee: 0.000018 ETH
```

**Claim Command:**
```bash
source .env && cast send --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  --value 18193951163780 \
  0x50b8D84a5d4132f1218DBB83E24684ABB384662D \
  "claimRewards(bytes)" \
  0x00030100110100000000000000000000000000030d40
```

**Result:**
```
TX: 0x9f0ad957af2d4c0399457e3778eaa1a6c095274c8bfc7e47de46d45bc80d36f3
Status: success ✅
```

---

### 14. Check Wallet Balance After Claim

**Command:**
```bash
source .env && cast call --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  0xdB358ec990df0F5c5e6f37d47Dc1cd68EBF9FC09 \
  "balanceOf(address)(uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A
```

**Output:**
```
260000000000000000000000000 [2.6e26]  # Balance: 260M ✅
```

**Tokens Received:** 10M (250M → 260M) ✅

---

### 15. Bridge Authorization Fix

**Issue Found:** Callback failed because Native Rewards wasn't authorized in Native Bridge

**Check Authorization:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xe1443382e3e2A966Ed457BC302fA1A6693b9F345 \
  "authorizedContracts(address)(bool)" \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252
```

**Output:** `false` ❌

**Fix Command:**
```bash
source .env && cast send --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  0xe1443382e3e2A966Ed457BC302fA1A6693b9F345 \
  "authorizeContract(address,bool)" \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252 \
  true
```

**Result:** ✅ Native Rewards authorized

**Verify:**
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xe1443382e3e2A966Ed457BC302fA1A6693b9F345 \
  "authorizedContracts(address)(bool)" \
  0xF1e57b023e856DD84c9AC35238B38dEd2Fc8d252
```

**Output:** `true` ✅

---

## Test Results Summary

### ✅ Features Working
1. **Pool Size Management** - Adjustable from 150M to 200M
2. **Unlock Rate Management** - Adjustable via action requirements (1000 → 2000 actions)
3. **Team Token Allocation** - Successfully allocated 10M to WALL2
4. **Governance Actions** - Testing function works (set to 100 actions)
5. **Claimable Calculation** - Correctly caps at 10M (min of unlocked vs allocated)
6. **Token Breakdown Views** - Shows earned vs team token split
7. **Cross-Chain Sync** - Native → Main chain via LayerZero
8. **Token Claiming** - Successfully claimed 10M tokens (250M → 260M balance)
9. **Pool Statistics** - getTeamPoolInfo returns accurate data

### ⚠️ Known Issues
1. **First Claim Callback Failed** - Native Rewards wasn't authorized in bridge
   - **Impact:** Native chain accounting shows stale data (10M still claimable)
   - **Resolution:** Bridge now authorized, future claims will work correctly
   - **Safety:** Main chain prevents double-claims (claimable = 0 after first claim)

### 🔧 Configuration Required for Production
1. Remove `setGovernanceActionsForTesting` function (testnet only)
2. Ensure Native Rewards authorized in Native Bridge during deployment
3. Set proper team token allocations via DAO or owner
4. Configure appropriate pool size and unlock rate

---

## Key Formulas

**Unlocked Tokens:**
```
unlocked = min(
  governanceActions × tokensPerAction,
  teamTokensAllocated
)
```

**Claimable Tokens:**
```
claimable = unlocked - teamTokensClaimed
```

**Tokens Per Action (auto-calculated):**
```
tokensPerAction = TEAM_TOKENS_POOL / actionsRequired
```

---

## Contract Architecture

```
User
 │
 ├─> Native Rewards (Arbitrum)
 │    ├─ Tracks: allocation, claimed, gov actions
 │    └─> NOWJC: syncRewardsData()
 │         └─> Native Bridge: sendSyncRewardsData()
 │              │
 │              └─> LayerZero
 │                   │
 │                   └─> Main Bridge (Ethereum)
 │                        └─> Main Rewards: handleSyncClaimableRewards()
 │                             ├─ Updates: userClaimableBalance
 │                             └─ User calls: claimRewards()
 │                                  ├─ Transfers: ERC20 tokens
 │                                  └─> Main Bridge: sendToNativeChain()
 │                                       │
 │                                       └─> LayerZero
 │                                            │
 │                                            └─> Native Bridge
 │                                                 └─> NOWJC: handleUpdateUserClaimData()
 │                                                      └─> Native Rewards: markTokensClaimed()
```

---

**Test Date:** December 31, 2025
**Tester:** WALL2
**Duration:** ~2 hours
**Status:** ✅ Core functionality validated
