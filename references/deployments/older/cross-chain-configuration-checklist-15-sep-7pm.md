# Cross-Chain Job Marketplace Configuration Checklist

## 📋 Deployed Contract Addresses

### Arbitrum Sepolia (Local Chain - Chain ID: 421614, CCTP Domain: 3)
- **LOWJC Proxy**: `0x7DD12e520F69387FA226402cFdd490ad09Cd4252` ✅ DEPLOYED & UPGRADED
- **LOWJC Implementation**: `0x5bc74b63f555a7BC6c0B7B7D71c919B3674Feb6F` ✅ DEPLOYED (Fixed domain validation)
- **CCTP v2 Transceiver**: `0xDa3cD34e254b3967d9568D2AA99F587B3E9B552d` ✅ DEPLOYED
- **Local Bridge**: `0x07c5135BEf0dA35eCEe413a6F18B7992659d3522` ✅ DEPLOYED

**Upgrade Commands Executed:**
```bash
# Deploy new implementation
source .env && forge create --broadcast --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY "src/current/interchain locking + unlocking/lowjc-final.sol:CrossChainLocalOpenWorkJobContract"
# Result: 0x5bc74b63f555a7BC6c0B7B7D71c919B3674Feb6F

# Upgrade proxy
source .env && cast send 0x7DD12e520F69387FA226402cFdd490ad09Cd4252 "upgradeToAndCall(address,bytes)" 0x5bc74b63f555a7BC6c0B7B7D71c919B3674Feb6F "0x" --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0x90a03e5130e026a379cd2425327b23057904590c3e46c65e39c0d90bb0503956

# Configure chain domain mappings (SUCCESSFUL - domain 0 now accepted!)
source .env && cast send 0x7DD12e520F69387FA226402cFdd490ad09Cd4252 "setChainDomainMapping(uint256[],uint32[])" "[421614,11155111,11155420]" "[3,0,2]" --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0xe3fb2e09d6ed5c46f13e342e5a437dd0b20219b4daacf26b19a19ebd229faf30

# Configure native chain settings  
source .env && cast send 0x7DD12e520F69387FA226402cFdd490ad09Cd4252 "setNativeChainConfig(uint32,address,uint256)" 2 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 1000000 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0xaacd36558485084860a05c67e53525a8533ef1bc65e7bde72f7355a18f40576f
```

### OP Sepolia (Native Chain - Chain ID: 11155420, CCTP Domain: 2)
- **NOWJC Proxy**: `0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5` ✅ DEPLOYED & UPGRADED
- **CCTP v2 Transceiver**: `0x39364725725627d0fFcE934bB633a9c6B532ad03` ✅ DEPLOYED
- **Native Bridge**: `0x30C338b2042164543Fb4bfF570e518f620C48D97` ✅ DEPLOYED

**Configuration Commands Executed:**
```bash
# Configure default max fee for CCTP transfers
source .env && cast send 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 "setDefaultMaxFee(uint256)" 1000000 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xf4726b9e8733feb0bfd5f98855d3519a2b6b99e31b9e6e17ea8d058c5c075abd
```

## 🔧 **Phase 2: Bridge Authorization - COMPLETED**

### Arbitrum Sepolia Bridge ↔ LOWJC Authorization
```bash
# Authorize LOWJC to use bridge
source .env && cast send 0x07c5135BEf0dA35eCEe413a6F18B7992659d3522 "authorizeContract(address,bool)" 0x7DD12e520F69387FA226402cFdd490ad09Cd4252 true --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0x0dfaff433fa1043461aa4450bc655cc16eb00703cdfde1b8b729cca735747998

# Set bridge in LOWJC
source .env && cast send 0x7DD12e520F69387FA226402cFdd490ad09Cd4252 "setBridge(address)" 0x07c5135BEf0dA35eCEe413a6F18B7992659d3522 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0x4b4ceafa949fb9dd768a789a7f23024d912dfc3e4c7d97125f5f8f5dfb0b884e
```

### Ethereum Sepolia Bridge ↔ LOWJC Authorization
```bash
# Authorize LOWJC to use bridge
source .env && cast send 0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3 "authorizeContract(address,bool)" 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6 true --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x77bb126dc559af22e5793b18a4a649026735b50554a650c1cc0d5e3c72f3779b

# Set bridge in LOWJC  
source .env && cast send 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6 "setBridge(address)" 0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x6c545fc9d18a2fd73ebc879ee79822e1843fdddd4e9ba78f022c0def13da879a
```

