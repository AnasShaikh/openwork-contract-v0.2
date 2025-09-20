# Cross-Chain Payment Release Implementation Plan
**Date**: September 18, 2025 - 4:00 AM  
**Feature**: Enable payment release to any registered local chain regardless of job origination chain

---

## 🎯 **OBJECTIVE**

Enable job applicants to receive payments on their preferred chain, even if the job was posted/started on a different chain. All payments flow through the native chain (Arbitrum Sepolia) as the central hub and can be released via CCTP to any registered local chain.

---

## 🏗️ **CURRENT ARCHITECTURE OVERVIEW**

### Existing Flow:
1. **Job Creation**: Posted on any local chain (LOWJC) → synced to native chain (NOWJC)
2. **Job Startup**: Funds locked on local chain → sent via CCTP to native chain escrow
3. **Payment Release**: Currently only releases back to the same local chain where job started

### Infrastructure Per Chain:
- **LOWJC**: Local job contract with CCTP integration
- **Local Bridge**: LayerZero bridge for cross-chain messaging  
- **CCTP Transceiver**: Handles USDC transfers via Circle's CCTP
- **Native Chain (Arbitrum)**: Central hub with NOWJC + CCTP receiver

---

## 📋 **DETAILED IMPLEMENTATION STEPS**

### **PHASE 1: Modify Application Process**

#### 1.1 Update Application Struct (LOWJC)
```solidity
struct Application {
    uint256 id;
    string jobId;
    address applicant;
    string applicationHash;
    MilestonePayment[] proposedMilestones;
    uint32 preferredPaymentChainDomain;  // NEW: CCTP domain for payments
    address preferredPaymentAddress;     // NEW: Address to receive payments on target chain
}
```

#### 1.2 Modify `applyToJob()` Function (LOWJC)
```solidity
function applyToJob(
    string memory _jobId, 
    string memory _appHash, 
    string[] memory _descriptions, 
    uint256[] memory _amounts,
    uint32 _preferredPaymentChainDomain,    // NEW PARAMETER
    address _preferredPaymentAddress,       // NEW PARAMETER  
    bytes calldata _nativeOptions
) external payable nonReentrant
```

**Implementation Details**:
- Validate `_preferredPaymentChainDomain` exists in bridge's peer registry
- Default to current chain domain if not specified
- Store payment preferences in Application struct
- Include payment preferences in LayerZero message to native chain

#### 1.3 Add Domain Validation Function (LOWJC)
```solidity
function isValidPaymentDomain(uint32 _domain) public view returns (bool) {
    // Query bridge to check if domain is registered as a peer
    // Return true if domain exists in peer registry or is current chain
}
```

---

### **PHASE 2: Update Job Management**

#### 2.1 Modify Job Struct (Both LOWJC & NOWJC)
```solidity
struct Job {
    // ... existing fields ...
    uint32 paymentTargetChainDomain;     // NEW: Where to release payments
    address paymentTargetAddress;        // NEW: Who receives payments on target chain
    uint32 applierOriginChainDomain;     // NEW: Where applicant applied from
}
```

#### 2.2 Update `startJob()` Function (LOWJC)
```solidity
function startJob(
    string memory _jobId, 
    uint256 _appId, 
    bool _useAppMilestones,
    bytes calldata _nativeOptions
) external payable nonReentrant {
    // ... existing logic ...
    
    // NEW: Capture selected applicant's payment preferences
    Application storage selectedApp = jobApplications[_jobId][_appId];
    job.paymentTargetChainDomain = selectedApp.preferredPaymentChainDomain;
    job.paymentTargetAddress = selectedApp.preferredPaymentAddress;
    job.applierOriginChainDomain = chainId; // Current chain where they applied
    
    // Include payment target info in LayerZero message to native chain
    bytes memory payload = abi.encode(
        "startJob", 
        msg.sender, 
        _jobId, 
        _appId, 
        _useAppMilestones,
        job.posterChainDomain,
        job.posterAddress,
        job.paymentTargetChainDomain,  // NEW
        job.paymentTargetAddress       // NEW
    );
}
```

#### 2.3 Update Cross-Chain Sync (NOWJC)
Modify native chain message handlers to capture and store payment target information when jobs are started.

---

### **PHASE 3: Implement Cross-Chain Payment Release**

#### 3.1 Add CCTP Integration to NOWJC
```solidity
// Add to NOWJC contract
address public cctpTransceiver;  // CCTP transceiver for outgoing transfers
mapping(uint32 => address) public chainDomainToCCTPReceiver; // Domain → receiver mapping

function setCCTPTransceiver(address _transceiver) external onlyOwner {
    cctpTransceiver = _transceiver;
}

function setChainCCTPReceiver(uint32 _domain, address _receiver) external onlyOwner {
    chainDomainToCCTPReceiver[_domain] = _receiver;
}
```

