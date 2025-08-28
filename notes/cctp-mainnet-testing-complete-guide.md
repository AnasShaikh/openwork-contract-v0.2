# CCTP Mainnet Testing - Complete Guide

## Overview

This guide provides complete instructions for testing CCTP (Cross-Chain Transfer Protocol) message-only transfers on mainnet. Based on successful testing conducted on August 26, 2025.

## Working Mainnet Contract Addresses

### Our Deployed Custom Contracts

#### ARB → OP Transfer (Successful)
- **CCTPMessageSender (ARB)**: `0x229a109EF2410A0Ef0E892269d3f3D3D8Ea8Dd2B`
- **CCTPMessageReceiver (OP)**: `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0`
- **Test Transaction**: `0x59f41cb40f936916c0384e067b896f64c7bf8df1866fbed079f947f1e63ceeae`
- **Receive Transaction**: `0xa67a3e091451149d6fb01a086b3d97da530b38a7323003b36cf2d83c8b731acd`

#### ETH → ARB Transfer (Successful)  
- **CCTPMessageSender (ETH)**: `0x17531Bb38207Aabb3E9ccD8B5f6f32a955926953`
- **CCTPMessageReceiver (ARB)**: `0x0462afc9884ff9fb088445ea25a4bfa88e0d48a1`
- **Test Transaction**: `0x1ff262a6f1b2594ecc16845898d8cbe2b3f1caae97b4691f20f5d38b1c02790a`
- **Receive Transaction**: `0xf313fa04bd6d3571851dbb41496bd6617b24a2d3146ccb743d9c1d0cecbf8434`

### Circle CCTP Infrastructure (Mainnet)

#### Ethereum Mainnet (Domain 0)
- **TokenMessenger**: `0xbd3fa81b58ba92a82136038b25adec7066af3155` ⚠️ **CRITICAL: Use this address, not docs**
- **MessageTransmitter**: `0x0a992d191deec32afe36203ad87d7d289a738f81`
- **USDC**: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

#### Arbitrum One (Domain 3)
- **TokenMessenger**: `0x19330d10D9Cc8751218eaf51E8885D058642E08A`
- **MessageTransmitter**: `0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca`
- **USDC**: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`

#### Optimism Mainnet (Domain 2)
- **TokenMessenger**: `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`
- **MessageTransmitter**: `0x4d41f22c5a0e5c74090899e5a8fb597a8842b3e8`
- **USDC**: `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85`

## Step-by-Step Mainnet Testing Process

### Prerequisites
```bash
# Required environment variables
WALL2_KEY=your_private_key_without_0x
WALL2_ADDRESS=your_wallet_address

# Required balances
# - ETH for gas (0.002+ ETH per chain)
# - USDC for transfers (2+ USDC total)
```

### Phase 1: Deploy Contracts

#### 1.1 Deploy Sender Contract
```bash
# For ETH → ARB
forge create --broadcast \
  --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY \
  --private-key $WALL2_KEY \
  src/current/cctp/cctp-message-sender.sol:CCTPMessageSender \
  --constructor-args \
    0xbd3fa81b58ba92a82136038b25adec7066af3155 \
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 \
    0x000000000000000000000000RECEIVER_CONTRACT_ADDRESS

# For ARB → OP  
forge create --broadcast \
  --rpc-url https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY \
  --private-key $WALL2_KEY \
  src/current/cctp/cctp-message-sender.sol:CCTPMessageSender \
  --constructor-args \
    0x19330d10D9Cc8751218eaf51E8885D058642E08A \
    0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
    0x000000000000000000000000RECEIVER_CONTRACT_ADDRESS
```

#### 1.2 Deploy Receiver Contract
```bash
# For ETH → ARB (receive on ARB)
forge create --broadcast \
  --rpc-url https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY \
  --private-key $WALL2_KEY \
  src/current/cctp/cctp-message-receiver.sol:CCTPMessageReceiver \
  --constructor-args \
    0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca \
    0xaf88d065e77c8cC2239327C5EDb3A432268e5831

# For ARB → OP (receive on OP)
forge create --broadcast \
  --rpc-url https://mainnet.optimism.io \
  --private-key $WALL2_KEY \
  src/current/cctp/cctp-message-receiver.sol:CCTPMessageReceiver \
  --constructor-args \
    0x4d41f22c5a0e5c74090899e5a8fb597a8842b3e8 \
    0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85
