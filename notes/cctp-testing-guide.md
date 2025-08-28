# CCTP Cross-Chain Transfer Testing Guide

This document contains the exact commands used to test the CCTP (Cross-Chain Transfer Protocol) functionality between Arbitrum Sepolia and OP Sepolia.

## Prerequisites

- Foundry installed
- Private key with testnet ETH on both chains
- USDC from https://faucet.circle.com (Arbitrum Sepolia)
- Environment variables configured in `.env`

## Environment Setup

```bash
# Contract addresses (already deployed)
BURN_CONTRACT=0x7Af451cc91974d5F686470b319E586E02Fa9a6a3  # ARB Sepolia
MINT_CONTRACT=0x26493A9a7cAc783564c71537ff8b669b3c2cf680   # OP Sepolia

# Source environment variables
source .env
```

## Test Execution Commands

### Step 1: Approve USDC for Burn Contract
```bash
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "approve(address,uint256)" 0x7Af451cc91974d5F686470b319E586E02Fa9a6a3 100000 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Result:** Transaction successful
- **Transaction Hash:** `0x5d1a0ff25a854178e56eaf06463fa46bbe46300895f286263abee47a9936f200`
- **Status:** Success (approved 0.1 USDC for burn contract)

### Step 2: Execute Burn Transaction
```bash
cast send 0x7Af451cc91974d5F686470b319E586E02Fa9a6a3 "sendToOpSepolia(uint256,address)" 100000 $OWNER_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Result:** Burn transaction successful
- **Transaction Hash:** `0x7a2a0792fd9ca05d8304fbd61527f150e7596e7df5247de8b8ab0e84307c06f1`
- **Status:** Success (burned 0.1 USDC and initiated cross-chain transfer)

### Step 3: Get Attestation from Circle API
```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=0x7a2a0792fd9ca05d8304fbd61527f150e7596e7df5247de8b8ab0e84307c06f1"
```

**Result:** Attestation retrieved (faster than expected 13+ minute wait)
- **Status:** "complete"
- **Event Nonce:** 166237
- **Message:** `0x000000000000000300000002000000000002895d0000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa50000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d000000000000000000000000aa6816876280c5a685baf3d9c214a092c7f3f6ef00000000000000000000000000000000000000000000000000000000000186a00000000000000000000000007af451cc91974d5f686470b319e586e02fa9a6a3`
- **Attestation:** `0xf3f5848972cdded2e041e38e16ad3ab3134cbf0008adc89b7c2d25554b959a9e7ccc246d10eb09bc98793ba0a1b101dbbb1c6cfd70ce35a48a2ab1ed4d29d0af1b3740bba311533e4b0a7672d137d7b39fdfe5581cebd70ded106092819dcc9f366d07015acc48ff96e05716ac600cb035433b046660f3269d4ce314e95b26aad11b`

### Step 4: Execute Mint Transaction on OP Sepolia
```bash
cast send 0x26493A9a7cAc783564c71537ff8b669b3c2cf680 "mintUSDC(bytes,bytes)" "0x000000000000000300000002000000000002895d0000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa50000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d000000000000000000000000aa6816876280c5a685baf3d9c214a092c7f3f6ef00000000000000000000000000000000000000000000000000000000000186a00000000000000000000000007af451cc91974d5F686470b319e586e02fa9a6a3" "0xf3f5848972cdded2e041e38e16ad3ab3134cbf0008adc89b7c2d25554b959a9e7ccc246d10eb09bc98793ba0a1b101dbbb1c6cfd70ce35a48a2ab1ed4d29d0af1b3740bba311533e4b0a7672d137d7b39fdfe5581cebd70ded106092819dcc9f366d07015acc48ff96e05716ac600cb035433b046660f3269d4ce314e95b26aad11b" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Result:** Mint transaction successful
- **Transaction Hash:** `0xd73b5a142d860efd7d977ef1dfe7f82e5a19c5e56a5f5851c04d9a45a0a4a054`
- **Status:** Success (minted 0.1 USDC on OP Sepolia)

### Step 5: Verify Balance on OP Sepolia
```bash
cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 "balanceOf(address)" $OWNER_ADDRESS --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Result:** Balance verification successful
- **Balance (hex):** `0x0000000000000000000000000000000000000000000000000000000000030d40`
- **Balance (decimal):** `200000` (0.2 USDC total)
- **Transfer Amount:** `100000` (0.1 USDC successfully transferred)

## Key Addresses

### Arbitrum Sepolia
- **USDC Token:** `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **Token Messenger:** `0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5`
- **Burn Contract:** `0x7Af451cc91974d5F686470b319E586E02Fa9a6a3`
- **Domain ID:** `3`

### OP Sepolia
- **USDC Token:** `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
- **Message Transmitter:** `0x7865fAfC2db2093669d92c0F33AeEF291086BEFD`
- **Mint Contract:** `0x26493A9a7cAc783564c71537ff8b669b3c2cf680`
- **Domain ID:** `2`

## Test Results Summary

✅ **All tests passed successfully**
- Approval transaction: ✅ Success
- Burn transaction: ✅ Success  
- Attestation retrieval: ✅ Success (immediate availability)
- Mint transaction: ✅ Success
- Balance verification: ✅ Success (0.1 USDC transferred)

## Notes

- USDC uses 6 decimals (100000 = 0.1 USDC)
- Attestation was available immediately (much faster than expected 13+ minutes)
- Circle API endpoint: `https://iris-api-sandbox.circle.com/v2/messages`
- Both contracts function correctly for cross-chain USDC transfers
- Total test execution time: < 5 minutes

## Important Warning: Message Processing

⚠️ **CRITICAL**: Before calling `processMessage()`, always check if message is already processed:

```bash
# Check message status first
cast call $RECEIVER_CONTRACT "getMessageByNonce(uint64)" YOUR_NONCE --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

If the `isProcessed` field shows `true`, **skip** the `processMessage()` step. Our receiver contract may auto-process messages during `receiveCCTPMessage()` to avoid duplicate processing errors.

## Contract Code Locations

- **Sender Contract:** `src/current/cctp/cctp-v2-sender.sol`
- **Receiver Contract:** `src/current/cctp/cctp-v2-receiver.sol`