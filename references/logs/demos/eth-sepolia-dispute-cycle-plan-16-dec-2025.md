# Ethereum Sepolia Dispute Resolution Cycle - Plan

**Date**: December 16, 2025  
**Objective**: Repeat complete dispute resolution cycle on ETH Sepolia → Arbitrum Sepolia  
**Based on**: OP Sepolia demo (14-Dec-complete-dispute-resolution-cycle-minimal-amounts.md)

---

## 🚨 **CRITICAL BLOCKER: CCTP Interface Mismatch**

### **Root Cause Identified**

The CCTP integration on ETH Sepolia is failing due to an **interface mismatch**:

**LOWJC's sendFunds() flow** (lines 216-227):
```solidity
function sendFunds(string memory _jobId, uint256 _amount) internal {
    // 1. Transfer USDC from user to LOWJC
    usdtToken.safeTransferFrom(msg.sender, address(this), _amount);
    
    // 2. Approve CCTP to spend LOWJC's USDC
    usdtToken.approve(cctpSender, _amount);
    
    // 3. Call CCTP's sendFast
    (bool success, ) = cctpSender.call(
        abi.encodeWithSignature("sendFast(uint256,uint32,bytes32,uint256)", 
        _amount, 3, mintRecipient, 1000)
    );
    require(success, "CCTP sender call failed");
}
```

**CCTP's sendFast() implementation**:
```solidity
function sendFast(...) external {
    // ❌ PROBLEM: Tries to pull from msg.sender (LOWJC)
    usdc.transferFrom(msg.sender, address(this), amount);
    usdc.approve(address(tokenMessenger), amount);
    tokenMessenger.depositForBurn(...);
}
```

### **The Issue**
- LOWJC has the USDC (transferred from user)
- LOWJC approves CCTP to spend its USDC  ✅
- CCTP tries to do `transferFrom(LOWJC, CCTP, amount)` ✅
- **But LOWJC didn't approve CCTP!** ❌ (The approval is for something else in CCTP's logic)

Actually wait, re-reading... LOWJC DOES approve CCTP: `usdtToken.approve(cctpSender, _amount);`

So the flow should be:
1. LOWJC has USDC (from user)
2. LOWJC approves CCTP contract to spend its USDC ✅
3. CCTP does `transferFrom(msg.sender=LOWJC, address(this)=CCTP, amount)` ✅ 
4. This should work!

### **Wait - Let me check the actual error more carefully...**

From the deployment log:
> **Issue**: `startJob` function fails with "CCTP sender call failed"

This is a low-level call failure. The `(bool success, )` is returning `false`. This could mean:
1. **Revert** in the CCTP function
2. **Out of gas**
3. **Wrong function signature**

Let me check the function signature:
- LOWJC calls: `"sendFast(uint256,uint32,bytes32,uint256)"`
- CCTP has: `function sendFast(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, uint256 maxFee)`

That matches! ✅

So the issue must be:
- **Either** CCTP is reverting (USDC approval issue? Token Messenger issue?)
- **Or** out of gas (the low-level call doesn't forward all gas by default - ah wait, it should)

---

## 📋 **Solution Options**

### **Option 1: Test CCTP Directly (RECOMMENDED)**
Test the CCTP contract directly to see the actual revert reason:
```bash
# Approve USDC first
cast send 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
  "approve(address,uint256)" \
  0xf9F10a70923dA5d5d0e17AEA4ED0a645431A0eD7 \
  10000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Call sendFast directly
cast send 0xf9F10a70923dA5d5d0e17AEA4ED0a645431A0eD7 \
  "sendFast(uint256,uint32,bytes32,uint256)" \
  10000 \
  3 \
  0x0000000000000000000000009E39B37275854449782F1a2a4524405cE79d6C1e \
  1000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

This will give us the **actual revert reason**!

### **Option 2: Use OP Sepolia (Working Setup)**
Since OP Sepolia has a fully working CCTP integration, we can run the dispute cycle there (which we already have demonstrated).

### **Option 3: Deploy Compatible CCTP**
Deploy a CCTP version that matches exactly what's working on OP Sepolia.

---

## 🎯 **Recommended Action**

**Execute Option 1** to diagnose the exact failure, then:
- If it's a simple fix (wrong domain, wrong token messenger address, etc.), fix and proceed
- If it's a fundamental incompatibility, switch to Option 2 (use OP Sepolia)

---

## 📝 **Full Dispute Cycle Steps (Once CCTP is fixed)**

Based on the successful OP Sepolia demo, the steps would be:

### **Phase 1: Job Setup**
1. Post job on ETH Sepolia (10k USDC per milestone)
2. Wait for sync to Arbitrum (~30s)
3. Apply to job from ETH Sepolia
4. Wait for application sync (~60s)
5. Approve USDC for job funding
6. **Start job with CCTP** (←  BLOCKED HERE)

### **Phase 2: Oracle Discovery**
7. Check available oracles on Arbitrum
8. Verify "General" oracle is active

### **Phase 3: Dispute Lifecycle**
9. Approve USDC for dispute fee
10. Raise dispute with "General" oracle
11. Wait for dispute sync (~30s)
12. Vote on dispute (FOR job giver)

### **Phase 4: Settlement**
13. Wait 60 minutes (voting period)
14. Settle dispute on Arbitrum
15. Get CCTP attestation (~10s)
16. Complete CCTP transfer on ETH Sepolia

### **Phase 5: Verification**
17. Verify funds received in winner's wallet
18. Check balance changes
19. Document results

---

## 📊 **Expected Results**

Based on OP Sepolia demo:
- **Total Cost**: ~0.01 USDC + gas fees
- **Time**: ~70 minutes (including voting period)
- **Success Rate**: 100% (if CCTP works)

---

## 🔧 **Next Action**

**IMMEDIATE**: Test CCTP directly to get actual revert reason, then proceed based on findings.

---

**Created**: December 16, 2025, 12:03 AM IST  
**Status**: ⏳ **BLOCKED ON CCTP DIAGNOSIS**
