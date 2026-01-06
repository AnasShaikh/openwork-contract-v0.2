# Cross-Chain Dispute Resolution Test Log - January 5, 2026

**Test Date:** January 5, 2026
**Dispute ID:** `40232-5-10`
**Status:** ✅ COMPLETE

---

## Test Overview

This test validates the complete cross-chain dispute resolution cycle:
1. Raise dispute from OP Sepolia via LocalAthena
2. LayerZero message delivery to Arbitrum Sepolia
3. CCTP transfer of dispute fee to NativeAthena
4. Vote on dispute on Arbitrum
5. Settlement after voting period
6. CCTP transfer of winner funds back to OP Sepolia
7. Voter fee distribution on Arbitrum

---

## Test Participants

| Role | Wallet | Address |
|------|--------|---------|
| Dispute Raiser (WALL2) | WALL2_KEY | `0xfD08836eeE6242092a9c869237a8d122275b024A` |
| Oracle Voter (WALL2) | WALL2_KEY | `0xfD08836eeE6242092a9c869237a8d122275b024A` |

---

## Contract Addresses

### OP Sepolia (Source Chain)
| Contract | Address |
|----------|---------|
| LocalAthena | `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6` |
| LocalBridge | `0xF069BE11c655270038f89DECFF4d9155D0910C95` |
| USDC | `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` |
| Message Transmitter (CCTP) | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` |

### Arbitrum Sepolia (Destination Chain)
| Contract | Address |
|----------|---------|
| NativeAthena | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` |
| NativeBridge | `0x0d628bbe01e32df7f32b12d321945fd64d3ee568` |
| Genesis | `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` |
| NOWJC | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` |
| ActivityTracker | `0x36B6417228ADd2EF231E2676F00251736c6f8d06` |
| USDC | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| Message Transmitter (CCTP) | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` |

---

## Initial Balances

### WALL2 USDC Balance - OP Sepolia
```bash
source .env && cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** `11,269,963` units (11.27 USDC)

### WALL2 USDC Balance - Arbitrum Sepolia
```bash
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `29,265,000` units (29.265 USDC)

---

## Step 1: Approve USDC for Dispute Fee

**Chain:** OP Sepolia
**TX Hash:** `0xd09bbf7a5b1549b4236a63c0452be65545c2eb8947b09797cdf46d3628bcfb9e`

```bash
source .env && cast send 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "approve(address,uint256)" 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 5000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result:** ✅ Success
- Approved 5,000 USDC units for LocalAthena

---

## Step 2: Raise Dispute via LocalAthena (Cross-Chain)

**Chain:** OP Sepolia
**TX Hash:** `0x96b0722efb7f39559268d60402ebc8ecf65639435612636dad887c0e7172897f`
**Block:** 37950325

```bash
source .env && cast send 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 \
  "raiseDispute(string,string,string,uint256,uint256,bytes)" \
  "40232-5" "QmCrossChainTest10" "General" 5000 10000 \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Parameters:**
| Parameter | Value |
|-----------|-------|
| Job ID | `40232-5` |
| Dispute Hash | `QmCrossChainTest10` |
| Oracle Name | `General` |
| Fee | `5,000` units (0.005 USDC) |
| Disputed Amount | `10,000` units (0.01 USDC) |
| LZ Options | `0x000301001101000000000000000000000000000F4240` (1M gas) |
| Native Fee | `0.001 ETH` |

**Result:** ✅ Success
- Triggered LayerZero message to Arbitrum
- Triggered CCTP transfer of 5,000 USDC to NativeAthena

---

## Step 3: Check LayerZero Message Status

**API Endpoint:** `https://scan-testnet.layerzero-api.com/v1/messages/tx/{txHash}`

```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0x96b0722efb7f39559268d60402ebc8ecf65639435612636dad887c0e7172897f" | jq '.data[0].status'
```

**Status Progression:**
1. `INFLIGHT` - "Ready for committer to commit verification"
2. `INFLIGHT` - "Verification committed"
3. `DELIVERED` - "Executor transaction confirmed"

