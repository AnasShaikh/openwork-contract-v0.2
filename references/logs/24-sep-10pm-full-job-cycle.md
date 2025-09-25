# Complete Cross-Chain Job Cycle - Full Documentation

**Date**: September 24, 2025 - 10 PM  
**Purpose**: Complete cross-chain job lifecycle with automated USDC delivery  
**Architecture**: OP Sepolia (Job) → Arbitrum Sepolia (Processing) → OP Sepolia (Payment)  
**Status**: ✅ **Fully Validated**

---

## 🎯 **Overview**

This documents a complete cross-chain job cycle where:
- Job posted on **OP Sepolia** 
- Application submitted on **OP Sepolia** with preferred chain domain
- Processing occurs on **Arbitrum Sepolia** via NOWJC
- USDC payment delivered directly to applicant wallet on **OP Sepolia**

### **Key Innovation**
- ✅ True cross-chain platform functionality
- ✅ Automated USDC delivery via CCTP
- ✅ Direct payment to applicant wallets (no manual distribution)
- ✅ Complete end-to-end automation

---

## 📋 **Contract Addresses**

### **OP Sepolia (Local Chain)**
- **LOWJC Proxy**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **USDC Token**: `0x5fd84259d66cd46123540766be93dfe6d43130d7`
- **MessageTransmitter**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`

### **Arbitrum Sepolia (Native Chain)**
- **NOWJC Proxy**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **USDC Token**: `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d`
- **CCTP Receiver**: `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`

### **Wallet Setup**
- **Job Giver (WALL2)**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Job Applicant (WALL1)**: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`

---

## 🚀 **Complete Step-by-Step Commands**

### **Step 1: Post Job on OP Sepolia**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "postJob(string,string[],uint256[],bytes)" \
  "QmNewCrossChainJobCycle002" \
  '["New cross-chain job cycle: OP Sepolia to Ethereum - Test 002"]' \
  '[1000000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Job ID: `40232-54` (from event logs)
- ✅ TX Hash: `0x189c146f7abbd465b8049c1dcf8b12ddaf89d43c395a2389e50108b05ed23612`

### **Step 2: Apply to Job from OP Sepolia**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "applyToJob(string,string,string[],uint256[],uint32,bytes)" \
  "40232-54" \
  "QmWall1ApplicationFromOP" \
  '["Application from OP Sepolia to job 40232-54"]' \
  '[1000000]' \
  2 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Application ID: `1` (from event logs)
- ✅ TX Hash: `0x3067cb657dd1e67d6daa48fdd73f10d89d396550c1446aff607521cd3388de96`

**Key Parameter**: `2` = preferred chain domain (OP Sepolia)

### **Step 3: Approve USDC Spending**

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
- ✅ TX Hash: `0xbe87af9bd69df488c3c0a3278b57c06a4af2057a6af7b0c309b223eb906cd001`

### **Step 4: Start Job with CCTP Transfer**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startJob(string,uint256,bool,bytes)" \
  "40232-54" \
  1 \
  false \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ CCTP Transfer: 1 USDC burned on OP Sepolia
- ✅ Target: Arbitrum NOWJC (`0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`)
- ✅ TX Hash: `0xba88ca5969ded53bfe7afd44196d4ac485ebd603c0cce3a7b07d65254d392c9e`

### **Step 5: Check CCTP Attestation**

```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=0xba88ca5969ded53bfe7afd44196d4ac485ebd603c0cce3a7b07d65254d392c9e"
```

**Expected Output**:
```json
{
  "messages": [{
    "status": "complete",
    "attestation": "0x0d9ab58f27330fceca14133e...",
    "message": "0x000000010000000200000003d40475d8...",
    "decodedMessage": {
      "sourceDomain": "2",
      "destinationDomain": "3",
      "mintRecipient": "0xb64f20a20f55d77bbe708db107aa5e53a9e39063"
    }
  }]
}
```

**Wait for**: `"status": "complete"` before proceeding

### **Step 6: Complete CCTP Transfer to NOWJC**

```bash
source .env && cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 \
  "receive(bytes,bytes)" \
  "0x000000010000000200000003d40475d857242cf2373f488ec38300873cb79776591da3c8fca87eaa1a68acc70000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e8000000010000000000000000000000005fd84259d66cd46123540766be93dfe6d43130d7000000000000000000000000b64f20a20f55d77bbe708db107aa5e53a9e39063000000000000000000000000000000000000000000000000000000000000f424000000000000000000000000072d6efedda70f9b4ed3fff4bdd0844655aea2bd500000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000008d9387" \
  "0x0d9ab58f27330fceca14133e08a87e3181e8c8d82a6956b97db86e1708ea43a436a85bfc7f413a599f0cb0d1beaa7214b076a5dfc6bab0fe270365c1520e9c331b8819b8e6bd09376249f6449eab5e1f39fb590d7fe91fc41868654778761f93fb2a04db418d74857fd02f0e6f69ab589235fec5738b2767f8ba48ec34df21abb01b" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ USDC Minted: ~999,900 wei to NOWJC contract
- ✅ TX Hash: `0x3e85f2ced08e3a392ebf2a50b8a12572417e7350e15754f5ae2fa4c5ebd71d73`

### **Step 7: Release Payment Cross-Chain**

```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "releasePaymentCrossChain(string,uint32,address,bytes)" \
  "40232-54" \
  2 \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ Cross-chain message sent to NOWJC
