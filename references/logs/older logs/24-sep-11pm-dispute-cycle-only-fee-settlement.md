# Complete Dispute Cycle with Fee Settlement - OP Sepolia Focus

**Date**: September 24, 2025 - 11 PM  
**Purpose**: Complete cross-chain dispute lifecycle with fee distribution testing  
**Architecture**: OP Sepolia (Job + Dispute) → Arbitrum Sepolia (Processing + Fee Settlement)  
**Status**: ✅ **Fully Validated - Fee Settlement Only**

---

## 🎯 **Overview**

This documents a complete cross-chain dispute cycle where:
- Job posted and managed on **OP Sepolia** 
- Application submitted on **OP Sepolia** with preferred chain domain
- Job started with CCTP funding to **Arbitrum Sepolia** NOWJC
- Dispute raised from **OP Sepolia** Athena Client
- Fee settlement processed on **Arbitrum Sepolia** Native Athena

### **Key Focus**
- ✅ Cross-chain dispute initiation via Athena Client
- ✅ CCTP fee routing (OP Sepolia → Arbitrum Sepolia)
- ✅ Traditional monolithic fee distribution (NOWJC calls disabled)
- ✅ Complete end-to-end dispute process validation

---

## 📋 **Contract Addresses & Implementation Details**

### **OP Sepolia (Local Chain)**
- **LOWJC Proxy**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **LOWJC Implementation**: Enhanced with chain domain storage support
- **Athena Client Proxy**: `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7`
- **Athena Client Implementation**: `src/current/testable-athena/athena-client-testable.sol`
- **USDC Token**: `0x5fd84259d66cd46123540766be93dfe6d43130d7`
- **MessageTransmitter**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`

### **Arbitrum Sepolia (Native Chain)**
- **Native Athena Proxy**: `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE`
- **Native Athena Implementation**: `0x46a6973D69112AFa973396F4f36607abb1388bDE` ✅ **ACTIVE**
- **Source File**: `src/current/testable-athena/native-athena-testable.sol`
- **Contract Class**: `NativeAthenaTestable`
- **Configuration**: NOWJC calls disabled for isolated fee distribution testing
- **NOWJC Proxy**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **USDC Token**: `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d`
- **CCTP Receiver**: `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`

### **Proxy Contract**
- **Proxy Source**: `src/current/interchain locking passed/proxy.sol`
- **Proxy Type**: UUPSProxy (ERC1967 compatible)
- **Implementation Query**: `getImplementation()` function available

### **Wallet Setup**
- **Job Giver (WALL2)**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Job Applicant (WALL1)**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`

---

## 🚀 **Complete Step-by-Step Commands**

### **Step 1: Post Job on OP Sepolia**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "postJob(string,string[],uint256[],bytes)" \
  "dispute-test-op-sepolia-only-001" \
  '["Milestone 1: Initial deliverable", "Milestone 2: Final completion"]' \
  '[500000, 500000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Job ID: `40232-55` (from event logs)
- ✅ TX Hash: `0xe51f857ae14053b54ebb1376687b2e75abb02a66031a31a80452a1bd216918af`
- ✅ Gas Used: 505,209

### **Step 2: Apply to Job from OP Sepolia**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "applyToJob(string,string,string[],uint256[],uint32,bytes)" \
  "dispute-test-op-sepolia-only-001" \
  "QmApplicantOpSepoliaOnly" \
  '["Milestone 1: Initial work delivery", "Milestone 2: Final project completion"]' \
  '[500000, 500000]' \
  2 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Application ID: `1` (from event logs)
- ✅ TX Hash: `0x2b0cc432ecc034a0f09f2b7a9991ce6a1d53f7e6dd5ce4af52aa2e16e6e70cf7`
- ✅ Gas Used: 609,548

**Key Parameter**: `2` = preferred chain domain (OP Sepolia)

### **Step 3: Approve USDC Spending for Job**

