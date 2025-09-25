# Complete Dispute Cycle Test Plan - September 22, 2025

## 🎯 **Test Objective**
Validate the complete cross-chain disputed job cycle using the new simplified interface architecture with chain domain storage for applicant preferences.

**Architecture**: Enhanced LOWJC → Enhanced Native Bridge → Enhanced Native Athena → Simplified NOWJC  
**Flow**: OP Sepolia → LayerZero + CCTP → Arbitrum Sepolia → Cross-chain settlement  
**Innovation**: First test of simplified interface pattern for dispute resolution

---

## 📋 **Test Environment Setup**

### **Updated Contract Addresses**
- **NOWJC Proxy**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e` (Arbitrum Sepolia)
- **NOWJC Implementation**: `0xb852098C17ee2B63e0b345b5D0F22CE84B5dF02f` ✅ (Simplified dispute interface)
- **Native Athena Proxy**: `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` (Arbitrum Sepolia)  
- **Native Athena Implementation**: `0xeAC3E57185FE584Ab1C6a79a893321253F0b862c` ✅ (Enhanced dispute logic)
- **LOWJC Proxy**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` (OP Sepolia)
- **LOWJC Implementation**: `0x7e34A4a539e4c6cFBfa2d6304b61e74F3672a4fc` ✅ (Chain domain storage)
- **Genesis Contract**: `0x85E0162A345EBFcbEb8862f67603F93e143Fa487` (Arbitrum Sepolia)

### **Supporting Infrastructure**
- **Enhanced Native Bridge**: `0xAff9967C6000ee6FEeC04D29a39Cc7a4ECFf4BC0` (Arbitrum Sepolia)
- **Local Bridge**: `0xaff9967c6000ee6feec04d29a39cc7a4ecff4bc0` (OP Sepolia)
- **Athena Client**: `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` (OP Sepolia)
- **CCTP Transceiver**: `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063` (Arbitrum Sepolia)

### **Test Participants**
- **Job Giver (WALL2)**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Job Applicant (WALL1)**: `0x1D06bb4395AE7BFe9264117726D069C251dC27f5`  
- **Chain Preference**: Applicant wants funds on **Ethereum Sepolia** (domain 0)

---

## 🚀 **Step-by-Step Test Execution Plan**

### **Phase 1: Job Creation & Application**

#### **Step 1.1: Post Job on OP Sepolia (WALL2 as Job Giver)**
```bash
# Post job with 1 USDC total (2 milestones of 0.5 USDC each)
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "postJob(string,string[],uint256[],bytes)" \
  "dispute-test-simplified-interface-001" \
  '["Milestone 1: Initial deliverable", "Milestone 2: Final completion"]' \
  '[500000, 500000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: Job posted with ID `dispute-test-simplified-interface-001`  
**Verification**: Check job exists in Genesis contract  
**Status**: ⏳ **PENDING**

#### **Step 1.2: Apply to Job from Ethereum Sepolia (WALL1 as Applicant)**
```bash
# Apply to job with preferredChainDomain=0 (Ethereum Sepolia)
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "applyToJob(string,string,string[],uint256[],uint32,bytes)" \
  "dispute-test-simplified-interface-001" \
  "QmApplicantPrefersDomain0" \
  '["Milestone 1: Initial work delivery", "Milestone 2: Final project completion"]' \
  '[500000, 500000]' \
  0 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL1_KEY
```

**Expected Result**: Application submitted with chain domain 0 stored in NOWJC  
**Verification**: Check `jobApplicantChainDomain["dispute-test-simplified-interface-001"][WALL1] == 0`  
**Status**: ⏳ **PENDING**

#### **Step 1.3: Start Job (WALL2 selects WALL1 and funds job)**
```bash
# Start job and fund via CCTP to NOWJC
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startJob(string,uint256,bool,bytes)" \
  "dispute-test-simplified-interface-001" \
  1 \
  false \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0015ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: Job funded via CCTP, USDC minted to NOWJC, job status = InProgress  
**Verification**: Check NOWJC USDC balance increased by 1 USDC  
**Status**: ⏳ **PENDING**

