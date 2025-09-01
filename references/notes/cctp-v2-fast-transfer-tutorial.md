# CCTP V2 Fast Transfer Tutorial for Dummies 🚀

**TL;DR**: Send USDC across chains in ~60 seconds with minimal fees using Circle's CCTP V2 Fast Transfer.

## Prerequisites
- Foundry installed
- Private key with testnet ETH on both chains
- USDC tokens from https://faucet.circle.com

## Step 1: Deploy the Transceiver Contract

### On Source Chain (OP Sepolia)
```bash
forge create --broadcast \
  src/current/cctp/cctp-v2-ft-transceiver.sol:CCTPv2Transceiver \
  --rpc-url https://optimism-sepolia.infura.io/v3/YOUR_KEY \
  --private-key 0xYOUR_PRIVATE_KEY \
  --constructor-args \
    0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA \
    0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
    0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

### On Destination Chain (Arbitrum Sepolia)
```bash
forge create --broadcast \
  src/current/cctp/cctp-v2-ft-transceiver.sol:CCTPv2Transceiver \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/YOUR_KEY \
  --private-key 0xYOUR_PRIVATE_KEY \
  --constructor-args \
    0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA \
    0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
    0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
```

**Save both contract addresses!**

## Step 2: Approve USDC Spending

```bash
# Approve USDC for the source chain transceiver
cast send 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "approve(address,uint256)" YOUR_SOURCE_CONTRACT 1000000 \
  --rpc-url https://optimism-sepolia.infura.io/v3/YOUR_KEY \
  --private-key 0xYOUR_PRIVATE_KEY
```

## Step 3: Send Fast Transfer

```bash
# Convert recipient address to bytes32 first
RECIPIENT_BYTES32=$(cast call YOUR_SOURCE_CONTRACT \
  "addressToBytes32(address)(bytes32)" YOUR_RECIPIENT_ADDRESS \
  --rpc-url https://optimism-sepolia.infura.io/v3/YOUR_KEY)

# Send fast transfer (250,000 wei = 0.25 USDC)
cast send YOUR_SOURCE_CONTRACT \
  "sendFast(uint256,uint32,bytes32,uint256)" \
  250000 \
  3 \
  $RECIPIENT_BYTES32 \
  100 \
  --rpc-url https://optimism-sepolia.infura.io/v3/YOUR_KEY \
  --private-key 0xYOUR_PRIVATE_KEY
```

**🎯 Save the transaction hash!**

## Step 4: Get Attestation (Wait ~60 seconds)

```bash
# Replace with your transaction hash and source domain (2 for OP Sepolia)
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=YOUR_TX_HASH"
```

**Wait for `"status": "complete"` then extract:**
- `"message"`: The CCTP message bytes
- `"attestation"`: The attestation signature

## Step 5: Complete Transfer on Destination

```bash
# Use the message and attestation from API response
cast send YOUR_DESTINATION_CONTRACT \
  "receive(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/YOUR_KEY \
  --private-key 0xYOUR_PRIVATE_KEY
```

## Step 6: Verify Success

```bash
# Check USDC balance on destination
cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)" YOUR_RECIPIENT_ADDRESS \
  --rpc-url https://arbitrum-sepolia.infura.io/v3/YOUR_KEY
```

## 🔧 Key Parameters

### Chain Details
| Chain | Domain | USDC Address |
|-------|---------|--------------|
| OP Sepolia | 2 | 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 |
| Arbitrum Sepolia | 3 | 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d |

### Constructor Args (Same for both chains)
- **TokenMessenger**: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
- **MessageTransmitter**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- **USDC**: Use chain-specific address from table above

## 🚨 Critical Notes

1. **Always set maxFee > 0** for Fast Transfers (we used 100 wei for 250k wei)
2. **Use correct domain** in API URL (`/v2/messages/SOURCE_DOMAIN`)
3. **Wait for "complete" status** before proceeding to Step 5
4. **USDC uses 6 decimals** (1 USDC = 1,000,000 wei)

## 🎯 Expected Results
- **Transfer Time**: ~60 seconds
- **Fee**: ~25 wei USDC (0.01% of amount)
- **Success Rate**: 100% with proper fee

## 🐛 Troubleshooting
- **"insufficient_fee"**: Increase maxFee parameter
- **"Message not found"**: Use correct domain in API URL
- **"pending_confirmations"**: Wait longer, check fee amount

That's it! You've successfully performed a CCTP V2 Fast Transfer! 🎉