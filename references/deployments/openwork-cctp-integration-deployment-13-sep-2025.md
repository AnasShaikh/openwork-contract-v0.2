# OpenWork CCTP Integration Deployment - September 13, 2025

## 🎯 Deployment Overview

Successfully deployed OpenWork contracts with CCTP integration on Arbitrum Sepolia and OP Sepolia testnets for atomic cross-chain USDT transfers.

## 📋 Contract Deployments

### **Arbitrum Sepolia (Local Chain)**

#### 1. CrossChainLocalOpenWorkJobContract (lowjc-final.sol)
- **Contract Address**: `0x8524d925d5593470fEFc5FE051a3A838A7268f9f`
- **Transaction Hash**: `0xd14355f0e1a9c928b177655b4c4654e43688d87854a6cebcb953066427bfc88f`
- **Deployer**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- **Constructor Args**:
  - Owner: `0xfD08836eeE6242092a9c869237a8d122275b024A`
  - USDT Token: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
  - Chain ID: `421614`
  - Bridge: `0x0000000000000000000000000000000000000000` (to be set later)
  - CCTP TokenMessenger: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`

#### 2. LayerZeroBridge (local-bridge-final.sol)
- **Contract Address**: `0x34235bf71eb82BF8E9F5CC5Af9cBeaCE26cB0c90`
- **Transaction Hash**: `0xdbc3377c929c4f80b62234473ef8bc79fd74d986d18f895a16772eeb803a85b9`
- **Deployer**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- **Constructor Args**:
  - LZ Endpoint: `0x6EDCE65403992e310A62460808c4b910D972f10f`
  - Owner: `0xfD08836eeE6242092a9c869237a8d122275b024A`
  - Native Chain EID: `40232` (OP Sepolia)
  - Main Chain EID: `40161` (Ethereum Sepolia)
  - This Local Chain EID: `40231` (Arbitrum Sepolia)

### **OP Sepolia (Native Chain)**

#### 3. NativeOpenWorkJobContract (nowjc-final.sol)
- **Contract Address**: `0x89db7411d1b32e9C2981360ecE2bD92f2243C91A`
- **Transaction Hash**: `0x66bb0bc1004e15e5e5771961d1f975d69cf4d57e5a3e68a228d3a35021afbd06`
- **Deployer**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- **Constructor Args**:
  - Owner: `0xfD08836eeE6242092a9c869237a8d122275b024A`
  - Bridge: `0x0000000000000000000000000000000000000000` (to be set later)
  - Genesis: `0x0000000000000000000000000000000000000000` (to be set later)
  - Rewards Contract: `0x0000000000000000000000000000000000000000` (to be set later)
  - CCTP MessageTransmitter: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
  - USDT Token: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`

#### 4. NativeChainBridge (native-bridge-final.sol)
- **Contract Address**: `0x0e7fB9975A7Ed057A490CA825345DE071efa126A`
- **Transaction Hash**: `0x9d75b3ff3d4c827bcfdab359df7dc9e9c518702c16665f69173f663f1e9a60cc`
- **Deployer**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- **Constructor Args**:
  - LZ Endpoint: `0x6EDCE65403992e310A62460808c4b910D972f10f`
  - Owner: `0xfD08836eeE6242092a9c869237a8d122275b024A`
  - Native Chain EID: `40232` (OP Sepolia)
  - Main Chain EID: `40161` (Ethereum Sepolia)
  - This Native Chain EID: `40232` (OP Sepolia)

## 🔧 Key Features Deployed

### **New CCTP Integration Features**:

1. **Atomic Cross-Chain Transfers**: Single transaction that burns USDT via CCTP and sends job data via LayerZero
2. **Enhanced startJob Function**: New parameters for CCTP recipient and fee configuration
3. **CCTP Completion Handling**: Two-phase job start with pending transfer tracking
4. **Local Payment Releases**: Direct USDT transfers on destination chain without LayerZero callbacks

### **New Function Signatures**:

#### lowjc-final.sol (Arbitrum Sepolia):
```solidity
function startJob(
    string memory _jobId,
    uint256 _appId,
    bool _useAppMilestones,
    bytes32 _recipientBytes32,    // NEW: CCTP recipient (nowjc contract as bytes32)
    uint256 _cctpMaxFee,         // NEW: CCTP fee limit (1000 wei for fast transfers)
    bytes calldata _nativeOptions // LayerZero options
) external payable
```

#### nowjc-final.sol (OP Sepolia):
```solidity
function startJob(
    address _jobGiver,
    string memory _jobId,
    uint256 _applicationId,
    bool _useApplicantMilestones,
    uint256 _amount              // NEW: Expected USDT amount from CCTP
) external

function completeCCTPJobStart(
    bytes calldata _message,     // CCTP message
    bytes calldata _attestation, // CCTP attestation
    string memory _jobId         // Job ID to complete
) external
```

## 🌐 Network Configuration

### **Chain Details**:
```
Arbitrum Sepolia:
- Chain ID: 421614
- LayerZero EID: 40231
- CCTP Domain: 3

OP Sepolia:
- Chain ID: 11155420
- LayerZero EID: 40232
- CCTP Domain: 2
```