---

### **Phase 2: Cross-Chain Dispute Initiation**

#### **Step 2.1: Raise Cross-Chain Dispute (WALL2 disputes work quality)**
```bash
# Raise dispute with 0.5 USDC fee via Athena Client cross-chain routing
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "raiseDispute(string,string,string,uint256,bytes)" \
  "dispute-test-simplified-interface-001" \
  "QmSimplifiedInterfaceDisputeTest" \
  "TestOracle" \
  500000 \
  0x00030100110100000000000000000000000000055730 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: 
- LayerZero message sent OP Sepolia → Arbitrum Sepolia
- 0.5 USDC transferred via CCTP to Native Athena
- Dispute created in Genesis with fee auto-registered in `accumulatedFees`
- Native Athena balance = 500,000 wei USDC

**Verification Commands**:
```bash
# Check Native Athena USDC balance
source .env && cast call 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d \
  "balanceOf(address)" 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check accumulated fees
source .env && cast call 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "accumulatedFees()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check dispute exists
source .env && cast call 0x85E0162A345EBFcbEb8862f67603F93e143Fa487 \
  "getDispute(string)" "dispute-test-simplified-interface-001" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Status**: ⏳ **PENDING**

---

### **Phase 3: Dispute Voting**

#### **Step 3.1: Vote on Dispute (WALL2 votes FOR job giver)**
```bash
# Vote FOR the job giver (against the applicant)
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "vote(uint8,string,bool,address)" \
  0 "dispute-test-simplified-interface-001" true 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Result**: Vote recorded with WALL2's earned tokens as voting power  
**Verification**: Check vote exists and weight calculated correctly  
**Status**: ⏳ **PENDING**

#### **Step 3.2: Additional Voting (if needed)**
```bash
# If WALL1 can vote (has earned tokens), vote AGAINST job giver
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "vote(uint8,string,bool,address)" \
  0 "dispute-test-simplified-interface-001" false 0x1D06bb4395AE7BFe9264117726D069C251dC27f5 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL1_KEY
```

**Expected Result**: Counter-vote recorded (if WALL1 has voting power)  
**Status**: ⏳ **PENDING**

---

### **Phase 4: Dispute Resolution & Fund Settlement**

#### **Step 4.1: Finalize Dispute and Distribute Fees**
```bash
# Process fee distribution and trigger disputed fund release
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "processFeePayment(string,address[],address[],uint256[],bool[],bool,uint256)" \
  "dispute-test-simplified-interface-001" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" \
  "[520000000000000000000000]" \
  "[true]" \
  true \
  250000 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Results**:
1. **Fee Distribution**: 250,000 wei USDC transferred to WALL2 (winning voter)
2. **Simplified Interface Call**: Native Athena calls `NOWJC.releaseDisputedFunds(winner, 500000, targetChainDomain)`
3. **Winner Determination**: Based on voting outcome (job giver vs applicant)
4. **Chain Domain Logic**: 
   - If applicant wins: Send to domain 0 (Ethereum Sepolia) 
   - If job giver wins: Send to domain 3 (Arbitrum Sepolia)
5. **Cross-chain Settlement**: If winner domain ≠ 3, CCTP transfer executed

**Status**: ⏳ **PENDING**

---

### **Phase 5: Verification & Results**

#### **Step 5.1: Verify Fee Distribution**
```bash
# Check WALL2 received dispute voting fees
source .env && cast call 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check Native Athena accumulated fees decreased
source .env && cast call 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "accumulatedFees()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Expected**: WALL2 balance increased by 250,000 wei, accumulatedFees decreased  
**Status**: ⏳ **PENDING**

#### **Step 5.2: Verify Disputed Fund Settlement**
```bash
# If applicant won - check USDC balance on Ethereum Sepolia
source .env && cast call 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
  "balanceOf(address)" 0x1D06bb4395AE7BFe9264117726D069C251dC27f5 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# If job giver won - check USDC balance on Arbitrum Sepolia  
