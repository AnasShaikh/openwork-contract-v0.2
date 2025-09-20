# Complete 2-Milestone Job Cycle Tutorial - Direct Payment to Applicant

**Date**: September 20, 2025  
**Purpose**: Step-by-step tutorial for complete job lifecycle with direct USDC payments to applicant wallets  
**Architecture**: OP Sepolia (LOWJC) ↔ Arbitrum Sepolia (NOWJC) with V2 Direct Payment

---

## 🎯 **Overview**

This tutorial demonstrates the complete OpenWork cross-chain job lifecycle where:
- Job giver posts a 2-milestone job on OP Sepolia
- Job applicant applies and gets selected
- USDC flows: OP Sepolia → Arbitrum → **Direct to applicant wallet** (no manual distribution)

### **Key Innovation: V2 Direct Payment**
Unlike traditional flows that send payments to LOWJC contracts requiring manual distribution, this system sends USDC **directly to the job applicant's wallet** automatically.

---

## 📋 **Prerequisites**

### **Contract Addresses**
- **OP Sepolia LOWJC**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **Arbitrum Sepolia NOWJC**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **V2 Implementation**: `0xA47aE86d4733f093DE77b85A14a3679C8CA3Aa45` (Direct Payment)

### **Wallet Setup**
- **Job Giver (WALL2)**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Job Applicant (WALL3)**: `0x1D06bb4395AE7BFe9264117726D069C251dC27f5`
- **USDC Required**: 1+ USDC on OP Sepolia for job giver

### **Tools Required**
- Foundry (cast)
- Environment variables configured (.env file)
- Access to both OP Sepolia and Arbitrum Sepolia

---

## 🚀 **Step-by-Step Tutorial**

### **Step 1: Post Job with 2 Milestones**

Post a job with 2 milestones of 0.5 USDC each on OP Sepolia:

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "postJob(string,string[],uint256[],bytes)" \
  "test-cross-chain-2milestone-cycle" \
  '["Milestone 1: Initial deliverable", "Milestone 2: Final completion"]' \
  '[500000, 500000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Result**: Job created with ID (e.g., `40232-38`)  
**Total Job Value**: 1.0 USDC (500,000 + 500,000 wei)

### **Step 2: Apply to Job as Applicant**

Job applicant applies with matching milestone structure:

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "applyToJob(string,string,string[],uint256[],bytes)" \
  "40232-38" \
  "QmWall3TwoMilestoneTest" \
  '["Milestone 1: Initial work delivery", "Milestone 2: Final project completion"]' \
  '[500000, 500000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL3_KEY
```

**Result**: Application submitted with matching milestone amounts

### **Step 3: Start Job (Cross-Chain USDC Transfer)**

Job giver selects applicant and starts job, triggering CCTP transfer:

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startJob(string,uint256,bool,bytes)" \
  "40232-38" \
  1 \
  false \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**What happens**: 
- 1.0 USDC transferred from job giver to LOWJC
- CCTP burns USDC on OP Sepolia 
- Cross-chain message sent to Arbitrum

### **Step 4: Check CCTP Attestation**

Wait for CCTP attestation to complete (usually 1-2 minutes):

```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=YOUR_TX_HASH"
```

**Look for**: `"status": "complete"` in response

### **Step 5: Complete CCTP Transfer to NOWJC**

Complete the CCTP transfer on Arbitrum Sepolia:

```bash
source .env && cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 \
  "receive(bytes,bytes)" \
  "MESSAGE_FROM_ATTESTATION" \
  "ATTESTATION_FROM_API" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Result**: ~0.9999 USDC minted to NOWJC on Arbitrum (after CCTP fees)

### **Step 6: Release Milestone Payment**

Trigger cross-chain payment release to applicant:

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "releasePaymentCrossChain(string,uint32,address,bytes)" \
  "40232-38" \
  2 \
  0x1D06bb4395AE7BFe9264117726D069C251dC27f5 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Parameters**:
- `"40232-38"`: Job ID
- `2`: Target chain domain (OP Sepolia)
- `0x1D06bb4395AE7BFe9264117726D069C251dC27f5`: WALL3's wallet address
- LayerZero options for cross-chain messaging

