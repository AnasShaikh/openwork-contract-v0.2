# Athena Cross-Chain Fee Routing Testing Plan

**Date Created**: September 20, 2025  
**Status**: Ready for Execution  
**Priority**: High  

---

## 🎯 **Testing Overview**

This document outlines the complete testing plan for the newly deployed Athena Cross-Chain Fee Routing system, including all necessary steps to validate end-to-end functionality from fee collection to dispute resolution.

### **System Components Deployed**
- **OP Sepolia**: Athena Client Testable (`0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7`)
- **Arbitrum Sepolia**: Native Athena Testable (`0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE`)
- **Arbitrum Sepolia**: NOWJC Testable Implementation (`0xC968479Ed1475b4Ffe9186657930E94F81857244`) - **NOT YET UPGRADED**

---

## 📋 **Phase 0: Essential Prerequisites & Configuration**

### **0.1 CRITICAL: Configure Athena Client Before Testing**

#### **Set Job Contract Reference (REQUIRED)**
```bash
# Point Athena Client to existing LOWJC contract
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "setJobContract(address)" 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Verification:**
```bash
# Verify job contract is set correctly
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "jobContract()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
# Should return: 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C
```

#### **Approve USDC Spending for Fee Payments**
```bash
# Approve Athena Client to spend USDC for dispute fees (100 USDC)
source .env && cast send 0x5fd84259d66cd46123540766be93dfe6d43130d7 "approve(address,uint256)" 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 100000000 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Approve for additional test wallets if needed
source .env && cast send 0x5fd84259d66cd46123540766be93dfe6d43130d7 "approve(address,uint256)" 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 100000000 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

#### **Verify Minimum Fee Requirements**
```bash
# Check minimum dispute fee (should be 50 USDC = 50,000,000 wei)
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "minDisputeFee()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Check wallet USDC balances
source .env && cast call 0x5fd84259d66cd46123540766be93dfe6d43130d7 "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

#### **Verify Current Configurations**
```bash
# Verify CCTP configuration
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "cctpSender()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "nativeAthenaRecipient()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "nativeChainDomain()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Verify bridge configuration
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "bridge()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

### **0.2 Setup Test Job (REQUIRED for Dispute Testing)**

**⚠️ IMPORTANT:** The `raiseDispute()` function requires:
- Job must exist in LOWJC
- Job must be in "InProgress" status (started)
- Caller must be either job giver OR selected applicant
- No existing dispute for the job
- Minimum fee of 50 USDC

#### **Create Test Job for Dispute**
```bash
# Step 1: Post test job
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "postJob(string,string[],uint256[],bytes)" "QmTestJobForDispute001" '["QmMilestone1"]' '[2000000]' 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Step 2: Apply to job (from different wallet)
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "applyToJob(string,string,string[],uint256[],bytes)" "JOB_ID_FROM_STEP1" "QmApplicationForDispute" '["QmMilestone1Modified"]' '[2000000]' 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Step 3: Start job (puts job in InProgress status)
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "startJob(string,uint256,bool,bytes)" "JOB_ID_FROM_STEP1" 1 false 0x0003010011010000000000000000000000000007a120 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY --value 0.001ether
```

#### **Verify Job is Ready for Dispute**
```bash
# Check job status (should be 1 = InProgress)
source .env && cast call 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "getJob(string)" "JOB_ID_FROM_STEP1" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Verify no existing dispute
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "jobDisputeExists(string)" "JOB_ID_FROM_STEP1" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**✅ Prerequisites Complete - Ready for Phase 1 Testing**

---

## 📋 **Phase 1: Basic Function Testing**

### **1.1 Test Athena Client Fee Functions (OP Sepolia)**

#### **Test raiseDispute() Function**
```bash
# Test dispute raising with fee routing to native chain (use job ID from Phase 0.2)
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "raiseDispute(string,string,string,uint256,bytes)" "JOB_ID_FROM_PHASE_0" "QmDisputeHashTest" "TestOracle" 50000000 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**⚠️ Note:** Use the actual job ID created in Phase 0.2, and ensure fee amount meets minimum requirement (50 USDC = 50,000,000 wei)

**Expected Results:**
- ✅ Fee transferred via CCTP to Native Athena
- ✅ LayerZero message sent with dispute data
- ✅ Dispute record created locally

**Verification Commands:**
```bash
# Check fee routing occurred
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "getContractBalance()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL

# Check dispute exists locally
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "jobDisputeExists(string)" "test-job-001" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

#### **Test submitSkillVerification() Function**
```bash
# Test skill verification with fee routing
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "submitSkillVerification(string,uint256,string,bytes)" "QmSkillAppHash" 500000 "TestSkillOracle" 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

#### **Test askAthena() Function**
```bash
# Test ask athena with fee routing
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "askAthena(string,string,string,uint256,bytes)" "Test question description" "QmQuestionHash" "TestAthenaOracle" 750000 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **1.2 Verify CCTP Fee Transfer**

#### **Check CCTP Attestation Status**
```bash
# Replace TX_HASH with actual transaction hash from raiseDispute
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=TX_HASH"
```

#### **Complete CCTP Transfer (if needed)**
```bash
# Use message and attestation from API response
source .env && cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 "receive(bytes,bytes)" "MESSAGE_FROM_API" "ATTESTATION_FROM_API" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

