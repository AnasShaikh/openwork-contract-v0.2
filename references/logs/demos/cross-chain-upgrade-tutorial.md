# Cross-Chain Upgrade Tutorial - Working Commands

**Date**: October 5, 2025  
**Purpose**: Essential commands for cross-chain contract upgrades  
**Status**: ✅ All commands tested and working

---

## 📋 **Key Contract Addresses**

### **Base Sepolia (Main Chain)**
- **Main DAO Proxy**: `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465`
- **Main Chain Bridge**: `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0`

### **Arbitrum Sepolia (Native Chain)**
- **Native Athena Proxy**: `0x46C17D706c5D5ADeF0831080190627E9bd234C78`
- **Native DAO Proxy**: `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5`
- **NOWJC Proxy**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **Native Bridge**: `0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c`

### **OP Sepolia (Local Chain)**
- **Athena Client Proxy**: `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7`
- **Local Bridge**: `0x6601cF4156160cf43fd024bac30851d3ee0F8668`

### **LayerZero EIDs**
- **Base Sepolia**: `40245`
- **Arbitrum Sepolia**: `40231`
- **OP Sepolia**: `40232`

---

## 🚀 **Step 1: Deploy New Native Bridge**

```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-bridge-upgrade-fix.sol:NativeChainBridge" --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 40245
```

---

## ⚙️ **Step 2: Configure Bridge Connections**

### **Set Peer Connections**
```bash
# Main Chain Bridge → Native Bridge
source .env && cast send 0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 "setPeer(uint32,bytes32)" 40231 0x0000000000000000000000003b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Native Bridge → Main Chain Bridge  
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "setPeer(uint32,bytes32)" 40245 0x00000000000000000000000070d30e5dAb5005b126c040f1d9b0bDDBc16679b0 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Set Target Contract Addresses**
```bash
# Set Native Athena
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "setNativeAthenaContract(address)" 0x46C17D706c5D5ADeF0831080190627E9bd234C78 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Set Native DAO
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "setNativeDaoContract(address)" 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Set NOWJC
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "setNativeOpenWorkJobContract(address)" 0x9E39B37275854449782F1a2a4524405cE79d6C1e --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Authorize Bridge**
```bash
# Authorize Main Chain Bridge to use Native Bridge
source .env && cast send 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "authorizeContract(address,bool)" 0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## 🔗 **Step 3: Update Contract Bridge References**

### **Native Athena**
```bash
source .env && cast send 0x46C17D706c5D5ADeF0831080190627E9bd234C78 "setBridge(address)" 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **NOWJC**
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "setBridge(address)" 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Native DAO**
```bash
source .env && cast send 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 "setBridge(address)" 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### **Athena Client (OP Sepolia)**
```bash
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "setBridge(address)" 0x6601cF4156160cf43fd024bac30851d3ee0F8668 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## 🧪 **Step 4: Deploy Test Implementations**

### **NOWJC Implementation**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/nowjc.sol:NativeOpenWorkJobContract"
```

### **Native DAO Implementation**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-dao.sol:NativeDAO"
```

### **Native Athena Implementation**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-upg-dao-refund-fees-multi-dispute-voting period fix.sol:NativeAthena"
```

### **Main Rewards Implementation (Same-Chain)**
```bash
source .env && forge create --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/main-rewards.sol:CrossChainRewardsContract"
```

### **Athena Client Implementation (OP Sepolia)**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol:LocalAthena"
```

---

## ✅ **Step 5: Execute Cross-Chain Upgrades**

### **NOWJC Cross-Chain Upgrade**
```bash
source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "upgradeContract(uint32,address,address,bytes)" 40231 0x9E39B37275854449782F1a2a4524405cE79d6C1e [NEW_IMPLEMENTATION] 0x0003010011010000000000000000000000000007a120 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY --value 0.001ether
```

### **Native DAO Cross-Chain Upgrade**
```bash
source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "upgradeContract(uint32,address,address,bytes)" 40231 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 [NEW_IMPLEMENTATION] 0x0003010011010000000000000000000000000007a120 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY --value 0.001ether
```

