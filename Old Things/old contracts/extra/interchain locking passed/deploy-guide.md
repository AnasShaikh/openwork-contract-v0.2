# CCTP + LayerZero Test Deployment Guide

## Overview
Deploy two minimal contracts to test USDC transfers via CCTP combined with data messaging via LayerZero in a single user transaction.

---

## Contract Addresses & Chain Info

### Arbitrum Sepolia (Sender Chain)
- **Chain ID**: 421614
- **LayerZero EID**: 40231
- **LayerZero Endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f`
- **USDC Token**: `0xf3c3351d6bd0098eeb33ca8f830faf2a141ea2e1`
- **CCTP TokenMessengerV2**: *[Need to find]*
- **CCTP Domain**: 3

### Optimism Sepolia (Receiver Chain)
- **Chain ID**: 11155420
- **LayerZero EID**: 40232
- **LayerZero Endpoint**: `0x6EDCE65403992e310A62460808c4b910D972f10f`
- **USDC Token**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
- **CCTP MessageTransmitterV2**: *[Need to find]*
- **CCTP Domain**: 2

---

## Deployment Steps

### Step 1: Deploy Receiver Contract (Optimism Sepolia)

**Constructor Parameters:**
```
_endpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f
_owner: YOUR_WALLET_ADDRESS
_messageTransmitterV2: [FIND_CCTP_ADDRESS]
_usdc: 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

**Save the deployed receiver contract address for Step 2.**

### Step 2: Convert Receiver Address to Bytes32

Use this formula to convert the receiver address:
```javascript
// If receiver address is 0x1234567890123456789012345678901234567890
bytes32 recipient = 0x0000000000000000000000001234567890123456789012345678901234567890
```

*Pad the address with 12 zeros at the beginning.*

### Step 3: Deploy Sender Contract (Arbitrum Sepolia)

**Constructor Parameters:**
```
_endpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f
_owner: YOUR_WALLET_ADDRESS
_tokenMessengerV2: [FIND_CCTP_ADDRESS]
_usdc: 0xf3c3351d6bd0098eeb33ca8f830faf2a141ea2e1
_targetCctpDomain: 2
_targetLzEid: 40232
_cctpRecipient: [BYTES32_FROM_STEP_2]
```

---

## Pre-Test Setup

### 1. Get Test Tokens
- **Arbitrum Sepolia ETH**: Use Arbitrum faucet
- **USDC**: Get from [Circle Testnet Faucet](https://faucet.circle.com/)
  - Request 10 USDC on Arbitrum Sepolia
  - Rate limit: 10 USDC per hour per address

### 2. Approve USDC
Approve the sender contract to spend your USDC:
```
Contract: 0xf3c3351d6bd0098eeb33ca8f830faf2a141ea2e1 (USDC)
Function: approve(SENDER_CONTRACT_ADDRESS, 1000000)
Amount: 1000000 (1 USDC with 6 decimals)
```

---

## Testing the Combined Transfer

### Function Call
Call `sendCombined()` on the **sender contract**:

**Parameters:**
```
usdcAmount: 1000000           // 1 USDC (6 decimals)
message: "Hello LayerZero"    // Test message
numbers: [1, 2, 3]          // Test numbers array
lzOptions: 0x               // Empty bytes (default options)
```

**ETH Value:** Include ~0.01 ETH for LayerZero gas fees

### Expected Events

**On Sender (Arbitrum Sepolia):**
- `CombinedTransferSent(transferId, sender, usdcAmount, cctpNonce, message, numbers)`

**On Receiver (Optimism Sepolia):**
- `LayerZeroDataReceived(transferId, sender, message, numbers)`
- `CCTPUSDCReceived(transferId, amount, cctpNonce)`
- `TransferCompleted(transferId, sender, usdcAmount, message, numbersSum)`

---

## Verification Functions

### Check Sender Status
```
getTransfer(transferId) → Returns transfer details
quoteLzFee(message, numbers, options) → Estimate fees before sending
```

### Check Receiver Status
```
getReceivedTransfer(transferId) → Returns received transfer details
isTransferComplete(transferId) → Returns true if both USDC and data arrived
getLatestData() → Returns (message, numbers, sum) from last transfer
getStats() → Returns (totalCompleted, latestMessage, usdcBalance)
```

---

## Key Notes

- **Deployment Order**: Always deploy receiver first, then sender
- **Address Format**: Convert receiver address to bytes32 for CCTP compatibility  
- **Test Small**: Start with 1 USDC to verify functionality
- **Monitor Events**: Track all events to confirm both USDC and data delivery
- **LayerZero Scan**: Use https://layerzeroscan.com to track cross-chain messages
- **CCTP Timing**: CCTP transfers take 13-19 minutes for finality

---

## Missing Information
- CCTP TokenMessengerV2 address for Arbitrum Sepolia
- CCTP MessageTransmitterV2 address for Optimism Sepolia

*These addresses need to be found from Circle's official documentation or contract explorers before deployment.*