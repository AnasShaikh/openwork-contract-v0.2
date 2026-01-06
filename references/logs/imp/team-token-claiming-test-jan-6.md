# Team Token Claiming Test Log - January 6, 2026

**Test Date:** January 6, 2026
**Networks:** Arbitrum Sepolia (Native) ↔ ETH Sepolia (Main)
**Status:** ✅ COMPLETE

---

## Test Participants

| Role | Wallet | Address |
|------|--------|---------|
| Team Member (WALL2) | WALL2_KEY | `0xfD08836eeE6242092a9c869237a8d122275b024A` |

---

## Contract Addresses

### Arbitrum Sepolia (Native Chain)
| Contract | Address |
|----------|---------|
| NOWJC | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` |
| NativeRewards | `0x15CCa7C81A46059A46E794e6d0114c8cd9856715` |
| NativeBridge | `0x0d628bbe01e32df7f32b12d321945fd64d3ee568` |

### ETH Sepolia (Main Chain)
| Contract | Address |
|----------|---------|
| MainRewards | `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C` |
| MainBridge | `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` |
| OpenworkToken | `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd` |

---

## Team Token Logic

Team tokens unlock based on governance actions:
- **Rate:** 150,000 OW tokens per governance action
- **Formula:** `claimable = min(govActions × 150,000, allocated) - claimed`
- **WALL2 Status:**
  - Allocated: 1,000,000 OW
  - Governance Actions: 5
  - Max Unlocked: 5 × 150,000 = 750,000 OW

---

## Pre-Test State

### Arbitrum Sepolia
```
Is Team Member: true
Allocated: 1,000,000 OW
Claimed: 0
Governance Actions: 5
Claimable: 750,000 OW (team) + 746 OW (other rewards) = 750,746 OW
```

### ETH Sepolia
```
Claimable Balance: 0
Total Claimed: 0
WALL2 OW Balance: 0
MainRewards OW Balance: 750,000,000 OW
```

---

## Test Execution

### Phase 0: Initial Verification

**Intent:** Verify current bridge configuration before testing.

**Check 1: NOWJC current bridge**
```bash
source .env && cast call 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "bridge()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
- **Result:** `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` (old bridge - wrong one)

**Check 2: MainRewards current bridge**
```bash
source .env && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C "bridge()" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```
- **Result:** `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` (MainBridge - correct)

**Check 3: Old NativeBridge peer configuration**
```bash
source .env && cast call 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 "peers(uint32)" 40161 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
- **Result:** `0x...a3346ff...` (peer set but mainChainEid was wrong)

---

### Phase 1: Bridge Configuration Fixes

**Problem:** NOWJC was pointing to `0xbCB4401e...` bridge which had `mainChainEid=40231` (Arbitrum itself, not ETH Sepolia). Needed to use `0x0d628bbe...` bridge that's already configured for cross-chain communication with LocalBridge.

**Intent for Fix 1:** Switch NOWJC to use the NativeBridge that's already working for cross-chain (used in dispute tests).

**Fix 1: Update NOWJC bridge**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "setBridge(address)" 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0x452814ed803074534b705bed17507002f09ca2eb88ba973c3e823246f4fcdecb`

**Intent for Fix 2:** The new NativeBridge needs to allow NOWJC to call its functions (sendSyncRewardsData, etc.).

**Fix 2: Authorize NOWJC on NativeBridge**
```bash
source .env && cast send 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  "authorizeContract(address,bool)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0xf930f1c65afd8f8a6f3dad781fd9558bfe87ff73042121919c42c97cf56a86cf`

**Intent for Fix 3:** LayerZero requires peer addresses to be set for each destination chain. NativeBridge needs to know MainBridge address for ETH Sepolia (40161).

**Fix 3: Set peer for ETH Sepolia on NativeBridge**
```bash
source .env && cast send 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  "setPeer(uint32,bytes32)" 40161 \
  0x000000000000000000000000a3346fF590717664efEc8424B2890aC3a7Bd1161 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0x36e79d83dd3227f4639ba14132a643c037809a950f4e89befb22e80810237034`

**Intent for Fix 4:** NativeBridge was originally deployed for local chain communication (mainChainEid=40231). For rewards sync, it needs to send to ETH Sepolia (40161).

**Fix 4: Update NativeBridge mainChainEid to ETH Sepolia**
```bash
source .env && cast send 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  "updateMainChainEid(uint32)" 40161 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0xf0da1c6b82a98bf1834bc3de0ac7f97629b0468cd061fb772cd5097dc584cf6c`

**Intent for Fix 5:** MainBridge peer was pointing to old NativeBridge. Update to new one for bidirectional communication.