#### 3.2 Implement Cross-Chain Payment Release Function (NOWJC)
```solidity
function releasePaymentToTargetChain(
    string memory _jobId,
    uint256 _amount,
    uint32 _targetChainDomain,
    address _targetRecipient
) internal {
    require(cctpTransceiver != address(0), "CCTP transceiver not set");
    require(chainDomainToCCTPReceiver[_targetChainDomain] != address(0), "Target chain not supported");
    
    // If target chain is current chain (Arbitrum), transfer directly
    if (_targetChainDomain == getCurrentCCTPDomain()) {
        usdtToken.safeTransfer(_targetRecipient, _amount);
        return;
    }
    
    // Otherwise, use CCTP to send to target chain
    usdtToken.approve(cctpTransceiver, _amount);
    
    bytes32 mintRecipient = bytes32(uint256(uint160(_targetRecipient)));
    (bool success, ) = cctpTransceiver.call(
        abi.encodeWithSignature(
            "sendFast(uint256,uint32,bytes32,uint256)", 
            _amount, 
            _targetChainDomain, 
            mintRecipient, 
            1000 // Default max fee
        )
    );
    require(success, "CCTP cross-chain transfer failed");
}
```

#### 3.3 Update Payment Release Handler (NOWJC)
```solidity
function handleReleasePayment(
    address _jobGiver,
    string memory _jobId,
    uint256 _amount,
    address _applierAddress,
    uint32 _applierChainDomain,
    uint256 _milestone,
    uint32 _posterChainDomain,
    address _posterAddress
) external onlyAuthorized {
    // ... existing logic for rewards processing ...
    
    // NEW: Get job's payment target info
    IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
    uint32 targetDomain = job.paymentTargetChainDomain;
    address targetAddress = job.paymentTargetAddress;
    
    // Default to applier's original chain if no preference set
    if (targetDomain == 0) {
        targetDomain = _applierChainDomain;
        targetAddress = _applierAddress;
    }
    
    // Release payment to target chain
    releasePaymentToTargetChain(_jobId, _amount, targetDomain, targetAddress);
    
    // ... rest of existing logic ...
}
```

---

### **PHASE 4: Update LOWJC Payment Release**

#### 4.1 Modify `releasePayment()` Function (LOWJC)
```solidity
function releasePayment(
    string memory _jobId,
    bytes calldata _nativeOptions
) external payable nonReentrant {
    // ... existing validation logic ...
    
    Job storage job = jobs[_jobId];
    uint256 amount = job.currentLockedAmount;
    
    // Include payment target info in message to native chain
    bytes memory nativePayload = abi.encode(
        "releasePayment", 
        msg.sender, 
        _jobId, 
        amount,
        job.applierAddress,
        job.applierChainDomain,
        job.currentMilestone,
        job.posterChainDomain,
        job.posterAddress,
        job.paymentTargetChainDomain,  // NEW: Where to send payment
        job.paymentTargetAddress       // NEW: Who receives payment
    );
    
    bridge.sendToNativeChain{value: msg.value}("releasePayment", nativePayload, _nativeOptions);
    
    // ... rest of existing logic ...
}
```

---

### **PHASE 5: Bridge Integration & Validation**

#### 5.1 Add Domain Validation to Bridges
```solidity
// Add to both Local Bridge and Native Bridge
function isValidCCTPDomain(uint32 _domain) external view returns (bool) {
    // Check if domain corresponds to a registered peer chain
    // or is the current chain's domain
    return peers[_domain] != bytes32(0) || _domain == getCurrentCCTPDomain();
}

function getCurrentCCTPDomain() public view returns (uint32) {
    // Return CCTP domain for current chain
    // Arbitrum Sepolia: 3, OP Sepolia: 2, etc.
}
```

#### 5.2 Update Peer Registration
Ensure when new chains are added to the bridge peer registry, their CCTP domains are also registered in the domain mapping.

---

### **PHASE 6: Genesis Storage Updates**

#### 6.1 Update Genesis Contract Structs
```solidity
struct Job {
    // ... existing fields ...
    uint32 paymentTargetChainDomain;
    address paymentTargetAddress;
    uint32 applierOriginChainDomain;
}

struct Application {
    // ... existing fields ...
    uint32 preferredPaymentChainDomain;
    address preferredPaymentAddress;
}
```