### OP Sepolia Bridge ↔ NOWJC Authorization
```bash
# Authorize NOWJC to use bridge
source .env && cast send 0x30C338b2042164543Fb4bfF570e518f620C48D97 "authorizeContract(address,bool)" 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 true --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x6bb5242da24eb89f34848ad7b15d4f76fb3548beadb4500b5ef233caa29c0496

# Set bridge in NOWJC
source .env && cast send 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 "setBridge(address)" 0x30C338b2042164543Fb4bfF570e518f620C48D97 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY  
# TX: 0x6426d343c61076a8f36aded4c1727404d9ed0c6897e74829a2e64f90ec31106b
```

## 🔧 **Phase 3: LayerZero Configuration - COMPLETED**

**LayerZero V2 Testnet EIDs:**
- Ethereum Sepolia: 40161
- Arbitrum Sepolia: 40231  
- OP Sepolia: 40232

### Arbitrum Sepolia Bridge Endpoints
```bash
# Configure chain endpoints (native=OP, main=ETH, this=ARB)
source .env && cast send 0x07c5135BEf0dA35eCEe413a6F18B7992659d3522 "updateChainEndpoints(uint32,uint32,uint32)" 40232 40161 40231 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0x1ded10cd2b0b912e633dc2fd2c8cdc56442f7179815bf1e695614cf01b3c90d1
```

### Ethereum Sepolia Bridge Endpoints  
```bash
# Configure chain endpoints (native=OP, main=ETH, this=ETH)
source .env && cast send 0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3 "updateChainEndpoints(uint32,uint32,uint32)" 40232 40161 40161 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xf4085bbfe168473da5b0016cd75406734f127e36ef1ce3c1d868ed8a1df092e6
```

### OP Sepolia Bridge Local Chain Management
```bash
# Add Ethereum Sepolia as authorized local chain
source .env && cast send 0x30C338b2042164543Fb4bfF570e518f620C48D97 "addLocalChain(uint32)" 40161 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xf9b1d2bf75569d5e01867e34a70b53de039ee1549d8c226c6f0a87c6b01c96e9

# Set main chain EID to Ethereum Sepolia  
source .env && cast send 0x30C338b2042164543Fb4bfF570e518f620C48D97 "updateMainChainEid(uint32)" 40161 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0xd167780dfb2c377de5eae3728a66607a7debb24b9bfe77670f2af5a9dd84a1fc
```

## 🔧 **Phase 4: CCTP Configuration - COMPLETED**

### Set CCTP Transceiver in NOWJC
```bash
# Configure CCTP transceiver on OP Sepolia NOWJC
source .env && cast send 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 "setCCTPTransceiver(address)" 0x39364725725627d0fFcE934bB633a9c6B532ad03 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x890e295273e16191dc435730bd449044eb0c3461e743af3f3de810b2e5ce01a4
```

### USDC Token Verification ✅
**All USDC addresses correctly configured:**
- **OP Sepolia NOWJC**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` ✅
- **Arbitrum Sepolia LOWJC**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` ✅  
- **Ethereum Sepolia LOWJC**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` ✅

## 🔧 **Phase 5: Contract Interfaces - COMPLETED**

### Set Contract References in Bridges
```bash
# Set LOWJC contract in Arbitrum Sepolia bridge
source .env && cast send 0x07c5135BEf0dA35eCEe413a6F18B7992659d3522 "setLowjcContract(address)" 0x7DD12e520F69387FA226402cFdd490ad09Cd4252 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
# TX: 0x9c11c399dc6d4556c9e66493c8ded98e4373d2e075737e1e0d700c4d69c182c4

# Set LOWJC contract in Ethereum Sepolia bridge  
source .env && cast send 0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3 "setLowjcContract(address)" 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x4b16887ae5a8c010bf03e8df878c9b58fd9ef006cd404decc5d74b611f09c6d6