```bash
source .env && cast send 0x5fd84259d66cd46123540766be93dfe6d43130d7 \
  "approve(address,uint256)" \
  0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  2000000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Approval: 2 USDC allowance granted
- ✅ TX Hash: `0x7bbd069029934dcc3b22284519da9f58e74b14fe83382745d18e491c918629f0`

### **Step 4: Start Job with CCTP Transfer**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startJob(string,uint256,bool,bytes)" \
  "40232-55" \
  1 \
  false \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ CCTP Transfer: 0.5 USDC burned on OP Sepolia
- ✅ Target: Arbitrum NOWJC (`0x9E39B37275854449782F1a2a4524405cE79d6C1e`)
- ✅ TX Hash: `0x4dd015016867b9b1b86f1bd7db05c803647273e60029434e4233ca0b22e079b1`
- ✅ Gas Used: 509,014

### **Step 5: Approve USDC for Dispute Fee**

```bash
source .env && cast send 0x5fd84259d66cd46123540766be93dfe6d43130d7 \
  "approve(address,uint256)" \
  0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  2000000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Approval: 2 USDC allowance granted to Athena Client
- ✅ TX Hash: `0x42bcb66060e5a30cb674ef2d917a5b9cc6ba784a6f41233201fffb22ddfd28a6`

### **Step 6: Raise Dispute via Athena Client**

```bash
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "raiseDispute(string,string,string,uint256,bytes)" \
  "40232-55" \
  "QmOpSepoliaDisputeTest001" \
  "TestOracle" \
  500000 \
  0x00030100110100000000000000000000000000055730 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ CCTP Transfer: 0.5 USDC burned on OP Sepolia
- ✅ Target: Native Athena (`0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE`)
- ✅ LayerZero Message: Cross-chain dispute data sent to Arbitrum
- ✅ TX Hash: `0xb925463323d3e176879242fe8792acd00b0d78037d4528cffc5e46a643bab14d`
- ✅ Gas Used: 468,367

### **Step 7: Vote on Dispute (Arbitrum Sepolia)**

```bash
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "vote(uint8,string,bool,address)" \
  0 "40232-55" true 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Vote: FOR job giver (true)
- ✅ Voter: WALL2 with valid earned tokens
- ✅ TX Hash: `0xb2783e35d465fe263f844ca369ed92e56f012ee11d13bf2ba0c0ca85092d708f`
- ✅ Gas Used: 321,207

### **Step 8: Process Fee Payment (Dispute Settlement)**