```

#### 1.3 Link Contracts (if not set in constructor)
```bash
# Set default recipient in sender
cast send $SENDER_CONTRACT "updateDefaultRecipient(bytes32)" \
  0x000000000000000000000000${RECEIVER_CONTRACT#0x} \
  --rpc-url $SOURCE_CHAIN_RPC --private-key $WALL2_KEY
```

### Phase 2: Execute Transfer

#### 2.1 Approve USDC
```bash
# Approve minimal USDC for sender contract
cast send $USDC_CONTRACT "approve(address,uint256)" \
  $SENDER_CONTRACT 100 \
  --rpc-url $SOURCE_CHAIN_RPC --private-key $WALL2_KEY
```

#### 2.2 Send Message
```bash
# Record start time
date && echo "Starting mainnet message send at $(date)"

# Send message (use correct domain ID)
cast send $SENDER_CONTRACT \
  "sendToDefault(uint32,string,uint256[])" \
  $DESTINATION_DOMAIN \
  "Mainnet Test Message" \
  "[100,200,300]" \
  --rpc-url $SOURCE_CHAIN_RPC --private-key $WALL2_KEY

# Record transaction hash from output!
```

#### 2.3 Wait for Attestation
```bash
# Check attestation status (expect 20-30+ minutes on mainnet)
curl "https://iris-api.circle.com/v2/messages/$SOURCE_DOMAIN?transactionHash=YOUR_TX_HASH"

# Wait for "status": "complete" and extract:
# - "message": The CCTP message bytes
# - "attestation": The attestation signature
```

#### 2.4 Receive Message
```bash
# Receive via Circle's MessageTransmitter (not our custom contract!)
cast send $MESSAGE_TRANSMITTER \
  "receiveMessage(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url $DEST_CHAIN_RPC --private-key $WALL2_KEY
```

#### 2.5 Verify Success
```bash
# Check USDC balance of receiver contract (should show 1 wei USDC)
cast call $USDC_DEST_CONTRACT "balanceOf(address)" $RECEIVER_CONTRACT \
  --rpc-url $DEST_CHAIN_RPC

# Check custom contract stats (optional)
cast call $RECEIVER_CONTRACT "getStats()" --rpc-url $DEST_CHAIN_RPC
```

## Domain Mappings (Critical Reference)
- **Ethereum**: Domain 0
- **Optimism**: Domain 2  
- **Arbitrum**: Domain 3
- **Base**: Domain 6
- **Polygon**: Domain 7

## RPC URLs
```bash
ETH_MAINNET_RPC=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
ARB_MAINNET_RPC=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY  
OP_MAINNET_RPC=https://mainnet.optimism.io
```

## Mainnet vs Testnet Results

### Cost Comparison
| Direction | Send Cost | Receive Cost | Total Cost | Testnet Cost |
|-----------|-----------|--------------|------------|--------------|
| ARB → OP  | $0.08     | $0.0001      | **$0.08**  | $0.01        |
| ETH → ARB | $1.04     | $0.015       | **$1.06**  | $0.01        |

### Timing Comparison  
| Phase | Testnet | ARB→OP Mainnet | ETH→ARB Mainnet |
|-------|---------|----------------|-----------------|
| Attestation | 15 seconds | 22 minutes | 30+ minutes |
| Total | <1 minute | ~25 minutes | ~35 minutes |

## Critical Notes

### ⚠️ Important Warnings
1. **TokenMessenger Address**: ETH mainnet uses `0xbd3fa81b58ba92a82136038b25adec7066af3155` NOT the address in Circle's docs
2. **MessageTransmitter Required**: Must receive via Circle's MessageTransmitter, not custom contract
3. **Domain IDs**: Use CCTP domain IDs (0,2,3), NOT chain IDs (1,10,42161)
4. **Attestation Time**: Mainnet takes 20-30+ minutes, NOT 13 minutes as documented
5. **Gas Requirements**: Need 0.002+ ETH per chain for mainnet gas costs

### ✅ Success Criteria
- [ ] Sender contract deployed with correct TokenMessenger
- [ ] Receiver contract deployed with correct MessageTransmitter
- [ ] USDC approved for sender contract
- [ ] Message sent successfully (transaction confirmed)
- [ ] Attestation received (status: "complete")
- [ ] Message received via MessageTransmitter (transaction confirmed)
- [ ] 1 wei USDC appears in receiver contract balance

## Troubleshooting

### High Gas Estimates ($90+)
- **Cause**: Wrong TokenMessenger address
- **Solution**: Use working addresses from this guide, not Circle docs

### Transaction Reverts
- **Cause**: Wrong domain ID or insufficient approvals
- **Solution**: Double-check domain mappings and USDC allowances

### Attestation Pending Forever
- **Cause**: Normal on mainnet, much slower than testnet
- **Solution**: Wait 20-30+ minutes, check transaction was confirmed

### "Message not found" Error
- **Cause**: Message not received via MessageTransmitter yet
- **Solution**: Complete receive step before trying to process

## Block Explorer Links
- **ETH**: https://etherscan.io/
- **ARB**: https://arbiscan.io/  
- **OP**: https://optimistic.etherscan.io/

## Contract Source Code
- **Sender**: `src/current/cctp/cctp-message-sender.sol`
- **Receiver**: `src/current/cctp/cctp-message-receiver.sol`

---

**Last Updated**: August 26, 2025  
**Status**: Fully tested and working on mainnet  
**Total Cost**: $0.08 - $1.06 per cross-chain message