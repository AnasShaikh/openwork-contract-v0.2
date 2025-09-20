# Complete Cross-Chain Job Cycle Tutorial - Multi-Chain Direct Payment

**Date**: September 20, 2025  
**Purpose**: Step-by-step tutorial for complete cross-chain job lifecycle with direct USDC payments  
**Architecture**: Multi-chain job posting with automated cross-chain payment delivery
**Flow**: Ethereum Sepolia (Job) → OP Sepolia (Application) → Arbitrum Sepolia (Processing) → OP Sepolia (Payment)

---

## 🎯 **Overview**

This tutorial demonstrates the complete OpenWork cross-chain job lifecycle where:
- Job giver posts a job on **Ethereum Sepolia**
- Job applicant applies from **OP Sepolia** (cross-chain application)
- Processing occurs on **Arbitrum Sepolia** (native chain)
- USDC payment delivers directly to applicant wallet on **OP Sepolia**

### **Key Innovation: True Cross-Chain Platform**
- ✅ Post jobs on any supported chain
- ✅ Apply from any chain to any job
- ✅ Automated cross-chain USDC delivery
- ✅ Direct payment to applicant wallets (no manual distribution)

---

## 📋 **Prerequisites**

### **Contract Addresses**

#### **Ethereum Sepolia (Local Chain)**
- **LOWJC Proxy**: `0x325c6615Caec083987A5004Ce9110f932923Bd3A`
- **USDC Token**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- **CCTP Sender**: `0x5ca4989dc80b19fc704af9d7a02b7a99a2fb3461`

#### **OP Sepolia (Local Chain)**  
- **LOWJC Proxy**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **USDC Token**: `0x5fd84259d66cd46123540766be93dfe6d43130d7`
- **CCTP Receiver**: `0x72d6efedda70f9b4ed3fff4bdd0844655aea2bd5`

#### **Arbitrum Sepolia (Native Chain)**
- **NOWJC Proxy**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **NOWJC Implementation**: `0x5b4f880C96118A1665F97bCe8A09d2454d6c462F` (Domain Fix + Direct Payment)
- **USDC Token**: `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d`
- **CCTP Receiver**: `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`

### **Wallet Setup**
- **Job Giver (WALL2)**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Job Applicant (WALL1)**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- **USDC Required**: 1+ USDC on Ethereum Sepolia for job giver

### **Tools Required**
- Foundry (cast)
- Environment variables configured (.env file)
- Access to Ethereum Sepolia, OP Sepolia, and Arbitrum Sepolia

---

## 🚀 **Step-by-Step Tutorial**

### **Step 1: Post Job on Ethereum Sepolia**

Post a 1 USDC job on Ethereum Sepolia:

```bash
source .env && cast send 0x325c6615Caec083987A5004Ce9110f932923Bd3A \
  "postJob(string,string[],uint256[],bytes)" \
  "eth-to-op-cycle-001" \
  '["Cross-chain job cycle: Ethereum to OP Sepolia"]' \
  '[1000000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: Job created with ID like `40233-3`

### **Step 2: Cross-Chain Application from OP Sepolia**

Apply to the Ethereum Sepolia job from OP Sepolia:

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "applyToJob(string,string,string[],uint256[],bytes)" \
  "40233-3" \
  "QmWall1CrossChainApplication" \
  '["Cross-chain application from OP Sepolia to Ethereum job"]' \
  '[1000000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Expected Result**: Cross-chain application successful, applicant registered

### **Step 3: Approve USDC Spending (Ethereum Sepolia)**

Allow LOWJC contract to spend USDC:

```bash
source .env && cast send 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
  "approve(address,uint256)" \
  0x325c6615Caec083987A5004Ce9110f932923Bd3A \
  2000000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: LOWJC approved to spend 2 USDC

### **Step 4: Start Job with CCTP Transfer**

Start the job and initiate CCTP transfer to Arbitrum NOWJC:

```bash
source .env && cast send 0x325c6615Caec083987A5004Ce9110f932923Bd3A \
  "startJob(string,uint256,bool,bytes)" \
  "40233-3" \
  1 \
  false \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: CCTP transfer initiated (1 USDC: Ethereum Sepolia → Arbitrum NOWJC)

### **Step 5: Check CCTP Attestation**

Check if CCTP attestation is ready (replace TX_HASH with actual hash):

```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/0?transactionHash=TX_HASH"
```

**Wait for**: Status "complete" before proceeding

### **Step 6: Complete CCTP Transfer to NOWJC**

Complete the CCTP transfer on Arbitrum Sepolia (use message/attestation from Step 5):

```bash
source .env && cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 \
  "receive(bytes,bytes)" \
  "MESSAGE_FROM_ATTESTATION" \
  "ATTESTATION_FROM_API" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: ~0.9999 USDC minted to NOWJC on Arbitrum Sepolia

