# CCTP + LayerZero Combined Transfer Deployment - January 12, 2025

## 🎯 Overview

Successfully deployed both the CCTPLayerZeroReceiver and CCTPLayerZeroSender contracts, creating a complete CCTP + LayerZero combined transfer system between Optimism Sepolia and Arbitrum Sepolia.

## 📋 Deployment Details

### Receiver Contract (Optimism Sepolia)
- **Contract Name**: `CCTPLayerZeroReceiver`
- **Source File**: `src/current/final-contracts+cctp/simple-receiver-cctp+lz.sol`
- **Network**: Optimism Sepolia (Chain ID: 11155420)
- **Contract Address**: `0xcEa41b526967Aa417bDDb052Dd93F4719AAb8023`
- **Transaction Hash**: `0xfc811634d8d80b6dc1a4ef77268d0f291c841ceeb708811044cf68e6ea4eedd4`
- **Deployer Address**: `0xfD08836eeE6242092a9c869237a8d122275b024A`

### Sender Contract (Arbitrum Sepolia)
- **Contract Name**: `CCTPLayerZeroSender`
- **Source File**: `src/current/final-contracts+cctp/simple-sender-cctp+lz.sol`
- **Network**: Arbitrum Sepolia (Chain ID: 421614)
- **Contract Address**: `0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A` *(Updated - correct USDC address)*
- **Transaction Hash**: `0x21f3a801d831e5cbd94012a3e97d2c2f2d3e71cdc9b7b16c23a41e4de9e3d089`
- **Deployer Address**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Deployment Time**: January 12, 2025

## 🔧 Constructor Parameters

### Receiver Contract (Optimism Sepolia)

1. **_endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f`
   - LayerZero Endpoint V2 for Optimism Sepolia
   
2. **_owner**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
   - Contract owner address
   
3. **_messageTransmitterV2**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
   - CCTP MessageTransmitterV2 for Optimism Sepolia (testnet)
   
4. **_usdc**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
   - USDC token address for Optimism Sepolia

### Sender Contract (Arbitrum Sepolia)

1. **_endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f`
   - LayerZero Endpoint V2 for Arbitrum Sepolia
   
2. **_owner**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
   - Contract owner address
   
3. **_tokenMessengerV2**: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
   - CCTP TokenMessengerV2 for Arbitrum Sepolia (testnet)
   
4. **_usdc**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
   - USDC token address for Arbitrum Sepolia *(Corrected)*
   
5. **_targetCctpDomain**: `2`
   - CCTP domain for Optimism Sepolia
   
6. **_targetLzEid**: `40232`
   - LayerZero EID for Optimism Sepolia
   
7. **_cctpRecipient**: `0x000000000000000000000000cEa41b526967Aa417bDDb052Dd93F4719AAb8023`
   - Receiver contract address in bytes32 format

## 🚀 Deployment Commands Used

### Receiver Contract (Optimism Sepolia)
```bash
source .env && forge create --broadcast --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY src/current/final-contracts+cctp/simple-receiver-cctp+lz.sol:CCTPLayerZeroReceiver --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

### Sender Contract (Arbitrum Sepolia)
```bash
source .env && forge create --broadcast --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY src/current/final-contracts+cctp/simple-sender-cctp+lz.sol:CCTPLayerZeroSender --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d 2 40232 0x000000000000000000000000cEa41b526967Aa417bDDb052Dd93F4719AAb8023
```

## 📊 Network Configuration

### Optimism Sepolia (Receiver Chain)
- **Chain ID**: 11155420
- **LayerZero EID**: 40232
- **RPC URL**: https://sepolia.optimism.io
- **Block Explorer**: https://sepolia-optimism.etherscan.io/
- **CCTP Domain**: 2

### Arbitrum Sepolia (Sender Chain)
- **Chain ID**: 421614
- **LayerZero EID**: 40231
- **RPC URL**: https://sepolia-rollup.arbitrum.io/rpc
- **Block Explorer**: https://sepolia.arbiscan.io/
- **CCTP Domain**: 3

## 🔍 Contract Features

This receiver contract supports:
- **LayerZero Message Reception**: Receives cross-chain data via LayerZero V2
- **CCTP USDC Reception**: Handles CCTP V2 USDC transfers with hook mechanism
- **Combined Transfer Tracking**: Tracks completion when both USDC and data arrive
- **Event Emission**: Emits events for LayerZero data, CCTP USDC, and transfer completion
- **Admin Functions**: Owner can withdraw ETH and USDC balances

## 🎛️ Key Functions

### View Functions
- `getReceivedTransfer(uint256 transferId)` - Get transfer details
- `isTransferComplete(uint256 transferId)` - Check if transfer completed
- `getLatestData()` - Get latest message, numbers, and sum
- `getStats()` - Get total completed transfers and balances

### Admin Functions
- `withdraw()` - Owner can withdraw ETH and USDC

## 📝 Compilation Notes

Contract compiled successfully with Solc 0.8.29 with minor warnings:
- Unused parameter warnings for `_origin` and `sender` (harmless)

## ✅ Status

**Deployment Complete and Ready for Testing**

- ✅ Contract deployed successfully to Optimism Sepolia
- ✅ All constructor parameters properly set
- ✅ Ready to receive LayerZero messages and CCTP transfers
- ✅ Compatible with sender contract deployment

## 🔗 Next Steps

1. Deploy corresponding sender contract to Arbitrum Sepolia
2. Convert receiver address to bytes32 format for sender constructor
3. Set up cross-chain transfer testing
4. Verify message and USDC reception functionality

## 🔄 Testing Attempts & Failures

### Attempt 1: Original Hook-Based Approach
**Sender Contract**: `0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A` (with hook)
**Approach**: Used `depositForBurnWithHook()` with hook data

**Commands Tried**:
```bash
# With empty LayerZero options
cast send 0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A \
  "sendCombined(uint256,string,uint256[],bytes)" \
  1000000 "Hello LayerZero" "[1,2,3]" "0x" \
  --value 0.01ether

