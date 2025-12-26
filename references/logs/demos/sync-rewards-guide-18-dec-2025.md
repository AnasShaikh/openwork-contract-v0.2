# Sync Rewards Data Guide

**Date**: December 18, 2025
**Purpose**: How to sync claimable tokens from Arbitrum Sepolia to Base Sepolia
**Status**: Tested & Working

---

## Overview

The `syncRewardsData` function sends a user's claimable token balance from NOWJC (Arbitrum Sepolia) to the Cross-Chain Rewards contract (Base Sepolia) via LayerZero.

**Flow:**
```
NOWJC (Arbitrum) → Profile Editing Bridge → LayerZero → Main Chain Bridge (Base) → Cross-Chain Rewards
```

---

## Prerequisites

Before syncing, the user must have:
1. **Earned tokens** (from completing jobs)
2. **Governance actions** (from creating/voting on DAO proposals)
3. **Claimable tokens > 0** (earned tokens unlocked by governance actions)

---

## Step 1: Check Eligibility

### Check Earned Tokens
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "getUserEarnedTokens(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

### Check Governance Actions
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "getUserGovernanceActions(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

### Check Claimable Tokens (CRITICAL)
```bash
source .env && cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De \
  "getUserTotalClaimableTokens(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

**Important**: `syncRewardsData` will FAIL if claimable = 0. Users need governance actions to unlock claimable tokens.

---

## Step 2: Simulate the Call

Before sending, simulate to catch errors:
```bash
source .env && cast estimate --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "syncRewardsData(bytes)" \
  "0x000301001101000000000000000000000000000F4240" \
  --from YOUR_WALLET_ADDRESS \
  --value 0.001ether
```

If this returns a gas estimate, the call will succeed. If it reverts, check:
- Claimable tokens > 0
- Bridge is set on NOWJC
- Sufficient ETH for LayerZero fees

---

## Step 3: Send syncRewardsData

```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "syncRewardsData(bytes)" \
  "0x000301001101000000000000000000000000000F4240" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $YOUR_PRIVATE_KEY \
  --value 0.001ether
```

**LZ Options breakdown:**
- `0x0003` - Options type 3 (executor options)
- `01` - Worker ID
- `0011` - Length
- `01` - Option type (LZ receive)
- `000000000000000000000000000F4240` - Gas limit (1,000,000)

---

## Step 4: Verify Delivery

### Check LayerZero Status
Visit LayerZeroScan with your transaction hash:
```
https://testnet.layerzeroscan.com/tx/YOUR_TX_HASH
```

### Check Destination Balance
Wait 1-5 minutes for LayerZero delivery, then check:
```bash
source .env && cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0xd6bE0C187408155be99C4e9d6f860eDDa27b056B \
  "getClaimableRewards(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

---

## Troubleshooting

### Error: "No tokens"
**Cause**: Claimable tokens = 0
**Fix**: User needs governance actions to unlock claimable tokens. Create or vote on a DAO proposal.

### Error: "Bridge not set"
**Cause**: NOWJC bridge not configured
**Fix**: Check `bridge()` on NOWJC returns Profile Editing Bridge address

### Message Not Delivered (Stuck in Flight)
**Cause**: Peer mismatch between bridges
**Fix**: Verify peers are correctly set:

```bash
# Check Profile Editing Bridge peer for Base Sepolia (40245)
cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0xE06D84d3941AB1f0c7A1d372d44293432208cb05 \
  "peers(uint32)" 40245

# Check Main Chain Bridge peer for Arbitrum Sepolia (40231)
cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 \
  "peers(uint32)" 40231
```

**Expected peers:**
- Profile Editing Bridge → `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` (Main Chain Bridge)
- Main Chain Bridge → `0xE06D84d3941AB1f0c7A1d372d44293432208cb05` (Profile Editing Bridge)

### Fix Peer Mismatch
```bash
# Update Main Chain Bridge peer (owner: WALL2)
source .env && cast send --rpc-url $BASE_SEPOLIA_RPC_URL \
  0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 \
  "setPeer(uint32,bytes32)" \
  40231 \
  0x000000000000000000000000E06D84d3941AB1f0c7A1d372d44293432208cb05 \
  --private-key $WALL2_KEY
```

---

## Contract Addresses

| Contract | Chain | Address |
|----------|-------|---------|
| NOWJC Proxy | Arbitrum Sepolia | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` |
| Native Rewards | Arbitrum Sepolia | `0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De` |
| Profile Editing Bridge | Arbitrum Sepolia | `0xE06D84d3941AB1f0c7A1d372d44293432208cb05` |
| Main Chain Bridge | Base Sepolia | `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` |
| Cross-Chain Rewards | Base Sepolia | `0xd6bE0C187408155be99C4e9d6f860eDDa27b056B` |

---

## Quick Reference

```bash
# Full sync flow for WALL1
source .env

# 1. Check claimable
cast call --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De \
  "getUserTotalClaimableTokens(address)(uint256)" \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef

# 2. Sync (if claimable > 0)
cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "syncRewardsData(bytes)" \
  "0x000301001101000000000000000000000000000F4240" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --value 0.001ether

# 3. Verify on Base (wait 1-5 min)
cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0xd6bE0C187408155be99C4e9d6f860eDDa27b056B \
  "getClaimableRewards(address)(uint256)" \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef
```

---

## Step 5: Claim Tokens on Base Sepolia

Once tokens are synced, users can claim them on Base Sepolia.

### Check Contract Has Sufficient Tokens
```bash
source .env && cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679 \
  "balanceOf(address)(uint256)" \
  0xd6bE0C187408155be99C4e9d6f860eDDa27b056B
```

### Check User's Current Token Balance
```bash
source .env && cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679 \
  "balanceOf(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

### Claim Rewards
```bash
source .env && cast send 0xd6bE0C187408155be99C4e9d6f860eDDa27b056B \
  "claimRewards(bytes)" \
  "0x000301001101000000000000000000000000000F4240" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $YOUR_PRIVATE_KEY \
  --value 0.001ether
```

**Note**: The `_options` parameter and ETH value are for sending a cross-chain message back to Arbitrum Sepolia to record the claim.

### Verify Claim Success
```bash
# Check new token balance
source .env && cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679 \
  "balanceOf(address)(uint256)" \
  YOUR_WALLET_ADDRESS

# Confirm claimable is now 0
cast call --rpc-url $BASE_SEPOLIA_RPC_URL \
  0xd6bE0C187408155be99C4e9d6f860eDDa27b056B \
  "getClaimableRewards(address)(uint256)" \
  YOUR_WALLET_ADDRESS
```

---

## Complete Rewards Cycle Summary

```
1. EARN TOKENS (Arbitrum Sepolia)
   └── Complete jobs on NOWJC → Earn OW tokens

2. UNLOCK CLAIMABLE (Arbitrum Sepolia)
   └── Create/vote on DAO proposals → Governance actions unlock claimable tokens

3. SYNC TO MAIN CHAIN (Arbitrum → Base Sepolia)
   └── Call syncRewardsData() → LayerZero delivers to Cross-Chain Rewards

4. CLAIM TOKENS (Base Sepolia)
   └── Call claimRewards() → Receive OW tokens in wallet

5. RECORD CLAIM (Base → Arbitrum Sepolia)
   └── Automatic cross-chain message updates claim data on native chain
```

---

**Last Tested**: December 18, 2025
**Result**: WALL1 earned 270 OW → synced → claimed successfully
