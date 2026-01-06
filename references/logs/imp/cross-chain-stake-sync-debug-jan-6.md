# Cross-Chain Stake Sync Debug Log - January 6, 2026

## Problem Summary

**Issue:** `stake()` and `unstake()` functions on MainDAO (ETH Sepolia) were not syncing stake data cross-chain to NativeDAO/Genesis (Arbitrum Sepolia). The `_sendStakeDataCrossChain()` internal function was failing silently due to try/catch blocks.

**Root Cause:** Insufficient gas allocation. Default gas estimation did not provide enough gas for the LayerZero cross-chain send call.

**Solution:** Explicitly set `--gas-limit 500000` when calling `stake()` or `unstake()`.

---

## Contract Addresses

### ETH Sepolia (Main Chain - EID 40161)
| Contract | Address |
|----------|---------|
| MainDAO Proxy | `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` |
| MainBridge | `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` |
| OpenworkToken | `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd` |

### Arbitrum Sepolia (Native Chain - EID 40231)
| Contract | Address |
|----------|---------|
| NativeDAO Proxy | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` |
| NativeBridge | `0x0d628bbe01e32df7f32b12d321945fd64d3ee568` |
| Genesis | `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` |

### Test Wallet
- **WALL2:** `0xfD08836eeE6242092a9c869237a8d122275b024A`

---

## Symptoms Observed

1. `stake()` transaction succeeded (StakeCreated event emitted)
2. No `StakeDataSentCrossChain` event emitted
3. No LayerZero message found on LZ Scan
4. Genesis on Arbitrum showed zero stake data for user

---

## Debugging Steps

### Step 1: Verify Arbitrum-Side Configuration

**Check NativeBridge.nativeDaoContract:**
```bash
source .env && cast call 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  "nativeDaoContract()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
- **Result:** `0x0` ❌ (not set)

**Fix: Set NativeDaoContract on NativeBridge:**
```bash
source .env && cast send 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  "setNativeDaoContract(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX:** `0xa2471652e1be2d642b4ab1056fe9c4460982c613eb4494ac105816915c2458be`

**Check NativeDAO.authorizedContracts[NativeBridge]:**
```bash
source .env && cast call 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "authorizedContracts(address)" 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
- **Result:** `false` ❌

**Fix: Authorize NativeBridge on NativeDAO:**
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "addAuthorizedContract(address)" 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX:** `0x9bbb9703fd1478c66597ac4db0b3d7c674f50c66acd60ffcd32bd398fbb70a5a`

### Step 2: Verify ETH Sepolia-Side Configuration

**All checks passed:**
```bash
# MainDAO bridge is set
source .env && cast call 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  "bridge()" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 ✅

# MainDAO is authorized on MainBridge
source .env && cast call 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "authorizedContracts(address)" 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: true ✅

# MainBridge nativeChainEid
source .env && cast call 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "nativeChainEid()" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 40231 ✅

# MainBridge peer for Arbitrum
source .env && cast call 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "peers(uint32)" 40231 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: 0x...0d628bbe... ✅

# Quote works
source .env && cast call 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  "quoteStakeUpdate(address,bool,bytes)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A true \
  0x0003010011010000000000000000000000000007a120 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: ~0.000023 ETH ✅

# MainDAO ETH balance
source .env && cast balance 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
# Result: ~0.0079 ETH ✅
```

### Step 3: Test Direct Bridge Call

Since all config was correct, we tested calling MainBridge directly.

**Temporarily authorize WALL2 on MainBridge:**
```bash
source .env && cast send 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "authorizeContract(address,bool)" 0xfD08836eeE6242092a9c869237a8d122275b024A true \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX:** `0xab5af16adea24b35b19751ba9b818d60c8ab760ef45c6553d71650a18617c4c4`

**Direct call to sendToNativeChain:**
```bash
source .env && cast send 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "sendToNativeChain(string,bytes,bytes)" "updateStakeData" \
  $(cast abi-encode "f(string,address,uint256,uint256,uint256,bool)" \
    "updateStakeData" 0xfD08836eeE6242092a9c869237a8d122275b024A \
    500000000000000000000 1767709164 2 true) \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX:** `0x4c6dedc722ac8182f27f41cbc5ae834b22250076dd146772fa01940be6ef72df`
- **Result:** SUCCESS! LZ message sent and delivered ✅

**Verify on LZ Scan:**
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0x4c6dedc722ac8182f27f41cbc5ae834b22250076dd146772fa01940be6ef72df"
```
- **Status:** DELIVERED ✅

**Verify stake synced to Genesis:**
```bash
source .env && cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "getStakerInfo(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
- **Result:** 500 OW, 2 min duration, isActive=true ✅

### Step 4: Test stake() with Explicit Gas Limit

The direct call worked, so the issue was in how MainDAO calls the bridge internally.