### **Native Athena Cross-Chain Upgrade**
```bash
source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "upgradeContract(uint32,address,address,bytes)" 40231 0x46C17D706c5D5ADeF0831080190627E9bd234C78 [NEW_IMPLEMENTATION] 0x0003010011010000000000000000000000000007a120 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY --value 0.001ether
```

### **Athena Client Cross-Chain Upgrade (OP Sepolia)**
```bash
source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "upgradeContract(uint32,address,address,bytes)" 40232 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 [NEW_IMPLEMENTATION] 0x0003010011010000000000000000000000000007a120 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY --value 0.001ether
```

### **Main Rewards Same-Chain Upgrade**
```bash
source .env && cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 "upgradeContract(uint32,address,address,bytes)" 40245 0xd6bE0C187408155be99C4e9d6f860eDDa27b056B [NEW_IMPLEMENTATION] 0x --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## 🔍 **Step 6: Verification Commands**

### **Check All Bridge Configurations**
```bash
echo "=== MAIN CHAIN BRIDGE PEERS ===" && source .env && cast call 0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 "peers(uint32)" 40231 --rpc-url $BASE_SEPOLIA_RPC_URL && echo && echo "=== NATIVE BRIDGE PEERS ===" && cast call 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "peers(uint32)" 40245 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL && echo && echo "=== NATIVE BRIDGE CONTRACT ADDRESSES ===" && echo "Native Athena:" && cast call 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "nativeAthenaContract()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL && echo "Native DAO:" && cast call 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "nativeDaoContract()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL && echo "NOWJC:" && cast call 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "nativeOpenWorkJobContract()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### **Check Bridge Authorization**
```bash
source .env && cast call 0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c "authorizedContracts(address)" 0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### **Verify Implementation Changes**
```bash
# Native Athena
source .env && cast call 0x46C17D706c5D5ADeF0831080190627E9bd234C78 "getImplementation()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# NOWJC
source .env && cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "getImplementation()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Native DAO
source .env && cast call 0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5 "getImplementation()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Main Rewards
source .env && cast call 0xd6bE0C187408155be99C4e9d6f860eDDa27b056B "getImplementation()" --rpc-url $BASE_SEPOLIA_RPC_URL

# Athena Client (OP Sepolia)
source .env && cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "getImplementation()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

---

## 🛡️ **Critical Authorization Requirements**

### **For Cross-Chain Upgrades Only (Native Chain Contracts)**
```solidity
function _authorizeUpgrade(address /* newImplementation */) internal view override {
    require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
}
```

### **For Same-Chain + Cross-Chain Upgrades (Main Chain Contracts)**
```solidity
function _authorizeUpgrade(address /* newImplementation */) internal view override {
    require(
        owner() == _msgSender() || 
        address(bridge) == _msgSender() || 
        address(mainDAO) == _msgSender(), 
        "Unauthorized upgrade"
    );
}

function upgradeFromDAO(address newImplementation) external {
    require(msg.sender == address(mainDAO), "Only DAO can upgrade");
    upgradeToAndCall(newImplementation, "");
}
```

---

## 🎯 **Testing Checklist**

**✅ Working Upgrades:**
- NOWJC (Arbitrum Sepolia)
- Native DAO (Arbitrum Sepolia)  
- Native Athena (Arbitrum Sepolia)
- Main Rewards (Base Sepolia - Same Chain)
- Athena Client (OP Sepolia)

**⚠️ Prerequisites:**
- Correct authorization in current implementation
- Proper bridge configuration
- Valid LayerZero peers
- Sufficient ETH for cross-chain messaging

**🔑 Key Learning:**
Cross-chain upgrade success depends on the **current** implementation's authorization logic, not the target implementation.

---

**Session Completed**: October 5, 2025  
**Status**: ✅ **ALL CROSS-CHAIN UPGRADES OPERATIONAL**