```bash
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "processFeePayment(string,address[],address[],uint256[],bool[],bool,uint256)" \
  "40232-55" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" \
  "[5]" \
  "[true]" \
  true \
  250000 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Fee Distribution: 250,000 wei USDC transferred to WALL2
- ✅ Winner Determination: Job giver wins (voted FOR = true)
- ✅ NOWJC Calls: Disabled (isolated fee distribution testing)
- ✅ TX Hash: `0x0631dbe1f8f9d8ac3b28a9abfeec386ae4211145f9a5a2d39d17c0cb05905bae`
- ✅ Gas Used: 69,413

---

## 🎯 **Key Technical Details**

### **Function Signatures**
- **postJob**: `postJob(string,string[],uint256[],bytes)`
- **applyToJob**: `applyToJob(string,string,string[],uint256[],uint32,bytes)` *(includes preferred chain domain)*
- **startJob**: `startJob(string,uint256,bool,bytes)`
- **raiseDispute**: `raiseDispute(string,string,string,uint256,bytes)`
- **vote**: `vote(uint8,string,bool,address)`
- **processFeePayment**: `processFeePayment(string,address[],address[],uint256[],bool[],bool,uint256)`

### **Domain Mapping**
- **OP Sepolia**: Domain `2`
- **Arbitrum Sepolia**: Domain `3`

### **Implementation Architecture**
- **Native Athena**: Traditional monolithic `processFeePayment` function
- **NOWJC Integration**: Calls disabled for isolated fee distribution testing
- **Proxy Pattern**: UUPSProxy with `getImplementation()` query support
- **Current Status**: Proven working version (rolled back from modular approach)

### **Fee Structure**
- **LayerZero Messages**: 0.001 ETH per cross-chain call
- **CCTP Fees**: ~100 wei per transfer
- **Dispute Fee**: 500,000 wei (0.5 USDC) via CCTP
- **Fee Distribution**: 250,000 wei (0.25 USDC) to winning voter

---

## 🎉 **Success Indicators**

### **Dispute Lifecycle Complete When**:
1. ✅ Job posted and applicant selected
2. ✅ Job started with CCTP funding to NOWJC
3. ✅ Dispute raised via Athena Client with CCTP fee transfer
4. ✅ Cross-chain message processed on Arbitrum
5. ✅ Voting completed with valid earned tokens
6. ✅ Fee distribution to winning voters completed

### **Final Results**:
- **Dispute Status**: Fee settlement completed
- **Job Giver Wins**: WALL2 voted FOR job giver (true)
- **Fee Distribution**: 250,000 wei USDC to WALL2 (winning voter)
- **Architecture**: Traditional monolithic approach (NOWJC calls disabled)
- **Settlement Scope**: Fee distribution only (job funds not settled due to disabled NOWJC calls)

---

## 📊 **Transaction Summary**

| Step | Description | TX Hash | Gas Used | Status | Notes |
|------|-------------|---------|----------|--------|-------|
| 1 | Post Job | `0xe51f857a...` | 505,209 | ✅ | Job `40232-55` created |
| 2 | Apply to Job | `0x2b0cc432...` | 609,548 | ✅ | Domain 2 preference set |
| 3 | Approve USDC (Job) | `0x7bbd0690...` | 38,337 | ✅ | 2 USDC allowance |
| 4 | Start Job | `0x4dd01501...` | 509,014 | ✅ | CCTP funding initiated |
| 5 | Approve USDC (Dispute) | `0x42bcb660...` | 38,337 | ✅ | 2 USDC allowance |
| 6 | Raise Dispute | `0xb9254633...` | 468,367 | ✅ | Cross-chain dispute sent |
| 7 | Vote on Dispute | `0xb2783e35...` | 321,207 | ✅ | FOR job giver vote cast |
| 8 | Process Fee Payment | `0x0631dbe1...` | 69,413 | ✅ | Fee distribution complete |

**Total Gas Used**: 2,559,432  
**Total ETH Spent**: ~0.006 ETH (LayerZero fees + gas)  
**Total USDC Moved**: 1.0 USDC (0.5 job funding + 0.5 dispute fee)  
**Fee Settlement**: 0.25 USDC distributed to winning voter

---

## 🚨 **Important Notes**

### **Critical Success Factors**
- Always include preferred chain domain (`uint32`) in `applyToJob`
- Approve USDC spending for both LOWJC and Athena Client contracts
- Use correct contract addresses for each chain
- Vote with wallets that have earned tokens (voting power)

### **Current Implementation Limitations**
- **NOWJC Calls Disabled**: Job fund settlement not performed
- **Fee Distribution Only**: Disputes resolve with voter rewards but no job fund transfer
- **Isolated Testing**: Designed for fee distribution system validation
- **Monolithic Approach**: Traditional `processFeePayment` (not modular functions)

### **Architecture Status**
- **Proven Working Version**: Rolled back from modular approach due to integration issues
- **Fee Distribution**: Fully operational and tested
- **Job Fund Settlement**: Disabled for isolated testing
- **Upgrade Path**: Modular implementation available for future deployment

---

## 🔧 **Implementation Query Commands**

### **Check Current Implementation**
```bash
source .env && cast call 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "getImplementation()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Result**: `0x46a6973D69112AFa973396F4f36607abb1388bDE`

### **Implementation Mapping**
- **Address**: `0x46a6973D69112AFa973396F4f36607abb1388bDE`
- **Source**: `src/current/testable-athena/native-athena-testable.sol`
- **Class**: `NativeAthenaTestable`
- **Status**: NOWJC calls disabled for fee distribution testing
- **Type**: Proven working version (traditional monolithic approach)

---

**Documentation Status**: ✅ **Complete and Validated**  
**Last Updated**: September 24, 2025 - 11 PM  
**Scope**: Cross-chain dispute initiation with fee settlement only  
**Architecture**: Traditional monolithic approach with NOWJC calls disabled