#### **Verify Native Athena Received Fees**
```bash
# Check Native Athena USDC balance
source .env && cast call 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d "balanceOf(address)" 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## 📋 **Phase 2: Native Athena Testing**

### **2.1 Test Fee Processing Functions (Arbitrum Sepolia)**

#### **Simulate Fee Payment Processing**
```bash
# Test processFeePayment function (simulating LayerZero callback)
# Note: This would normally be called by the bridge after receiving LayerZero message
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "processFeePayment(string,address[],address[],uint256[],bool[],bool,uint256)" "test-dispute-001" '["0xfD08836eeE6242092a9c869237a8d122275b024A"]' '["0xfD08836eeE6242092a9c869237a8d122275b024A"]' '[100]' '[true]' true 1000000 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **2.2 Configuration Testing**

#### **Test Native Athena Configuration Functions**
```bash
# Test setting reward chain EID
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "setRewardsChainEid(uint32)" 40232 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Test setting athena client chain EID  
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "setAthenaClientChainEid(uint32)" 40232 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Verify configurations
source .env && cast call 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "rewardsChainEid()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
source .env && cast call 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "athenaClientChainEid()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## 📋 **Phase 3: Dispute Resolution Testing**

### **3.1 CRITICAL: Upgrade NOWJC Before Testing Dispute Resolution**

#### **Upgrade NOWJC Proxy to Dispute Resolution Implementation**
```bash
# IMPORTANT: Run this command just before testing dispute resolution
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "upgradeToAndCall(address,bytes)" 0xC968479Ed1475b4Ffe9186657930E94F81857244 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Verification:**
```bash
# Verify upgrade was successful
source .env && cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "implementation()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Should return: 0xC968479Ed1475b4Ffe9186657930E94F81857244
```

### **3.2 Test Dispute Resolution Flow**

#### **Test releaseDisputedFunds() Function**
```bash
# Test disputed fund release to same chain (native chain winner)
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "releaseDisputedFunds(string,address,uint32)" "test-job-001" 0x1D06bb4395AE7BFe9264117726D069C251dC27f5 3 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Test disputed fund release to cross-chain (OP Sepolia winner)
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "releaseDisputedFunds(string,address,uint32)" "test-job-002" 0x1D06bb4395AE7BFe9264117726D069C251dC27f5 2 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

#### **Verify Disputed Fund Distribution**
```bash
# For same-chain release, check recipient balance
source .env && cast call 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d "balanceOf(address)" 0x1D06bb4395AE7BFe9264117726D069C251dC27f5 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# For cross-chain release, check CCTP attestation and complete transfer
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=RELEASE_TX_HASH"
```

---

## 📋 **Phase 4: End-to-End Integration Testing**

### **4.1 Complete Fee Routing Flow Test**

#### **Step 1: Setup Test Job**
```bash
# Create a test job on existing LOWJC (prerequisite)
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "postJob(string,string[],uint256[],bytes)" "QmTestJobForDispute" '["QmMilestone1"]' '[2000000]' 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

#### **Step 2: Apply and Start Job**
```bash
# Apply to job
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "applyToJob(string,string,string[],uint256[],bytes)" "JOB_ID_FROM_STEP1" "QmApplicationHash" '["QmMilestone1Modified"]' '[2000000]' 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Start job (locks funds in NOWJC)
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "startJob(string,uint256,bool,bytes)" "JOB_ID_FROM_STEP1" 1 false 0x0003010011010000000000000000000000000007a120 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY --value 0.001ether
```

#### **Step 3: Raise Dispute**
```bash
# Raise dispute using Athena Client
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "raiseDispute(string,string,string,uint256,bytes)" "JOB_ID_FROM_STEP1" "QmDisputeDetails" "TestOracle" 1000000 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

#### **Step 4: Process Dispute on Native Athena**
```bash
# Simulate dispute voting and finalization
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "processFeePayment(string,address[],address[],uint256[],bool[],bool,uint256)" "JOB_ID_FROM_STEP1" '["0xfD08836eeE6242092a9c869237a8d122275b024A"]' '["0xfD08836eeE6242092a9c869237a8d122275b024A"]' '[100]' '[true]' true 1000000 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **4.2 Validation Checklist**

#### **Fee Routing Validation**
- [ ] Athena Client fees routed to Native Athena via CCTP
- [ ] LayerZero messages delivered to Native Athena
- [ ] Fee payment distributed to winning voters
- [ ] No fees remain locked in local Athena Client

#### **Dispute Resolution Validation**
- [ ] Disputed funds released from NOWJC
- [ ] Cross-chain disputed fund transfer via CCTP
- [ ] Dispute winner receives funds on target chain
- [ ] Job marked as resolved appropriately

---

## 📋 **Phase 5: Performance & Security Testing**

