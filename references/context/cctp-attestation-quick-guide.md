# CCTP Attestation Quick Guide

**Purpose**: Avoid common mistakes when checking and completing CCTP attestations  
**Date**: September 20, 2025

---

## 🎯 **Quick Reference**

### **Step 1: Check Attestation Status**

**Correct API Format**:
```bash
curl "https://iris-api-sandbox.circle.com/v2/messages/DOMAIN?transactionHash=TX_HASH"
```

**Domain Numbers**:
- **Ethereum Sepolia**: `0`
- **OP Sepolia**: `2` 
- **Arbitrum Sepolia**: `3`

**Example**:
```bash
# For OP Sepolia → Arbitrum transfer
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=0x9624d1913135d4120a6e30419aa9b9dbe7c583f4e3a1da4c5aec646a0486c65c"
```

### **Step 2: Wait for "complete" Status**

**Look for**: `"status": "complete"`  
**Wait time**: Usually 1-2 minutes for testnet

---

## 🔧 **Complete CCTP Transfer**

### **Contract Addresses**

**CCTP Transceivers**:
- **OP Sepolia**: Use MessageTransmitter `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- **Arbitrum Sepolia**: Use CCTP Transceiver `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`
- **Ethereum Sepolia**: Use MessageTransmitter `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`

### **Completion Command**

**Arbitrum Sepolia** (most common):
```bash
source .env && cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 \
  "receive(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**OP Sepolia**:
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## ❌ **Common Mistakes**

### **Wrong API Format**
```bash
# ❌ Wrong - missing domain
curl "https://iris-api-sandbox.circle.com/attestations/TX_HASH"

# ✅ Correct - includes domain
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=TX_HASH"
```

### **Wrong Contract**
```bash
# ❌ Wrong - using MessageTransmitter on Arbitrum
cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 "receiveMessage..."

# ✅ Correct - using CCTP Transceiver on Arbitrum  
cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 "receive..."
```

### **Wrong Function Name**
```bash
# ❌ Wrong - receiveMessage on Arbitrum transceiver
"receiveMessage(bytes,bytes)"

# ✅ Correct - receive on Arbitrum transceiver
"receive(bytes,bytes)"
```

---

## 🎯 **Chain-Specific Quick Commands**

### **OP Sepolia → Arbitrum**
```bash
# 1. Check attestation
curl "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=YOUR_TX"

# 2. Complete on Arbitrum
cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 "receive(bytes,bytes)" "MESSAGE" "ATTESTATION" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Arbitrum → OP Sepolia**
```bash
# 1. Check attestation  
curl "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=YOUR_TX"

# 2. Complete on OP Sepolia
cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 "receiveMessage(bytes,bytes)" "MESSAGE" "ATTESTATION" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Ethereum → Arbitrum**
```bash
# 1. Check attestation
curl "https://iris-api-sandbox.circle.com/v2/messages/0?transactionHash=YOUR_TX"

# 2. Complete on Arbitrum  
cast send 0xB64f20A20F55D77bbe708Db107AA5E53a9e39063 "receive(bytes,bytes)" "MESSAGE" "ATTESTATION" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## 🔍 **Verification**

**Expected API Response**:
```json
{
  "messages": [{
    "status": "complete",
    "decodedMessage": {
      "sourceDomain": "2",
      "destinationDomain": "3", 
      "mintRecipient": "0x9e39b37275854449782f1a2a4524405ce79d6c1e"
    }
  }]
}
```

**Key Fields**:
- ✅ `"status": "complete"`
- ✅ `"mintRecipient"`: Should match expected recipient
- ✅ `"amount"`: Should match transfer amount

---

**Last Updated**: September 20, 2025  
**Status**: ✅ **Reference Guide Complete**