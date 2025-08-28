# CCTP Message-Only Cross-Chain Communication - Complete Guide

This guide walks you through sending rich message data across chains using Circle's CCTP (Cross-Chain Transfer Protocol) with minimal USDC as a carrier. No prior CCTP knowledge required!

## What is CCTP Message-Only?

**CCTP Message-Only** allows you to send text messages, arrays, custom data between different blockchains using Circle's infrastructure. Since pure message-only isn't available on testnets yet, we use **1 wei USDC** (0.000001 USDC) as a "carrier" to enable rich cross-chain messaging.

## Prerequisites

### Required Tools
- **Foundry** installed (`curl -L https://foundry.paradigm.xyz | bash`)
- **Private key** with testnet ETH on both chains
- **USDC tokens** from https://faucet.circle.com

### Required Environment Variables (.env file)
```bash
PRIVATE_KEY=your_private_key_without_0x_prefix
OWNER_ADDRESS=0xYourWalletAddress
ARBITRUM_SEPOLIA_RPC_URL=https://arbitrum-sepolia.infura.io/v3/YOUR_INFURA_KEY  
OPTIMISM_SEPOLIA_RPC_URL=https://optimism-sepolia.infura.io/v3/YOUR_INFURA_KEY
```

## Step 1: Understanding the Architecture

### Components
1. **CCTPMessageSender** (Source Chain) - Sends messages with minimal USDC
2. **CCTPMessageReceiver** (Destination Chain) - Receives and processes messages
3. **Circle Attestation Service** - Validates cross-chain transfers

### Chain Details
- **Arbitrum Sepolia**: Domain ID = 3, USDC = `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **OP Sepolia**: Domain ID = 2, USDC = `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`

## Step 2: Deploy Contracts

### Deploy Sender on Arbitrum Sepolia
```bash
source .env
forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  src/current/cctp/cctp-message-sender.sol:CCTPMessageSender \
  --constructor-args \
    0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5 \
    0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
    0x0000000000000000000000000000000000000000000000000000000000000000
```

**Save the deployed address as `SENDER_CONTRACT`**

### Deploy Receiver on OP Sepolia
```bash
forge create --broadcast \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  src/current/cctp/cctp-message-receiver.sol:CCTPMessageReceiver \
  --constructor-args \
    0x7865fAfC2db2093669d92c0F33AeEF291086BEFD \
    0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

**Save the deployed address as `RECEIVER_CONTRACT`**

### Link Contracts
```bash
# Set receiver as default recipient in sender
cast send $SENDER_CONTRACT "updateDefaultRecipient(bytes32)" \
  0x000000000000000000000000${RECEIVER_CONTRACT#0x} \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Step 3: Send Your First Message

### Approve USDC for Sender
```bash
# Approve minimal USDC (100 wei = 0.0001 USDC allows 100 messages)
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "approve(address,uint256)" $SENDER_CONTRACT 100 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Send Message with Data
```bash
# Send message with text and array data
cast send $SENDER_CONTRACT \
  "sendToDefault(uint32,string,uint256[])" \
  2 \
  "Hello Cross-Chain World!" \
  "[1,2,3,4,5]" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**🎯 Record the transaction hash from the output!**

## Step 4: Get Attestation

### Wait for Attestation (Usually 15-60 seconds)
```bash
# Replace TX_HASH with your transaction hash
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=TX_HASH"
```

**Look for `"status": "complete"` in the response. Extract:**
- `"message"`: The CCTP message bytes
- `"attestation"`: The attestation signature

## Step 5: Receive Message on Destination

### Process CCTP Message
```bash
# Use MESSAGE and ATTESTATION from the API response
cast send $RECEIVER_CONTRACT \
  "receiveCCTPMessage(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Step 6: Process Message Data

### Extract CCTP Nonce
From the attestation API response, find `"eventNonce"` (e.g., "166251")

### Process Your Message
```bash
# Process the message with your original data
cast send $RECEIVER_CONTRACT \
  "processMessage(uint64,string,uint256[])" \
  NONCE_FROM_API \
  "Hello Cross-Chain World!" \
  "[1,2,3,4,5]" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Step 7: Verify Success

### Check Message Reception
```bash
# Get total messages
cast call $RECEIVER_CONTRACT "getStats()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Sum the numbers in your message (should return 15 for [1,2,3,4,5])
cast call $RECEIVER_CONTRACT "sumLatestNumbers()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Get your specific message
cast call $RECEIVER_CONTRACT "getMessageByNonce(uint64)" YOUR_NONCE --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

## Complete Example Walkthrough

### Example: Send "Hello CCTP!" with numbers [10,20,30]