**Result:** ✅ DELIVERED (after ~40 seconds)

---

## Step 4: Complete CCTP Transfer for Dispute Fee

**Chain:** Arbitrum Sepolia
**TX Hash:** `0x5927e74967c4336c0d6a232feacd132c6af41f6fe20064cfc84224f38b1098f2`
**Block:** 231131991

### Get CCTP Attestation
```bash
curl -s "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=0x96b0722efb7f39559268d60402ebc8ecf65639435612636dad887c0e7172897f" | jq '.'
```

**Attestation Details:**
| Field | Value |
|-------|-------|
| Source Domain | 2 (OP Sepolia) |
| Destination Domain | 3 (Arbitrum Sepolia) |
| Amount | 5,000 units |
| Mint Recipient | `0x20ec5833261d9956399c3885b22439837a6ed7b2` (NativeAthena) |
| Max Fee | 1,000 units |
| Fee Executed | 1,000 units |
| Net Amount | 4,000 units |

### Complete CCTP Transfer
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "0x0000000100000002000000030ef6a805cd3b6f8281db940030d86375f06b53cd10405934fdf75f1bcd7741fc0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e8000000010000000000000000000000005fd84259d66cd46123540766be93dfe6d43130d700000000000000000000000020ec5833261d9956399c3885b22439837a6ed7b200000000000000000000000000000000000000000000000000000000000013880000000000000000000000002139ef959b7c83ff853db8882c258e586e07e9be00000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000003e80000000000000000000000000000000000000000000000000000000000988c5c" \
  "0x4c6b17b510b2239844f42f39fe999279fd161e83bc7652393fbc993cd665291c5b0dc02517cab2d8468269e55fe7ecc1f83f39518d8316c96540a926d37fcd391ca403efd77acca720444ea26cb96c11fae4882814f2e5fbc241c4aff03c7a050c6ec698c9d3a1530d14a74d2b58be50e6838dbb2f1e9792b2a1277c882171e7e11c" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result:** ✅ Success
- 4,000 USDC minted to NativeAthena (5,000 - 1,000 CCTP fee)

---

## Step 5: Verify Dispute Created on Arbitrum

**Chain:** Arbitrum Sepolia
**Dispute ID:** `40232-5-10`

```bash
source .env && cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "getDispute(string)" "40232-5-10" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Dispute Details:**
| Field | Value |
|-------|-------|
| Dispute ID | `40232-5-10` |
| Disputed Amount | 10,000 units |
| Fee | 5,000 units |
| Raiser | `0xfD08836eeE6242092a9c869237a8d122275b024A` |
| isVotingActive | `true` |
| Timestamp | `0x695d02c9` (1767940809) |

**Result:** ✅ Dispute created successfully

---

## Step 6: Vote on Dispute

**Chain:** Arbitrum Sepolia
**TX Hash:** `0x85d576eba5aea2dbebbe7bae4fe6111f66ca4708140f63bcf29c199cb453605e`
**Block:** 231131881

```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "vote(uint8,string,bool,address)" 0 "40232-5-10" true \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Parameters:**
| Parameter | Value |
|-----------|-------|
| VotingType | `0` (Dispute) |
| Dispute ID | `40232-5-10` |
| Vote For | `true` (in favor of dispute raiser) |
| Claim Address | `0xfD08836eeE6242092a9c869237a8d122275b024A` |

**Result:** ✅ Success
- 5 votes recorded FOR dispute raiser
- Member activity updated in ActivityTracker

---

## Step 7: Wait for Voting Period

**Voting Period:** 2 minutes (configured in NativeAthena)

```bash
sleep 120
```

**Result:** ✅ Waited 120 seconds

---

## Step 8: Settle Dispute

**Chain:** Arbitrum Sepolia
**TX Hash:** `0x87c7d28fa21c96a923b7dfb3ebaadfbe3d39f1cadb4e6c530c6c7d4e8e33dd95`
**Block:** 231132480