# With provided LayerZero options  
cast send 0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A \
  "sendCombined(uint256,string,uint256[],bytes)" \
  100000 "Hello LayerZero" "[1,2,3]" \
  "0x00030100110100000000000000000000000000030d40" \
  --value 0.001ether
```
**Result**: ❌ Gas estimation failed with `execution reverted, data: "0x"`

### Attempt 2: Simplified No-Hook Approach  
**Sender Contract**: `0x74002201465B423b07357A74076F71eC41606e6b` (simplified)
**Approach**: Modified contract to use basic `depositForBurn()` without hooks

**Contract Changes Made**:
- Removed `depositForBurnWithHook()` interface
- Updated to use `depositForBurn()` 
- Removed hook-related constants (`DEFAULT_MAX_FEE`, `SOFT_FINALITY`)
- Simplified transaction logic

**Commands Tried**:
```bash
# Test with new LayerZero options
cast send 0x74002201465B423b07357A74076F71eC41606e6b \
  "sendCombined(uint256,string,uint256[],bytes)" \
  100000 "Hello LayerZero" "[1,2,3]" \
  "0x00030100110100000000000000000000000000055730" \
  --value 0.001ether
```
**Result**: ❌ Same gas estimation failure

### Attempt 3: Direct CCTP Testing (Issue Isolation)
**Approach**: Test CCTP `depositForBurn()` directly to isolate problem

**Commands Tried**:
```bash
# Direct call to TokenMessengerV2
cast send 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA \
  "depositForBurn(uint256,uint32,bytes32,address)" \
  100000 2 \
  0x000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a \
  0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
```
**Result**: ❌ Same gas estimation failure - **CCTP itself is failing**

## 🔍 Configuration Verification

### Successful Setup Steps ✅
1. **LayerZero Peer Configuration**:
   - Sender → Receiver: `setPeer(40232, 0x000...receiver...)`
   - Receiver → Sender: `setPeer(40231, 0x000...sender...)`
   
2. **USDC Approvals**:
   - Approved sender contract: 1,000,000 wei USDC
   - Approved TokenMessengerV2 directly: 1,000,000 wei USDC
   
3. **Contract Verification**:
   - USDC Balance: 17,477,943 wei (≈17.48 USDC)
   - Allowances confirmed via `cast call`
   - Target CCTP domain: 2 (Optimism Sepolia) ✅

### Current Contract Addresses
- **Receiver** (Optimism Sepolia): `0xcEa41b526967Aa417bDDb052Dd93F4719AAb8023` ✅
- **Sender V1** (with hooks): `0x52e710A7597f3a2DC036b1940c8c2CAF69Abbe7A` ❌ 
- **Sender V2** (simplified): `0x74002201465B423b07357A74076F71eC41606e6b` ❌

## 🚨 Root Cause Analysis

**Key Finding**: Direct calls to CCTP TokenMessengerV2 contract fail, indicating the issue is **not with our contract logic** but with:

1. **CCTP Contract Interface**: The `depositForBurn()` function signature may be incorrect
2. **CCTP Contract Functionality**: The contract at `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` may not be functional
3. **Missing Prerequisites**: CCTP may have undocumented setup requirements

## 📋 Transaction Hashes

### Successful Operations
- **Sender V2 Deployment**: `0x8571fa4ad87781e5741a748db41a747f6a66029167bca2ea787988c39ade99c9`
- **Sender V2 Peer Setup**: `0xb25be2e88d94d09bad7ad17cb28419270a07a50cf09be5f97b5d255c1527584a`
- **Receiver Peer Update**: `0x1c4c533433cf10330db97c8aa4e52b3df1c9a35c15b31735f5c115cd64e11a84`
- **USDC Approvals**: `0xd37bb5e4ce7621779dcc9084ed6147101571f369a50d80c87589d0c5b7f491df`, `0xef678b399e579f7667d5e66936582d672200e3bfafa8caa486b61d2dfec43a75`

### Failed Operations
- **All `sendCombined()` calls**: Gas estimation failure
- **Direct CCTP `depositForBurn()`**: Gas estimation failure

## 🔬 Next Steps Required

1. **Verify CCTP Interface**: Find official CCTP V2 interface for Arbitrum Sepolia
2. **Alternative CCTP Addresses**: Check if different TokenMessenger addresses exist
3. **CCTP Documentation**: Consult Circle's official testnet documentation
4. **Expert Consultation**: Get guidance on correct CCTP setup for Arbitrum Sepolia

## 📚 Related Documentation

- `src/current/final-contracts+cctp/deploy-guide.md` - Deployment guide
- `references/logs/wormhole-cctp-deployment-commands.md` - Command format reference
- `references/deployments/cctp-v2-deployments-2025-01-27.md` - CCTP addresses reference
- `references/notes/cctp-layerzero-transaction-failure-report-2025-01-12.md` - Initial failure report

---

**Status**: ❌ **CCTP Contract Issue Identified** - Direct CCTP calls failing, awaiting expert consultation on correct Arbitrum Sepolia CCTP configuration.