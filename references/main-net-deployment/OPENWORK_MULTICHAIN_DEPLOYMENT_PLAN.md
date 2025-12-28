# OpenWork Multichain System - Complete Deployment Plan (MAINNET)
**Version:** 26-Dec-2025 (Mainnet)
**Document Date:** 28-Dec-2025
**Network:** Production Mainnet

---

## Document Overview

**📖 This document explains:**
- System architecture and chain configuration
- Contract deployment order and dependencies
- Configuration requirements and cross-chain integration
- Conceptual understanding of the multichain deployment

**🚀 Ready to deploy? Use the execution checklist:**
→ **[DEPLOYMENT_EXECUTION_CHECKLIST.md](./DEPLOYMENT_EXECUTION_CHECKLIST.md)** ← Start here for actual deployment

The execution checklist contains every command needed with checkboxes and address tracking.

---

## Table of Contents
0. [Companion Documents](#companion-documents) ⭐ **Start with execution checklist**
1. [System Overview](#system-overview)
2. [Chain Configuration](#chain-configuration)
3. [Contract Deployment Map](#contract-deployment-map)
4. [UUPS Proxy Deployment Guide](#uups-proxy-deployment-guide)
5. [Deployment Order](#deployment-order)
6. [Configuration Steps](#configuration-steps)
7. [Cross-Chain Integration](#cross-chain-integration)
8. [Verification Checklist](#verification-checklist)

---

## Companion Documents

### 📋 DEPLOYMENT EXECUTION CHECKLIST (START HERE)

**For step-by-step execution of the entire deployment, see:**
[DEPLOYMENT_EXECUTION_CHECKLIST.md](./DEPLOYMENT_EXECUTION_CHECKLIST.md)

This is your **primary deployment document** - a complete checklist with:
- ✅ Every command needed to deploy all 51 contracts across 6 chains
- ✅ Checkbox tracking for each deployment step
- ✅ Address recording variables for each deployed contract
- ✅ Configuration commands in the correct order
- ✅ Cross-chain LayerZero peer setup (bidirectional)
- ✅ Final verification commands for the complete system
- ✅ Template-based approach for local chains (deploy once, replicate for all)

**Use this checklist during actual deployment to track progress and ensure nothing is missed.**

### 📚 Command Templates Reference

**For command syntax and patterns, see:**
[DEPLOYMENT_COMMAND_TEMPLATES.md](./DEPLOYMENT_COMMAND_TEMPLATES.md)

Reference document with:
- Command templates and syntax examples
- UUPS 3-step deployment patterns
- Chain-specific constants (EIDs, CCTP domains, addresses)
- Configuration command patterns

---

## 1. System Overview

The OpenWork multichain system consists of **3 chain types**:

### **Main Chain (Ethereum Mainnet)**
- **Role:** Governance & Rewards Hub
- **LayerZero EID:** 30101
- **Purpose:** Token distribution, main governance, reward calculations
- **Why Ethereum:** Maximum security and decentralization for governance and token distribution

### **Native Chain (Base Mainnet)**
- **Role:** Job Hub & Dispute Resolution
- **LayerZero EID:** 30184
- **CCTP Domain:** 6
- **Purpose:** Core data storage, job management, dispute resolution, profile management
- **Why Base:** Low fees, high throughput, optimal for job operations and data storage

### **Local Chains (Multi-chain Support)**
- **Role:** Job Execution & User Interface
- **Supported Chains:** Arbitrum, Optimism, Polygon, Avalanche, and any chain with both LayerZero V2 + CCTP support
- **Purpose:** User-facing job operations, local job contracts on each ecosystem
- **Requirement:** Chains MUST support both LayerZero V2 and Circle CCTP

---

## 2. Chain Configuration

### 2.1 Mainnet Chain Identifiers

| Chain | LayerZero EID | CCTP Domain | Role | Network ID |
|-------|---------------|-------------|------|------------|
| **Ethereum** | 30101 | 0 | Main Chain | 1 |
| **Base** | 30184 | 6 | Native Chain | 8453 |
| **Arbitrum** | 30110 | 3 | Local Chain | 42161 |
| **Optimism** | 30111 | 2 | Local Chain | 10 |
| **Polygon** | 30109 | 7 | Local Chain | 137 |
| **Avalanche** | 30106 | 1 | Local Chain | 43114 |

### 2.2 Required External Contracts (Mainnet)

#### LayerZero V2 Endpoints (Mainnet)
All chains use the same LayerZero V2 endpoint address:
- **Universal Endpoint:** `0x1a44076050125825900e736c501f859c50fE728c`

#### CCTP Contracts (Circle - Mainnet)

**Ethereum Mainnet:**
- Token Messenger: `0xBd3fa81B58Ba92a82136038B25aDec7066af3155`
- Message Transmitter: `0x0a992d191DEeC32aFe36203Ad87D7d289a738F81`
- USDC Token: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`

**Base Mainnet:**
- Token Messenger: `0x1682Ae6375C4E4A97e4B583BC394c861A46D8962`
- Message Transmitter: `0xAD09780d193884d503182aD4588450C416D6F9D4`
- USDC Token: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

**Arbitrum Mainnet:**
- Token Messenger: `0x19330d10D9Cc8751218eaf51E8885D058642E08A`
- Message Transmitter: `0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca`
- USDC Token: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`

**Optimism Mainnet:**
- Token Messenger: `0x2B4069517957735bE00ceE0fadAE88a26365528f`
- Message Transmitter: `0x4D41f22c5a0e5c74090899E5a8Fb597a8842b3e8`
- USDC Token: `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85`

**Polygon Mainnet:**
- Token Messenger: `0x9daF8c91AEFAE50b9c0E69629D3F6Ca40cA3B3FE`
- Message Transmitter: `0xF3be9355363857F3e001be68856A2f96b4C39Ba9`
- USDC Token: `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`

**Avalanche Mainnet:**
- Token Messenger: `0x6B25532e1060CE10cc3B0A99e5683b91BFDe6982`
- Message Transmitter: `0x8186359aF5F57FbB40c6b14A588d2A59C0C29880`
- USDC Token: `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E`

---

## 3. Contract Deployment Map

### 3.1 Main Chain (Ethereum Mainnet)

| # | Contract Name | Type | Upgradeability | Dependencies |
|---|---------------|------|----------------|--------------|
| 1 | OpenWork Token | ERC20 | Non-upgradeable | None |
| 2 | Main DAO (Impl) | Governor | UUPS | OpenWork Token |
| 3 | Main DAO (Proxy) | UUPSProxy | Proxy | Main DAO Impl |
| 4 | Main Rewards (Impl) | Rewards | UUPS | OpenWork Token, Genesis |
| 5 | Main Rewards (Proxy) | UUPSProxy | Proxy | Main Rewards Impl |
| 6 | Main Chain Bridge | OApp | Non-upgradeable | LZ Endpoint |

**Key Addresses Needed:**
- LayerZero Endpoint V2: `0x1a44076050125825900e736c501f859c50fE728c`
- OpenWork Token deployment address
- Native Chain EID: 30184 (Base)

**Gas Considerations:**
- Ethereum mainnet has high gas costs
- Optimize contract deployment order
- Consider batch transactions for configuration

---

### 3.2 Native Chain (Base Mainnet)

| # | Contract Name | Type | Upgradeability | Dependencies |
|---|---------------|------|----------------|--------------|
| 1 | OpenWork Genesis (Impl) | Storage | UUPS | None |
| 2 | OpenWork Genesis (Proxy) | UUPSProxy | Proxy | Genesis Impl |
| 3 | Profile Genesis (Impl) | Storage | UUPS | None |
| 4 | Profile Genesis (Proxy) | UUPSProxy | Proxy | Profile Genesis Impl |
| 5 | Genesis Reader Helper | Helper | Non-upgradeable | Genesis Proxies |
| 6 | Native DAO (Impl) | Governor | UUPS | Genesis, Bridge |
| 7 | Native DAO (Proxy) | UUPSProxy | Proxy | Native DAO Impl |
| 8 | Native Rewards (Impl) | Rewards | UUPS | Genesis, NOWJC |
| 9 | Native Rewards (Proxy) | UUPSProxy | Proxy | Native Rewards Impl |
| 10 | NOWJC (Impl) | Job Contract | UUPS | Genesis, Rewards, CCTP |
| 11 | NOWJC (Proxy) | UUPSProxy | Proxy | NOWJC Impl |
| 12 | Native Athena Oracle Manager (Impl) | Oracle Mgmt | UUPS | Genesis, Native Athena |
| 13 | Native Athena Oracle Manager (Proxy) | UUPSProxy | Proxy | Oracle Manager Impl |
| 14 | Native Athena (Impl) | Dispute Res | UUPS | Genesis, DAO, NOWJC, Oracle Mgr |
| 15 | Native Athena (Proxy) | UUPSProxy | Proxy | Native Athena Impl |
| 16 | Profile Manager (Impl) | Profile Mgmt | UUPS | Genesis, Bridge |
| 17 | Profile Manager (Proxy) | UUPSProxy | Proxy | Profile Manager Impl |
| 18 | Native Chain Bridge | OApp | Non-upgradeable | LZ Endpoint |
| 19 | CCTP Transceiver | CCTP Handler | Non-upgradeable | CCTP Contracts, USDC |

**Key Addresses Needed:**
- LayerZero Endpoint V2: `0x1a44076050125825900e736c501f859c50fE728c`
- USDC token: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- CCTP TokenMessenger: `0x1682Ae6375C4E4A97e4B583BC394c861A46D8962`
- CCTP MessageTransmitter: `0xAD09780d193884d503182aD4588450C416D6F9D4`
- Main Chain EID: 30101 (Ethereum)
- Local Chain EIDs: 30110 (Arbitrum), 30111 (Optimism), 30109 (Polygon), 30106 (Avalanche)

---

### 3.3 Local Chains (Deploy on EACH Supported Chain)

**Deploy on: Arbitrum, Optimism, Polygon, Avalanche**

| # | Contract Name | Type | Upgradeability | Dependencies |
|---|---------------|------|----------------|--------------|
| 1 | LOWJC (Impl) | Job Contract | UUPS | USDC, Bridge, CCTP |
| 2 | LOWJC (Proxy) | UUPSProxy | Proxy | LOWJC Impl |
| 3 | Athena Client (Impl) | Dispute Client | UUPS | USDC, LOWJC, Bridge, CCTP |
| 4 | Athena Client (Proxy) | UUPSProxy | Proxy | Athena Client Impl |
| 5 | Local Bridge | OApp | Non-upgradeable | LZ Endpoint |
| 6 | CCTP Transceiver | CCTP Handler | Non-upgradeable | CCTP Contracts, USDC |

**Key Addresses Needed (Per Chain):**
- LayerZero Endpoint V2: `0x1a44076050125825900e736c501f859c50fE728c`
- USDC token address (chain-specific)
- CCTP TokenMessenger (if supported)
- CCTP MessageTransmitter (if supported)
- Native Chain EID: 30184 (Base)
- Main Chain EID: 30101 (Ethereum)
- This chain's EID

---

## 4. UUPS Proxy Deployment Guide

### 4.1 UUPS Pattern Overview

All upgradeable contracts use the UUPS (Universal Upgradeable Proxy Standard) pattern:
- **Implementation Contract:** Contains the logic
- **Proxy Contract:** Delegates calls to implementation
- **Initialization:** Done via `initialize()` after proxy deployment

### 4.2 Deployment Steps for UUPS Contracts

For each UUPS contract, follow these steps:

#### Step 1: Deploy Implementation Contract
```solidity
// Example: Deploy Native DAO Implementation
NativeDAO implementation = new NativeDAO();
```

**Important:** The implementation contract is deployed in a disabled state (initializers are disabled in constructor).

#### Step 2: Prepare Initialization Data
```solidity
// Encode the initialize function call with parameters
bytes memory initData = abi.encodeWithSignature(
    "initialize(address,address,address)",
    ownerAddress,
    bridgeAddress,
    genesisAddress
);
```

#### Step 3: Deploy Proxy
```solidity
// Deploy UUPSProxy pointing to implementation with init data
UUPSProxy proxy = new UUPSProxy(
    address(implementation),
    initData
);
```

#### Step 4: Cast Proxy to Implementation Interface
```solidity
// Create interface to interact with proxy as if it's the implementation
NativeDAO nativeDAO = NativeDAO(address(proxy));
```

### 4.3 UUPS Contract List

**Main Chain (Ethereum):**
- Main DAO
- Main Rewards

**Native Chain (Base):**
- OpenWork Genesis
- Profile Genesis
- Native DAO
- Native Rewards
- NOWJC
- Native Athena
- Native Athena Oracle Manager
- Profile Manager

**Local Chains (Each):**
- LOWJC
- Athena Client

> **💡 For practical UUPS deployment commands (forge create, cast send, etc.), see [DEPLOYMENT_COMMAND_TEMPLATES.md](./DEPLOYMENT_COMMAND_TEMPLATES.md)**

---

## 5. Deployment Order

> **🚀 READY TO DEPLOY?**
>
> This section explains the **conceptual deployment order and dependencies**.
>
> **For actual deployment execution**, use the complete step-by-step checklist:
> → [DEPLOYMENT_EXECUTION_CHECKLIST.md](./DEPLOYMENT_EXECUTION_CHECKLIST.md) ← **START HERE**
>
> The checklist provides every command with checkboxes, address tracking, and proper sequencing.

### Phase 1: Main Chain Deployment (Ethereum Mainnet)

#### 1.1 Deploy OpenWork Token
```
Contract: OpenWorkToken
Type: Standard ERC20
Constructor: (name, symbol, initialSupply, owner)
Initial Supply: As defined in tokenomics
Owner: Multisig wallet address
```

#### 1.2 Deploy Main DAO
```
Step 1: Deploy MainDAO implementation
Step 2: Prepare init data: initialize(owner, openworkToken, proposalStakeThreshold)
  - owner: Timelock contract address
  - openworkToken: Token address from step 1.1
  - proposalStakeThreshold: 100 * 10**18 (100 tokens)
Step 3: Deploy UUPSProxy with implementation + init data
Result: Main DAO Proxy address
```

#### 1.3 Deploy Main Rewards
```
Step 1: Deploy MainRewards implementation
Step 2: Prepare init data: initialize(owner, openworkToken, mainDAO)
  - owner: Multisig or Timelock
  - openworkToken: Token address
  - mainDAO: Main DAO proxy address
Step 3: Deploy UUPSProxy with implementation + init data
Result: Main Rewards Proxy address
```

#### 1.4 Deploy Main Chain Bridge
```
Contract: MainChainBridge (OApp)
Constructor: (lzEndpoint, owner, nativeChainEid)
Parameters:
  - lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c
  - owner: Multisig wallet
  - nativeChainEid: 30184 (Base)
```

### Phase 2: Native Chain Deployment (Base Mainnet)

#### 2.1 Deploy OpenWork Genesis (UUPS)
```
Step 1: Deploy OpenworkGenesis implementation
Step 2: Prepare init data: initialize(owner)
  - owner: Multisig wallet address
Step 3: Deploy UUPSProxy with implementation + init data
Result: OpenWork Genesis Proxy address

Note: This is the main storage contract for jobs, oracles, disputes, stakes, etc.
```

#### 2.2 Deploy Profile Genesis (UUPS)
```
Step 1: Deploy ProfileGenesis implementation
Step 2: Prepare init data: initialize(owner)
  - owner: Multisig wallet address
Step 3: Deploy UUPSProxy with implementation + init data
Result: Profile Genesis Proxy address

Note: This is the storage contract for user profiles, portfolios, and ratings.
```

#### 2.3 Deploy Genesis Reader Helper
```
Contract: GenesisReaderHelper
Type: Helper contract (non-upgradeable)
Constructor: (genesisAddress)
  - genesisAddress: OpenWork Genesis Proxy address from 2.1

Note: Helper contract for batch reading data from Genesis contracts.
```

#### 2.4 Deploy Native DAO
```
Step 1: Deploy NativeDAO implementation
Step 2: Prepare init data: initialize(owner, bridge, genesis)
  - owner: Timelock or multisig
  - bridge: Zero address initially, update after bridge deployment
  - genesis: OpenWork Genesis Proxy address from 2.1
Step 3: Deploy UUPSProxy with implementation + init data
Result: Native DAO Proxy address
```

#### 2.5 Deploy Native Rewards
```
Step 1: Deploy NativeRewards implementation
Step 2: Prepare init data: initialize(owner, nowjContract, genesis)
  - owner: Multisig
  - nowjContract: Zero address initially, update later
  - genesis: OpenWork Genesis Proxy address from 2.1
Step 3: Deploy UUPSProxy with implementation + init data
Result: Native Rewards Proxy address
```

#### 2.6 Deploy NOWJC
```
Step 1: Deploy NOWJC implementation
Step 2: Prepare init data: initialize(owner, bridge, genesis, rewardsContract, usdtToken, cctpReceiver)
  - owner: Multisig
  - bridge: Zero address initially
  - genesis: OpenWork Genesis Proxy address from 2.1
  - rewardsContract: Native Rewards proxy from 2.5
  - usdtToken: Base USDC address (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)
  - cctpReceiver: Zero address initially, update after CCTP deployment
Step 3: Deploy UUPSProxy with implementation + init data
Result: NOWJC Proxy address
```

#### 2.7 Deploy Native Athena Oracle Manager
```
Step 1: Deploy NativeAthenaOracleManager implementation
Step 2: Prepare init data: initialize(owner, genesis, nativeAthena)
  - owner: Multisig
  - genesis: OpenWork Genesis Proxy address from 2.1
  - nativeAthena: Zero address initially, update later
Step 3: Deploy UUPSProxy with implementation + init data
Result: Oracle Manager Proxy address
```

#### 2.8 Deploy Native Athena
```
Step 1: Deploy NativeAthena implementation
Step 2: Prepare init data: initialize(owner, daoContract, genesis, nowjContract, usdcToken)
  - owner: Multisig
  - daoContract: Native DAO proxy
  - genesis: OpenWork Genesis Proxy address from 2.1
  - nowjContract: NOWJC proxy
  - usdcToken: Base USDC address
Step 3: Deploy UUPSProxy with implementation + init data
Result: Native Athena Proxy address
```

#### 2.9 Deploy Profile Manager
```
Step 1: Deploy ProfileManager implementation
Step 2: Prepare init data: initialize(owner, bridge, genesis)
  - owner: Multisig
  - bridge: Zero address initially
  - genesis: Profile Genesis Proxy address from 2.2
Step 3: Deploy UUPSProxy with implementation + init data
Result: Profile Manager Proxy address
```

#### 2.10 Deploy Native Chain Bridge
```
Contract: NativeChainBridge (OApp)
Constructor: (lzEndpoint, owner, mainChainEid)
Parameters:
  - lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c
  - owner: Multisig wallet
  - mainChainEid: 30101 (Ethereum)
```

#### 2.11 Deploy CCTP Transceiver
```
Contract: CCTPv2TransceiverWithRewardsDynamic
Constructor: (tokenMessenger, messageTransmitter, usdc)
Parameters:
  - tokenMessenger: 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962
  - messageTransmitter: 0xAD09780d193884d503182aD4588450C416D6F9D4
  - usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
```

### Phase 3: Local Chain Deployment (Repeat for EACH Local Chain)

**Chains to Deploy:** Arbitrum, Optimism, Polygon, Avalanche

#### 3.1 Deploy LOWJC (Per Local Chain)
```
Step 1: Deploy LOWJC implementation
Step 2: Prepare init data: initialize(owner, usdtToken, chainId, bridge, cctpSender)
  chainId = LayerZero EID of this chain
  Example for Arbitrum: 30110
Step 3: Deploy UUPSProxy with implementation + init data
Result: LOWJC Proxy address
```

#### 3.2 Deploy Athena Client (Per Local Chain)
```
Step 1: Deploy AthenaClient implementation
Step 2: Prepare init data: initialize(owner, usdtToken, chainId, bridge, cctpSender, nativeAthenaRecipient)
  - chainId: This chain's LayerZero EID
  - nativeAthenaRecipient: Native Athena proxy address on Base
Step 3: Deploy UUPSProxy with implementation + init data
Result: Athena Client Proxy address
```

#### 3.3 Deploy Local Bridge (Per Local Chain)
```
Contract: LocalBridge (OApp)
Constructor: (lzEndpoint, owner, nativeChainEid, mainChainEid, thisLocalChainEid)
Parameters:
  - lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c
  - owner: Multisig
  - nativeChainEid: 30184 (Base)
  - mainChainEid: 30101 (Ethereum)
  - thisLocalChainEid: This chain's EID
```

#### 3.4 Deploy CCTP Transceiver (Per Local Chain)
```
Contract: CCTPv2TransceiverWithRewardsDynamic
Constructor: (tokenMessenger, messageTransmitter, usdc)
Parameters: Chain-specific addresses (see section 2.2)
```

---

## 6. Configuration Steps

> **⚙️ CONFIGURATION COMMANDS**
>
> This section shows **conceptual configuration steps** in Solidity-style pseudo-code.
>
> **For actual cast send commands**, use the execution checklist:
> → [DEPLOYMENT_EXECUTION_CHECKLIST.md](./DEPLOYMENT_EXECUTION_CHECKLIST.md)
>
> Section 2.5, 3.13, and Phase 4 contain all configuration commands with proper sequencing.

### 6.1 Main Chain Configuration (Ethereum Mainnet)

#### Main DAO Configuration
```solidity
// 1. Set token address (if not in initialize)
mainDAO.setTokenAddress(openworkTokenAddress);

// 2. Configure governance parameters
mainDAO.updateProposalStakeThreshold(100 * 10**18);
mainDAO.updateVotingStakeThreshold(50 * 10**18);

// 3. Set bridge for cross-chain governance
mainDAO.setBridge(mainChainBridgeAddress);

// 4. Transfer ownership to timelock
mainDAO.transferOwnership(timelockAddress);
```

#### Main Rewards Configuration
```solidity
// 1. Set DAO contract
mainRewards.setDAOContract(mainDAOAddress);

// 2. Verify reward bands are initialized
uint256 bandCount = mainRewards.getRewardBandsCount();
// Should be 20 bands

// 3. Transfer ownership to governance
mainRewards.transferOwnership(timelockAddress);
```

#### Main Chain Bridge Configuration
```solidity
// 1. Authorize contracts to use bridge
mainChainBridge.authorizeContract(mainDAOAddress, true);
mainChainBridge.authorizeContract(mainRewardsAddress, true);

// 2. Set Native Chain EID (Base)
mainChainBridge.updateNativeChainEid(30184);

// 3. Configure LayerZero peer (Native Chain)
mainChainBridge.setPeer(30184, addressToBytes32(nativeChainBridgeAddress));

// 4. Set gas limits and options (optional)
// Configure appropriate gas limits for cross-chain messages
```

### 6.2 Native Chain Configuration (Base Mainnet)

#### Native DAO Configuration
```solidity
// 1. Set NOWJC contract
nativeDAO.setNOWJContract(nowjcProxyAddress);

// 2. Set bridge
nativeDAO.setBridge(nativeBridgeAddress);

// 3. Set genesis
nativeDAO.setGenesis(genesisAddress);

// 4. Configure thresholds
nativeDAO.updateProposalStakeThreshold(100 * 10**18);
nativeDAO.updateVotingStakeThreshold(50 * 10**18);
nativeDAO.updateProposalRewardThreshold(100 * 10**18);
nativeDAO.updateVotingRewardThreshold(100 * 10**18);

// 5. Transfer ownership to timelock
nativeDAO.transferOwnership(timelockAddress);
```

#### Native Rewards Configuration
```solidity
// 1. Update NOWJC contract reference
nativeRewards.setJobContract(nowjcProxyAddress);

// 2. Set genesis
nativeRewards.setGenesis(genesisAddress);

// 3. Set profile genesis for referrals
nativeRewards.setProfileGenesis(profileGenesisAddress);

// 4. Verify reward bands
uint256 bandCount = nativeRewards.getRewardBandsCount();
// Should be 20 bands

// 5. Transfer ownership to multisig/timelock
nativeRewards.transferOwnership(multisigAddress);
```

#### NOWJC Configuration
```solidity
// 1. Set bridge
nowjc.setBridge(nativeBridgeAddress);

// 2. Set genesis
nowjc.setGenesis(genesisAddress);

// 3. Set rewards contract
nowjc.setRewardsContract(nativeRewardsProxyAddress);

// 4. Set CCTP receiver (CCTP Transceiver address)
nowjc.setCCTPReceiver(cctpTransceiverAddress);

// 5. Set CCTP transceiver for cross-chain payments
nowjc.setCCTPTransceiver(cctpTransceiverAddress);

// 6. Set Native Athena for dispute resolution
nowjc.setNativeAthena(nativeAthenaProxyAddress);

// 7. Set treasury for commission
nowjc.setTreasury(treasuryWalletAddress);

// 8. Configure commission
nowjc.setCommissionPercentage(100); // 1% = 100 basis points
nowjc.setMinCommission(1e6); // 1 USDC

// 9. Authorize Native Athena for fund release
nowjc.addAuthorizedContract(nativeAthenaProxyAddress);

// 10. Transfer ownership to multisig
nowjc.transferOwnership(multisigAddress);
```

#### Native Athena Configuration
```solidity
// 1. Set genesis
nativeAthena.setGenesis(genesisAddress);

// 2. Set NOWJC contract
nativeAthena.setNOWJContract(nowjcProxyAddress);

// 3. Set Oracle Manager
nativeAthena.setOracleManager(oracleManagerProxyAddress);

// 4. Set DAO contract
nativeAthena.setDAOContract(nativeDAOProxyAddress);

// 5. Set USDC token
nativeAthena.setUSDCToken(baseUSDCAddress);

// 6. Set bridge
nativeAthena.setBridge(nativeBridgeAddress);

// 7. Configure governance parameters
nativeAthena.updateMinOracleMembers(3);
nativeAthena.updateVotingPeriod(60); // 60 minutes
nativeAthena.updateMinStakeRequired(100);
nativeAthena.updateMemberActivityThreshold(90); // 90 days

// 8. Transfer ownership to multisig
nativeAthena.transferOwnership(multisigAddress);
```

#### Native Athena Oracle Manager Configuration
```solidity
// 1. Set genesis
oracleManager.setGenesis(genesisAddress);

// 2. Set Native Athena
oracleManager.setNativeAthena(nativeAthenaProxyAddress);

// 3. Authorize Native Athena to manage oracles
oracleManager.setAuthorizedCaller(nativeAthenaProxyAddress, true);

// 4. Transfer ownership to multisig
oracleManager.transferOwnership(multisigAddress);
```

#### Profile Manager Configuration
```solidity
// 1. Set bridge
profileManager.setBridge(nativeBridgeAddress);

// 2. Set genesis
profileManager.setGenesis(profileGenesisAddress);

// 3. Transfer ownership to multisig
profileManager.transferOwnership(multisigAddress);
```

#### Native Chain Bridge Configuration
```solidity
// 1. Authorize contracts
nativeBridge.authorizeContract(nativeDAOProxyAddress, true);
nativeBridge.authorizeContract(nowjcProxyAddress, true);
nativeBridge.authorizeContract(nativeAthenaProxyAddress, true);
nativeBridge.authorizeContract(profileManagerProxyAddress, true);

// 2. Set contract addresses for routing
nativeBridge.setNativeDaoContract(nativeDAOProxyAddress);
nativeBridge.setNativeAthenaContract(nativeAthenaProxyAddress);
nativeBridge.setNativeOpenWorkJobContract(nowjcProxyAddress);
nativeBridge.setProfileManager(profileManagerProxyAddress);

// 3. Set chain EIDs
nativeBridge.updateMainChainEid(30101); // Ethereum

// 4. Add all local chains
nativeBridge.addLocalChain(30110); // Arbitrum
nativeBridge.addLocalChain(30111); // Optimism
nativeBridge.addLocalChain(30109); // Polygon
nativeBridge.addLocalChain(30106); // Avalanche

// 5. Configure LayerZero peers
nativeBridge.setPeer(30101, addressToBytes32(mainChainBridgeAddress)); // Ethereum
nativeBridge.setPeer(30110, addressToBytes32(arbitrumLocalBridgeAddress)); // Arbitrum
nativeBridge.setPeer(30111, addressToBytes32(optimismLocalBridgeAddress)); // Optimism
nativeBridge.setPeer(30109, addressToBytes32(polygonLocalBridgeAddress)); // Polygon
nativeBridge.setPeer(30106, addressToBytes32(avalancheLocalBridgeAddress)); // Avalanche

// 6. Transfer ownership to multisig
nativeBridge.transferOwnership(multisigAddress);
```

#### CCTP Transceiver Configuration
```solidity
// 1. Fund reward pool (important for mainnet!)
cctpTransceiver.fundRewardPool{value: 10 ether}(); // Adjust based on expected volume

// 2. Configure reward parameters
cctpTransceiver.setMaxRewardAmount(0.001 ether); // Cap at 0.001 ETH
cctpTransceiver.setEstimatedGasUsage(200000); // Estimated gas for receive()
cctpTransceiver.setRewardMultiplier(2); // 2x gas cost

// 3. Transfer ownership to multisig
cctpTransceiver.transferOwnership(multisigAddress);
```

### 6.3 Local Chain Configuration (Per Chain)

**Repeat for each local chain: Arbitrum, Optimism, Polygon, Avalanche**

#### LOWJC Configuration
```solidity
// 1. Set bridge
lowjc.setBridge(localBridgeAddress);

// 2. Set CCTP sender (CCTP Transceiver address)
lowjc.setCCTPSender(cctpTransceiverAddress);

// 3. Set CCTP mint recipient (NOWJC on Base)
lowjc.setCCTPMintRecipient(nowjcProxyAddressOnBase);

// 4. Set Athena Client for dispute resolution
lowjc.setAthenaClientContract(athenaClientProxyAddress);

// 5. Set USDT token (actually USDC)
lowjc.setUSDTToken(chainSpecificUSDCAddress);

// 6. Transfer ownership to multisig
lowjc.transferOwnership(multisigAddress);
```

#### Athena Client Configuration
```solidity
// 1. Set bridge
athenaClient.setBridge(localBridgeAddress);

// 2. Set job contract
athenaClient.setJobContract(lowjcProxyAddress);

// 3. Set CCTP sender
athenaClient.setCCTPSender(cctpTransceiverAddress);

// 4. Set native Athena recipient (Native Athena on Base)
athenaClient.setNativeAthenaRecipient(nativeAthenaProxyAddressOnBase);

// 5. Set native chain domain (Base = 6)
athenaClient.setNativeChainDomain(6);

// 6. Set minimum dispute fee
athenaClient.setMinDisputeFee(50 * 10**6); // 50 USDC

// 7. Transfer ownership to multisig
athenaClient.transferOwnership(multisigAddress);
```

#### Local Bridge Configuration
```solidity
// 1. Authorize contracts
localBridge.authorizeContract(lowjcProxyAddress, true);
localBridge.authorizeContract(athenaClientProxyAddress, true);

// 2. Set contract addresses
localBridge.setAthenaClientContract(athenaClientProxyAddress);
localBridge.setLowjcContract(lowjcProxyAddress);

// 3. Verify chain EIDs (set in constructor)
// nativeChainEid: 30184 (Base)
// mainChainEid: 30101 (Ethereum)
// thisLocalChainEid: This chain's EID

// 4. Configure LayerZero peers
localBridge.setPeer(30184, addressToBytes32(nativeChainBridgeAddress)); // Base
localBridge.setPeer(30101, addressToBytes32(mainChainBridgeAddress)); // Ethereum

// 5. Transfer ownership to multisig
localBridge.transferOwnership(multisigAddress);
```

#### CCTP Transceiver Configuration
```solidity
// 1. Fund reward pool
cctpTransceiver.fundRewardPool{value: 5 ether}(); // Adjust based on chain

// 2. Configure reward parameters
cctpTransceiver.setMaxRewardAmount(0.001 ether);
cctpTransceiver.setEstimatedGasUsage(200000);
cctpTransceiver.setRewardMultiplier(2);

// 3. Transfer ownership to multisig
cctpTransceiver.transferOwnership(multisigAddress);
```

---

## 7. Cross-Chain Integration

> **🔗 CROSS-CHAIN SETUP**
>
> This section explains **how cross-chain connections work conceptually**.
>
> **For actual setPeer commands (all bidirectional pairs)**, see:
> → [DEPLOYMENT_EXECUTION_CHECKLIST.md](./DEPLOYMENT_EXECUTION_CHECKLIST.md) - Section 5.1
>
> The checklist includes all LayerZero peer configurations in the correct order.

### 7.1 LayerZero Peer Configuration Summary

All bridges must be configured to recognize each other as trusted peers. Use the `addressToBytes32()` helper function for address conversion.

#### Main Chain Bridge (Ethereum) Peers
```solidity
// Ethereum → Base
mainChainBridge.setPeer(30184, addressToBytes32(nativeChainBridgeAddress));
```

#### Native Chain Bridge (Base) Peers
```solidity
// Base → Ethereum
nativeBridge.setPeer(30101, addressToBytes32(mainChainBridgeAddress));

// Base → All Local Chains
nativeBridge.setPeer(30110, addressToBytes32(arbitrumLocalBridgeAddress));
nativeBridge.setPeer(30111, addressToBytes32(optimismLocalBridgeAddress));
nativeBridge.setPeer(30109, addressToBytes32(polygonLocalBridgeAddress));
nativeBridge.setPeer(30106, addressToBytes32(avalancheLocalBridgeAddress));
```

#### Local Chain Bridges Peers (Each)
```solidity
// Local → Base
localBridge.setPeer(30184, addressToBytes32(nativeChainBridgeAddress));

// Local → Ethereum
localBridge.setPeer(30101, addressToBytes32(mainChainBridgeAddress));
```

### 7.2 CCTP Integration

#### Payment Flow: Local Chain → Base
1. **User deposits USDC** to LOWJC on local chain
2. **LOWJC** approves and calls CCTP Transceiver `sendFast()`
3. **CCTP Transceiver** burns USDC and emits CCTP message
4. **Off-chain relayer** attests and relays message to Base
5. **CCTP Receiver** on Base mints USDC to NOWJC
6. **NOWJC** receives USDC and processes job payment

#### Fee Flow: Local Chain → Base
1. **User pays dispute fee** to Athena Client on local chain
2. **Athena Client** routes fee through CCTP to Native Athena on Base
3. **Native Athena** receives fee and processes dispute
4. **After voting**, fees distributed to winning voters

### 7.3 Chain-Specific Notes

#### Polygon (Different USDC)
- Polygon uses USDC.e (bridged) and native USDC
- Use native USDC address: `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`

---

## 8. Verification Checklist

### 8.1 Main Chain (Ethereum Mainnet)
- [ ] OpenWork Token deployed and initial supply verified
- [ ] Token contract ownership transferred to multisig/timelock
- [ ] Main DAO proxy deployed with correct implementation
- [ ] Main DAO initialized with correct parameters
- [ ] Main DAO ownership transferred to timelock
- [ ] Main Rewards proxy deployed with correct implementation
- [ ] Main Rewards initialized correctly
- [ ] Main Rewards ownership transferred to timelock
- [ ] Main Chain Bridge deployed
- [ ] Bridge authorized by DAO and Rewards
- [ ] Native Chain peer configured on bridge (Base EID: 30184)
- [ ] Bridge ownership transferred to multisig
- [ ] Test proposal creation on Main DAO (post-timelock)
- [ ] Test voting on Main DAO
- [ ] Verify on Etherscan

### 8.2 Native Chain (Base Mainnet)
- [ ] OpenWork Genesis deployed
- [ ] Profile Genesis deployed
- [ ] Genesis Reader Helper deployed
- [ ] Native DAO proxy deployed and initialized
- [ ] Native Rewards proxy deployed and initialized
- [ ] NOWJC proxy deployed and initialized
- [ ] Native Athena Oracle Manager deployed and initialized
- [ ] Native Athena proxy deployed and initialized
- [ ] Profile Manager proxy deployed and initialized
- [ ] Native Chain Bridge deployed
- [ ] CCTP Transceiver deployed and funded
- [ ] All contract cross-references configured
- [ ] Bridge peers configured (Main + All Local Chains)
- [ ] Bridge authorized by all native contracts
- [ ] CCTP funding pool has sufficient balance
- [ ] All ownerships transferred to multisig
- [ ] Test job posting from local chain
- [ ] Test dispute raising
- [ ] Test profile creation
- [ ] Verify on Basescan

### 8.3 Local Chains Verification (Per Chain)

#### Arbitrum Mainnet
- [ ] LOWJC proxy deployed and initialized
- [ ] Athena Client proxy deployed and initialized
- [ ] Local Bridge deployed
- [ ] CCTP Transceiver deployed and funded
- [ ] Bridge peers configured (Base + Ethereum)
- [ ] Bridge authorized by LOWJC and Athena Client
- [ ] CCTP mint recipients configured
- [ ] All ownerships transferred to multisig
- [ ] Test job posting
- [ ] Test cross-chain application
- [ ] Test payment release via CCTP
- [ ] Test dispute initiation
- [ ] Verify on Arbiscan

#### Optimism Mainnet
- [ ] LOWJC proxy deployed and initialized
- [ ] Athena Client proxy deployed and initialized
- [ ] Local Bridge deployed
- [ ] CCTP Transceiver deployed and funded
- [ ] Bridge peers configured (Base + Ethereum)
- [ ] Bridge authorized by LOWJC and Athena Client
- [ ] CCTP mint recipients configured
- [ ] All ownerships transferred to multisig
- [ ] Test job posting
- [ ] Test cross-chain application
- [ ] Test payment release via CCTP
- [ ] Test dispute initiation
- [ ] Verify on Optimistic Etherscan

#### Polygon Mainnet
- [ ] LOWJC proxy deployed and initialized
- [ ] Athena Client proxy deployed and initialized
- [ ] Local Bridge deployed
- [ ] CCTP Transceiver deployed and funded
- [ ] Bridge peers configured (Base + Ethereum)
- [ ] Bridge authorized by LOWJC and Athena Client
- [ ] CCTP mint recipients configured (using native USDC)
- [ ] All ownerships transferred to multisig
- [ ] Test job posting
- [ ] Test cross-chain application
- [ ] Test payment release via CCTP
- [ ] Test dispute initiation
- [ ] Verify on Polygonscan

#### Avalanche Mainnet
- [ ] LOWJC proxy deployed and initialized
- [ ] Athena Client proxy deployed and initialized
- [ ] Local Bridge deployed
- [ ] CCTP Transceiver deployed and funded
- [ ] Bridge peers configured (Base + Ethereum)
- [ ] Bridge authorized by LOWJC and Athena Client
- [ ] CCTP mint recipients configured
- [ ] All ownerships transferred to multisig
- [ ] Test job posting
- [ ] Test cross-chain application
- [ ] Test payment release via CCTP
- [ ] Test dispute initiation
- [ ] Verify on Snowtrace

### 8.4 Cross-Chain Integration Tests
- [ ] Test LayerZero message from Ethereum → Base
- [ ] Test LayerZero message from Base → Ethereum
- [ ] Test LayerZero message from each Local Chain → Base
- [ ] Test LayerZero message from Base → each Local Chain
- [ ] Test CCTP transfer from Arbitrum → Base
- [ ] Test CCTP transfer from Optimism → Base
- [ ] Test CCTP transfer from Polygon → Base
- [ ] Test CCTP transfer from Avalanche → Base
- [ ] Test full job cycle across chains (post → apply → start → pay)
- [ ] Test profile creation propagation
- [ ] Test governance action sync
- [ ] Test reward calculation sync
- [ ] Test dispute resolution flow
- [ ] Test cross-chain payment release with CCTP
- [ ] Test gas cost estimates for all cross-chain operations
- [ ] Monitor LayerZero message delivery times
- [ ] Monitor CCTP attestation times

---

## 9. Mainnet Deployment Best Practices

### 9.1 Pre-Deployment
1. **Complete Security Audits:** Ensure all contracts are audited by reputable firms
2. **Bug Bounty Program:** Launch bug bounty before mainnet deployment
3. **Testnet Testing:** Thorough testing on all testnets for at least 2-4 weeks
4. **Emergency Procedures:** Document emergency pause and upgrade procedures
5. **Multisig Setup:** Use at least 3/5 or 4/7 multisig for all administrative functions
6. **Timelock Configuration:** Set appropriate delays (24-48 hours) for governance actions

### 9.2 Deployment Strategy
1. **Phased Rollout:** Deploy to one local chain first, validate, then expand
2. **Gas Price Monitoring:** Deploy during low gas periods on Ethereum
3. **Transaction Nonce Management:** Track nonces carefully across chains
4. **Deployment Scripts:** Use deterministic deployment addresses where possible
5. **Address Book:** Maintain comprehensive address registry

### 9.3 Post-Deployment
1. **Ownership Transfer:** Transfer all ownerships to multisig/timelock immediately
2. **Contract Verification:** Verify all contracts on block explorers
3. **Monitoring Setup:** Set up monitoring for all contracts and bridges
4. **Rate Limiting:** Consider implementing rate limits on cross-chain functions
5. **User Communication:** Announce deployment with clear documentation

### 9.4 Mainnet Security Considerations
- **Gas Limits:** Set appropriate gas limits for cross-chain messages
- **Slippage Protection:** Implement slippage checks for CCTP transfers
- **Replay Protection:** Ensure proper replay protection on all chains
- **Oracle Prices:** If using price feeds, use reliable oracles
- **Emergency Pause:** Ensure pause mechanisms are accessible but secure
- **Upgrade Paths:** Document clear upgrade procedures via governance

---

## 10. Deployment Scripts Recommendations

### 10.1 Script Organization
```
/scripts
  /deploy
    /mainnet
      /ethereum
        - 01-deploy-token.ts
        - 02-deploy-dao.ts
        - 03-deploy-rewards.ts
        - 04-deploy-bridge.ts
        - 05-configure.ts
      /base
        - 01-deploy-genesis.ts
        - 02-deploy-dao.ts
        - 03-deploy-rewards.ts
        - 04-deploy-nowjc.ts
        - 05-deploy-athena.ts
        - 06-deploy-profile-manager.ts
        - 07-deploy-bridge.ts
        - 08-deploy-cctp.ts
        - 09-configure.ts
      /local-chains
        /arbitrum
          - 01-deploy-contracts.ts
          - 02-configure.ts
        /optimism
          - 01-deploy-contracts.ts
          - 02-configure.ts
        /polygon
          - 01-deploy-contracts.ts
          - 02-configure.ts
        /avalanche
          - 01-deploy-contracts.ts
          - 02-configure.ts
  /config
    - mainnet-addresses.json
    - cross-chain-setup.ts
  /test
    - mainnet-integration-tests.ts
  /verify
    - verify-all-contracts.ts
```

### 10.2 Mainnet Environment Variables
```bash
# Main Chain (Ethereum Mainnet)
ETHEREUM_MAINNET_RPC=
ETHEREUM_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
ETHEREUM_DEPLOYER_PRIVATE_KEY=
ETHEREUM_MULTISIG_ADDRESS=
ETHEREUM_TIMELOCK_ADDRESS=

# Native Chain (Base Mainnet)
BASE_MAINNET_RPC=
BASE_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
BASE_USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
BASE_CCTP_MESSENGER=0x1682Ae6375C4E4A97e4B583BC394c861A46D8962
BASE_CCTP_TRANSMITTER=0xAD09780d193884d503182aD4588450C416D6F9D4
BASE_DEPLOYER_PRIVATE_KEY=
BASE_MULTISIG_ADDRESS=

# Arbitrum Mainnet
ARBITRUM_MAINNET_RPC=
ARBITRUM_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
ARBITRUM_USDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
ARBITRUM_CCTP_MESSENGER=0x19330d10D9Cc8751218eaf51E8885D058642E08A
ARBITRUM_CCTP_TRANSMITTER=0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca
ARBITRUM_DEPLOYER_PRIVATE_KEY=
ARBITRUM_MULTISIG_ADDRESS=

# Optimism Mainnet
OPTIMISM_MAINNET_RPC=
OPTIMISM_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
OPTIMISM_USDC=0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85
OPTIMISM_CCTP_MESSENGER=0x2B4069517957735bE00ceE0fadAE88a26365528f
OPTIMISM_CCTP_TRANSMITTER=0x4D41f22c5a0e5c74090899E5a8Fb597a8842b3e8
OPTIMISM_DEPLOYER_PRIVATE_KEY=
OPTIMISM_MULTISIG_ADDRESS=

# Polygon Mainnet
POLYGON_MAINNET_RPC=
POLYGON_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
POLYGON_USDC=0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
POLYGON_CCTP_MESSENGER=0x9daF8c91AEFAE50b9c0E69629D3F6Ca40cA3B3FE
POLYGON_CCTP_TRANSMITTER=0xF3be9355363857F3e001be68856A2f96b4C39Ba9
POLYGON_DEPLOYER_PRIVATE_KEY=
POLYGON_MULTISIG_ADDRESS=

# Avalanche Mainnet
AVALANCHE_MAINNET_RPC=
AVALANCHE_LZ_ENDPOINT=0x1a44076050125825900e736c501f859c50fE728c
AVALANCHE_USDC=0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E
AVALANCHE_CCTP_MESSENGER=0x6B25532e1060CE10cc3B0A99e5683b91BFDe6982
AVALANCHE_CCTP_TRANSMITTER=0x8186359aF5F57FbB40c6b14A588d2A59C0C29880
AVALANCHE_DEPLOYER_PRIVATE_KEY=
AVALANCHE_MULTISIG_ADDRESS=

# Chain EIDs (Mainnet)
ETHEREUM_EID=30101
BASE_EID=30184
ARBITRUM_EID=30110
OPTIMISM_EID=30111
POLYGON_EID=30109
AVALANCHE_EID=30106

# CCTP Domains (Mainnet)
ETHEREUM_CCTP_DOMAIN=0
BASE_CCTP_DOMAIN=6
ARBITRUM_CCTP_DOMAIN=3
OPTIMISM_CCTP_DOMAIN=2
POLYGON_CCTP_DOMAIN=7
AVALANCHE_CCTP_DOMAIN=1

# Security
BLOCK_EXPLORER_API_KEYS=
MAINNET_GAS_PRICE_LIMIT=100 # In gwei
```

---

## 11. Post-Deployment Actions

### 11.1 Immediate Actions
1. **Verify All Contracts:** Submit source code to all block explorers
2. **Transfer Ownerships:** Move all admin controls to multisig/timelock
3. **Fund CCTP Transceivers:** Ensure sufficient ETH for rewards
4. **Document Addresses:** Publish comprehensive address list
5. **Test End-to-End:** Run complete integration tests on mainnet
6. **Enable Monitoring:** Set up alerts and monitoring dashboards

### 11.2 Communication
- [ ] Publish deployment announcement
- [ ] Update documentation with mainnet addresses
- [ ] Create user guides for each chain
- [ ] Announce on social media and forums
- [ ] Prepare customer support materials

### 11.3 Ongoing Maintenance
- [ ] Monitor bridge activity and gas costs
- [ ] Track CCTP transfer times and success rates
- [ ] Monitor contract balances and treasury
- [ ] Review and respond to user feedback
- [ ] Plan for upgrades via governance

---

## Appendix A: Mainnet Contract Addresses Template

```json
{
  "ethereum": {
    "chainId": 1,
    "lzEid": 30101,
    "contracts": {
      "openworkToken": "",
      "mainDAO": {
        "implementation": "",
        "proxy": ""
      },
      "mainRewards": {
        "implementation": "",
        "proxy": ""
      },
      "mainChainBridge": "",
      "timelock": "",
      "multisig": ""
    }
  },
  "base": {
    "chainId": 8453,
    "lzEid": 30184,
    "cctpDomain": 6,
    "contracts": {
      "openworkGenesis": "",
      "profileGenesis": "",
      "genesisReaderHelper": "",
      "nativeDAO": {
        "implementation": "",
        "proxy": ""
      },
      "nativeRewards": {
        "implementation": "",
        "proxy": ""
      },
      "nowjc": {
        "implementation": "",
        "proxy": ""
      },
      "nativeAthena": {
        "implementation": "",
        "proxy": ""
      },
      "nativeAthenaOracleManager": {
        "implementation": "",
        "proxy": ""
      },
      "profileManager": {
        "implementation": "",
        "proxy": ""
      },
      "nativeChainBridge": "",
      "cctpTransceiver": "",
      "multisig": ""
    }
  },
  "arbitrum": {
    "chainId": 42161,
    "lzEid": 30110,
    "cctpDomain": 3,
    "contracts": {
      "lowjc": {
        "implementation": "",
        "proxy": ""
      },
      "athenaClient": {
        "implementation": "",
        "proxy": ""
      },
      "localBridge": "",
      "cctpTransceiver": "",
      "multisig": ""
    }
  },
  "optimism": {
    "chainId": 10,
    "lzEid": 30111,
    "cctpDomain": 2,
    "contracts": {
      "lowjc": {
        "implementation": "",
        "proxy": ""
      },
      "athenaClient": {
        "implementation": "",
        "proxy": ""
      },
      "localBridge": "",
      "cctpTransceiver": "",
      "multisig": ""
    }
  },
  "polygon": {
    "chainId": 137,
    "lzEid": 30109,
    "cctpDomain": 7,
    "contracts": {
      "lowjc": {
        "implementation": "",
        "proxy": ""
      },
      "athenaClient": {
        "implementation": "",
        "proxy": ""
      },
      "localBridge": "",
      "cctpTransceiver": "",
      "multisig": ""
    }
  },
  "avalanche": {
    "chainId": 43114,
    "lzEid": 30106,
    "cctpDomain": 1,
    "contracts": {
      "lowjc": {
        "implementation": "",
        "proxy": ""
      },
      "athenaClient": {
        "implementation": "",
        "proxy": ""
      },
      "localBridge": "",
      "cctpTransceiver": "",
      "multisig": ""
    }
  }
}
```

---

## Appendix B: Emergency Procedures

### Pause Mechanism
If critical issues are detected:

1. **Main Chain:** Pause via multisig governance proposal
2. **Native Chain:** Pause NOWJC, Native Athena via multisig
3. **Local Chains:** Pause LOWJC, Athena Client via multisig
4. **Bridges:** Only LayerZero can pause (contact LayerZero team)

### Upgrade Procedure (via Governance)
1. Deploy new implementation contract
2. Create governance proposal to upgrade
3. Wait for timelock delay
4. Execute upgrade transaction
5. Verify upgrade successful
6. Test upgraded functionality

### Emergency Contact List
- LayerZero Support: [support contact]
- Circle CCTP Support: [support contact]
- Security Team: [contact]
- Community Discord: [link]

---

**End of Mainnet Deployment Plan**

This document provides a comprehensive guide for deploying the OpenWork multichain system on production mainnet. Follow each phase sequentially, verify thoroughly at each step, and prioritize security throughout the deployment process.

**CRITICAL REMINDER:** Mainnet deployment is irreversible. Triple-check all addresses, parameters, and configurations before execution. Use testnet deployments to practice the entire deployment process before mainnet.