# Set NOWJC contract in OP Sepolia bridge
source .env && cast send 0x30C338b2042164543Fb4bfF570e518f620C48D97 "setNativeOpenWorkJobContract(address)" 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x09045c98db9664aded6b19d1dbfd4379dbb754cde1d424aab9c70b31fd7edd82
```

### Ethereum Sepolia (Local Chain - Chain ID: 11155111, CCTP Domain: 0)
- **LOWJC Proxy**: `0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6` ✅ DEPLOYED & UPGRADED
- **LOWJC Implementation**: `0x97Bb997916eFa79b427c650a0CAC5d4f6D3aa33D` ✅ DEPLOYED (Fixed domain validation)
- **CCTP v2 Transceiver**: `0x89487307c274A15996217a766374C48B3d7bF1d7` ✅ DEPLOYED
- **Local Bridge**: `0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3` ✅ DEPLOYED

**Upgrade Commands Executed:**
```bash
# Deploy new implementation
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/interchain locking + unlocking/lowjc-final.sol:CrossChainLocalOpenWorkJobContract"
# Result: 0x97Bb997916eFa79b427c650a0CAC5d4f6D3aa33D

# Upgrade proxy
source .env && cast send 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6 "upgradeToAndCall(address,bytes)" 0x97Bb997916eFa79b427c650a0CAC5d4f6D3aa33D "0x" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x4f28af8a570fb1936fe31aec265a1d9a5658c953e4eda232762cb128ea9e49cd

# Configure chain domain mappings
source .env && cast send 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6 "setChainDomainMapping(uint256[],uint32[])" "[421614,11155111,11155420]" "[3,0,2]" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x83b98fcaa0c2e3e8f42b6455194d7462e537b8b3edce3792da3d228af05240f0