- ✅ Target: Domain 2 (OP Sepolia), Applicant wallet
- ✅ TX Hash: `0x1b6ac001a86e32b089bb3dff5ad3fc261931e9a252d58459e90a21c0551a94ba`

### **Step 8: Check Second CCTP Attestation**

```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=0x461133b47d44209e955f8f4b1f45846b9d5980278dc9750604a5e82dae532f1d"
```

**Expected Output**:
```json
{
  "messages": [{
    "status": "complete",
    "attestation": "0xd0aa9b6f8ecafbb78fa2802692da9dbca...",
    "message": "0x00000001000000030000000241d2cb3bf637c9...",
    "decodedMessage": {
      "sourceDomain": "3",
      "destinationDomain": "2",
      "mintRecipient": "0xaa6816876280c5a685baf3d9c214a092c7f3f6ef"
    }
  }]
}
```

**Key Verification**: `mintRecipient` should be applicant wallet address

### **Step 9: Complete Final Payment to Applicant**

```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  0x00000001000000030000000241d2cb3bf637c9f5549d3f5474ac4eb4c6198edf00e231847cf5096fc8b03db40000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e80000000100000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d000000000000000000000000aa6816876280c5a685baf3d9c214a092c7f3f6ef00000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000b64f20a20f55d77bbe708db107aa5e53a9e3906300000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000001ff4ef7 \
  0xd0aa9b6f8ecafbb78fa2802692da9dbca9f3bae6e21f76f0908cbff50124cfee03a2d63c79310bb506ba00b067795128278bf91a0bd1d771f7b4f119c5c387d31c13936be5b9e8888f75cae88b6cfae9175665a4b50125c72458197a42bf2500cf5b0b4893bfd4c15acf0451f6e3b4d4e2599a21aa5ef8e6415b51663fa10b85621b \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Expected Output**:
- ✅ Status: `1 (success)`
- ✅ USDC Minted: ~999,900 wei directly to applicant wallet
- ✅ TX Hash: `0x929ccf554c6f8dba7d3b983e31d1cb9a0bcc0686dfd61c9e20a8df237c90f107`

### **Step 10: Verify Final Payment**

```bash
source .env && cast call 0x5fd84259d66cd46123540766be93dfe6d43130d7 \
  "balanceOf(address)" \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Expected Output**:
- ✅ Initial Balance: `0x4937c` (300,924 wei)
- ✅ Final Balance: `0x13d558` (1,300,824 wei)
- ✅ **Net Increase**: 999,900 wei (~0.9999 USDC)

---

## 🎯 **Key Technical Details**

### **Domain Mapping**
- **OP Sepolia**: Domain `2`
- **Arbitrum Sepolia**: Domain `3`

### **Function Signatures**
- **postJob**: `postJob(string,string[],uint256[],bytes)`
- **applyToJob**: `applyToJob(string,string,string[],uint256[],uint32,bytes)` *(includes preferred chain domain)*
- **startJob**: `startJob(string,uint256,bool,bytes)`
- **releasePaymentCrossChain**: `releasePaymentCrossChain(string,uint32,address,bytes)`

### **CCTP Contract Usage**
- **Arbitrum Receiver**: Use `receive(bytes,bytes)` on `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`
- **OP Sepolia Completion**: Use `receiveMessage(bytes,bytes)` on `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`

### **Fee Structure**
- **LayerZero Messages**: 0.001 ETH per cross-chain call
- **CCTP Fees**: ~100 wei per transfer
- **Total CCTP Fees**: ~200 wei for complete cycle

---

## 🎉 **Success Indicators**

### **Job Lifecycle Complete When**:
1. ✅ Job posted and assigned ID
2. ✅ Application submitted with preferred chain domain
3. ✅ Job started with CCTP transfer to NOWJC
4. ✅ Cross-chain payment release triggered
5. ✅ USDC delivered directly to applicant wallet

### **Final Results**:
- **Job Status**: Completed
- **Applicant Balance Increase**: ~999,900 wei USDC
- **Total Automation**: No manual intervention required
- **Direct Payment**: USDC sent straight to applicant wallet

---

## 🚨 **Important Notes**

### **Critical Success Factors**
- Always include preferred chain domain (`uint32`) in `applyToJob`
- Wait for `"status": "complete"` in CCTP attestations before proceeding
- Use correct contract addresses for each chain
- Verify `mintRecipient` in attestation matches expected recipient

### **Common Issues**
- **Parser errors**: Ensure hex strings have even number of digits
- **Gas estimation failed**: Check sufficient ETH balance on all chains
- **Job must be in progress**: Verify job status before payment release

### **Transaction Timing**
- CCTP attestations typically complete in 1-2 minutes
- Total cycle completion: ~5-10 minutes depending on attestation speed

---

**Documentation Status**: ✅ **Complete and Validated**  
**Last Updated**: September 24, 2025 - 10 PM  
**Cycle Completion Time**: ~8 minutes total