#### 6.2 Add Setter Functions
```solidity
function setJobPaymentTarget(
    string memory _jobId, 
    uint32 _targetDomain, 
    address _targetAddress
) external onlyAuthorized {
    jobs[_jobId].paymentTargetChainDomain = _targetDomain;
    jobs[_jobId].paymentTargetAddress = _targetAddress;
}

function setApplicationPaymentPreference(
    string memory _jobId,
    uint256 _appId,
    uint32 _preferredDomain,
    address _preferredAddress
) external onlyAuthorized {
    applications[_jobId][_appId].preferredPaymentChainDomain = _preferredDomain;
    applications[_jobId][_appId].preferredPaymentAddress = _preferredAddress;
}
```

---

## 🧪 **TESTING PLAN**

### Test Scenario 1: Same Chain Payment (Current Behavior)
1. Job posted on OP Sepolia
2. Applicant from OP Sepolia applies (default payment chain = OP Sepolia)
3. Job started → funds go to Arbitrum
4. Payment released → should return to OP Sepolia

### Test Scenario 2: Cross-Chain Payment
1. Job posted on OP Sepolia  
2. Applicant from Polygon applies, specifies payment chain = Polygon
3. Job started → funds go to Arbitrum, payment target = Polygon
4. Payment released → should go to Polygon via CCTP

### Test Scenario 3: Native Chain Payment
1. Job posted on OP Sepolia
2. Applicant specifies payment chain = Arbitrum Sepolia (native chain)
3. Job started → funds go to Arbitrum
4. Payment released → direct transfer on Arbitrum (no CCTP needed)

### Test Scenario 4: Invalid Chain Handling
1. Applicant specifies unsupported payment chain domain
2. Application should fail with proper error message
3. Fallback to applicant's origin chain if preference invalid

---

## 🔧 **DEPLOYMENT STRATEGY**

### Phase 1: Backend Updates
1. Update LOWJC implementation with new application fields
2. Update NOWJC with CCTP integration
3. Update Genesis storage contract
4. Deploy updated implementations

### Phase 2: Configuration
1. Configure CCTP transceivers on native chain
2. Set up chain domain mappings
3. Register CCTP receiver addresses for all supported chains
4. Test CCTP transfers between chains

### Phase 3: Proxy Upgrades
1. Upgrade LOWJC proxies on all local chains
2. Upgrade NOWJC proxy on native chain
3. Upgrade Genesis storage proxy
4. Verify all contracts upgraded successfully

### Phase 4: Integration Testing
1. Test end-to-end flows for all scenarios
2. Verify CCTP attestation and completion processes
3. Test error handling and fallback mechanisms
4. Performance testing with multiple concurrent payments

---

## 🚨 **RISK CONSIDERATIONS**

### Technical Risks:
1. **CCTP Failures**: Network congestion or CCTP issues could delay payments
2. **Gas Costs**: Multiple cross-chain transactions increase gas costs
3. **Domain Mapping**: Incorrect domain mappings could send funds to wrong chains

### Mitigation Strategies:
1. **Retry Logic**: Implement retry mechanisms for failed CCTP transfers
2. **Gas Estimation**: Provide gas estimates for cross-chain payments
3. **Validation**: Strict domain validation before processing payments
4. **Emergency Functions**: Admin functions to recover stuck funds

### Security Considerations:
1. **Authorization**: Only authorized contracts can trigger cross-chain payments
2. **Validation**: Validate all payment targets before CCTP transfers
3. **Limits**: Consider implementing daily/weekly payment limits per chain
4. **Monitoring**: Track all cross-chain payments for anomaly detection

---

## 📊 **SUCCESS METRICS**

1. **Functional**: All test scenarios pass successfully
2. **Performance**: Cross-chain payments complete within 2-3 minutes
3. **Reliability**: 99%+ success rate for CCTP transfers
4. **User Experience**: Clear error messages for invalid payment chains
5. **Gas Efficiency**: Reasonable gas costs for cross-chain operations

---

## 🎯 **FINAL DELIVERABLES**

1. **Updated Contracts**: LOWJC, NOWJC, Genesis with cross-chain payment support
2. **Configuration Scripts**: Deployment and configuration scripts
3. **Testing Suite**: Comprehensive tests for all payment scenarios  
4. **Documentation**: Updated API documentation and user guides
5. **Monitoring Tools**: Scripts to monitor cross-chain payment health

---

**Status**: Ready for implementation  
**Estimated Timeline**: 3-5 days for development + 2-3 days for testing
**Dependencies**: Current CCTP integration must be fully operational