**Stake with explicit gas limit:**
```bash
source .env && cast send 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  "stake(uint256,uint256,bytes)" \
  500000000000000000000 \
  2 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --gas-limit 500000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX:** `0xaa6ada896b60f0500d0c3189952f07e2063e1c9b0d048a19463190d1c388bec5`
- **Gas Used:** 430,716
- **Result:** SUCCESS! Both StakeCreated AND StakeDataSentCrossChain events emitted ✅

**Verify LZ message:**
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0xaa6ada896b60f0500d0c3189952f07e2063e1c9b0d048a19463190d1c388bec5"
```
- **Status:** DELIVERED ✅

**Verify updated stake on Genesis:**
```bash
source .env && cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "getStakerInfo(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
- **Result:** Amount=500 OW, unlockTime=1767710400 (new), duration=2, isActive=true ✅

### Step 5: Cleanup - Remove Test Authorization

```bash
source .env && cast send 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 \
  "authorizeContract(address,bool)" 0xfD08836eeE6242092a9c869237a8d122275b024A false \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX:** `0xc8d6b1ef15c502fc7f67826004ef7194752aa788fb2b874936e2fcd2dc7f6310`

---

## Root Cause Analysis

### The Silent Failure Pattern

In `main-dao.sol`, the `_sendStakeDataCrossChain()` function uses try/catch:

```solidity
function _sendStakeDataCrossChain(
    address staker,
    bool isActive,
    bytes memory _options
) internal {
    if (address(bridge) == address(0)) return;

    // ... create payload ...

    uint256 fee = 0;
    try bridge.quoteNativeChain(payload, _options) returns (uint256 quotedFee) {
        fee = quotedFee;
    } catch {
        return;  // SILENT FAIL #1
    }

    if (fee > 0 && address(this).balance >= fee) {
        try bridge.sendToNativeChain{value: fee}("updateStakeData", payload, _options) {
            emit StakeDataSentCrossChain(staker, isActive, fee);
        } catch {
            // SILENT FAIL #2
        }
    }
}
```

### Why Gas Was the Issue

| Transaction Type | Gas Used | Cross-Chain Result |
|-----------------|----------|-------------------|
| stake() with auto gas | ~138k | ❌ Silent failure |
| unstake() with auto gas | ~282k | ❌ Silent failure |
| stake() with --gas-limit 500000 | ~430k | ✅ Success |

The LayerZero `_lzSend()` call requires significant gas. When the transaction runs low on gas during the try block, the call fails and control passes to the empty catch block, resulting in silent failure.

---

## Solution: Always Use Explicit Gas Limit

### For stake():
```bash
source .env && cast send 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  "stake(uint256,uint256,bytes)" \
  AMOUNT_IN_WEI \
  DURATION_MINUTES \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --gas-limit 500000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALLET_KEY
```

### For unstake():
```bash
source .env && cast send 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  "unstake(bytes)" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --gas-limit 500000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALLET_KEY
```

---

## Verification Commands

### Check stake on MainDAO (ETH Sepolia):
```bash
source .env && cast call 0x43eBB3d1db00AEb3af1689b231EaEF066273805f \
  "getStakerInfo(address)" WALLET_ADDRESS \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

### Check stake synced to Genesis (Arbitrum):
```bash
source .env && cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "getStakerInfo(address)" WALLET_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Check LZ message status:
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/TX_HASH" | jq '.data[0].status'
```

---

## Prerequisites Checklist

Before staking, verify these are configured:

### ETH Sepolia (MainDAO side):
- [ ] MainDAO.bridge() = MainBridge address
- [ ] MainBridge.authorizedContracts(MainDAO) = true
- [ ] MainBridge.nativeChainEid() = 40231 (Arbitrum)
- [ ] MainBridge.peers(40231) = NativeBridge address (bytes32)

### Arbitrum Sepolia (NativeDAO side):
- [ ] NativeBridge.nativeDaoContract() = NativeDAO address
- [ ] NativeDAO.authorizedContracts(NativeBridge) = true
- [ ] NativeBridge.allowedSourceChains(40161) = true
- [ ] NativeBridge.peers(40161) = MainBridge address (bytes32)

---

## LZ Options Reference

- **500k gas:** `0x0003010011010000000000000000000000000007a120`
- **1M gas:** `0x000301001101000000000000000000000000000F4240`

---

## Future Recommendations

1. **Frontend/Scripts:** Always set gas limit to 500k+ for stake/unstake calls
2. **Contract Improvement:** Consider removing try/catch or adding explicit error events to surface failures
3. **Monitoring:** Check for `StakeDataSentCrossChain` event after stake transactions - absence indicates sync failure

---

**Debug completed:** January 6, 2026
**Issue resolved:** Cross-chain stake sync now working with explicit gas limit
