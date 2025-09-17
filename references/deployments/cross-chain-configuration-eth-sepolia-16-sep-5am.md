# Cross-Chain Job Marketplace Configuration Checklist - Ethereum Sepolia Deployment

## 📋 Deployed Contract Addresses

### Ethereum Sepolia (Local Chain - Chain ID: 11155111, CCTP Domain: 0)
- **LOWJC Contract**: `0x0e788A4243D070e026039e1d845deD8A18b6E0aC` ✅ DEPLOYED (Non-upgradeable)
- **CCTP v2 Transceiver**: `0xc16448B4E9735De617f1A7C97C7d8BF16337E6D0` ✅ DEPLOYED
- **Local Bridge**: `0xBc35365E91597025663e073C2eb3c5d05C82817F` ✅ DEPLOYED

**Deployment Commands Executed:**
```bash
# Deploy CCTP v2 Transceiver
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/cctp-v2-ft-transceiver.sol:CCTPv2Transceiver" --constructor-args 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
# Result: 0xc16448B4E9735De617f1A7C97C7d8BF16337E6D0
# TX: 0xeeb3470b9cd87ea02329c6a5c2edfa5f69a36ab50eaaa0ba6b38a9332c1275e8

# Deploy LayerZero Bridge
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/local-bridge-final.sol:LayerZeroBridge" --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 40232 40161 40161
# Result: 0xBc35365E91597025663e073C2eb3c5d05C82817F
# TX: 0x308419281dd085308beff4366adaacd138ee0b92a7ba9452b7bc594ad95e42af

# Deploy LOWJC (Non-upgradeable)
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/lowjc-final.sol:CrossChainLocalOpenWorkJobContract" --constructor-args 0xfD08836eeE6242092a9c869237a8d122275b024A 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 11155111 0xBc35365E91597025663e073C2eb3c5d05C82817F 0xc16448B4E9735De617f1A7C97C7d8BF16337E6D0
# Result: 0x0e788A4243D070e026039e1d845deD8A18b6E0aC
# TX: 0x1690d1613c3dc6aeb7138087a64c23b4898545a411b2fa1247ec5c9bfb75074d

# Configure chain domain mappings
source .env && cast send 0x0e788A4243D070e026039e1d845deD8A18b6E0aC "setChainDomainMapping(uint256[],uint32[])" "[11155111,11155420]" "[0,2]" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xac783f76e8f804a16dd5fc93c2a77b04945e22bc84d025e9516fe31a841bc52e

# Configure native chain settings
source .env && cast send 0x0e788A4243D070e026039e1d845deD8A18b6E0aC "setNativeChainConfig(uint32,address,uint256)" 2 0xc85439E5Ed38586482e157B887497354081cA76C 1000000 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x307f668ff85d55d857c1a1787b642685792e017872a0a78af57300d923196c08
```

### OP Sepolia (Native Chain - Chain ID: 11155420, CCTP Domain: 2)
- **NOWJC Contract**: `0xc85439E5Ed38586482e157B887497354081cA76C` ✅ DEPLOYED (Non-upgradeable)
- **CCTP v2 Transceiver**: `0xB64f20A20F55D77bbe708Db107AA5E53a9E39063` ✅ DEPLOYED
- **Native Bridge**: `0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87` ✅ DEPLOYED

**Deployment Commands Executed:**
```bash
# Deploy CCTP v2 Transceiver
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/cctp-v2-ft-transceiver.sol:CCTPv2Transceiver" --constructor-args 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
# Result: 0xB64f20A20F55D77bbe708Db107AA5E53a9E39063
# TX: 0x483467f554151b002d6b302ae2d5edcf85696c63fcd08fb5853abfa6f3d2e6a7

# Deploy Native Chain Bridge
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/native-bridge-final.sol:NativeChainBridge" --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 40161
# Result: 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87
# TX: 0x8246327a6556c0af857bfb4debad597a19d3bbd8aa4a4161e88a372d95f90893

# Deploy NOWJC (Non-upgradeable)
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/nowjc-final.sol:NativeOpenWorkJobContract" --constructor-args 0xfD08836eeE6242092a9c869237a8d122275b024A 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 0xB64f20A20F55D77bbe708Db107AA5E53a9E39063
# Result: 0xc85439E5Ed38586482e157B887497354081cA76C
# TX: 0xccf1ec95e966446453ba591ce4c89927a00a58764fc36ce1f1799176f73e1460
```

## 🔧 **Phase 2: Bridge Authorization - COMPLETED**