**Fix 5: Update MainBridge peer for Arbitrum**
```bash
source .env && cast send 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "setPeer(uint32,bytes32)" 40231 \
  0x0000000000000000000000000d628bbe01e32df7f32b12d321945fd64d3ee568 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0x15508d98f5460eba4528febfd5c5cb79745ba98b7ed621180a7f45a2b84c545a`

---

### Phase 2: Sync Rewards to Main Chain

**Intent:** The native chain (Arbitrum) tracks how many tokens a user has unlocked. This must be synced to the main chain (ETH Sepolia) where the actual OW tokens are stored in MainRewards. The sync sends `totalUnlocked` value which MainRewards uses to calculate claimable balance.

**Step 2.1: Call syncRewardsData() on NOWJC**

This function:
1. Calls `NativeRewards.getUserTotalUnlockedTokens(msg.sender)` to get total unlocked
2. Sends this value to MainBridge via `NativeBridge.sendSyncRewardsData()`
3. LayerZero delivers to MainBridge which calls `MainRewards.handleSyncClaimableRewards()`

```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "syncRewardsData(bytes)" 0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0x08ba4b32269aff36384804c600ac85410e428d828ae525fd9cd56d0eab1fcde6`
- **LZ Options:** `0x0003010011010000000000000000000000000007a120` = 500k gas
- **Value sent:** 0.001 ETH for LayerZero fee
- **Payload:** `syncClaimableRewards` + user address + totalUnlocked (750,746 OW)

**Step 2.2: Wait for LZ Delivery**
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0x08ba4b32269aff36384804c600ac85410e428d828ae525fd9cd56d0eab1fcde6" | jq '.data[0].status'
```
- **Initial Status:** INFLIGHT → Ready for DVNs to verify
- **After ~30s:** INFLIGHT → Verification committed
- **After ~90s:** DELIVERED → Executor transaction confirmed
- **Source:** Arbitrum Sepolia (40231)
- **Destination:** ETH Sepolia (40161)

**Step 2.3: Verify Claimable on MainRewards**

MainRewards receives the sync and calculates: `claimable = totalUnlocked - totalClaimed`
Since totalClaimed was 0, claimable = totalUnlocked = 750,746 OW

```bash
source .env && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C \
  "userClaimableBalance(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```
- **Result:** `0x9ee01263777ae6aa0000` = **750,746 OW** ✅

---

### Phase 3: Claim Tokens

**Intent:** User claims their unlocked tokens from MainRewards. The contract transfers OW tokens to the user and sends a callback to the native chain to update `teamTokensClaimed` (prevents double-claiming).

**Step 3.0: Pre-claim verification**

Before claiming, we verified all conditions in `claimRewards()`:
```solidity
// From main-rewards.sol lines 197-229
function claimRewards(bytes calldata _options) external payable nonReentrant {
    uint256 claimableAmount = userClaimableBalance[msg.sender];
    require(claimableAmount > 0, "No rewards to claim");  // ✅ 750,746 OW
    require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");  // ✅ 750M OW
    // ... transfer and callback
}
```

```bash
# Check all conditions
source .env && echo "1. Claimable:" && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C "userClaimableBalance(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 750,746 OW ✅

source .env && echo "2. Contract balance:" && cast call 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd "balanceOf(address)" 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 750,000,000 OW ✅

source .env && echo "3. Bridge set:" && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C "bridge()" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 ✅

source .env && echo "4. MainRewards authorized:" && cast call 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 "authorizedContracts(address)" 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: true ✅
```

**Step 3.1: Get quote for callback fee**
```bash
source .env && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C \
  "quoteClaimSync(address,uint256,bytes)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  $(cast --to-dec 0x9ee01263777ae6aa0000) \
  0x0003010011010000000000000000000000000007a120 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```
- **Result:** ~0.000023 ETH (we sent 0.0005 ETH to be safe)

**Step 3.2: Call claimRewards() on MainRewards**
```bash
source .env && cast send 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C \
  "claimRewards(bytes)" 0x0003010011010000000000000000000000000007a120 \
  --value 0.0005ether --gas-limit 500000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0xd889041449125a382bde5b1e5be6d88dcdbd4480378b909f6484a8d471b7e9c9`
- **Gas Used:** 323,719
- **Actions performed by contract:**
  1. `userClaimableBalance[msg.sender] = 0` - Reset claimable
  2. `userTotalClaimed[msg.sender] += claimableAmount` - Track claimed
  3. `openworkToken.transfer(msg.sender, claimableAmount)` - Transfer 750,746 OW to WALL2
  4. `bridge.sendToNativeChain("updateUserClaimData", payload, _options)` - Send callback

**Step 3.3: Wait for Callback LZ Delivery**

The callback tells the native chain how much was claimed, so it can update `teamTokensClaimed`.