# Configure native chain settings
source .env && cast send 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6 "setNativeChainConfig(uint32,address,uint256)" 2 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5 1000000 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
# TX: 0x51d5cae8301d6cda3807bfd85c1eff67e755968dc28a1e9510885b371da76aea
```

---

## 🔧 Configuration Checklist

### Phase 1: Chain Domain Mappings (CRITICAL - Do First)

#### 1.1 Configure Arbitrum Sepolia LOWJC
- [ ] **Set Chain Domain Mappings**
  ```solidity
  // On Arbitrum Sepolia LOWJC: 0x7DD12e520F69387FA226402cFdd490ad09Cd4252
  setChainDomainMapping(
    [421614, 11155111, 11155420], // Chain IDs
    [3, 0, 2]                     // CCTP Domains
  )
  ```

- [ ] **Set Native Chain Configuration**
  ```solidity
  // On Arbitrum Sepolia LOWJC: 0x7DD12e520F69387FA226402cFdd490ad09Cd4252
  setNativeChainConfig(
    2,                                              // OP Sepolia CCTP Domain
    0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5,    // OP Sepolia NOWJC address
    1000000                                         // Default max fee (1 USDC)
  )
  ```

#### 1.2 Configure Ethereum Sepolia LOWJC
- [ ] **Set Chain Domain Mappings**
  ```solidity
  // On Ethereum Sepolia LOWJC: 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6
  setChainDomainMapping(
    [421614, 11155111, 11155420], // Chain IDs
    [3, 0, 2]                     // CCTP Domains
  )
  ```

- [ ] **Set Native Chain Configuration**
  ```solidity
  // On Ethereum Sepolia LOWJC: 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6
  setNativeChainConfig(
    2,                                              // OP Sepolia CCTP Domain
    0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5,    // OP Sepolia NOWJC address
    1000000                                         // Default max fee (1 USDC)
  )
  ```

#### 1.3 Configure OP Sepolia NOWJC
- [ ] **Set Default Max Fee**
  ```solidity
  // On OP Sepolia NOWJC: 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5
  setDefaultMaxFee(1000000) // 1 USDC max fee for cross-chain transfers
  ```

### Phase 2: Bridge Authorization (CRITICAL)

#### 2.1 Authorize Local Bridges to Use LOWJC Contracts
- [ ] **Arbitrum Sepolia Bridge Authorization**
  ```solidity
  // On Arbitrum Sepolia Local Bridge: 0x07c5135BEf0dA35eCEe413a6F18B7992659d3522
  authorizeContract(0x7DD12e520F69387FA226402cFdd490ad09Cd4252, true) // LOWJC
  ```

- [ ] **Ethereum Sepolia Bridge Authorization**
  ```solidity
  // On Ethereum Sepolia Local Bridge: 0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3
  authorizeContract(0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6, true) // LOWJC
  ```

#### 2.2 Authorize Native Bridge to Use NOWJC Contract
- [ ] **OP Sepolia Bridge Authorization**
  ```solidity
  // On OP Sepolia Native Bridge: 0x30C338b2042164543Fb4bfF570e518f620C48D97
  authorizeContract(0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5, true) // NOWJC
  ```

#### 2.3 Set Bridge References in Job Contracts
- [ ] **Set Bridge in Arbitrum Sepolia LOWJC**
  ```solidity
  // On Arbitrum Sepolia LOWJC: 0x7DD12e520F69387FA226402cFdd490ad09Cd4252
  setBridge(0x07c5135BEf0dA35eCEe413a6F18B7992659d3522) // Local Bridge
  ```

- [ ] **Set Bridge in Ethereum Sepolia LOWJC**
  ```solidity
  // On Ethereum Sepolia LOWJC: 0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6
  setBridge(0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3) // Local Bridge
  ```

- [ ] **Set Bridge in OP Sepolia NOWJC**
  ```solidity
  // On OP Sepolia NOWJC: 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5
  setBridge(0x30C338b2042164543Fb4bfF570e518f620C48D97) // Native Bridge
  ```

### Phase 3: LayerZero Configuration - ❌ PENDING VERIFICATION

⚠️ **NOTE**: LayerZero EIDs need verification from deployment logs

### Phase 4: CCTP Configuration

#### 4.1 Set CCTP Transceivers in Job Contracts
- [ ] **Set CCTP Transceiver in OP Sepolia NOWJC**
  ```solidity
  // On OP Sepolia NOWJC: 0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5
  setCCTPTransceiver(0x39364725725627d0fFcE934bB633a9c6B532ad03)
  ```

### Phase 5: Contract Interface Configuration

#### 5.1 Set Contract References in Bridges
- [ ] **Set LOWJC Contract in Arbitrum Sepolia Bridge**
  ```solidity
  // On Arbitrum Sepolia Local Bridge: 0x07c5135BEf0dA35eCEe413a6F18B7992659d3522
  setLowjcContract(0x7DD12e520F69387FA226402cFdd490ad09Cd4252)
  ```

- [ ] **Set LOWJC Contract in Ethereum Sepolia Bridge**
  ```solidity
  // On Ethereum Sepolia Local Bridge: 0x151F97417a69a40dF2C3a053A4b17C1EdA6749a3
  setLowjcContract(0x0508A7B5F9A21B6438dbE95e15f6F97b664f9Bc6)
  ```

- [ ] **Set NOWJC Contract in OP Sepolia Bridge**
  ```solidity
  // On OP Sepolia Native Bridge: 0x30C338b2042164543Fb4bfF570e518f620C48D97
  setNativeOpenWorkJobContract(0x7b8ee59E4938177e3CDB5Be3adEe28e55aed64d5)
  ```

---

## 📊 Configuration Status

- [x] **Phase 1**: Chain Domain Mappings - ✅ **COMPLETED**
  - [x] Arbitrum Sepolia LOWJC: Chain domains + native config ✅
  - [x] Ethereum Sepolia LOWJC: Chain domains + native config ✅
  - [x] OP Sepolia NOWJC: Default max fee ✅
  
- [x] **Phase 2**: Bridge Authorization - ✅ **COMPLETED**
  - [x] Arbitrum Sepolia: Bridge ↔ LOWJC authorization ✅
  - [x] Ethereum Sepolia: Bridge ↔ LOWJC authorization ✅
  - [x] OP Sepolia: Bridge ↔ NOWJC authorization ✅
  
- [x] **Phase 3**: LayerZero Configuration - ✅ **COMPLETED**
  - [x] Arbitrum Sepolia: Chain endpoints configured ✅
  - [x] Ethereum Sepolia: Chain endpoints configured ✅
  - [x] OP Sepolia: Local chains + main chain configured ✅
  
- [x] **Phase 4**: CCTP Configuration - ✅ **COMPLETED**
  - [x] OP Sepolia NOWJC: CCTP transceiver configured ✅
  - [x] All chains: USDC token addresses verified ✅
  
- [x] **Phase 5**: Contract Interfaces - ✅ **COMPLETED**
  - [x] Arbitrum Sepolia: Bridge → LOWJC interface ✅
  - [x] Ethereum Sepolia: Bridge → LOWJC interface ✅
  - [x] OP Sepolia: Bridge → NOWJC interface ✅

# 🎉 **ALL PHASES COMPLETED!**

**✅ READY FOR FULL JOB CYCLE TESTING ✅**