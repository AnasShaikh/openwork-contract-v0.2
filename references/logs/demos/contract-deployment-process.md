# Contract Deployment Process

Standard process for deploying OpenWork contracts to testnet/mainnet.

## Prerequisites

```bash
# Load environment variables
source .env
```

**Required env variables:**
- `ARBITRUM_SEPOLIA_RPC_URL`
- `OPTIMISM_SEPOLIA_RPC_URL`
- `ETHEREUM_SEPOLIA_RPC_URL`
- `WALL2_KEY` (deployer private key)
- `ETHERSCAN_API_KEY` (for verification)

---

## Step 1: Check Wallet Balance

```bash
# Get wallet address
source .env && cast wallet address --private-key $WALL2_KEY

# Check balance (Arbitrum Sepolia)
source .env && cast balance <WALLET_ADDRESS> --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --ether
```

---

## Step 2: Deploy Implementation Contract

### For UUPS Upgradeable Contracts

```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/path/to/contract.sol:ContractName"
```

**Example - OpenworkGenesis:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis.sol:OpenworkGenesis"
```

**Output:**
```
Deployer: 0x...
Deployed to: 0x... (IMPLEMENTATION_ADDRESS)
Transaction hash: 0x...
```

---

## Step 3: Deploy Proxy Contract

### For UUPS Proxies

The proxy needs:
1. Implementation address
2. Encoded initialize call data

```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" \
  --constructor-args <IMPLEMENTATION_ADDRESS> $(cast calldata "initialize(<PARAMS>)" <VALUES>)
```

**Example - OpenworkGenesis Proxy (single address param):**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" \
  --constructor-args 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b $(cast calldata "initialize(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A)
```

**Output:**
```
Deployer: 0x...
Deployed to: 0x... (PROXY_ADDRESS - use this for all interactions)
Transaction hash: 0x...
```

---

## Step 3b: Deferred Initialization Pattern (For Circular Dependencies)

When contracts have circular dependencies (e.g., NOWJC needs RewardsContract address, RewardsContract needs NOWJC address), use deferred initialization:

### Deploy Proxy with Empty Init Data

```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" \
  --constructor-args <IMPLEMENTATION_ADDRESS> 0x
```

**Note:** The `0x` represents empty bytes - no initialization call is made during deployment.

### Initialize Later via cast send

Once all contract addresses are available, initialize each proxy:

```bash
source .env && cast send <PROXY_ADDRESS> \
  "initialize(<PARAM_TYPES>)" <PARAM_VALUES> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Example - NOWJC (6 params):**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "initialize(address,address,address,address,address,address)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 \
  0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  0xD22C85d18D188D37FD9D38974420a6BD68fFC315 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Example - OpenWorkRewardsContract (3 params):**
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 \
  "initialize(address,address,address)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### Recommended Deployment Order (Arbitrum Native Chain)

1. **OpenworkGenesis** - Deploy impl + proxy with init (no dependencies)
2. **OpenWorkRewardsContract** - Deploy impl + proxy with empty init (`0x`)
3. **NOWJC** - Deploy impl + proxy with empty init (`0x`)
4. **NativeChainBridge** - Deploy directly (non-UUPS, needs LayerZero endpoint)
5. **CCTPv2Transceiver** - Deploy directly (non-UUPS, needs Circle addresses)
6. **Initialize NOWJC** - Now has all addresses (bridge, genesis, rewards, usdc, cctp)
7. **Initialize OpenWorkRewardsContract** - Now has NOWJC address

---

## Step 4: Verify Implementation Contract

```bash
source .env && forge verify-contract <IMPLEMENTATION_ADDRESS> \
  "src/path/to/contract.sol:ContractName" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir
```

**Example:**
```bash
source .env && forge verify-contract 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b \
  "src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis.sol:OpenworkGenesis" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir
```

---

## Step 5: Verify Proxy Contract

```bash
source .env && forge verify-contract <PROXY_ADDRESS> \
  "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" <IMPLEMENTATION_ADDRESS> $(cast calldata "initialize(<PARAMS>)" <VALUES>))