1. **Deploy contracts** (Steps 1-2)
2. **Send message**:
   ```bash
   cast send $SENDER_CONTRACT "sendToDefault(uint32,string,uint256[])" 2 "Hello CCTP!" "[10,20,30]"
   ```
3. **Get attestation** with your TX hash
4. **Receive on OP**: 
   ```bash
   cast send $RECEIVER_CONTRACT "receiveCCTPMessage(bytes,bytes)" "YOUR_MESSAGE" "YOUR_ATTESTATION"
   ```
5. **Process data**:
   ```bash
   cast send $RECEIVER_CONTRACT "processMessage(uint64,string,uint256[])" YOUR_NONCE "Hello CCTP!" "[10,20,30]"
   ```
6. **Verify**: `sumLatestNumbers()` should return `60` (10+20+30)

## Advanced Features

### Send Custom Byte Data
```bash
cast send $SENDER_CONTRACT \
  "sendCustomData(uint32,address,bytes)" \
  2 \
  $RECEIVER_CONTRACT \
  "0x68656c6c6f" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### Send to Specific Recipient
```bash
cast send $SENDER_CONTRACT \
  "sendMessage(uint32,address,string,uint256[])" \
  2 \
  $CUSTOM_RECIPIENT \
  "Direct message" \
  "[100,200]" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Timing Expectations

| Phase | Expected Time | Actual Experience |
|-------|---------------|-------------------|
| Attestation Ready | 13+ minutes (docs) | **15 seconds** ⚡ |
| End-to-End Complete | ~15 minutes | **40 seconds** ⚡ |

**Note**: Testnet performance is much faster than documented!

## Cost Analysis

- **Per Message**: 1 wei USDC = 0.000001 USDC (~$0.000001)
- **100 Messages**: 0.0001 USDC (~$0.0001)
- **Gas Costs**: ~$0.01-0.05 per transaction on testnets

## Troubleshooting

### Common Issues

#### "Message already processed"
- Each CCTP nonce can only be processed once
- **IMPORTANT**: Our receiver contract may auto-process messages during `receiveCCTPMessage()`
- **Always check first** with `getMessageByNonce(YOUR_NONCE)` before calling `processMessage()`
- If `isProcessed` field shows `true`, skip the `processMessage()` step
- Check if message was already received but not correlated

#### "CCTP message verification failed"
- Wrong attestation or message format
- Verify you copied the complete hex strings from API

#### "Message not found"
- Wrong nonce or message not received yet
- Check receiver stats: `getStats()`

#### Attestation Not Ready
- API returns empty or error
- Wait longer (up to 13 minutes)
- Verify transaction hash is correct

### Debug Commands
```bash
# Check sender stats
cast call $SENDER_CONTRACT "getTotalMessagesSent()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check receiver stats  
cast call $RECEIVER_CONTRACT "getStats()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# CRITICAL: Check specific message status before processing
cast call $RECEIVER_CONTRACT "getMessageByNonce(uint64)" YOUR_NONCE --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Get unprocessed messages
cast call $RECEIVER_CONTRACT "getUnprocessedMessages()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Check USDC balance
cast call $RECEIVER_CONTRACT "getUSDCBalance()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

## Contract Addresses (Reference)

### Our Deployed Contracts
- **Sender (ARB Sepolia)**: `0x7507c31957DD1bDC53fd77099E29A787AA1D66B2`
- **Receiver (OP Sepolia)**: `0xB93013E06931d19d5361517A5d3A8487eAc2fA46`

### CCTP Infrastructure
#### Arbitrum Sepolia
- **TokenMessenger**: `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`
- **USDC**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **Domain**: `3`

#### OP Sepolia  
- **MessageTransmitter**: `0x7865fAfC2db2093669d92c0F33AeEF291086BEFD`
- **USDC**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
- **Domain**: `2`

## Security Considerations

- **Never commit private keys** to version control
- **Test with small amounts** first
- **Verify contract addresses** before deployment
- **Check attestation status** before processing
- **Use proper error handling** in production

## Next Steps

1. **Deploy to mainnet** (use mainnet CCTP addresses)
2. **Integrate into dApps** for cross-chain messaging
3. **Build UI** for non-technical users
4. **Add encryption** for private messages
5. **Implement batching** for multiple messages

## Conclusion

You now have a complete CCTP message-only system that can send rich data across chains for virtually no cost! This system bridges the gap until native CCTP V2 message-only functionality becomes available on all networks.

**Key Benefits:**
- ⚡ **Fast**: Sub-minute delivery
- 💰 **Cheap**: ~$0.000001 per message  
- 🛡️ **Secure**: Circle's proven infrastructure
- 🚀 **Scalable**: Handles any message size/complexity

Happy cross-chain messaging! 🌉