```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "settleDispute(string)" "40232-5-10" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Settlement Outcome:**
| Field | Value |
|-------|-------|
| Result | Dispute raiser wins (votesFor > votesAgainst) |
| Votes For | 5 |
| Votes Against | 0 |
| Winner Funds via CCTP | 9,000 units (disputed amount - commission) |
| Voter Fee Distributed | 5,000 units to WALL2 on Arbitrum |

**Result:** ✅ Success
- Triggered CCTP transfer of 9,000 USDC to winner on OP Sepolia
- Distributed 5,000 USDC voter fee to WALL2 on Arbitrum

---

## Step 9: Complete CCTP Transfer for Winner Funds

**Chain:** OP Sepolia
**TX Hash:** `0x34e0557268f68367a1f4c8a42e71224991147d9b2ffb12ccdcd6a009137555b0`
**Block:** 37950501

### Get CCTP Attestation
```bash
curl -s "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=0x87c7d28fa21c96a923b7dfb3ebaadfbe3d39f1cadb4e6c530c6c7d4e8e33dd95" | jq '.'
```

**Attestation Details:**
| Field | Value |
|-------|-------|
| Source Domain | 3 (Arbitrum Sepolia) |
| Destination Domain | 2 (OP Sepolia) |
| Amount | 9,000 units |
| Mint Recipient | `0xfd08836eee6242092a9c869237a8d122275b024a` (WALL2) |
| Max Fee | 1,000 units |
| Fee Executed | 1,000 units |
| Net Amount | 8,000 units |

### Complete CCTP Transfer
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "0x0000000100000003000000020b93c7e381961834e843b00066bde3c2d14f20b6fb6a5af7c777e07a8a7097890000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e80000000100000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a0000000000000000000000000000000000000000000000000000000000002328000000000000000000000000d22c85d18d188d37fd9d38974420a6bd68ffc31500000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000243bcd0" \
  "0x0358405f5b20d357d79d5960dc015a602b036dcd5ea6bd3a803e483daedf89bb5293073ee06012d5f242c0c550fe02a785fa91005ebf5eecc6bf3459b10652f21c925bc0396917c7bdfa72082db9d8ef9aa8aa4f05c9c30596948bbe07fa6e5fa26d1f605403a6fee83e4152cf55d13298990f3ceb2c7c4206b1e915f1ca4699bb1b" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result:** ✅ Success
- 8,000 USDC minted to WALL2 on OP Sepolia (9,000 - 1,000 CCTP fee)

---

## Final Balances

### WALL2 USDC Balance - OP Sepolia
```bash
source .env && cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** `11,268,987` units (11.27 USDC)

