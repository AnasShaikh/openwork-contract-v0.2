# OpenWork Deployment Command Templates

**Purpose**: Standard command templates for deploying OpenWork contracts
**Version**: 1.0
**Last Updated**: December 28, 2025

---

## Table of Contents
1. [Non-UUPS Contract Deployment](#1-non-uups-contract-deployment)
2. [UUPS Contract Deployment (3-Step Process)](#2-uups-contract-deployment-3-step-process)
3. [Contract Configuration Commands](#3-contract-configuration-commands)
4. [Verification Commands](#4-verification-commands)
5. [Common Patterns & Examples](#5-common-patterns--examples)

---

## Prerequisites

### Environment Setup
```bash
# Load environment variables
source .env

# Required variables:
# - ETHEREUM_MAINNET_RPC_URL
# - BASE_MAINNET_RPC_URL
# - ARBITRUM_MAINNET_RPC_URL
# - OPTIMISM_MAINNET_RPC_URL
# - POLYGON_MAINNET_RPC_URL
# - AVALANCHE_MAINNET_RPC_URL
# - DEPLOYER_PRIVATE_KEY (or specific wallet keys)
```

---

## 1. Non-UUPS Contract Deployment

### 1.1 Simple Contract (No Constructor Parameters)

**Template:**
```bash
forge create --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/path/to/Contract.sol:ContractName"
```

**Example - Genesis Contract:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-genesis.sol:OpenworkGenesis"
```

### 1.2 Contract with Constructor Parameters

**Template:**
```bash
forge create --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/path/to/Contract.sol:ContractName" \
  --constructor-args <param1> <param2> <param3>
```

**Example - OpenWork Token:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token.sol:VotingToken" \
  --constructor-args 0xYourMultisigAddress
```

**Example - Main Chain Bridge:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/main-chain-bridge.sol:MainChainBridge" \
  --constructor-args 0x1a44076050125825900e736c501f859c50fE728c 0xYourMultisigAddress 30184
```
**Parameters:**
- `0x1a44076050125825900e736c501f859c50fE728c` = LayerZero V2 Endpoint (universal)
- `0xYourMultisigAddress` = Owner address
- `30184` = Native Chain EID (Base)

**Example - Native Chain Bridge:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-bridge.sol:NativeChainBridge" \
  --constructor-args 0x1a44076050125825900e736c501f859c50fE728c 0xYourMultisigAddress 30101
```
**Parameters:**
- `0x1a44076050125825900e736c501f859c50fE728c` = LayerZero V2 Endpoint
- `0xYourMultisigAddress` = Owner address
- `30101` = Main Chain EID (Ethereum)

**Example - Local Bridge:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/local-bridge.sol:LocalBridge" \
  --constructor-args 0x1a44076050125825900e736c501f859c50fE728c 0xYourMultisigAddress 30184 30101 30110
```
**Parameters:**
- `0x1a44076050125825900e736c501f859c50fE728c` = LayerZero V2 Endpoint
- `0xYourMultisigAddress` = Owner address
- `30184` = Native Chain EID (Base)
- `30101` = Main Chain EID (Ethereum)
- `30110` = This Local Chain EID (Arbitrum)

**Example - CCTP Transceiver:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/cctp-transceiver.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962 0xAD09780d193884d503182aD4588450C416D6F9D4 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
```
**Parameters (Base Mainnet):**
- `0x1682Ae6375C4E4A97e4B583BC394c861A46D8962` = CCTP TokenMessenger
- `0xAD09780d193884d503182aD4588450C416D6F9D4` = CCTP MessageTransmitter
- `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` = USDC Token

**Example - Genesis Reader Helper:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/genesis-reader-helper.sol:GenesisReaderHelper" \
  --constructor-args 0xOpenWorkGenesisProxyAddress
```

---

## 2. UUPS Contract Deployment (3-Step Process)

### Overview
UUPS contracts require:
1. **Step 1**: Deploy Implementation contract
2. **Step 2**: Deploy Proxy contract pointing to implementation
3. **Step 3**: Initialize the proxy with required parameters

---

### 2.1 STEP 1: Deploy Implementation

**Template:**
```bash
forge create --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/path/to/Contract.sol:ContractName"
```

**Example - Main DAO Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/main-dao.sol:MainDAO"
```
✅ **Result**: Implementation address (e.g., `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4`)

**Example - OpenWork Genesis Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-genesis.sol:OpenworkGenesis"
```

**Example - Profile Genesis Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/profile-genesis.sol:ProfileGenesis"
```

**Example - Native DAO Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-dao.sol:NativeDAO"
```

**Example - Native Rewards Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol:NativeRewards"
```

**Example - NOWJC Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/nowjc.sol:NativeOpenWorkJobContract"
```

**Example - Native Athena Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-athena.sol:NativeAthena"
```

**Example - Native Athena Oracle Manager Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-athena-oracle-manager.sol:NativeAthenaOracleManager"
```

**Example - Profile Manager Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/profile-manager.sol:ProfileManager"
```

**Example - LOWJC Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/lowjc.sol:LocalOpenWorkJobContract"
```

**Example - Athena Client Implementation:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/athena-client.sol:AthenaClient"
```

---

### 2.2 STEP 2: Deploy Proxy

**Template:**
```bash
forge create --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/path/to/proxy.sol:UUPSProxy" \
  --constructor-args <IMPLEMENTATION_ADDRESS> 0x
```

**Note**: The `0x` at the end means "no initialization data during proxy deployment". We initialize in Step 3.

**Example - Main DAO Proxy:**
```bash
source .env && forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args 0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4 0x
```
✅ **Result**: Proxy address (e.g., `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465`)

**Example - Genesis Proxy:**
```bash
source .env && forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args 0xYourImplementationAddress 0x
```

**IMPORTANT**: Always use the **Proxy address** for all interactions after deployment!

---

### 2.3 STEP 3: Initialize Proxy

**Template:**
```bash
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <PROXY_ADDRESS> \
  "initialize(<paramType1>,<paramType2>,...)" \
  <param1Value> <param2Value> ...
```

---

### 2.3.1 Genesis Contracts Initialization

**OpenWork Genesis:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourGenesisProxyAddress \
  "initialize(address)" \
  0xYourMultisigAddress
```
**Parameters:**
- `address owner` = Multisig wallet address

**Profile Genesis:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourProfileGenesisProxyAddress \
  "initialize(address)" \
  0xYourMultisigAddress
```
**Parameters:**
- `address owner` = Multisig wallet address

---

### 2.3.2 Main Chain (Ethereum) Initialization

**Main DAO:**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourMainDAOProxyAddress \
  "initialize(address,address,uint256)" \
  0xYourTimelockAddress \
  0xYourOpenWorkTokenAddress \
  100000000000000000000
```
**Parameters:**
- `address owner` = Timelock contract address
- `address openworkToken` = OpenWork Token address
- `uint256 proposalStakeThreshold` = 100 * 10^18 (100 tokens)

**Main Rewards:**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourMainRewardsProxyAddress \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0xYourOpenWorkTokenAddress \
  0xYourMainDAOProxyAddress
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address openworkToken` = OpenWork Token address
- `address mainDAO` = Main DAO Proxy address

---

### 2.3.3 Native Chain (Base) Initialization

**Native DAO:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeDAOProxyAddress \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0x0000000000000000000000000000000000000000 \
  0xYourGenesisProxyAddress
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address bridge` = Zero address initially (update after bridge deployment)
- `address genesis` = OpenWork Genesis Proxy address

**Native Rewards:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeRewardsProxyAddress \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0x0000000000000000000000000000000000000000 \
  0xYourGenesisProxyAddress
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address nowjContract` = Zero address initially (update after NOWJC deployment)
- `address genesis` = OpenWork Genesis Proxy address

**NOWJC:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress \
  "initialize(address,address,address,address,address,address)" \
  0xYourMultisigAddress \
  0x0000000000000000000000000000000000000000 \
  0xYourGenesisProxyAddress \
  0xYourNativeRewardsProxyAddress \
  0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  0x0000000000000000000000000000000000000000
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address bridge` = Zero address initially
- `address genesis` = OpenWork Genesis Proxy address
- `address rewardsContract` = Native Rewards Proxy address
- `address usdtToken` = Base USDC address (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)
- `address cctpReceiver` = Zero address initially (update after CCTP deployment)

**Native Athena Oracle Manager:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourOracleManagerProxyAddress \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0xYourGenesisProxyAddress \
  0x0000000000000000000000000000000000000000
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address genesis` = OpenWork Genesis Proxy address
- `address nativeAthena` = Zero address initially (update after Native Athena deployment)

**Native Athena:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeAthenaProxyAddress \
  "initialize(address,address,address,address,address)" \
  0xYourMultisigAddress \
  0xYourNativeDAOProxyAddress \
  0xYourGenesisProxyAddress \
  0xYourNOWJCProxyAddress \
  0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address daoContract` = Native DAO Proxy address
- `address genesis` = OpenWork Genesis Proxy address
- `address nowjContract` = NOWJC Proxy address
- `address usdcToken` = Base USDC address

**Profile Manager:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourProfileManagerProxyAddress \
  "initialize(address,address,address)" \
  0xYourMultisigAddress \
  0x0000000000000000000000000000000000000000 \
  0xYourProfileGenesisProxyAddress
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address bridge` = Zero address initially
- `address genesis` = Profile Genesis Proxy address

---

### 2.3.4 Local Chain Initialization

**LOWJC (per local chain):**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLOWJCProxyAddress \
  "initialize(address,address,uint32,address,address)" \
  0xYourMultisigAddress \
  0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
  30110 \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address usdtToken` = Chain-specific USDC address (Arbitrum: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831)
- `uint32 chainId` = This chain's LayerZero EID (Arbitrum: 30110)
- `address bridge` = Zero address initially
- `address cctpSender` = Zero address initially

**Athena Client (per local chain):**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourAthenaClientProxyAddress \
  "initialize(address,address,uint32,address,address,address)" \
  0xYourMultisigAddress \
  0xaf88d065e77c8cC2239327C5EDb3A432268e5831 \
  30110 \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  0xYourNativeAthenaProxyAddressOnBase
```
**Parameters:**
- `address owner` = Multisig wallet address
- `address usdtToken` = Chain-specific USDC address
- `uint32 chainId` = This chain's LayerZero EID
- `address bridge` = Zero address initially
- `address cctpSender` = Zero address initially
- `address nativeAthenaRecipient` = Native Athena Proxy address on Base

---

## 3. Contract Configuration Commands

### 3.1 Basic Configuration

**Set Bridge Reference:**
```bash
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <CONTRACT_ADDRESS> \
  "setBridge(address)" \
  <BRIDGE_ADDRESS>
```

**Set Genesis Reference:**
```bash
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <CONTRACT_ADDRESS> \
  "setGenesis(address)" \
  <GENESIS_ADDRESS>
```

**Authorize Contract:**
```bash
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <CONTRACT_ADDRESS> \
  "authorizeContract(address,bool)" \
  <AUTHORIZED_CONTRACT_ADDRESS> true
```

**Transfer Ownership:**
```bash
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <CONTRACT_ADDRESS> \
  "transferOwnership(address)" \
  <NEW_OWNER_ADDRESS>
```

---

### 3.2 LayerZero Peer Configuration

**Set Peer (Bridge to Bridge):**
```bash
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <BRIDGE_ADDRESS> \
  "setPeer(uint32,bytes32)" \
  <REMOTE_CHAIN_EID> \
  0x000000000000000000000000<REMOTE_BRIDGE_ADDRESS_WITHOUT_0x>
```

**Example - Native Bridge → Main Bridge:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress \
  "setPeer(uint32,bytes32)" \
  30101 \
  0x000000000000000000000000YourMainBridgeAddressOnEthereum
```

**Example - Main Bridge → Native Bridge:**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourMainBridgeAddress \
  "setPeer(uint32,bytes32)" \
  30184 \
  0x000000000000000000000000YourNativeBridgeAddressOnBase
```

**Example - Native Bridge → Local Bridge:**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress \
  "setPeer(uint32,bytes32)" \
  30110 \
  0x000000000000000000000000YourLocalBridgeAddressOnArbitrum
```

---

### 3.3 Native Chain (Base) Configuration

**Native DAO Configuration:**
```bash
# Set NOWJC contract
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeDAOProxyAddress "setNOWJContract(address)" 0xYourNOWJCProxyAddress

# Set bridge
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeDAOProxyAddress "setBridge(address)" 0xYourNativeBridgeAddress

# Set genesis
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeDAOProxyAddress "setGenesis(address)" 0xYourGenesisProxyAddress
```

**NOWJC Configuration:**
```bash
# Set bridge
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "setBridge(address)" 0xYourNativeBridgeAddress

# Set rewards contract
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "setRewardsContract(address)" 0xYourNativeRewardsProxyAddress

# Set CCTP receiver
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "setCCTPReceiver(address)" 0xYourCCTPTransceiverAddress

# Set CCTP transceiver
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "setCCTPTransceiver(address)" 0xYourCCTPTransceiverAddress

# Set Native Athena
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "setNativeAthena(address)" 0xYourNativeAthenaProxyAddress

# Set treasury
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "setTreasury(address)" 0xYourTreasuryAddress

# Authorize Native Athena
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNOWJCProxyAddress "addAuthorizedContract(address)" 0xYourNativeAthenaProxyAddress
```

**Native Athena Configuration:**
```bash
# Set genesis
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeAthenaProxyAddress "setGenesis(address)" 0xYourGenesisProxyAddress

# Set NOWJC
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeAthenaProxyAddress "setNOWJContract(address)" 0xYourNOWJCProxyAddress

# Set Oracle Manager
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeAthenaProxyAddress "setOracleManager(address)" 0xYourOracleManagerProxyAddress

# Set DAO
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeAthenaProxyAddress "setDAOContract(address)" 0xYourNativeDAOProxyAddress

# Set bridge
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeAthenaProxyAddress "setBridge(address)" 0xYourNativeBridgeAddress
```

**Native Bridge Configuration:**
```bash
# Authorize contracts
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "authorizeContract(address,bool)" 0xYourNativeDAOProxyAddress true

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "authorizeContract(address,bool)" 0xYourNOWJCProxyAddress true

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "authorizeContract(address,bool)" 0xYourNativeAthenaProxyAddress true

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "authorizeContract(address,bool)" 0xYourProfileManagerProxyAddress true

# Set contract addresses
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "setNativeDaoContract(address)" 0xYourNativeDAOProxyAddress

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "setNativeAthenaContract(address)" 0xYourNativeAthenaProxyAddress

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "setNativeOpenWorkJobContract(address)" 0xYourNOWJCProxyAddress

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "setProfileManager(address)" 0xYourProfileManagerProxyAddress

# Update Main Chain EID
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "updateMainChainEid(uint32)" 30101

# Add local chains
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "addLocalChain(uint32)" 30110

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "addLocalChain(uint32)" 30111

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "addLocalChain(uint32)" 30109

cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourNativeBridgeAddress "addLocalChain(uint32)" 30106
```

---

### 3.4 Local Chain Configuration

**LOWJC Configuration:**
```bash
# Set bridge
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLOWJCProxyAddress "setBridge(address)" 0xYourLocalBridgeAddress

# Set CCTP sender
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLOWJCProxyAddress "setCCTPSender(address)" 0xYourCCTPTransceiverAddress

# Set CCTP mint recipient (NOWJC on Base)
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLOWJCProxyAddress "setCCTPMintRecipient(address)" 0xYourNOWJCProxyAddressOnBase

# Set Athena Client
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLOWJCProxyAddress "setAthenaClientContract(address)" 0xYourAthenaClientProxyAddress
```

**Athena Client Configuration:**
```bash
# Set bridge
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourAthenaClientProxyAddress "setBridge(address)" 0xYourLocalBridgeAddress

# Set LOWJC
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourAthenaClientProxyAddress "setJobContract(address)" 0xYourLOWJCProxyAddress

# Set CCTP sender
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourAthenaClientProxyAddress "setCCTPSender(address)" 0xYourCCTPTransceiverAddress

# Set native chain domain (Base = 6)
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourAthenaClientProxyAddress "setNativeChainDomain(uint32)" 6
```

**Local Bridge Configuration:**
```bash
# Authorize contracts
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLocalBridgeAddress "authorizeContract(address,bool)" 0xYourLOWJCProxyAddress true

cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLocalBridgeAddress "authorizeContract(address,bool)" 0xYourAthenaClientProxyAddress true

# Set contract addresses
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLocalBridgeAddress "setLowjcContract(address)" 0xYourLOWJCProxyAddress

cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourLocalBridgeAddress "setAthenaClientContract(address)" 0xYourAthenaClientProxyAddress
```

**CCTP Transceiver Configuration:**
```bash
# Fund reward pool
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourCCTPTransceiverAddress "fundRewardPool()" --value 5ether

# Set max reward amount
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourCCTPTransceiverAddress "setMaxRewardAmount(uint256)" 1000000000000000

# Set estimated gas usage
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourCCTPTransceiverAddress "setEstimatedGasUsage(uint256)" 200000

# Set reward multiplier
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourCCTPTransceiverAddress "setRewardMultiplier(uint256)" 2
```

---

## 4. Verification Commands

### 4.1 Read Contract State

**Check Owner:**
```bash
cast call --rpc-url $RPC_URL \
  <CONTRACT_ADDRESS> \
  "owner()(address)"
```

**Check Genesis Address:**
```bash
cast call --rpc-url $RPC_URL \
  <CONTRACT_ADDRESS> \
  "genesis()(address)"
```

**Check Bridge Address:**
```bash
cast call --rpc-url $RPC_URL \
  <CONTRACT_ADDRESS> \
  "bridge()(address)"
```

**Check LayerZero Peer:**
```bash
cast call --rpc-url $RPC_URL \
  <BRIDGE_ADDRESS> \
  "peers(uint32)(bytes32)" \
  <REMOTE_CHAIN_EID>
```

**Check Authorization:**
```bash
cast call --rpc-url $RPC_URL \
  <CONTRACT_ADDRESS> \
  "authorizedContracts(address)(bool)" \
  <AUTHORIZED_ADDRESS>
```

**Check Proxy Implementation:**
```bash
cast call --rpc-url $RPC_URL \
  <PROXY_ADDRESS> \
  "implementation()(address)"
```

---

### 4.2 Verify on Block Explorer

**Etherscan (Ethereum):**
```bash
forge verify-contract \
  --chain-id 1 \
  --num-of-optimizations 200 \
  --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  <CONTRACT_ADDRESS> \
  src/path/to/Contract.sol:ContractName
```

**Basescan:**
```bash
forge verify-contract \
  --chain-id 8453 \
  --num-of-optimizations 200 \
  --watch \
  --etherscan-api-key $BASESCAN_API_KEY \
  <CONTRACT_ADDRESS> \
  src/path/to/Contract.sol:ContractName
```

**Arbiscan:**
```bash
forge verify-contract \
  --chain-id 42161 \
  --num-of-optimizations 200 \
  --watch \
  --etherscan-api-key $ARBISCAN_API_KEY \
  <CONTRACT_ADDRESS> \
  src/path/to/Contract.sol:ContractName
```

---

## 5. Common Patterns & Examples

### 5.1 Upgrade UUPS Contract

```bash
# Call upgradeToAndCall on the proxy
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <PROXY_ADDRESS> \
  "upgradeToAndCall(address,bytes)" \
  <NEW_IMPLEMENTATION_ADDRESS> \
  0x
```

**Example:**
```bash
source .env && cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  0xYourProxyAddress \
  "upgradeToAndCall(address,bytes)" \
  0xYourNewImplementationAddress \
  0x
```

---

### 5.2 Emergency Rollback

```bash
# Upgrade back to previous implementation
cast send --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  <PROXY_ADDRESS> \
  "upgradeToAndCall(address,bytes)" \
  <PREVIOUS_IMPLEMENTATION_ADDRESS> \
  0x
```

---

### 5.3 Batch Configuration Script

**Example - Complete Local Chain Setup:**
```bash
#!/bin/bash
source .env

CHAIN="arbitrum"
RPC_URL=$ARBITRUM_MAINNET_RPC_URL
LOWJC_PROXY="0xYourLOWJCProxy"
ATHENA_CLIENT_PROXY="0xYourAthenaClientProxy"
LOCAL_BRIDGE="0xYourLocalBridge"
CCTP_TRANSCEIVER="0xYourCCTPTransceiver"

echo "Configuring LOWJC..."
cast send --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $LOWJC_PROXY "setBridge(address)" $LOCAL_BRIDGE

cast send --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $LOWJC_PROXY "setCCTPSender(address)" $CCTP_TRANSCEIVER

echo "Configuring Athena Client..."
cast send --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ATHENA_CLIENT_PROXY "setBridge(address)" $LOCAL_BRIDGE

cast send --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ATHENA_CLIENT_PROXY "setJobContract(address)" $LOWJC_PROXY

echo "Configuring Local Bridge..."
cast send --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $LOCAL_BRIDGE "authorizeContract(address,bool)" $LOWJC_PROXY true

cast send --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $LOCAL_BRIDGE "authorizeContract(address,bool)" $ATHENA_CLIENT_PROXY true

echo "Configuration complete!"
```

---

## Chain-Specific Constants

### LayerZero EIDs (Mainnet)
```
Ethereum:  30101
Base:      30184
Arbitrum:  30110
Optimism:  30111
Polygon:   30109
Avalanche: 30106
```

### CCTP Domains (Mainnet)
```
Ethereum:  0
Base:      6
Arbitrum:  3
Optimism:  2
Polygon:   7
Avalanche: 1
```

### USDC Addresses (Mainnet)
```
Ethereum:  0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
Base:      0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Arbitrum:  0xaf88d065e77c8cC2239327C5EDb3A432268e5831
Optimism:  0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85
Polygon:   0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
Avalanche: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E
```

### LayerZero V2 Endpoint (Universal)
```
0x1a44076050125825900e736c501f859c50fE728c
```

---

**End of Deployment Command Templates**

For questions or issues, refer to:
- [OpenWork Multichain Deployment Plan](./OPENWORK_MULTICHAIN_DEPLOYMENT_PLAN.md)
- Deployment logs in `references/logs/`