```

**Example:**
```bash
source .env && forge verify-contract 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b $(cast calldata "initialize(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A))
```

---

## Step 6: Check Verification Status

```bash
source .env && forge verify-check <GUID> --chain arbitrum-sepolia --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Non-UUPS Contracts

For contracts that are NOT upgradeable, skip the proxy step:

```bash
# Deploy directly
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/path/to/contract.sol:ContractName" \
  --constructor-args <ARG1> <ARG2> ...

# Verify directly
source .env && forge verify-contract <CONTRACT_ADDRESS> \
  "src/path/to/contract.sol:ContractName" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir \
  --constructor-args $(cast abi-encode "constructor(<TYPES>)" <VALUES>)
```

---

## Chain Identifiers

| Network | Chain ID | Forge Chain Name |
|---------|----------|------------------|
| Arbitrum Sepolia | 421614 | `arbitrum-sepolia` |
| OP Sepolia | 11155420 | `optimism-sepolia` |
| Ethereum Sepolia | 11155111 | `sepolia` |

---

## Common Initialize Signatures

| Contract | Initialize Signature |
|----------|---------------------|
| OpenworkGenesis | `initialize(address _owner)` |
| OpenWorkRewardsContract | `initialize(address _owner, address _jobContract, address _genesis)` |
| NOWJC | `initialize(address _owner, address _bridge, address _genesis, address _rewardsContract, address _usdcToken, address _cctpReceiver)` |
| NativeDAO | `initialize(address _owner, address _bridge, address _genesis)` |
| MainRewards | `initialize(address _owner, address _openworkToken, address _bridge)` |

---

## Documentation

After each deployment:
1. Update `references/deployments/openwork-contract-addresses-jan-26.md`
2. Log commands in `references/logs/imp/deployment-log-testnet-2-jan-26.md`

---

# Post-Deployment Configuration Checklist Template (Native Chain)

After deploying all contracts on the **Native Chain (Arbitrum)**, use this checklist to configure inter-contract dependencies. Replace `<PLACEHOLDER>` values with actual deployed addresses.

---

## 1. OpenworkGenesis (Storage Contract)

**Proxy:** `<OPENWORK_GENESIS_PROXY>`
**Init params:** `owner`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `authorizeContract(NOWJC, true)` | `<NOWJC_PROXY>` | ❌ |
| `authorizeContract(NativeDAO, true)` | `<NATIVE_DAO_PROXY>` | ❌ |
| `authorizeContract(NativeAthena, true)` | `<NATIVE_ATHENA_PROXY>` | ❌ |
| `authorizeContract(OracleManager, true)` | `<ORACLE_MANAGER_PROXY>` | ❌ |
| `authorizeContract(RewardsContract, true)` | `<REWARDS_CONTRACT_PROXY>` | ❌ |
| `setAdmin(owner, true)` | Optional | - |
| `setMainDAO(NativeDAO)` | Optional | - |

### B. Config needed FROM other contracts:
None (central storage)

---

## 2. OpenWorkRewardsContract

**Proxy:** `<REWARDS_CONTRACT_PROXY>`
**Init params:** `owner`, `jobContract`, `genesis`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setProfileGenesis(address)` | `<PROFILE_GENESIS_PROXY>` | ❌ |
| `setNativeDAO(address)` | `<NATIVE_DAO_PROXY>` | ❌ |
| `setTeamTokensPool(uint256)` | Optional | - |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ❌ |

---

## 3. NOWJC (NativeOpenWorkJobContract)

**Proxy:** `<NOWJC_PROXY>`
**Init params:** `owner`, `bridge`, `genesis`, `rewardsContract`, `usdcToken`, `cctpReceiver`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(owner, true)` | `<OWNER>` | ❌ |
| `setCCTPTransceiver(address)` | `<CCTP_TRANSCEIVER>` | ❌ |
| `setNativeAthena(address)` | `<NATIVE_ATHENA_PROXY>` | ❌ |
| `setNativeDAO(address)` | `<NATIVE_DAO_PROXY>` | ❌ |
| `setTreasury(address)` | `<TREASURY>` | ❌ |
| `addAuthorizedContract(bridge)` | `<NATIVE_BRIDGE>` | ❌ |
| `addAuthorizedContract(owner)` | `<OWNER>` | ❌ |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ❌ |

---

## 4. NativeChainBridge (LayerZero OApp)

**Address:** `<NATIVE_BRIDGE>` (non-upgradeable)
**Constructor params:** `endpoint`, `owner`, `mainChainEid`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setNativeDaoContract(address)` | `<NATIVE_DAO_PROXY>` | ❌ |
| `setNativeAthenaContract(address)` | `<NATIVE_ATHENA_PROXY>` | ❌ |
| `setNativeOpenWorkJobContract(address)` | `<NOWJC_PROXY>` | ❌ |
| `setProfileManager(address)` | `<PROFILE_MANAGER_PROXY>` | ❌ |
| `setNativeDAO(address)` | `<NATIVE_DAO_PROXY>` | ❌ |
| `authorizeContract(NOWJC, true)` | `<NOWJC_PROXY>` | ❌ |
| `setPeer(eid, bytes32)` | Cross-chain (deferred) | ⏳ |
| `addLocalChain(localChainEid)` | Each local chain EID | ❌ |

### B. Config needed FROM other contracts:
None

---

## 5. CCTPv2Transceiver (CCTP Integration)

**Address:** `<CCTP_TRANSCEIVER>` (non-upgradeable)
**Constructor params:** `tokenMessenger`, `messageTransmitter`, `usdc`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(address, bool)` | Optional | - |
| `setMainDAO(address)` | Optional | - |
| `setMaxRewardAmount(uint256)` | Optional (default 0.001 ETH) | - |
| `setEstimatedGasUsage(uint256)` | Optional (default 200k) | - |
| `setRewardMultiplier(uint256)` | Optional (default 2x) | - |

### B. Config needed FROM other contracts:
None (standalone - NOWJC calls it directly via sendFast)

**Status:** No required configuration

---

## 6. NativeDAO

**Proxy:** `<NATIVE_DAO_PROXY>`
**Init params:** `owner`, `bridge`, `genesis`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setNOWJContract(address)` | `<NOWJC_PROXY>` | ❌ |
| `setAdmin(owner, true)` | `<OWNER>` | ❌ |
| `addAuthorizedContract(bridge)` | `<NATIVE_BRIDGE>` | ❌ |

*Note: Bridge must be authorized to call `updateStakeData()` for cross-chain stake sync.*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ❌ |

---

## 7. NativeAthena

**Proxy:** `<NATIVE_ATHENA_PROXY>`
**Init params:** `owner`, `daoContract`, `genesis`, `nowjContract`, `usdcToken`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setOracleManager(address)` | `<ORACLE_MANAGER_PROXY>` | ❌ |
| `setBridge(address)` | `<NATIVE_BRIDGE>` | ❌ |

*Note: `setGenesis`, `setNOWJContract`, `setDAOContract`, `setUSDCToken` already set via init*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ❌ |

---

## 8. NativeAthenaOracleManager

**Proxy:** `<ORACLE_MANAGER_PROXY>`
**Init params:** `owner`, `genesis`, `nativeAthena`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAuthorizedCaller(address, bool)` | `<NATIVE_ATHENA_PROXY>` | ❌ |
| `setAdmin(address, bool)` | Optional | - |
| `setMainDAO(address)` | Optional | - |

*Note: `setGenesis`, `setNativeAthena` already set via init*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ❌ |

---

## 9. ProfileGenesis (Storage Contract)

**Proxy:** `<PROFILE_GENESIS_PROXY>`
**Init params:** `owner`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `authorizeContract(ProfileManager, true)` | `<PROFILE_MANAGER_PROXY>` | ❌ |

### B. Config needed FROM other contracts:
None (storage contract)

---

## 10. ProfileManager

**Proxy:** `<PROFILE_MANAGER_PROXY>`
**Init params:** `owner`, `bridge`, `genesis`

> ⚠️ **IMPORTANT:** The `genesis` param MUST be `<PROFILE_GENESIS_PROXY>` (ProfileGenesis), NOT OpenworkGenesis. ProfileManager manages user profiles via ProfileGenesis.

### A. Config ON this contract:
None required - `setBridge` and `setGenesis` already set via init

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| ProfileGenesis | `authorizeContract(this, true)` | ❌ |

**Status:** No additional config needed on this contract

---

## Placeholder Reference

| Placeholder | Description |
|-------------|-------------|
| `<OWNER>` | Deployer/admin wallet address |
| `<TREASURY>` | Treasury address (can be same as owner) |
| `<OPENWORK_GENESIS_PROXY>` | OpenworkGenesis proxy address |
| `<REWARDS_CONTRACT_PROXY>` | OpenWorkRewardsContract proxy address |
| `<NOWJC_PROXY>` | NativeOpenWorkJobContract proxy address |
| `<NATIVE_BRIDGE>` | NativeChainBridge address |
| `<CCTP_TRANSCEIVER>` | CCTPv2Transceiver address |
| `<NATIVE_DAO_PROXY>` | NativeDAO proxy address |
| `<NATIVE_ATHENA_PROXY>` | NativeAthena proxy address |
| `<ORACLE_MANAGER_PROXY>` | NativeAthenaOracleManager proxy address |
| `<PROFILE_GENESIS_PROXY>` | ProfileGenesis proxy address |
| `<PROFILE_MANAGER_PROXY>` | ProfileManager proxy address |
| `<USDC_TOKEN>` | USDC token address for the network |

---

## Configuration Execution Order

1. **Storage contracts authorize consumers:**
   - OpenworkGenesis.authorizeContract() for NOWJC, NativeDAO, NativeAthena, OracleManager, RewardsContract
   - ProfileGenesis.authorizeContract() for ProfileManager

2. **Set cross-references:**
   - OpenWorkRewardsContract.setProfileGenesis()
   - OpenWorkRewardsContract.setNativeDAO()
   - NativeDAO.setNOWJContract()
   - NativeDAO.setAdmin(owner, true)
   - NativeDAO.addAuthorizedContract(bridge)
   - NativeAthena.setOracleManager()
   - NativeAthena.setBridge()
   - NativeAthenaOracleManager.setAuthorizedCaller(NativeAthena)

3. **NOWJC configuration:**
   - NOWJC.setAdmin()
   - NOWJC.setCCTPTransceiver()
   - NOWJC.setNativeAthena()
   - NOWJC.setNativeDAO()
   - NOWJC.setTreasury()
   - NOWJC.addAuthorizedContract(bridge)
   - NOWJC.addAuthorizedContract(owner)

4. **Bridge configuration:**
   - NativeChainBridge.setNativeDaoContract()
   - NativeChainBridge.setNativeAthenaContract()
   - NativeChainBridge.setNativeOpenWorkJobContract()
   - NativeChainBridge.setProfileManager()
   - NativeChainBridge.setNativeDAO()
   - NativeChainBridge.authorizeContract(NOWJC)

5. **Cross-chain (after remote deployment):**
   - NativeChainBridge.setPeer()

---

# Local Chain Configuration Checklist Template

## 1. LOWJC (CrossChainLocalOpenWorkJobContract)

**Proxy:** `<LOWJC_PROXY>`
**Init params:** `owner`, `usdcToken`, `chainId`, `bridge`, `cctpSender`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAthenaClientContract(address)` | `<LOCAL_ATHENA_PROXY>` | ❌ |
| `setCCTPMintRecipient(address)` | `<NOWJC_PROXY>` (Native Chain) | ❌ |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| LocalBridge | `authorizeContract(this, true)` | ❌ |

---

## 2. LocalAthena

**Proxy:** `<LOCAL_ATHENA_PROXY>`
**Init params:** `owner`, `usdcToken`, `chainId`, `bridge`, `cctpSender`, `nativeAthenaRecipient`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setJobContract(address)` | `<LOWJC_PROXY>` | ❌ |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| LOWJC | `setAthenaClientContract(this)` | ❌ |

---

## 3. LocalBridge (LayerZero OApp)

**Address:** `<LOCAL_BRIDGE>` (non-upgradeable)
**Constructor params:** `endpoint`, `owner`, `nativeChainEid`, `mainChainEid`, `thisLocalChainEid`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAthenaClientContract(address)` | `<LOCAL_ATHENA_PROXY>` | ❌ |
| `setLowjcContract(address)` | `<LOWJC_PROXY>` | ❌ |
| `authorizeContract(LOWJC, true)` | `<LOWJC_PROXY>` | ❌ |
| `setPeer(eid, bytes32)` | `<NATIVE_BRIDGE>` (cross-chain) | ⏳ |

### B. Config needed FROM other contracts:
None

---

## 4. CCTPv2Transceiver (CCTP Integration)

**Address:** `<CCTP_TRANSCEIVER>` (non-upgradeable)
**Constructor params:** `tokenMessenger`, `messageTransmitter`, `usdc`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(address, bool)` | Optional | - |
| `setMainDAO(address)` | Optional | - |
| `setMaxRewardAmount(uint256)` | Optional (default 0.001 ETH) | - |
| `setEstimatedGasUsage(uint256)` | Optional (default 200k) | - |
| `setRewardMultiplier(uint256)` | Optional (default 2x) | - |

### B. Config needed FROM other contracts:
None (standalone - LOWJC calls it directly via sendFast)

**Status:** ✅ No required configuration

---

## Local Chain Configuration Order

1. **LocalBridge setup:**
   - LocalBridge.setAthenaClientContract()
   - LocalBridge.setLowjcContract()
   - LocalBridge.authorizeContract(LOWJC)

2. **LOWJC setup:**
   - LOWJC.setAthenaClientContract()
   - LOWJC.setCCTPMintRecipient()

3. **LocalAthena setup:**
   - LocalAthena.setJobContract()

4. **Cross-chain (bidirectional peer setup):**
   - LocalBridge.setPeer(nativeChainEid, nativeBridgeBytes32)
   - NativeChainBridge.setPeer(localChainEid, localBridgeBytes32)

---

# Main Chain Configuration Checklist Template

## 1. MainRewardsContract

**Proxy:** `<MAIN_REWARDS_PROXY>`
**Init params:** `owner`, `openworkToken`, `bridge`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setMainDAO(address)` | `<MAIN_DAO_PROXY>` | ❌ |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| MainBridge | `authorizeContract(this, true)` | ❌ |

---

## 2. MainDAO

**Proxy:** `<MAIN_DAO_PROXY>`
**Init params:** `owner`, `openworkToken`, `chainId`, `bridge`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(owner, true)` | `<OWNER>` | ❌ |

*Note: Owner is auto-admin in init*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| MainBridge | `setMainDaoContract(this)` | ❌ |
| MainBridge | `authorizeContract(this, true)` | ❌ |

---

## 3. OpenworkToken

**Address:** `<OPENWORK_TOKEN>` (non-upgradeable)
**Constructor params:** `initialOwner`, `mainRewardsContract`, `daoAddress`

**Status:** No configuration required (immutable ERC20)

---

## 4. MainBridge (LayerZero OApp)

**Address:** `<MAIN_BRIDGE>` (non-upgradeable)
**Constructor params:** `endpoint`, `owner`, `nativeChainEid`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setMainDaoContract(address)` | `<MAIN_DAO_PROXY>` | ❌ |
| `setRewardsContract(address)` | `<MAIN_REWARDS_PROXY>` | ❌ |
| `authorizeContract(MainDAO, true)` | `<MAIN_DAO_PROXY>` | ❌ |
| `authorizeContract(MainRewards, true)` | `<MAIN_REWARDS_PROXY>` | ❌ |
| `setAllowedSourceChain(nativeEid, true)` | Native Chain EID | ❌ |
| `setAllowedSourceChain(localEid, true)` | Local Chain EID | ❌ |
| `setPeer(nativeEid, bytes32)` | `<NATIVE_BRIDGE>` | ⏳ |

### B. Config needed FROM other contracts:

None

---

## Main Chain Configuration Order

1. **Initialize proxies:**
   - MainRewardsContract.initialize(_owner, _openworkToken, _bridge)
   - MainDAO.initialize(_owner, _openworkToken, _chainId, _bridge)

2. **MainBridge setup:**
   - MainBridge.setMainDaoContract()
   - MainBridge.setRewardsContract()
   - MainBridge.authorizeContract(MainDAO)
   - MainBridge.authorizeContract(MainRewards)
   - MainBridge.setAllowedSourceChain(nativeEid, true)
   - MainBridge.setAllowedSourceChain(localEid, true)

3. **MainRewardsContract setup:**
   - MainRewardsContract.setMainDAO()

4. **Cross-chain (bidirectional peer setup):**
   - MainBridge.setPeer(nativeEid, nativeBridgeBytes32)
   - NativeChainBridge.setPeer(mainEid, mainBridgeBytes32)

---

## Placeholder Reference (Main Chain)

| Placeholder | Description |
|-------------|-------------|
| `<OWNER>` | Deployer/admin wallet address |
| `<MAIN_REWARDS_PROXY>` | MainRewardsContract proxy address |
| `<MAIN_DAO_PROXY>` | MainDAO proxy address |
| `<OPENWORK_TOKEN>` | OpenworkToken address |
| `<MAIN_BRIDGE>` | MainBridge address |
| `<NATIVE_BRIDGE>` | NativeChainBridge address (on native chain) |

---

*Last updated: January 2, 2026 - Added Main Chain configuration checklist template*