### WALL2 USDC Balance - Arbitrum Sepolia
```bash
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `29,278,192` units (29.28 USDC)

---

## Balance Changes Summary

| Chain | Initial | Final | Change | Notes |
|-------|---------|-------|--------|-------|
| OP Sepolia | 11,269,963 | 11,268,987 | -976 | Paid fees for 2 disputes (40232-5-9 + 40232-5-10), received 8,000 back |
| Arbitrum | 29,265,000 | 29,278,192 | +13,192 | Received voter fees from multiple disputes |

---

## Transaction Summary

| Step | Chain | TX Hash | Status |
|------|-------|---------|--------|
| 1. Approve USDC | OP Sepolia | `0xd09bbf7a5b1549b4236a63c0452be65545c2eb8947b09797cdf46d3628bcfb9e` | ✅ |
| 2. Raise Dispute | OP Sepolia | `0x96b0722efb7f39559268d60402ebc8ecf65639435612636dad887c0e7172897f` | ✅ |
| 3. LZ Message | - | DELIVERED | ✅ |
| 4. CCTP Fee | Arbitrum | `0x5927e74967c4336c0d6a232feacd132c6af41f6fe20064cfc84224f38b1098f2` | ✅ |
| 5. Vote | Arbitrum | `0x85d576eba5aea2dbebbe7bae4fe6111f66ca4708140f63bcf29c199cb453605e` | ✅ |
| 6. Settle | Arbitrum | `0x87c7d28fa21c96a923b7dfb3ebaadfbe3d39f1cadb4e6c530c6c7d4e8e33dd95` | ✅ |
| 7. CCTP Winner | OP Sepolia | `0x34e0557268f68367a1f4c8a42e71224991147d9b2ffb12ccdcd6a009137555b0` | ✅ |

---

## Test Results

| Goal | Expected | Actual | Status |
|------|----------|--------|--------|
| Raise dispute cross-chain | Dispute created on Arbitrum | `40232-5-10` created | ✅ |
| LZ message delivery | DELIVERED status | DELIVERED in ~40s | ✅ |
| CCTP fee transfer | 4,000 to NativeAthena | 4,000 received | ✅ |
| Vote recorded | Vote TX succeeds | 5 votes FOR | ✅ |
| Settlement | Dispute raiser wins | Winner determined | ✅ |
| Winner funds via CCTP | 8,000 to winner | 8,000 received | ✅ |
| Voter fee | 5,000 to voter | 5,000 distributed | ✅ |

---

## Flow Diagram

```
OP Sepolia                              Arbitrum Sepolia
────────────                            ─────────────────

WALL2 approves 5,000 USDC
         │
         ▼
LocalAthena.raiseDispute()
         │
         ├──► CCTP: 5,000 USDC ──────────► 4,000 USDC to NativeAthena
         │    (minus 1,000 fee)               (fee held for voters)
         │
         └──► LayerZero message ─────────► NativeBridge.lzReceive()
                                                    │
                                                    ▼
                                           NativeAthena.handleRaiseDispute()
                                                    │
                                                    ▼
                                           Genesis creates dispute 40232-5-10
                                                    │
                                                    ▼
                                           NativeAthena.vote()
                                           (WALL2 votes FOR, 5 votes)
                                                    │
                                                    ▼
                                           [Wait 2 minutes]
                                                    │
                                                    ▼
                                           NativeAthena.settleDispute()
                                                    │
                                           ┌───────┴───────┐
                                           │               │
                                           ▼               ▼
                                    NOWJC releases    5,000 USDC
                                    9,000 USDC       to WALL2 (voter fee)
                                           │
         ┌─────────────────────────────────┘
         │
         ▼
CCTP: 9,000 USDC ────────────────────────────────────────────►
(minus 1,000 fee)
         │
         ▼
8,000 USDC to WALL2
```

---

## Technical Notes

### LZ Options Encoding
- `0x000301001101000000000000000000000000000F4240` = 1,000,000 gas limit
- Format: `0x0003` (version) + `01` (type) + `0011` (length) + `01` (executor) + gas amount

### CCTP Fees
- OP Sepolia → Arbitrum: 1,000 units fee (20% of 5,000)
- Arbitrum → OP Sepolia: 1,000 units fee (11% of 9,000)

### Timing
- LZ message delivery: ~40 seconds
- CCTP attestation: ~10-20 seconds
- Voting period: 2 minutes (120 seconds)

### LayerZero API
```
Testnet: https://scan-testnet.layerzero-api.com/v1/messages/tx/{txHash}
```

### Circle CCTP API
```
Sandbox: https://iris-api-sandbox.circle.com/v2/messages/{domain}?transactionHash={txHash}
Domain 2 = OP Sepolia
Domain 3 = Arbitrum Sepolia
```

---

## Conclusion

The cross-chain dispute resolution flow is **fully functional**:
1. Disputes can be raised from any local chain via LocalAthena
2. LayerZero reliably delivers messages to the native chain
3. CCTP successfully transfers USDC fees and winner funds
4. Voting and settlement work correctly on the native chain
5. Winner funds are correctly routed back to the originating chain

---

**Log Created:** January 5, 2026
**Last Updated:** January 5, 2026