### **CCTP Integration**:
```
Arbitrum Sepolia:
- TokenMessenger: 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA
- USDT: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d

OP Sepolia:
- MessageTransmitter: 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275
- USDT: 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

### **LayerZero Configuration**:
```
Both Chains:
- Endpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f
```

## 📋 Required Setup Steps

### **1. Configure Bridge Addresses**:
```bash
# Set bridge in lowjc contract (Arbitrum Sepolia)
cast send 0x8524d925d5593470fEFc5FE051a3A838A7268f9f "setBridge(address)" 0x34235bf71eb82BF8E9F5CC5Af9cBeaCE26cB0c90 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY

# Set bridge in nowjc contract (OP Sepolia)
cast send 0x89db7411d1b32e9C2981360ecE2bD92f2243C91A "setBridge(address)" 0x0e7fB9975A7Ed057A490CA825345DE071efa126A --rpc-url https://sepolia.optimism.io --private-key $PRIVATE_KEY
```

### **2. Configure Bridge Authorizations**:
```bash
# Authorize lowjc contract on local bridge (Arbitrum Sepolia)
cast send 0x34235bf71eb82BF8E9F5CC5Af9cBeaCE26cB0c90 "authorizeContract(address,bool)" 0x8524d925d5593470fEFc5FE051a3A838A7268f9f true --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY

# Set nowjc contract in native bridge (OP Sepolia)
cast send 0x0e7fB9975A7Ed057A490CA825345DE071efa126A "setNativeOpenWorkJobContract(address)" 0x89db7411d1b32e9C2981360ecE2bD92f2243C91A --rpc-url https://sepolia.optimism.io --private-key $PRIVATE_KEY
```

### **3. Configure LayerZero Peers**:
```bash
# Set peer on local bridge (Arbitrum → OP Sepolia)
cast send 0x34235bf71eb82BF8E9F5CC5Af9cBeaCE26cB0c90 "setPeer(uint32,bytes32)" 40232 0x0000000000000000000000000e7fB9975A7Ed057A490CA825345DE071efa126A --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY

# Set peer on native bridge (OP Sepolia → Arbitrum)
cast send 0x0e7fB9975A7Ed057A490CA825345DE071efa126A "setPeer(uint32,bytes32)" 40231 0x00000000000000000000000034235bf71eb82BF8E9F5CC5Af9cBeaCE26cB0c90 --rpc-url https://sepolia.optimism.io --private-key $PRIVATE_KEY
```

## 🧪 Testing the New Flow

### **Convert nowjc Address to bytes32**:
```bash
# Helper function to convert address to bytes32
cast call 0x8524d925d5593470fEFc5FE051a3A838A7268f9f "addressToBytes32(address)" 0x89db7411d1b32e9C2981360ecE2bD92f2243C91A --rpc-url https://sepolia-rollup.arbitrum.io/rpc
```

### **Test startJob with CCTP**:
```bash
# 1. Approve USDT
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "approve(address,uint256)" 0x8524d925d5593470fEFc5FE051a3A838A7268f9f 1000000 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY

# 2. Quote LayerZero fee
cast call 0x34235bf71eb82BF8E9F5CC5Af9cBeaCE26cB0c90 "quoteNativeChain(bytes,bytes)" 0x... 0x --rpc-url https://sepolia-rollup.arbitrum.io/rpc

# 3. Call new startJob function
cast send 0x8524d925d5593470fEFc5FE051a3A838A7268f9f "startJob(string,uint256,bool,bytes32,uint256,bytes)" "test-job-001" 1 true 0x00000000000000000000000089db7411d1b32e9C2981360ecE2bD92f2243C91A 1000 0x --value [LZ_FEE] --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $PRIVATE_KEY
```

### **Complete CCTP Transfer**:
```bash
# Wait for CCTP attestation (~60-90 seconds), then complete transfer
cast send 0x89db7411d1b32e9C2981360ecE2bD92f2243C91A "completeCCTPJobStart(bytes,bytes,string)" [CCTP_MESSAGE] [CCTP_ATTESTATION] "test-job-001" --rpc-url https://sepolia.optimism.io --private-key $PRIVATE_KEY
```

## 🎯 What's Different from Original

### **Original Flow**:
1. USDT transferred locally on Arbitrum Sepolia
2. LayerZero message sent to OP Sepolia
3. Job started but funds remain on source chain
4. Payments require LayerZero callbacks to Arbitrum

### **New CCTP Flow**:
1. **Atomic execution**: CCTP burn + LayerZero send in single transaction
2. **Cross-chain USDT**: Funds transferred to OP Sepolia where job executes
3. **Local payments**: Direct USDT transfers without LayerZero callbacks
4. **60-90 second completion**: Fast CCTP v2 transfers

## ✅ Deployment Status

- ✅ All 4 contracts deployed successfully
- ✅ CCTP integration active on both chains
- ✅ LayerZero messaging ready
- ✅ Non-UUPS contracts for simplified testing
- 🔶 Configuration setup required
- 🔶 Testing flow ready to execute

## 🚀 Next Steps

1. **Configure Contracts**: Set bridge addresses and authorizations
2. **Set LayerZero Peers**: Enable cross-chain messaging
3. **Test Complete Flow**: Execute atomic CCTP + LayerZero job start
4. **Verify CCTP Completion**: Confirm USDT transfer and local payment capability
5. **Performance Analysis**: Measure timing and gas costs vs original flow

---

**Deployment Complete**: September 13, 2025  
**Architecture**: CCTP V2 + LayerZero V2 Integration  
**Status**: Ready for Configuration and Testing