### **Step 7: Release Payment Cross-Chain**

Release payment from Ethereum Sepolia to target OP Sepolia:

```bash
source .env && cast send 0x325c6615Caec083987A5004Ce9110f932923Bd3A \
  "releasePaymentCrossChain(string,uint32,address,bytes)" \
  "40233-3" \
  2 \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: Cross-chain message sent to Arbitrum NOWJC

### **Step 8: NOWJC Processes Payment** 

NOWJC automatically receives the cross-chain message and initiates CCTP transfer to applicant.

**Monitor for**: Transaction on Arbitrum Sepolia from NOWJC contract

### **Step 9: Check Second CCTP Attestation**

Check attestation for NOWJC → OP Sepolia transfer:

```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=NOWJC_TX_HASH"
```

**Wait for**: Status "complete" with mint recipient as applicant address

### **Step 10: Complete Direct Payment**

Complete the CCTP transfer on OP Sepolia (direct to applicant):

```bash
source .env && cast send 0x72d6efedda70f9b4ed3fff4bdd0844655aea2bd5 \
  "receive(bytes,bytes)" \
  "MESSAGE_FROM_SECOND_ATTESTATION" \
  "SECOND_ATTESTATION_FROM_API" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: ~0.9999 USDC minted directly to applicant wallet

### **Step 11: Verify Final Payment**

Check applicant's USDC balance:

```bash
source .env && cast call 0x5fd84259d66cd46123540766be93dfe6d43130d7 \
  "balanceOf(address)" \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Expected Result**: Increased USDC balance showing payment received

---

## 🎯 **Key Features Demonstrated**

### **✅ True Cross-Chain Platform**
- Job posted on **Ethereum Sepolia**
- Application from **OP Sepolia**
- Processing on **Arbitrum Sepolia**  
- Payment delivered to **OP Sepolia**

### **✅ Automated Payment Flow**
- No manual fund distribution required
- Direct USDC delivery to applicant wallets
- Standard CCTP fees (~100 wei per transfer)
- End-to-end automation

### **✅ Multi-Chain Support**
- All testnet domains supported (0=Ethereum, 2=OP, 3=Arbitrum)
- Cross-chain validation and routing
- Unified job platform across chains

---

## 🚨 **Important Notes**

### **CCTP Timing**
- Allow 1-2 minutes between CCTP initiation and attestation availability
- Always check attestation status before completing transfers
- Attestations expire after ~24 hours

### **Gas Requirements**
- LayerZero messages require ~0.0015 ETH per cross-chain call
- CCTP completions require standard gas fees
- Ensure sufficient ETH on all chains

### **Domain Mapping**
- Domain 0: Ethereum Sepolia
- Domain 2: OP Sepolia  
- Domain 3: Arbitrum Sepolia

### **Fee Structure**
- Standard CCTP fee: 100 wei USDC per transfer
- Two CCTP transfers per job: ~200 wei total fee
- Final amount: ~0.9998 USDC received by applicant

---

## 🎉 **Success Indicators**

### **Job Lifecycle Complete When**:
1. ✅ Job posted and visible on native chain
2. ✅ Cross-chain application successful
3. ✅ Job started with CCTP transfer to NOWJC
4. ✅ Payment released with cross-chain message
5. ✅ USDC delivered directly to applicant wallet

### **Expected Final State**:
- Job status: Completed
- Applicant balance: Increased by ~0.9998 USDC
- All cross-chain messages processed
- No manual intervention required

---

## 🚀 **Production Readiness**

This tutorial demonstrates a **production-ready** multi-chain job platform with:
- ✅ Full cross-chain functionality
- ✅ Automated payment delivery
- ✅ CCTP integration for USDC transfers
- ✅ Direct payment to applicant wallets
- ✅ Error handling and validation

**Ready for mainnet deployment** with appropriate contract upgrades and production CCTP integration.

---

**Tutorial Date**: September 20, 2025  
**Implementation Status**: Production Ready  
**Multi-Chain Support**: Ethereum, Optimism, Arbitrum (Testnets)