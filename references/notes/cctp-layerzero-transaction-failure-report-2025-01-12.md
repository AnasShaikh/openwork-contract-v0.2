# CCTP + LayerZero Transaction Failure Report - January 12, 2025

## 🎯 Summary

Successfully deployed and configured CCTP + LayerZero combined transfer contracts, but the `sendCombined()` transaction is reverting during gas estimation with no specific error data.

## 📋 What Was Accomplished

### ✅ Contract Deployments
- **Receiver Contract** (Optimism Sepolia): `0xcEa41b526967Aa417bDDb052Dd93F4719AAb8023`
- **Sender Contract** (Arbitrum Sepolia): `0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A` *(Redeployed with correct USDC address)*

### ✅ Contract Configuration
1. **LayerZero Peer Setup**:
   - Sender → Receiver: EID 40232 → `0x000000000000000000000000cEa41b526967Aa417bDDb052Dd93F4719AAb8023`
   - Receiver → Sender: EID 40231 → `0x00000000000000000000000052e710A7597f3a2DC036b1940c8c2CAF69Abbe7A`

2. **USDC Setup**:
   - Balance: 17,477,943 wei (≈17.48 USDC) in wallet `0xfD08836eeE6242092a9c869237a8d122275b024A`
   - Allowance: 1,000,000 wei (1 USDC) approved for sender contract
   - Correct USDC address used: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`

## ❌ The Problem

### Transaction Failure
**Command Attempted**:
```bash
cast send 0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A \
  "sendCombined(uint256,string,uint256[],bytes)" \
  100000 "Hello LayerZero" "[1,2,3]" \
  "0x00030100110100000000000000000000000000030d40" \
  --value 0.001ether --private-key $WALL2_KEY \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc
```

**Error**:
```
Error: Failed to estimate gas: server returned an error response: error code 3: execution reverted, data: "0x"
```

### Attempts Made
1. **Original amount**: 1,000,000 wei (1 USDC) - Failed
2. **Smaller amount**: 100,000 wei (0.1 USDC) - Failed
3. **Different LayerZero options**: Both empty bytes `0x` and provided options `0x00030100110100000000000000000000000000030d40` - Failed

## 🔍 Verified Configurations

### Constructor Parameters Used
**Sender Contract (Arbitrum Sepolia)**:
- `_endpoint`: `0x6EDCE65403992e310A62460808c4b910D972f10f` ✅
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A` ✅
- `_tokenMessengerV2`: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` ❓
- `_usdc`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` ✅
- `_targetCctpDomain`: `2` (Optimism Sepolia) ✅
- `_targetLzEid`: `40232` (Optimism Sepolia) ✅
- `_cctpRecipient`: `0x000000000000000000000000cEa41b526967Aa417bDDb052Dd93F4719AAb8023` ✅

### Verification Results
- **USDC Balance**: ✅ Sufficient (17.48 USDC)
- **USDC Allowance**: ✅ Correct (1 USDC approved)
- **Target CCTP Domain**: ✅ Domain 2 confirmed in contract
- **LayerZero Peers**: ✅ Both directions set correctly
- **Contract Ownership**: ✅ Owner address matches deployer

## 🤔 Potential Issues

### 1. CCTP TokenMessengerV2 Address
The most likely culprit is the CCTP TokenMessengerV2 address: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`

**Source**: Referenced from `references/deployments/cctp-v2-deployments-2025-01-27.md`

**Issue**: This address may be incorrect, outdated, or not compatible with the USDC token address we're using.

### 2. CCTP Hook Implementation
The contract uses `depositForBurnWithHook()` which may have specific requirements or restrictions that aren't being met.

### 3. LayerZero Configuration
While peers are set, there might be additional LayerZero configuration needed that's not obvious from the contract code.

## 📊 Contract Addresses Used

### Arbitrum Sepolia
- **LayerZero Endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f`
- **USDC Token**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **CCTP TokenMessengerV2**: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` ❓
- **CCTP Domain**: 3

### Optimism Sepolia
- **LayerZero Endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f`
- **USDC Token**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
- **CCTP MessageTransmitterV2**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- **CCTP Domain**: 2

## 🔧 Recommended Next Steps

1. **Verify CCTP TokenMessengerV2 Address**: Check Circle's official documentation or contract explorers to confirm the correct TokenMessengerV2 address for Arbitrum Sepolia.

2. **Test CCTP Directly**: Try calling `depositForBurnWithHook()` directly on the TokenMessengerV2 contract to isolate whether the issue is CCTP-specific.

3. **Check LayerZero Requirements**: Verify if there are additional LayerZero setup requirements beyond peer configuration.

4. **Contract Debugging**: Consider adding debug logging or using a local fork to get more detailed error information.

5. **Alternative Approach**: Test with CCTP V1 addresses if V2 is causing issues.

## 📚 Related Files

- **Deployment Doc**: `references/deployments/cctp-layerzero-receiver-deployment-2025-01-12.md`
- **Deploy Guide**: `src/current/final-contracts+cctp/deploy-guide.md`
- **CCTP References**: `references/deployments/cctp-v2-deployments-2025-01-27.md`
- **Sender Contract**: `src/current/final-contracts+cctp/simple-sender-cctp+lz.sol`
- **Receiver Contract**: `src/current/final-contracts+cctp/simple-receiver-cctp+lz.sol`

## 🔗 Transaction Hashes

### Successful Operations
- **Sender Deployment**: `0x21f3a801d831e5cbd94012a3e97d2c2f2d3e71cdc9b7b16c23a41e4de9e3d089`
- **Receiver Deployment**: `0xfc811634d8d80b6dc1a4ef77268d0f291c841ceeb708811044cf68e6ea4eedd4`
- **Sender Peer Setup**: `0xc396c1f46d4978a4d61e12c42765308f899b9bc64ad51b14b86264ca06783445`
- **Receiver Peer Setup**: `0x08704dcff593ed0bb399e73f9ec7d495a70a5552f9328ca55e773bcea0d855ad`
- **USDC Approval**: `0xa089edbc94b4f314f6db678d6ec528016cba16ae60efb159374b73ef84f7e0f4`

### Failed Operation
- **sendCombined()**: Gas estimation failure, no transaction hash generated

---

**Status**: ❌ Awaiting expert consultation to resolve CCTP transaction reversion issue.