### Ethereum Sepolia Bridge ↔ LOWJC Authorization
```bash
# Authorize LOWJC to use bridge
source .env && cast send 0xBc35365E91597025663e073C2eb3c5d05C82817F "authorizeContract(address,bool)" 0x0e788A4243D070e026039e1d845deD8A18b6E0aC true --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x57b36e08601e24a2ce5707646dec3e276f1b085c691e82705ae6c545f02cd30d

# Set bridge in LOWJC
source .env && cast send 0x0e788A4243D070e026039e1d845deD8A18b6E0aC "setBridge(address)" 0xBc35365E91597025663e073C2eb3c5d05C82817F --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x923b9b8bfd6aaec9180885f988473179373dee195cacc1a16ee08fc82c443703
```

### OP Sepolia Bridge ↔ NOWJC Authorization
```bash
# Authorize NOWJC to use bridge
source .env && cast send 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87 "authorizeContract(address,bool)" 0xc85439E5Ed38586482e157B887497354081cA76C true --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x6a34a86f052892266ddf9c2173866bc94fdd473009483ff4af53527b21616e2e

# Set bridge in NOWJC
source .env && cast send 0xc85439E5Ed38586482e157B887497354081cA76C "setBridge(address)" 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xdea0fcb3b331e00beccf216aeeba25029aba0f9082809b6355250654bca6ce29
```

## 🔧 **Phase 3: LayerZero Configuration - COMPLETED**

**LayerZero V2 Testnet EIDs:**
- Ethereum Sepolia: 40161
- OP Sepolia: 40232

### Ethereum Sepolia Bridge Endpoints
```bash
# Configure chain endpoints (native=OP, main=ETH, this=ETH)
source .env && cast send 0xBc35365E91597025663e073C2eb3c5d05C82817F "updateChainEndpoints(uint32,uint32,uint32)" 40232 40161 40161 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x96048b35a68e319949e3a29010132183192380335397f3df15a08c5449f0c2cf
```

### OP Sepolia Bridge Local Chain Management
```bash
# Add Ethereum Sepolia as authorized local chain
source .env && cast send 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87 "addLocalChain(uint32)" 40161 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xce0f3a8408892c55c9978282ef16f74d65f5ca5023c51af33020beae70542871

# Set main chain EID to Ethereum Sepolia
source .env && cast send 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87 "updateMainChainEid(uint32)" 40161 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x2b833fa194a6b2821717e515c080817ba22c9d3592fc8add3afa69f412f6c29e
```

## 🔧 **Phase 4: CCTP Configuration - COMPLETED**

### Set CCTP Receiver in NOWJC
```bash
# Configure CCTP receiver on OP Sepolia NOWJC
source .env && cast send 0xc85439E5Ed38586482e157B887497354081cA76C "setCCTPReceiver(address)" 0xB64f20A20F55D77bbe708Db107AA5E53a9E39063 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x524b4094a5966901cf821ca709aa9795d9286f9a00f29122cfd99497384b8910
```

### USDC Token Verification ✅
**All USDC addresses correctly configured:**
- **OP Sepolia NOWJC**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` ✅
- **Ethereum Sepolia LOWJC**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` ✅

## 🔧 **Phase 5: Contract Interfaces - COMPLETED**

### Set Contract References in Bridges
```bash
# Set LOWJC contract in Ethereum Sepolia bridge
source .env && cast send 0xBc35365E91597025663e073C2eb3c5d05C82817F "setLowjcContract(address)" 0x0e788A4243D070e026039e1d845deD8A18b6E0aC --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x5d5c2a99e5b677f38c970c4a8d1b3023eaadd158a741ba92fc5a600fddd6d3de

# Set NOWJC contract in OP Sepolia bridge
source .env && cast send 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87 "setNativeOpenWorkJobContract(address)" 0xc85439E5Ed38586482e157B887497354081cA76C --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x84c74a4af4e35062aa96e1b65d4a1fb6b0113ffdc940b1aa1d5367b8f1641346
```

---

## 🔧 Configuration Checklist

### Phase 1: Chain Domain Mappings (CRITICAL - Do First)

#### 1.1 Configure Ethereum Sepolia LOWJC
- [x] **Set Chain Domain Mappings**
  ```solidity
  // On Ethereum Sepolia LOWJC: 0x0e788A4243D070e026039e1d845deD8A18b6E0aC
  setChainDomainMapping(
    [11155111, 11155420], // Chain IDs
    [0, 2]                // CCTP Domains
  )
  ```

- [x] **Set Native Chain Configuration**
  ```solidity
  // On Ethereum Sepolia LOWJC: 0x0e788A4243D070e026039e1d845deD8A18b6E0aC
  setNativeChainConfig(
    2,                                              // OP Sepolia CCTP Domain
    0xc85439E5Ed38586482e157B887497354081cA76C,    // OP Sepolia NOWJC address
    1000000                                         // Default max fee (1 USDC)
  )
  ```