source .env && cast call 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check job status updated to Cancelled
source .env && cast call 0x85E0162A345EBFcbEb8862f67603F93e143Fa487 \
  "getJob(string)" "dispute-test-simplified-interface-001" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Expected**: Winner received 500,000 wei USDC on their preferred chain, job status = Cancelled  
**Status**: ⏳ **PENDING**

---

## 📊 **Test Tracking Matrix**

| Phase | Step | Description | Expected Result | Status | TX Hash | Notes |
|-------|------|-------------|-----------------|--------|---------|-------|
| 1.1 | Post Job | WALL2 posts job on OP Sepolia | Job ID created | ⏳ | | |
| 1.2 | Apply Job | WALL1 applies with domain 0 | Chain domain stored | ⏳ | | |
| 1.3 | Start Job | WALL2 funds job via CCTP | NOWJC receives USDC | ⏳ | | |
| 2.1 | Raise Dispute | Cross-chain dispute initiation | Native Athena gets fees | ⏳ | | |
| 3.1 | Vote | WALL2 votes on dispute | Vote recorded | ⏳ | | |
| 3.2 | Counter Vote | WALL1 votes (if eligible) | Counter vote recorded | ⏳ | | |
| 4.1 | Finalize | Process fees + settle funds | Winner gets milestone | ⏳ | | |
| 5.1 | Verify Fees | Check voter rewards | WALL2 got voting fees | ⏳ | | |
| 5.2 | Verify Settlement | Check winner funds | Winner got on right chain | ⏳ | | |

---

## 🚨 **Error Handling & Detour Planning**

### **Common Issues & Solutions**

#### **Issue 1: Contract Size Errors**
- **Symptom**: "max code size exceeded" during deployment
- **Solution**: ✅ **RESOLVED** - Simplified interface architecture implemented
- **Backup**: Use existing working implementations from `enhanced-bridge-deployment-20-sep.md`

#### **Issue 2: Chain Domain Not Found**
- **Symptom**: "Applicant chain domain not found" error in dispute resolution
- **Solution**: Check `jobApplicantChainDomain` mapping, ensure application went through enhanced LOWJC
- **Backup**: Use default domain 3 (Arbitrum) for testing

#### **Issue 3: Authorization Errors**
- **Symptom**: "Only Native Athena can resolve disputes" error
- **Solution**: Verify Native Athena proxy address set correctly in NOWJC: `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE`
- **Fix Command**: 
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setNativeAthena(address)" 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

#### **Issue 4: Insufficient Voting Power**
- **Symptom**: "No voting power" error during voting
- **Solution**: Use wallets with earned tokens (WALL2 confirmed to have earned tokens)
- **Backup**: Comment out voting power validation for testing

#### **Issue 5: CCTP Transfer Failures**
- **Symptom**: Cross-chain transfers fail or timeout
- **Solution**: Check CCTP attestation status, wait for completion, retry if needed
- **Verification**: Use Circle CCTP API to check message status

### **Rollback Plan**
If simplified interface testing fails, rollback to proven implementations:

