# Ethereum Sepolia CCTP Fix - December 16, 2025

**Date**: December 16, 2025, 12:20 AM IST  
**Issue**: CCTP transfers failing on Ethereum Sepolia  
**Status**: ✅ RESOLVED  
**Time to Fix**: ~15 minutes

---

## 🚨 Problem

**Symptom**: `startJob` function failing with error: **"CCTP sender call failed"**

All LayerZero messaging worked perfectly, but CCTP transfers were reverting immediately when called from LOWJC or Athena Client contracts.

---

## 🔍 Root Cause

**Wrong TokenMessenger address used in CCTP constructor during deployment.**

### Incorrect Deployment (Dec 15, 2025):
```solidity
constructor(
  0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5,  // ❌ WRONG TokenMessenger
  0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275,  // ✅ Correct MessageTransmitter
  0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238   // ✅ Correct USDC
)
```

### Correct Addresses (from CCTP Guide):
```solidity
constructor(
  0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA,  // ✅ CORRECT TokenMessenger
  0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275,  // ✅ MessageTransmitter
  0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238   // ✅ USDC
)
```

**Key Learning**: Circle's CCTP infrastructure addresses are **standard across ALL testnet chains**. The TokenMessenger and MessageTransmitter addresses are the **same on Ethereum Sepolia, Arbitrum Sepolia, OP Sepolia, and Base Sepolia**.

---

## ✅ Solution

### Step 1: Redeploy CCTP with Correct Address
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/cctp-v2-ft-transceiver-with-rewards-dynamic.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
```

**Result**: New CCTP deployed at `0x0ad0306EAfCBf121Ed9990055b89e1249011455F`

### Step 2: Update Contract References
```bash
# Update LOWJC
cast send 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 \
  "setCCTPSender(address)" 0x0ad0306EAfCBf121Ed9990055b89e1249011455F \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Update Athena Client
cast send 0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf \
  "setCCTPSender(address)" 0x0ad0306EAfCBf121Ed9990055b89e1249011455F \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### Step 3: Test startJob
```bash
# Approve USDC
cast send 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
  "approve(address,uint256)" 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 50000 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Start job (previously failing)
cast send 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 \
  "startJob(string,uint256,bool,bytes)" "40161-2" 1 false 0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result**: ✅ **SUCCESS!** CCTP transfer completed, 50,000 USDC burned on Ethereum Sepolia.

---

## 📋 Standard CCTP Addresses (ALL Testnets)

**NEVER change these addresses - they are standard across all testnets:**

| Contract | Address | Used For |
|----------|---------|----------|
| **TokenMessenger** | `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` | Burns/Mints USDC |
| **MessageTransmitter** | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` | Cross-chain messages |

**Chain-Specific (varies per chain):**
- **USDC Token Address** - Check Circle docs for each testnet
  - Ethereum Sepolia: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
  - Arbitrum Sepolia: `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d`
  - OP Sepolia: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
  - Base Sepolia: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

---

## 🎯 Verification Steps

After any CCTP deployment, **always test directly**:

```bash
# 1. Approve USDC to CCTP
cast send <USDC_TOKEN> "approve(address,uint256)" <CCTP_ADDRESS> 10000 \
  --rpc-url $RPC_URL --private-key $KEY

# 2. Call sendFast directly
cast send <CCTP_ADDRESS> \
  "sendFast(uint256,uint32,bytes32,uint256)" \
  10000 3 <MINT_RECIPIENT_BYTES32> 1000 \
  --rpc-url $RPC_URL --private-key $KEY
```

If this fails, the TokenMessenger address is likely wrong.

---

## 📚 Reference

**Source of Truth**: `references/logs/CCTP-CONFIRMATION-REWARDS-COMPLETE-GUIDE.md`

This guide contains the **correct standard addresses** that should be used for all CCTP deployments.

---

## ✅ Lessons Learned

1. **Always use the standard Circle CCTP addresses** - they don't change between testnet chains
2. **Test CCTP directly first** before integrating with contracts
3. **Reference the CCTP guide** when deploying to new chains
4. **USDC token addresses vary per chain** - double-check these
5. **TokenMessenger and MessageTransmitter are constant** across all testnets

---

## 🔧 Quick Fix Checklist

If CCTP fails in the future:

- [ ] Check TokenMessenger address matches: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
- [ ] Check MessageTransmitter matches: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- [ ] Verify USDC token address is correct for the chain
- [ ] Test CCTP `sendFast` directly before blaming contract logic
- [ ] Redeploy CCTP if addresses are wrong
- [ ] Update contract references (`setCCTPSender`)

---

**Fixed By**: Cline AI Assistant  
**Verified By**: Complete dispute resolution cycle test  
**Status**: Production-ready for Ethereum Sepolia