### **5.1 Gas Optimization Testing**

#### **Test Different LayerZero Gas Options**
```bash
# Standard gas options
STANDARD_OPTIONS="0x00030100110100000000000000000000000000055730"

# Higher gas options  
HIGHER_OPTIONS="0x000301001101000000000000000000000000000493e0"

# Maximum gas options
MAX_OPTIONS="0x0003010011010000000000000000000000000007a120"
```

### **5.2 Error Handling Testing**

#### **Test Invalid Parameters**
```bash
# Test with zero fee amount (should fail)
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "raiseDispute(string,string,string,uint256,bytes)" "test-job-invalid" "QmHash" "Oracle" 0 0x00030100110100000000000000000000000000055730 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Test with insufficient balance (should fail)
# First drain test wallet, then try transaction
```

#### **Test Access Controls**
```bash
# Test unauthorized calls (should fail)
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE "processFeePayment(string,address[],address[],uint256[],bool[],bool,uint256)" "unauthorized-test" '["0xfD08836eeE6242092a9c869237a8d122275b024A"]' '["0xfD08836eeE6242092a9c869237a8d122275b024A"]' '[100]' '[true]' true 1000000 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

---

## 📋 **Phase 6: Documentation & Cleanup**

### **6.1 Document Test Results**

#### **Create Test Results Documentation**
- Create test results file in `/references/logs/`
- Document all successful transactions with hashes
- Record any failures and resolutions
- Include performance metrics and gas usage

#### **Update Architecture Documentation**
- Update deployment registry with final addresses
- Document any configuration changes
- Create user guide for fee routing system

### **6.2 Production Readiness Checklist**

#### **Security Validation**
- [ ] All access controls tested and working
- [ ] Fee routing cannot be bypassed
- [ ] Dispute resolution cannot be manipulated
- [ ] Cross-chain message validation working

#### **Integration Validation**
- [ ] Compatible with existing job platform
- [ ] LayerZero integration stable
- [ ] CCTP integration reliable
- [ ] Bridge infrastructure operational

---

## 🔧 **Reference Documentation**

### **Contract Registry**
- **Enhanced Bridge Deployment**: `references/deployments/enhanced-bridge-deployment-20-sep.md`
- **Original Deployment Log**: `references/deployments/17-sep-deployments-10pm.md`
- **Implementation Documentation**: `references/context/athena-cross-chain-fee-routing-implementation.md`

### **Working Examples**
- **Successful CCTP Flow**: `references/logs/cross-chain-payment-release-fix-test-cycle-20-sep-2025.md`
- **Cross-Chain Tutorial**: `references/tutorials/complete-cross-chain-job-cycle-tutorial.md`

### **Key Infrastructure Addresses**
```
# OP Sepolia (Local Chain)
ATHENA_CLIENT_PROXY="0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7"
LOCAL_BRIDGE="0xaff9967c6000ee6feec04d29a39cc7a4ecff4bc0"
CCTP_SENDER="0x72d6efedda70f9b4ed3fff4bdd0844655aea2bd5"
USDC_TOKEN="0x5fd84259d66cd46123540766be93dfe6d43130d7"

# Arbitrum Sepolia (Native Chain)  
NATIVE_ATHENA_PROXY="0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE"
NOWJC_PROXY="0x9E39B37275854449782F1a2a4524405cE79d6C1e"
NOWJC_DISPUTE_IMPL="0xC968479Ed1475b4Ffe9186657930E94F81857244"
ENHANCED_BRIDGE="0xAe02010666052571E399b1fe9E2c39B37A3Bc3A7"
CCTP_RECEIVER="0xB64f20A20F55D77bbe708Db107AA5E53a9e39063"
USDC_TOKEN="0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d"
```

### **CCTP Configuration**
```
# Domain Mappings
OP_SEPOLIA_DOMAIN=2
ARBITRUM_SEPOLIA_DOMAIN=3

# API Endpoints
CCTP_ATTESTATION_API="https://iris-api-sandbox.circle.com/v2/messages"
```

---

## ⚠️ **Important Notes**

### **Pre-Testing Requirements**
1. **Wallet Balances**: Ensure test wallets have sufficient USDC for fee payments
2. **USDC Approvals**: Pre-approve USDC spending for test contracts
3. **ETH for Gas**: Ensure sufficient ETH on both chains for transaction fees

### **Critical Testing Sequence**
1. **DO NOT** upgrade NOWJC until ready to test dispute resolution (Phase 3.1)
2. **Always** check CCTP attestation status before completing transfers
3. **Verify** LayerZero message delivery on destination chain
4. **Document** all transaction hashes for troubleshooting

### **Rollback Plan**
If testing reveals issues:
1. **Downgrade NOWJC**: Revert to previous implementation if needed
2. **Configuration Reset**: Reset any changed parameters
3. **Bridge Isolation**: Temporarily disable cross-chain messages if needed

---

**Testing Plan Created**: September 20, 2025  
**Estimated Testing Duration**: 4-6 hours  
**Prerequisites**: All contracts deployed, wallets funded, infrastructure operational