```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0xd889041449125a382bde5b1e5be6d88dcdbd4480378b909f6484a8d471b7e9c9" | jq '.data[0].status'
```
- **Status:** DELIVERED (~40 seconds)
- **Payload:** `updateUserClaimData` + user address + claimed amount (750,746 OW)
- **Destination handler:** `NativeBridge._lzReceive()` → `NOWJC.handleUpdateUserClaimData()` → `NativeRewards.updateUserClaimData()`

---

### Phase 4: Post-Claim Verification

**Intent:** Verify tokens were received and callback updated native chain state correctly.

**Step 4.1: Verify ETH Sepolia state**
```bash
# WALL2 OW token balance
source .env && cast call 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 0x9ee01263777ae6aa0000 = 750,746 OW ✅

# MainRewards claimable (should be 0)
source .env && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C \
  "userClaimableBalance(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 0 ✅

# MainRewards totalClaimed
source .env && cast call 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C \
  "userTotalClaimed(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 0x9ee01263777ae6aa0000 = 750,746 OW ✅
```

**Step 4.2: Verify Arbitrum state (after callback delivery)**
```bash
# teamTokensClaimed on NativeRewards
source .env && cast call 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "teamTokensClaimed(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Result: 0x9ed194db19b238c00000 = 750,000 OW ✅ (team portion only)

# Team tokens still claimable
source .env && cast call 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "getTeamTokensClaimable(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Result: 0 ✅

# getUserTotalUnlockedTokens (unchanged)
source .env && cast call 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "getUserTotalUnlockedTokens(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Result: 0x9ee01263777ae6aa0000 = 750,746 OW
```

---

## Post-Test State Summary

### ETH Sepolia (Main Chain)
| Field | Value |
|-------|-------|
| WALL2 OW Balance | **750,746 OW** ✅ |
| Claimable Balance | 0 ✅ |
| Total Claimed | 750,746 OW ✅ |

### Arbitrum Sepolia (Native Chain)
| Field | Value |
|-------|-------|
| teamTokensClaimed | **750,000 OW** ✅ |
| Team Claimable | 0 ✅ |
| getUserTotalUnlockedTokens | 750,746 OW |

**Note on amounts:** The 746 OW difference between total (750,746) and team (750,000) comes from other reward types (referral/network rewards) that are also tracked in `getUserTotalUnlockedTokens`.

---

## Expected Flow Diagram

```
Arbitrum Sepolia                           ETH Sepolia
────────────────                           ───────────

NOWJC.syncRewardsData()
    │
    └──► NativeBridge.sendSyncRewardsData()
              │
              └──► LayerZero (40231 → 40161) ──────► MainBridge._lzReceive()
                                                          │
                                                          └──► MainRewards.handleSyncClaimableRewards()
                                                                    │
                                                                    └──► userClaimableBalance = 750,746

                                                    MainRewards.claimRewards()
                                                          │
                                                          ├──► Transfer 750,746 OW to WALL2
                                                          │
                                                          └──► MainBridge.sendToNativeChain()
                                                                    │
NativeBridge._lzReceive() ◄────── LayerZero (40161 → 40231) ───────┘
    │
    └──► NOWJC.handleUpdateUserClaimData()
              │
              └──► NativeRewards.updateUserClaimData()
                        │
                        └──► teamTokensClaimed = 750,000
```

---

## Key Transaction Hashes

| Step | TX Hash | Chain |
|------|---------|-------|
| Update NOWJC bridge | `0x452814ed...` | Arbitrum |
| Authorize NOWJC | `0xf930f1c6...` | Arbitrum |
| Set ETH Sepolia peer | `0x36e79d83...` | Arbitrum |
| Update mainChainEid | `0xf0da1c6b...` | Arbitrum |
| Update MainBridge peer | `0x15508d98...` | ETH Sepolia |
| Sync rewards | `0x08ba4b32...` | Arbitrum |
| Claim tokens | `0xd889041...` | ETH Sepolia |

---

## Notes

- **LZ Options:** `0x0003010011010000000000000000000000000007a120` = 500k gas
- **Sync LZ Delivery:** ~90 seconds
- **Callback LZ Delivery:** ~40 seconds
- **Team tokens vs Total:** Team portion is 750,000 OW, additional 746 OW from other reward types (referral/network)
- **Security:** MainRewards calculates `claimable = totalUnlocked - totalClaimed` to prevent double-claims

---

## Test Result: ✅ PASSED

All objectives completed successfully:
1. ✅ Synced rewards from native to main chain
2. ✅ Claimed OW tokens on main chain
3. ✅ Received callback on native chain
4. ✅ teamTokensClaimed updated correctly

---

**Log Created:** January 6, 2026
**Last Updated:** January 6, 2026