### **Step 7: Find NOWJC Execution Transaction**

The previous step sends a LayerZero message to NOWJC. Find the execution transaction:
- Check [Arbscan NOWJC contract](https://sepolia.arbiscan.io/address/0x9E39B37275854449782F1a2a4524405cE79d6C1e)
- Look for recent transaction calling `sendFast()` 
- Example TX: `0x6ea27e797d6e0c52b8768c7f05627ab6e8f33fa24a0ac458fb3700776a716eb2`

### **Step 8: Check Direct Payment Attestation**

Verify NOWJC sent USDC directly to applicant:

```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=0x6ea27e797d6e0c52b8768c7f05627ab6e8f33fa24a0ac458fb3700776a716eb2"
```

**Verify**:
- `"mintRecipient": "0x1d06bb4395ae7bfe9264117726d069c251dc27f5"` ✅ (WALL3's wallet)
- `"amount": "500000"` ✅ (0.5 USDC milestone)
- `"status": "complete"` ✅

### **Step 9: Complete Direct Payment to Applicant**

Complete the CCTP transfer to mint USDC directly to applicant's wallet:

```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "MESSAGE_FROM_MILESTONE_ATTESTATION" \
  "ATTESTATION_FROM_MILESTONE_API" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Result**: 0.49995 USDC minted directly to WALL3's wallet on OP Sepolia

### **Step 10: Verify Applicant Received Payment**

Check the applicant's USDC balance:

```bash
source .env && cast call 0x5fd84259d66cd46123540766be93dfe6d43130d7 \
  "balanceOf(address)" \
  0x1D06bb4395AE7BFe9264117726D069C251dC27f5 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Expected**: Increased balance showing received milestone payment

---

## 🔄 **For Multiple Milestones**

The system automatically handles each milestone. For the second milestone:

1. **Repeat Steps 6-10** for milestone 2
2. **Final verification**: Total applicant balance should show ~0.9999 USDC (both milestones)

**Example Final Balance**: 1,499,850 wei = 1.49985 USDC

---

## ⚡ **Key Technical Notes**

### **CCTP Fee Structure**
- **Fee per transfer**: ~100 wei (0.0001 USDC)
- **Expected amounts**: 500,000 wei becomes ~499,950 wei after fees

### **Domain Mapping**
- **OP Sepolia**: Domain 2
- **Arbitrum Sepolia**: Domain 3

### **Critical Success Indicators**
1. **Direct Recipient**: CCTP `mintRecipient` shows applicant wallet (not LOWJC)
2. **Automatic Execution**: No manual distribution required
3. **Full Amount**: Applicant receives milestone amounts minus CCTP fees only

### **V2 Direct Payment Architecture**
```
Job Giver (OP) → LOWJC → CCTP → NOWJC (Arbitrum) 
                                    ↓
              Applicant Wallet ← CCTP ← sendFast(applicant_address)
```

---

## 🎯 **Success Metrics**

✅ **Complete automation**: No manual intervention after job start  
✅ **Direct payments**: USDC goes straight to applicant wallet  
✅ **Cross-chain efficiency**: Leverages LayerZero + CCTP  
✅ **Milestone support**: Handles multiple payment releases  
✅ **Fee optimization**: Only CCTP fees, no additional overhead  

---

## 🚨 **Troubleshooting**

### **Common Issues**
1. **"Job must be in progress" error**: All milestones already completed
2. **CCTP "pending_confirmations"**: Wait for attestation, check API status
3. **Gas estimation failed**: Ensure sufficient ETH for gas on both chains
4. **Wrong recipient**: Verify applicant address in `releasePaymentCrossChain`

### **Verification Commands**
```bash
# Check NOWJC USDC balance (should decrease after payment)
cast call 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d "balanceOf(address)" 0x9E39B37275854449782F1a2a4524405cE79d6C1e --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check applicant balance (should increase)
cast call 0x5fd84259d66cd46123540766be93dfe6d43130d7 "balanceOf(address)" 0x1D06bb4395AE7BFe9264117726D069C251dC27f5 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

---

**Tutorial Status**: ✅ **Validated with real transactions**  
**Last Updated**: September 20, 2025  
**Version**: V2 Direct Payment Implementation