```bash
# Rollback NOWJC to working payment release version
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "upgradeToAndCall(address,bytes)" 0x5b4f880C96118A1665F97bCe8A09d2454d6c462F 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Rollback Native Athena to CCTP fee accounting version  
source .env && cast send 0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE \
  "upgradeToAndCall(address,bytes)" 0xD4a2c4B468C5472eb14b657B814883F03de62506 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## 🎯 **Success Criteria**

### **Minimum Success (Core Functionality)**
- ✅ Job posted, applied to, and started successfully
- ✅ Cross-chain dispute raised without errors  
- ✅ Voting mechanism works for eligible voters
- ✅ Fee distribution to winning voters completed
- ✅ Disputed funds released to winner (any chain)

### **Full Success (Simplified Interface Validation)**
- ✅ All minimum success criteria met
- ✅ **Chain domain logic working**: Winner gets funds on their preferred chain
- ✅ **Simplified interface tested**: Native Athena → NOWJC 3-parameter call works
- ✅ **Cross-chain settlement**: If applicant wins, funds go to Ethereum Sepolia (domain 0)
- ✅ **Architecture validated**: Clean separation between policy (Native Athena) and execution (NOWJC)

### **Innovation Success (Architecture Breakthrough)**
- ✅ Contract size constraint overcome through interface pattern
- ✅ Maintainable architecture with clear separation of concerns
- ✅ Extensible design ready for future dispute resolution enhancements
- ✅ Reusable pattern for other complex contract interactions

---

## 📋 **Post-Test Documentation**

### **Results to Document**
1. **Transaction hashes** for each step
2. **Gas usage** analysis for simplified interface calls
3. **Timing metrics** for cross-chain components  
4. **Error encountered** and resolution steps taken
5. **Architecture performance** vs previous implementations

### **Update Files**
- `references/logs/nowjc-dispute-resolution-fix-22-sep-2025.md` (add test results)
- `references/deployments/enhanced-bridge-deployment-20-sep.md` (update registry)
- Create new log: `complete-dispute-cycle-test-results-22-sep-2025.md`

---

---

## 🔄 **CURRENT STATUS UPDATE - September 22, 2025**

### **✅ COMPLETED SETUP WORK**
1. **Architecture Deployed**: Simplified interface pattern successfully implemented
   - **NOWJC**: `0xb852098C17ee2B63e0b345b5D0F22CE84B5dF02f` (Simplified dispute interface)
   - **Native Athena**: `0xeAC3E57185FE584Ab1C6a79a893321253F0b862c` (Enhanced dispute logic)
   - **LOWJC (Ethereum)**: `0xE32da9C3D7fD15C1Cc7c6D9f6ECDB0Bb8A74b69B` (Chain domain storage)

2. **Job Created**: Job `40232-47` posted on OP Sepolia ✅
   - **TX**: `0x39923add1a9f69a817c37b6e7c61307235f350a390a0a2c6d4d236209a4398c0`
   - **Description**: "dispute-test-simplified-interface-002"
   - **Milestones**: 2 x 500,000 wei (0.5 USDC each)
   - **Job Giver**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)

### **🎯 NEXT STEP TO RESUME**
**Step 1.2**: Apply to job `40232-47` from Ethereum Sepolia (WALL1 with chain domain 0 preference)

```bash
source .env && cast send 0x7e34A4a539e4c6cFBfa2d6304b61e74F3672a4fc \
  "applyToJob(string,uint32)" \
  "40232-47" \
  0 \
  --value 0.0015ether \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### **🔗 QUICK RESUME CHECKLIST**
- [ ] Apply to job from Ethereum Sepolia (chain domain 0)
- [ ] Start job and fund via CCTP 
- [ ] Raise cross-chain dispute
- [ ] Vote on dispute
- [ ] Process fee payment & distribute disputed funds
- [ ] Verify cross-chain settlement to Ethereum Sepolia

### **📋 TRACKING PROGRESS**
| Step | Description | Status | TX Hash | Notes |
|------|-------------|--------|---------|-------|
| 1.1 | Post Job | ✅ | `0x39923add...` | Job `40232-47` created |
| 1.2 | Apply from ETH | ✅ | `0x7ad06a6e...` | Chain domain 0 preference stored |
| 1.3 | Start Job | ⏳ | | **← NEXT STEP** |
| 2.1 | Raise Dispute | ⏳ | | |
| 3.1 | Vote | ⏳ | | |
| 4.1 | Finalize | ⏳ | | |
| 5.1 | Verify | ⏳ | | |

### **🎨 ARCHITECTURE INNOVATION BEING TESTED**
**Simplified Interface Pattern**: Native Athena handles complex dispute logic, calls NOWJC with simple 3-parameter interface:
```solidity
function releaseDisputedFunds(address _recipient, uint256 _amount, uint32 _targetChainDomain) external
```

This breakthrough solved the 24KB contract size limit while improving maintainability.

---

**Test Plan Created**: September 22, 2025  
**Status**: 🟡 **IN PROGRESS** - Ready to resume at Step 1.2  
**Innovation**: First test of simplified interface pattern for contract size constraint resolution  
**Risk Level**: Low (proven components, rollback plan available)  
**Expected Duration**: 25-35 minutes remaining