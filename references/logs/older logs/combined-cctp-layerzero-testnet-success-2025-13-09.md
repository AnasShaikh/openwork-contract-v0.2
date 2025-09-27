# Combined CCTP + LayerZero Testnet Success - Complete Guide

**Date**: 13 Sep, 2025  
**Status**: ✅ Successfully Demonstrated on Testnet  
**Duration**: ~4 hours from concept to working demo  

## 🎯 What This Achieves

**Atomic cross-chain transfers**: Send USDC via CCTP + custom data via LayerZero in a single transaction. No conflicts, no race conditions, just clean execution.

## 📋 Deployed Contract Addresses

### Successfully Deployed & Configured:
- **Arbitrum Sepolia**: `0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5`
- **OP Sepolia**: `0x683950bf3BB544Eb8FfC70BF0dc1f5C7EBA91270`
- **Contract**: `CCTPLayerZeroCombinedTransceiver`
- **Source File**: `src/current/cctp/cctp-lz-combined-transceiver.sol`

## 🚀 Step-by-Step Replication Commands

### Step 1: Deploy Contracts (if needed)

```bash
# Deploy to Arbitrum Sepolia
forge create --broadcast \
  src/current/cctp/cctp-lz-combined-transceiver.sol:CCTPLayerZeroCombinedTransceiver \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY \
  --constructor-args \
    0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA \
    0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
    0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
    0x6EDCE65403992e310A62460808c4b910D972f10f \
    0xfD08836eeE6242092a9c869237a8d122275b024A

# Deploy to OP Sepolia
forge create --broadcast \
  src/current/cctp/cctp-lz-combined-transceiver.sol:CCTPLayerZeroCombinedTransceiver \
  --rpc-url https://optimism-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY \
  --constructor-args \
    0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA \
    0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
    0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
    0x6EDCE65403992e310A62460808c4b910D972f10f \
    0xfD08836eeE6242092a9c869237a8d122275b024A
```

### Step 2: Configure Chain Mappings

```bash
# Configure OP Sepolia mapping on Arbitrum contract
cast send 0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  "setChainConfig(uint32,uint32,uint32,bool)" \
  11155420 2 40232 true \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY

# Configure Arbitrum Sepolia mapping on OP contract  
cast send 0x683950bf3BB544Eb8FfC70BF0dc1f5C7EBA91270 \
  "setChainConfig(uint32,uint32,uint32,bool)" \
  421614 3 40231 true \
  --rpc-url https://optimism-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY
```

### Step 3: Set LayerZero Peers

```bash
# Set Arbitrum → OP peer
cast send 0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  "setPeer(uint32,bytes32)" \
  40232 \
  0x000000000000000000000000683950bf3BB544Eb8FfC70BF0dc1f5C7EBA91270 \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY

# Set OP → Arbitrum peer
cast send 0x683950bf3BB544Eb8FfC70BF0dc1f5C7EBA91270 \
  "setPeer(uint32,bytes32)" \
  40231 \
  0x0000000000000000000000005e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  --rpc-url https://optimism-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY
```

### Step 4: Approve USDC and Execute Combined Transfer

```bash
# Check balance first (optional)
cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0

# Approve USDC spending
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "approve(address,uint256)" \
  0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  500000 \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY

# Convert recipient to bytes32
cast call 0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  "addressToBytes32(address)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0

# Get LayerZero fee quote (optional)
cast call 0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  "quoteLzFee(uint32,string,uint256[],bytes)" \
  11155420 \
  "Your message here!" \
  "[42,100,200]" \
  "0x00030100110100000000000000000000000000030d40" \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0

# Execute combined transfer 🚀
cast send 0x5e533F0fD6A3b192ecb8c97b3aF93162650c9FA5 \
  "sendCombined(uint32,uint256,bytes32,uint256,string,uint256[],bytes)" \
  11155420 \
  200000 \
  0x000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a \
  100 \
  "Combined CCTP+LZ transfer test!" \
  "[42,100,200]" \
  "0x00030100110100000000000000000000000000030d40" \
  --value 0.01ether \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY
```

### Step 5: Monitor and Complete Transfer

```bash
# Wait 60+ seconds, then get CCTP attestation
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=YOUR_TX_HASH"

# Complete CCTP transfer on OP Sepolia (when attestation is "complete")
cast send 0x683950bf3BB544Eb8FfC70BF0dc1f5C7EBA91270 \
  "receiveCCTP(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url https://optimism-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0 \
  --private-key $WALL2_KEY

# Verify USDC received
cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "balanceOf(address)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url https://optimism-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0
```

