# Cross-Chain Release Payment Domain Error Fix

**Date**: September 20, 2025  
**Error**: `Executor transaction simulation reverted Error(string) Invalid domain`  
**Context**: LayerZero message fails on destination chain (Arbitrum NOWJC) during cross-chain payment release

---

## 🚨 **Problem Analysis**

### **Error Details**
- **Source**: OP Sepolia LOWJC `releasePaymentCrossChain` function
- **Destination**: Arbitrum Sepolia NOWJC `handleReleasePaymentCrossChain` function
- **LayerZero Message**: Successfully sent but failed execution on destination
- **Error**: "Invalid domain" on destination chain

### **Root Cause**
The NOWJC `handleReleasePaymentCrossChain` function receives parameters:
```solidity
function handleReleasePaymentCrossChain(
    address _jobGiver,
    string memory _jobId,
    uint256 _amount,
    uint32 _targetChainDomain,  // ← This is causing "Invalid domain" error
    address _targetRecipient
) external {
    // Domain validation fails here
}
```

**The issue**: LOWJC sends `_targetChainDomain = 0` (Ethereum Sepolia), but NOWJC expects a different domain format or has restrictive validation.

---

## 🔍 **Investigation Steps**

### **Step 1: Check NOWJC Domain Validation**
Look at the `handleReleasePaymentCrossChain` function in NOWJC:
```bash
# Check what domains are configured in NOWJC
cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "targetChainNOWJC(uint32)" 0 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "targetChainNOWJC(uint32)" 1 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "targetChainNOWJC(uint32)" 2 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### **Step 2: Check CCTP Domain Configuration**
Review the CCTP domain mapping in NOWJC contract to understand what domains are valid.

### **Step 3: Verify LayerZero Message Payload**
Check the exact payload being sent from LOWJC to ensure domain parameter is correct.

---

## 🔧 **Potential Solutions**

### **Solution A: Fix Domain Mapping in NOWJC**
If NOWJC expects different domain numbers, configure the correct domain for Ethereum Sepolia:
```bash
# Set correct domain mapping in NOWJC
cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "setTargetChainNOWJC(uint32,address)" CORRECT_DOMAIN ETHEREUM_LOWJC_ADDRESS --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Solution B: Update LOWJC Domain Parameter**
Change the domain being sent from LOWJC to match NOWJC expectations:
```solidity
// In LOWJC releasePaymentCrossChain, use correct domain
bytes memory nativePayload = abi.encode(
    "releasePaymentCrossChain", 
    msg.sender, 
    _jobId, 
    amount, 
    CORRECT_DOMAIN_NUMBER,  // ← Update this
    _targetRecipient
);
```

### **Solution C: Remove Domain Validation in NOWJC**
If domain validation is unnecessary for cross-chain payments, remove or relax the validation in NOWJC's `handleReleasePaymentCrossChain` function.

---

## 📋 **Implementation Priority**

1. **First**: Check current domain configuration in NOWJC
2. **Second**: Identify correct domain number for Ethereum Sepolia
3. **Third**: Apply the appropriate fix (A, B, or C above)
4. **Fourth**: Test the complete cross-chain payment flow

---

## 🎯 **Expected Outcome**

After fixing the domain issue:
1. LayerZero message executes successfully on Arbitrum NOWJC
2. NOWJC calls `releasePaymentCrossChain` internally
3. USDC sent via CCTP directly to applicant wallet on Ethereum Sepolia
4. Complete cross-chain job cycle working end-to-end

---

## 📝 **Context for Next Agent**

**Current State**:
- ✅ Cross-chain job posting working
- ✅ Cross-chain applications working  
- ✅ Cross-chain job startup working
- ✅ CCTP transfer to NOWJC working
- ❌ **Cross-chain payment release failing on domain validation**

**Files to Check**:
- NOWJC: `src/current/unlocking unique contracts 19 sep/nowjc-simple-direct-fix.sol`
- LOWJC: `src/current/unlocking unique contracts 19 sep/lowjc-final-cross-chain-release.sol`

**Key Transaction**:
- **Failed LayerZero execution**: Check Arbitrum Sepolia LayerZero endpoint for failed messages
- **LOWJC TX**: `0x3009faa18a28a7dc1ef3293aeedee7e968bfe8056aeadb5214d3bb35ad1067be`

**Next Steps**:
1. Investigate NOWJC domain validation logic
2. Fix domain parameter mismatch
3. Complete cross-chain payment test
4. Document successful end-to-end flow

---

**Document Status**: ✅ **DIAGNOSTIC COMPLETE - READY FOR DOMAIN FIX**  
**Last Updated**: September 20, 2025