### Phase 2: Bridge Authorization (CRITICAL)

#### 2.1 Authorize Local Bridges to Use LOWJC Contracts
- [x] **Ethereum Sepolia Bridge Authorization**
  ```solidity
  // On Ethereum Sepolia Local Bridge: 0xBc35365E91597025663e073C2eb3c5d05C82817F
  authorizeContract(0x0e788A4243D070e026039e1d845deD8A18b6E0aC, true) // LOWJC
  ```

#### 2.2 Authorize Native Bridge to Use NOWJC Contract
- [x] **OP Sepolia Bridge Authorization**
  ```solidity
  // On OP Sepolia Native Bridge: 0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87
  authorizeContract(0xc85439E5Ed38586482e157B887497354081cA76C, true) // NOWJC
  ```

#### 2.3 Set Bridge References in Job Contracts
- [x] **Set Bridge in Ethereum Sepolia LOWJC**
  ```solidity
  // On Ethereum Sepolia LOWJC: 0x0e788A4243D070e026039e1d845deD8A18b6E0aC
  setBridge(0xBc35365E91597025663e073C2eb3c5d05C82817F) // Local Bridge
  ```

- [x] **Set Bridge in OP Sepolia NOWJC**
  ```solidity
  // On OP Sepolia NOWJC: 0xc85439E5Ed38586482e157B887497354081cA76C
  setBridge(0x6B346dE9C82f274179dbbcFc9c372a8C08Ee6f87) // Native Bridge
  ```

### Phase 3: LayerZero Configuration - ✅ COMPLETED

#### 3.1 Configure Bridge Endpoints
- [x] **Ethereum Sepolia Bridge Endpoints**
- [x] **OP Sepolia Local Chain Management**

### Phase 4: CCTP Configuration - ✅ COMPLETED

#### 4.1 Set CCTP Transceivers in Job Contracts
- [x] **Set CCTP Receiver in OP Sepolia NOWJC**
  ```solidity
  // On OP Sepolia NOWJC: 0xc85439E5Ed38586482e157B887497354081cA76C
  setCCTPReceiver(0xB64f20A20F55D77bbe708Db107AA5E53a9E39063)
  ```

### Phase 5: Contract Interface Configuration - ✅ COMPLETED

#### 5.1 Set Contract References in Bridges
- [x] **Set LOWJC Contract in Ethereum Sepolia Bridge**
- [x] **Set NOWJC Contract in OP Sepolia Bridge**

---

## 📊 Configuration Status

- [x] **Phase 1**: Chain Domain Mappings - ✅ **COMPLETED**
  - [x] Ethereum Sepolia LOWJC: Chain domains + native config ✅
  
- [x] **Phase 2**: Bridge Authorization - ✅ **COMPLETED**
  - [x] Ethereum Sepolia: Bridge ↔ LOWJC authorization ✅
  - [x] OP Sepolia: Bridge ↔ NOWJC authorization ✅
  
- [x] **Phase 3**: LayerZero Configuration - ✅ **COMPLETED**
  - [x] Ethereum Sepolia: Chain endpoints configured ✅
  - [x] OP Sepolia: Local chains + main chain configured ✅
  
- [x] **Phase 4**: CCTP Configuration - ✅ **COMPLETED**
  - [x] OP Sepolia NOWJC: CCTP receiver configured ✅
  - [x] All chains: USDC token addresses verified ✅
  
- [x] **Phase 5**: Contract Interfaces - ✅ **COMPLETED**
  - [x] Ethereum Sepolia: Bridge → LOWJC interface ✅
  - [x] OP Sepolia: Bridge → NOWJC interface ✅

## 🎯 **Key Changes from Previous Deployment**

### ✅ **Major Updates:**
1. **Replaced Arbitrum Sepolia with Ethereum Sepolia** as the local chain
2. **Removed UUPS Upgradeability** - All contracts now use direct constructor initialization
3. **Maintained OP Sepolia** as the native chain for consistency
4. **Updated LayerZero EID configurations** for Ethereum Sepolia integration
5. **Preserved all CCTP and cross-chain functionality**

### ✅ **Architecture Improvements:**
- **Non-upgradeable contracts** provide better security and simplicity
- **Constructor-based initialization** eliminates proxy complexity
- **Cleaner deployment process** without upgrade mechanisms
- **Same cross-chain functionality** with simplified contract architecture

# 🎉 **ALL PHASES COMPLETED!**

**✅ ETHEREUM SEPOLIA + OP SEPOLIA CROSS-CHAIN SETUP READY ✅**

**Ready for full job cycle testing with:**
- Cross-chain job posting from Ethereum Sepolia
- Native processing on OP Sepolia  
- CCTP-based USDC transfers
- LayerZero message bridging