## 🔧 Key Configuration Values

### Contract Constructor Parameters:
- **TokenMessenger**: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` (both chains)
- **MessageTransmitter**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` (both chains)
- **LayerZero Endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f` (both chains)

### Chain Mappings:
| Chain | Chain ID | CCTP Domain | LayerZero EID | USDC Address |
|-------|----------|-------------|---------------|--------------|
| OP Sepolia | 11155420 | 2 | 40232 | 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 |
| Arbitrum Sepolia | 421614 | 3 | 40231 | 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d |

### Function Parameters:
- **destinationChainId**: Use chain ID (11155420 for OP, 421614 for Arbitrum)
- **usdcAmount**: In wei (200000 = 0.2 USDC)
- **mintRecipient**: Your address in bytes32 format
- **maxFee**: 100 wei minimum for fast transfer
- **message**: Any string you want to send
- **numbers**: Array of uint256 values
- **lzOptions**: `"0x00030100110100000000000000000000000000030d40"` (standard)

## 🎯 Successful Test Results

**Transaction Hash**: `0x3fa5fe601557d6f49dbcc13eda32b2caf4e2ea988fe7de034f17f2215a9a6a79`

**✅ What Worked Perfectly:**
1. **Atomic Execution**: CCTP burn + LayerZero send in single transaction
2. **No Conflicts**: Both protocols executed cleanly without interference
3. **CCTP Fast Transfer**: 0.2 USDC burned on Arbitrum, ready to mint on OP
4. **LayerZero Message**: "Combined CCTP+LZ transfer test!" + [42,100,200] sent successfully
5. **Event Emissions**: All events fired correctly for tracking

**⏱️ Timing:**
- **Combined Transaction**: Immediate execution
- **CCTP Attestation**: ~60-90 seconds on testnet
- **LayerZero Message**: Delivered automatically by relayers

## 🔑 Critical Success Factors

### 1. **Correct Contract Deployment**
- Must use exact constructor parameters for each chain
- LayerZero endpoint must match chain's official endpoint

### 2. **Proper Configuration**  
- Chain mappings must link CCTP domains to LayerZero EIDs correctly
- LayerZero peers must be set bidirectionally

### 3. **Right Parameters**
- Use chain IDs (not domains/EIDs) in `sendCombined()` 
- maxFee > 0 for CCTP fast transfers
- Sufficient ETH for LayerZero fees (~0.007 ETH)

### 4. **Environment Variables**
```bash
export WALL2_KEY=0720f50ce9cdedb2677f92f40fa9b6eea44fe60508b01eebdcd25500728c71ea
export WALL2_ADDRESS=0xfD08836eeE6242092a9c869237a8d122275b024A
```

## 🚨 Half-Asleep Checklist

**Before running commands:**
- [ ] Source .env file: `source .env`
- [ ] Check USDC balance (need some for transfer)
- [ ] Check ETH balance (need ~0.02 ETH for gas + LZ fees)
- [ ] Contracts already deployed? (see addresses above)

**Configuration needed? (one-time setup):**
- [ ] Chain mappings set on both contracts?
- [ ] LayerZero peers set bidirectionally?  

**Ready to transfer:**
- [ ] Replace YOUR_MESSAGE and numbers in command
- [ ] Replace amount if needed (200000 = 0.2 USDC)
- [ ] Have 0.01+ ETH in transaction for LayerZero fees
- [ ] Copy transaction hash for attestation monitoring

## 🏆 Why This Works

**Clean Separation**: CCTP handles USDC transfers, LayerZero handles arbitrary data. No overlap, no conflicts.

**Atomic Execution**: Both calls happen in same transaction, so either both succeed or both revert. No partial states.

**Battle-Tested Components**: Uses proven LayerZero OApp patterns + working CCTP V2 interfaces from successful mainnet transfers.

**Testnet Proven**: Successfully demonstrated on live testnets with real cross-chain infrastructure.

## 📈 Next Steps for Production

1. **Deploy to Mainnet**: Use mainnet contract addresses and chain IDs
2. **Gas Optimization**: Fine-tune LayerZero options for lower fees  
3. **Error Handling**: Add more sophisticated error recovery
4. **Events Enhancement**: Add more detailed event data for better tracking

---

**Last Updated**: Sep 13, 2025  
**Status**: ✅ Ready for Replication  
**Confidence Level**: 💯 Bulletproof on testnet