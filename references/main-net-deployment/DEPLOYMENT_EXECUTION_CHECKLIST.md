# OpenWork Multichain System - Deployment Execution Checklist

**Version:** 26-Dec-2025 (Mainnet)
**Document Date:** 28-Dec-2025
**Network:** Production Mainnet

---

## Purpose

This document provides a complete execution checklist for deploying the OpenWork multichain system from scratch. Each command must be run in order, and addresses must be recorded as they are deployed.

**⚡ Template-Based Approach:**
- **Main Chain & Native Chain:** Full step-by-step commands provided
- **Local Chains:** Template commands shown for ONE chain (Arbitrum)
- **Replication:** Simply replace chain-specific variables (ARBITRUM → OPTIMISM/POLYGON/AVALANCHE) to deploy on other chains
- This reduces document length while maintaining completeness

**Related Documents:**
- [OPENWORK_MULTICHAIN_DEPLOYMENT_PLAN.md](./OPENWORK_MULTICHAIN_DEPLOYMENT_PLAN.md) - Conceptual deployment guide
- [DEPLOYMENT_COMMAND_TEMPLATES.md](./DEPLOYMENT_COMMAND_TEMPLATES.md) - Command templates reference

---

## Table of Contents

0. [⚠️ CRITICAL: Documentation & Logging](#critical-documentation--logging) **READ FIRST**
1. [Pre-Deployment Setup](#1-pre-deployment-setup)
2. [Phase 1: Main Chain (Ethereum Mainnet)](#2-phase-1-main-chain-ethereum-mainnet)
3. [Phase 2: Native Chain (Base Mainnet)](#3-phase-2-native-chain-base-mainnet)
4. [Phase 3: Local Chain (Template - Replicate for All)](#4-phase-3-local-chain-template---replicate-for-all)
5. [Phase 4: Cross-Chain Configuration](#5-phase-4-cross-chain-configuration)
6. [Phase 5: Final Verification](#6-phase-5-final-verification)
7. [Post-Deployment: Finalize Documentation](#7-post-deployment-finalize-documentation)

---

## ⚠️ CRITICAL: Documentation & Logging

Before starting deployment, set up proper documentation:

### Create Deployment Log File

Create a log file to record EVERYTHING:

```bash
# Create timestamped deployment log
export DEPLOYMENT_LOG="deployment-log-$(date +%Y-%m-%d-%H%M%S).md"
touch $DEPLOYMENT_LOG

# Add header
cat > $DEPLOYMENT_LOG << 'EOF'
# OpenWork Mainnet Deployment Log
**Date:** $(date)
**Deployer:** [Your Name/Team]
**Network:** Production Mainnet

---

## Deployment Session

### Environment
- Ethereum RPC: [redacted]
- Base RPC: [redacted]
- Deployer Address: [record here]

### Commands & Outputs

EOF
```

### Documentation Requirements

**✅ YOU MUST:**

1. **Record EVERY Command** - Copy each command before running it:
   ```bash
   echo "### Command: Deploy OpenWork Token" >> $DEPLOYMENT_LOG
   echo '```bash' >> $DEPLOYMENT_LOG
   echo "forge create --broadcast ..." >> $DEPLOYMENT_LOG
   echo '```' >> $DEPLOYMENT_LOG
   ```

2. **Record EVERY Output** - Capture the output:
   ```bash
   forge create ... 2>&1 | tee -a $DEPLOYMENT_LOG
   ```

3. **Record EVERY Address** - Document deployed addresses:
   ```bash
   echo "**Deployed Address:** 0x..." >> $DEPLOYMENT_LOG
   echo "**Transaction Hash:** 0x..." >> $DEPLOYMENT_LOG
   echo "**Block Number:** ..." >> $DEPLOYMENT_LOG
   echo "" >> $DEPLOYMENT_LOG
   ```

4. **Create Contract Address Document**:
   ```bash
   # Create separate address registry
   cat > deployed-contracts-$(date +%Y-%m-%d).json << 'EOF'
   {
     "deployment_date": "YYYY-MM-DD",
     "network": "mainnet",
     "chains": {
       "ethereum": {
         "openwork_token": "0x...",
         "main_dao_impl": "0x...",
         "main_dao_proxy": "0x...",
         "main_rewards_impl": "0x...",
         "main_rewards_proxy": "0x...",
         "main_bridge": "0x..."
       },
       "base": {
         "openwork_genesis_impl": "0x...",
         "openwork_genesis_proxy": "0x...",
         "profile_genesis_impl": "0x...",
         "profile_genesis_proxy": "0x...",
         "native_dao_impl": "0x...",
         "native_dao_proxy": "0x...",
         "native_rewards_impl": "0x...",
         "native_rewards_proxy": "0x...",
         "nowjc_impl": "0x...",
         "nowjc_proxy": "0x...",
         "native_athena_impl": "0x...",
         "native_athena_proxy": "0x...",
         "oracle_manager_impl": "0x...",
         "oracle_manager_proxy": "0x...",
         "profile_manager_impl": "0x...",
         "profile_manager_proxy": "0x...",
         "direct_contract_manager": "0x...",
         "native_bridge": "0x...",
         "cctp_transceiver": "0x...",
         "genesis_reader": "0x..."
       },
       "arbitrum": {
         "lowjc_impl": "0x...",
         "lowjc_proxy": "0x...",
         "athena_client_impl": "0x...",
         "athena_client_proxy": "0x...",
         "local_bridge": "0x...",
         "cctp_transceiver": "0x...",
         "genesis_reader": "0x..."
       }
     }
   }
   EOF
   ```

### Quick Logging Helper Functions

Add these to your shell session:

```bash
# Log a command
log_cmd() {
  echo "" >> $DEPLOYMENT_LOG
  echo "### $1" >> $DEPLOYMENT_LOG
  echo '```bash' >> $DEPLOYMENT_LOG
  echo "$2" >> $DEPLOYMENT_LOG
  echo '```' >> $DEPLOYMENT_LOG
}

# Log output
log_output() {
  echo "" >> $DEPLOYMENT_LOG
  echo "**Output:**" >> $DEPLOYMENT_LOG
  echo '```' >> $DEPLOYMENT_LOG
  echo "$1" >> $DEPLOYMENT_LOG
  echo '```' >> $DEPLOYMENT_LOG
}

# Log deployed address
log_address() {
  echo "" >> $DEPLOYMENT_LOG
  echo "**Deployed $1:**" >> $DEPLOYMENT_LOG
  echo "- Address: \`$2\`" >> $DEPLOYMENT_LOG
  echo "- TX Hash: \`$3\`" >> $DEPLOYMENT_LOG
  echo "- Block: \`$4\`" >> $DEPLOYMENT_LOG
}

# Example usage:
# OUTPUT=$(forge create ... 2>&1)
# echo "$OUTPUT"
# log_cmd "Deploy OpenWork Token" "forge create ..."
# log_output "$OUTPUT"
# log_address "OpenWork Token" "0x123..." "0xabc..." "12345"
```

### Why This Matters

- **Recovery:** If deployment fails mid-way, you can resume
- **Verification:** Block explorers can verify using exact commands
- **Audit Trail:** Complete record for security audits
- **Troubleshooting:** Debug issues with full context
- **Documentation:** Future reference for upgrades
- **Team Communication:** Share exact deployment state

**🚨 DO NOT SKIP THIS STEP - Mainnet deployment without logs is extremely risky!**

---

## 1. Pre-Deployment Setup

### 1.1 Environment Variables

```bash
# RPC URLs
export ETHEREUM_MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export BASE_MAINNET_RPC_URL="https://base-mainnet.g.alchemy.com/v2/YOUR_KEY"
export ARBITRUM_MAINNET_RPC_URL="https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY"
export OPTIMISM_MAINNET_RPC_URL="https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY"
export POLYGON_MAINNET_RPC_URL="https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"
export AVALANCHE_MAINNET_RPC_URL="https://api.avax.network/ext/bc/C/rpc"

# Deployer private key
export DEPLOYER_PRIVATE_KEY="0xYourPrivateKey"

# Multisig addresses
export ETHEREUM_MULTISIG="0xYourEthereumMultisigAddress"
export BASE_MULTISIG="0xYourBaseMultisigAddress"
export ARBITRUM_MULTISIG="0xYourArbitrumMultisigAddress"
export OPTIMISM_MULTISIG="0xYourOptimismMultisigAddress"
export POLYGON_MULTISIG="0xYourPolygonMultisigAddress"
export AVALANCHE_MULTISIG="0xYourAvalancheMultisigAddress"

# LayerZero Universal Endpoint
export LZ_ENDPOINT="0x1a44076050125825900e736c501f859c50fE728c"

# LayerZero EIDs
export ETHEREUM_EID=30101
export BASE_EID=30184
export ARBITRUM_EID=30110
export OPTIMISM_EID=30111
export POLYGON_EID=30109
export AVALANCHE_EID=30106

# CCTP Domains
export ETHEREUM_CCTP_DOMAIN=0
export BASE_CCTP_DOMAIN=6
export ARBITRUM_CCTP_DOMAIN=3
export OPTIMISM_CCTP_DOMAIN=2
export POLYGON_CCTP_DOMAIN=7
export AVALANCHE_CCTP_DOMAIN=1

# CCTP Contract Addresses - Ethereum
export ETHEREUM_TOKEN_MESSENGER="0xBd3fa81B58Ba92a82136038B25aDec7066af3155"
export ETHEREUM_MESSAGE_TRANSMITTER="0x0a992d191DEeC32aFe36203Ad87D7d289a738F81"
export ETHEREUM_USDC="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

# CCTP Contract Addresses - Base
export BASE_TOKEN_MESSENGER="0x1682Ae6375C4E4A97e4B583BC394c861A46D8962"
export BASE_MESSAGE_TRANSMITTER="0xAD09780d193884d503182aD4588450C416D6F9D4"
export BASE_USDC="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"

# CCTP Contract Addresses - Arbitrum
export ARBITRUM_TOKEN_MESSENGER="0x19330d10D9Cc8751218eaf51E8885D058642E08A"
export ARBITRUM_MESSAGE_TRANSMITTER="0xC30362313FBBA5cf9163F0bb16a0e01f01A896ca"
export ARBITRUM_USDC="0xaf88d065e77c8cC2239327C5EDb3A432268e5831"

# CCTP Contract Addresses - Optimism
export OPTIMISM_TOKEN_MESSENGER="0x2B4069517957735bE00ceE0fadAE88a26365528f"
export OPTIMISM_MESSAGE_TRANSMITTER="0x4D41f22c5a0e5c74090899E5a8Fb597a8842b3e8"
export OPTIMISM_USDC="0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"

# CCTP Contract Addresses - Polygon
export POLYGON_TOKEN_MESSENGER="0x9daF8c91AEFAE50b9c0E69629D3F6Ca40cA3B3FE"
export POLYGON_MESSAGE_TRANSMITTER="0xF3be9355363857F3e001be68856A2f96b4C39Ba9"
export POLYGON_USDC="0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"

# CCTP Contract Addresses - Avalanche
export AVALANCHE_TOKEN_MESSENGER="0x6B25532e1060CE10cc3B0A99e5683b91BFDe6982"
export AVALANCHE_MESSAGE_TRANSMITTER="0x8186359aF5F57FbB40c6b14A588d2A59C0C29880"
export AVALANCHE_USDC="0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E"
```

### 1.2 Address Tracking Variables

```bash
# Main Chain (Ethereum) - To be filled as deployed
export OPENWORK_TOKEN=""
export MAIN_DAO_IMPL=""
export MAIN_DAO_PROXY=""
export MAIN_REWARDS_IMPL=""
export MAIN_REWARDS_PROXY=""
export MAIN_BRIDGE=""

# Native Chain (Base) - To be filled as deployed
export OPENWORK_GENESIS_IMPL=""
export OPENWORK_GENESIS_PROXY=""
export PROFILE_GENESIS_IMPL=""
export PROFILE_GENESIS_PROXY=""
export NATIVE_DAO_IMPL=""
export NATIVE_DAO_PROXY=""
export NATIVE_REWARDS_IMPL=""
export NATIVE_REWARDS_PROXY=""
export NOWJC_IMPL=""
export NOWJC_PROXY=""
export NATIVE_ATHENA_IMPL=""
export NATIVE_ATHENA_PROXY=""
export ORACLE_MANAGER_IMPL=""
export ORACLE_MANAGER_PROXY=""
export PROFILE_MANAGER_IMPL=""
export PROFILE_MANAGER_PROXY=""
export DIRECT_CONTRACT_MANAGER=""
export NATIVE_BRIDGE=""
export BASE_CCTP_TRANSCEIVER=""
export BASE_GENESIS_READER=""

# Local Chains (Example: Arbitrum) - Replicate pattern for each chain
# Pattern: {CHAIN}_LOWJC_IMPL, {CHAIN}_LOWJC_PROXY, etc.
# Chains: ARBITRUM, OPTIMISM, POLYGON, AVALANCHE

export ARBITRUM_LOWJC_IMPL=""
export ARBITRUM_LOWJC_PROXY=""
export ARBITRUM_ATHENA_CLIENT_IMPL=""
export ARBITRUM_ATHENA_CLIENT_PROXY=""
export ARBITRUM_LOCAL_BRIDGE=""
export ARBITRUM_CCTP_TRANSCEIVER=""
export ARBITRUM_GENESIS_READER=""

# Repeat the above pattern for:
# - OPTIMISM_*
# - POLYGON_*
# - AVALANCHE_*
```

---

## 2. Phase 1: Main Chain (Ethereum Mainnet)

### 2.1 Deploy OpenWork Token

- [ ] **Deploy OpenWork Token**
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-token.sol:OpenWorkToken" \
  --constructor-args $ETHEREUM_MULTISIG
```

- [ ] **Record address:**
```bash
export OPENWORK_TOKEN="0x________________"
```

- [ ] **Verify deployment:**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $OPENWORK_TOKEN "owner()" | cast --to-address
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $OPENWORK_TOKEN "totalSupply()"
```

---

### 2.2 Deploy Main DAO (UUPS)

- [ ] **Deploy Main DAO Implementation**
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/main-dao.sol:MainDAO"
```

- [ ] **Record address:**
```bash
export MAIN_DAO_IMPL="0x________________"
```

- [ ] **Deploy Main DAO Proxy**
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $MAIN_DAO_IMPL 0x
```

- [ ] **Record address:**
```bash
export MAIN_DAO_PROXY="0x________________"
```

- [ ] **Initialize Main DAO**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_DAO_PROXY \
  "initialize(address,address,uint256)" \
  $ETHEREUM_MULTISIG \
  $OPENWORK_TOKEN \
  100000000000000000000
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_DAO_PROXY "owner()" | cast --to-address
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_DAO_PROXY "openWorkToken()" | cast --to-address
```

---

### 2.3 Deploy Main Rewards (UUPS)

- [ ] **Deploy Main Rewards Implementation**
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/main-rewards.sol:MainRewards"
```

- [ ] **Record address:**
```bash
export MAIN_REWARDS_IMPL="0x________________"
```

- [ ] **Deploy Main Rewards Proxy**
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $MAIN_REWARDS_IMPL 0x
```

- [ ] **Record address:**
```bash
export MAIN_REWARDS_PROXY="0x________________"
```

- [ ] **Initialize Main Rewards**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_REWARDS_PROXY \
  "initialize(address,address,address)" \
  $ETHEREUM_MULTISIG \
  $OPENWORK_TOKEN \
  $MAIN_DAO_PROXY
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_REWARDS_PROXY "owner()" | cast --to-address
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_REWARDS_PROXY "openWorkToken()" | cast --to-address
```

---

### 2.4 Deploy Main Bridge

- [ ] **Deploy Main Bridge**
```bash
forge create --broadcast \
  --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/main-chain-bridge.sol:MainChainBridge" \
  --constructor-args $LZ_ENDPOINT $ETHEREUM_MULTISIG $BASE_EID
```

- [ ] **Record address:**
```bash
export MAIN_BRIDGE="0x________________"
```

- [ ] **Verify deployment:**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "owner()" | cast --to-address
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "nativeChainEid()"
```

---

### 2.5 Configure Main Chain Contracts

- [ ] **Main DAO - Set Bridge**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_DAO_PROXY \
  "setBridge(address)" \
  $MAIN_BRIDGE
```

- [ ] **Main DAO - Set Rewards**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_DAO_PROXY \
  "setRewards(address)" \
  $MAIN_REWARDS_PROXY
```

- [ ] **Main Rewards - Set Bridge**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_REWARDS_PROXY \
  "setBridge(address)" \
  $MAIN_BRIDGE
```

- [ ] **Main Bridge - Set DAO**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_BRIDGE \
  "setMainDaoContract(address)" \
  $MAIN_DAO_PROXY
```

- [ ] **Main Bridge - Set Rewards**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_BRIDGE \
  "setMainRewardsContract(address)" \
  $MAIN_REWARDS_PROXY
```

- [ ] **Main Bridge - Authorize DAO**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_BRIDGE \
  "authorizeContract(address,bool)" \
  $MAIN_DAO_PROXY true
```

- [ ] **Main Bridge - Authorize Rewards**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_BRIDGE \
  "authorizeContract(address,bool)" \
  $MAIN_REWARDS_PROXY true
```

---

## 3. Phase 2: Native Chain (Base Mainnet)

### 3.1 Deploy OpenWork Genesis (UUPS)

- [ ] **Deploy OpenWork Genesis Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-genesis.sol:OpenworkGenesis"
```

- [ ] **Record address:**
```bash
export OPENWORK_GENESIS_IMPL="0x________________"
```

- [ ] **Deploy OpenWork Genesis Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $OPENWORK_GENESIS_IMPL 0x
```

- [ ] **Record address:**
```bash
export OPENWORK_GENESIS_PROXY="0x________________"
```

- [ ] **Initialize OpenWork Genesis**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_GENESIS_PROXY \
  "initialize(address)" \
  $BASE_MULTISIG
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $OPENWORK_GENESIS_PROXY "owner()" | cast --to-address
```

---

### 3.2 Deploy Profile Genesis (UUPS)

- [ ] **Deploy Profile Genesis Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/profile-genesis.sol:ProfileGenesis"
```

- [ ] **Record address:**
```bash
export PROFILE_GENESIS_IMPL="0x________________"
```

- [ ] **Deploy Profile Genesis Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $PROFILE_GENESIS_IMPL 0x
```

- [ ] **Record address:**
```bash
export PROFILE_GENESIS_PROXY="0x________________"
```

- [ ] **Initialize Profile Genesis**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $PROFILE_GENESIS_PROXY \
  "initialize(address)" \
  $BASE_MULTISIG
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $PROFILE_GENESIS_PROXY "owner()" | cast --to-address
```

---

### 3.3 Deploy Native DAO (UUPS)

- [ ] **Deploy Native DAO Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-dao.sol:NativeDAO"
```

- [ ] **Record address:**
```bash
export NATIVE_DAO_IMPL="0x________________"
```

- [ ] **Deploy Native DAO Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $NATIVE_DAO_IMPL 0x
```

- [ ] **Record address:**
```bash
export NATIVE_DAO_PROXY="0x________________"
```

- [ ] **Initialize Native DAO**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_DAO_PROXY \
  "initialize(address,address,address,uint256)" \
  $BASE_MULTISIG \
  $OPENWORK_GENESIS_PROXY \
  0x0000000000000000000000000000000000000000 \
  100000000000000000000
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "genesis()" | cast --to-address
```

---

### 3.4 Deploy Native Rewards (UUPS)

- [ ] **Deploy Native Rewards Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-rewards.sol:NativeRewards"
```

- [ ] **Record address:**
```bash
export NATIVE_REWARDS_IMPL="0x________________"
```

- [ ] **Deploy Native Rewards Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $NATIVE_REWARDS_IMPL 0x
```

- [ ] **Record address:**
```bash
export NATIVE_REWARDS_PROXY="0x________________"
```

- [ ] **Initialize Native Rewards**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY \
  "initialize(address,address,address,address)" \
  $BASE_MULTISIG \
  $OPENWORK_GENESIS_PROXY \
  $NATIVE_DAO_PROXY \
  0x0000000000000000000000000000000000000000
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_REWARDS_PROXY "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_REWARDS_PROXY "genesis()" | cast --to-address
```

---

### 3.5 Deploy NOWJC (UUPS)

- [ ] **Deploy NOWJC Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/nowjc.sol:NOWJC"
```

- [ ] **Record address:**
```bash
export NOWJC_IMPL="0x________________"
```

- [ ] **Deploy NOWJC Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $NOWJC_IMPL 0x
```

- [ ] **Record address:**
```bash
export NOWJC_PROXY="0x________________"
```

- [ ] **Initialize NOWJC**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY \
  "initialize(address,address,address,address,address,address,address,address)" \
  $BASE_MULTISIG \
  $BASE_USDC \
  $OPENWORK_GENESIS_PROXY \
  0x0000000000000000000000000000000000000000 \
  $NATIVE_REWARDS_PROXY \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "genesis()" | cast --to-address
```

---

### 3.6 Deploy Native Athena (UUPS)

- [ ] **Deploy Native Athena Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-athena.sol:NativeAthena"
```

- [ ] **Record address:**
```bash
export NATIVE_ATHENA_IMPL="0x________________"
```

- [ ] **Deploy Native Athena Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $NATIVE_ATHENA_IMPL 0x
```

- [ ] **Record address:**
```bash
export NATIVE_ATHENA_PROXY="0x________________"
```

- [ ] **Initialize Native Athena**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_ATHENA_PROXY \
  "initialize(address,address,address,address,address,address,uint256,uint256)" \
  $BASE_MULTISIG \
  $OPENWORK_GENESIS_PROXY \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  5000000000000000000 \
  3
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "genesis()" | cast --to-address
```

---

### 3.7 Deploy Native Athena Oracle Manager (UUPS)

- [ ] **Deploy Oracle Manager Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-athena-oracle-manager.sol:NativeAthenaOracleManager"
```

- [ ] **Record address:**
```bash
export ORACLE_MANAGER_IMPL="0x________________"
```

- [ ] **Deploy Oracle Manager Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $ORACLE_MANAGER_IMPL 0x
```

- [ ] **Record address:**
```bash
export ORACLE_MANAGER_PROXY="0x________________"
```

- [ ] **Initialize Oracle Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $ORACLE_MANAGER_PROXY \
  "initialize(address,address,address)" \
  $BASE_MULTISIG \
  $OPENWORK_GENESIS_PROXY \
  $NATIVE_ATHENA_PROXY
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $ORACLE_MANAGER_PROXY "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $ORACLE_MANAGER_PROXY "genesis()" | cast --to-address
```

---

### 3.8 Deploy Profile Manager (UUPS)

- [ ] **Deploy Profile Manager Implementation**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/profile-manager.sol:ProfileManager"
```

- [ ] **Record address:**
```bash
export PROFILE_MANAGER_IMPL="0x________________"
```

- [ ] **Deploy Profile Manager Proxy**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $PROFILE_MANAGER_IMPL 0x
```

- [ ] **Record address:**
```bash
export PROFILE_MANAGER_PROXY="0x________________"
```

- [ ] **Initialize Profile Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $PROFILE_MANAGER_PROXY \
  "initialize(address,address,address)" \
  $BASE_MULTISIG \
  $PROFILE_GENESIS_PROXY \
  0x0000000000000000000000000000000000000000
```

- [ ] **Verify initialization:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $PROFILE_MANAGER_PROXY "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $PROFILE_MANAGER_PROXY "profileGenesis()" | cast --to-address
```

---

### 3.9 Deploy Direct Contract Manager

- [ ] **Deploy Direct Contract Manager**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/direct-contract-manager.sol:DirectContractManager" \
  --constructor-args $BASE_MULTISIG $OPENWORK_GENESIS_PROXY $NOWJC_PROXY
```

- [ ] **Record address:**
```bash
export DIRECT_CONTRACT_MANAGER="0x________________"
```

- [ ] **Verify deployment:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $DIRECT_CONTRACT_MANAGER "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $DIRECT_CONTRACT_MANAGER "genesis()" | cast --to-address
```

---

### 3.10 Deploy Native Bridge

- [ ] **Deploy Native Bridge**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/native-bridge.sol:NativeBridge" \
  --constructor-args $LZ_ENDPOINT $BASE_MULTISIG $ETHEREUM_EID
```

- [ ] **Record address:**
```bash
export NATIVE_BRIDGE="0x________________"
```

- [ ] **Verify deployment:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "mainChainEid()"
```

---

### 3.11 Deploy CCTP Transceiver (Base)

- [ ] **Deploy CCTP Transceiver**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/cctp-transceiver.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args $BASE_TOKEN_MESSENGER $BASE_MESSAGE_TRANSMITTER $BASE_USDC
```

- [ ] **Record address:**
```bash
export BASE_CCTP_TRANSCEIVER="0x________________"
```

- [ ] **Verify deployment:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $BASE_CCTP_TRANSCEIVER "owner()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $BASE_CCTP_TRANSCEIVER "usdc()" | cast --to-address
```

---

### 3.12 Deploy Genesis Reader Helper (Base)

- [ ] **Deploy Genesis Reader Helper**
```bash
forge create --broadcast \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/genesis-reader-helper.sol:GenesisReaderHelper" \
  --constructor-args $OPENWORK_GENESIS_PROXY
```

- [ ] **Record address:**
```bash
export BASE_GENESIS_READER="0x________________"
```

- [ ] **Verify deployment:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $BASE_GENESIS_READER "genesis()" | cast --to-address
```

---

### 3.13 Configure Native Chain Contracts

#### 3.13.1 Native DAO Configuration

- [ ] **Set NOWJC**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_DAO_PROXY "setNOWJContract(address)" $NOWJC_PROXY
```

- [ ] **Set Bridge**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_DAO_PROXY "setBridge(address)" $NATIVE_BRIDGE
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "nowjc()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "bridge()" | cast --to-address
```

#### 3.13.2 Native Rewards Configuration

- [ ] **Set Bridge**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_REWARDS_PROXY "setBridge(address)" $NATIVE_BRIDGE
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_REWARDS_PROXY "bridge()" | cast --to-address
```

#### 3.13.3 NOWJC Configuration

- [ ] **Set Bridge**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY "setBridge(address)" $NATIVE_BRIDGE
```

- [ ] **Set Native Athena**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY "setNativeAthena(address)" $NATIVE_ATHENA_PROXY
```

- [ ] **Set CCTP Receiver**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY "setCCTPReceiver(address)" $BASE_CCTP_TRANSCEIVER
```

- [ ] **Set CCTP Transceiver**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY "setCCTPTransceiver(address)" $BASE_CCTP_TRANSCEIVER
```

- [ ] **Set Treasury**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY "setTreasury(address)" $BASE_MULTISIG
```

- [ ] **Authorize Native Athena**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NOWJC_PROXY "addAuthorizedContract(address)" $NATIVE_ATHENA_PROXY
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "bridge()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "nativeAthena()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "cctpReceiver()" | cast --to-address
```

#### 3.13.4 Native Athena Configuration

- [ ] **Set NOWJC**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_ATHENA_PROXY "setNOWJContract(address)" $NOWJC_PROXY
```

- [ ] **Set Oracle Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_ATHENA_PROXY "setOracleManager(address)" $ORACLE_MANAGER_PROXY
```

- [ ] **Set DAO**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_ATHENA_PROXY "setDAOContract(address)" $NATIVE_DAO_PROXY
```

- [ ] **Set Bridge**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_ATHENA_PROXY "setBridge(address)" $NATIVE_BRIDGE
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "nowjc()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "oracleManager()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "bridge()" | cast --to-address
```

#### 3.13.5 Profile Manager Configuration

- [ ] **Set Bridge**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $PROFILE_MANAGER_PROXY "setBridge(address)" $NATIVE_BRIDGE
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $PROFILE_MANAGER_PROXY "bridge()" | cast --to-address
```

#### 3.13.6 Native Bridge Configuration

- [ ] **Authorize Native DAO**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "authorizeContract(address,bool)" $NATIVE_DAO_PROXY true
```

- [ ] **Authorize NOWJC**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "authorizeContract(address,bool)" $NOWJC_PROXY true
```

- [ ] **Authorize Native Athena**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "authorizeContract(address,bool)" $NATIVE_ATHENA_PROXY true
```

- [ ] **Authorize Profile Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "authorizeContract(address,bool)" $PROFILE_MANAGER_PROXY true
```

- [ ] **Set Native DAO Contract**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "setNativeDaoContract(address)" $NATIVE_DAO_PROXY
```

- [ ] **Set Native Athena Contract**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "setNativeAthenaContract(address)" $NATIVE_ATHENA_PROXY
```

- [ ] **Set NOWJC Contract**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "setNativeOpenWorkJobContract(address)" $NOWJC_PROXY
```

- [ ] **Set Profile Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "setProfileManager(address)" $PROFILE_MANAGER_PROXY
```

- [ ] **Add Local Chain - Arbitrum**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "addLocalChain(uint32)" $ARBITRUM_EID
```

- [ ] **Add Local Chain - Optimism**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "addLocalChain(uint32)" $OPTIMISM_EID
```

- [ ] **Add Local Chain - Polygon**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "addLocalChain(uint32)" $POLYGON_EID
```

- [ ] **Add Local Chain - Avalanche**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE "addLocalChain(uint32)" $AVALANCHE_EID
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "nativeDaoContract()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "nativeAthenaContract()" | cast --to-address
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "nativeOpenWorkJobContract()" | cast --to-address
```

#### 3.13.7 Genesis Authorization

- [ ] **OpenWork Genesis - Authorize Native DAO**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_GENESIS_PROXY "authorizeContract(address,bool)" $NATIVE_DAO_PROXY true
```

- [ ] **OpenWork Genesis - Authorize NOWJC**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_GENESIS_PROXY "authorizeContract(address,bool)" $NOWJC_PROXY true
```

- [ ] **OpenWork Genesis - Authorize Native Athena**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_GENESIS_PROXY "authorizeContract(address,bool)" $NATIVE_ATHENA_PROXY true
```

- [ ] **OpenWork Genesis - Authorize Oracle Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_GENESIS_PROXY "authorizeContract(address,bool)" $ORACLE_MANAGER_PROXY true
```

- [ ] **OpenWork Genesis - Authorize Direct Contract Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $OPENWORK_GENESIS_PROXY "authorizeContract(address,bool)" $DIRECT_CONTRACT_MANAGER true
```

- [ ] **Profile Genesis - Authorize Profile Manager**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $PROFILE_GENESIS_PROXY "authorizeContract(address,bool)" $PROFILE_MANAGER_PROXY true
```

---

## 4. Phase 3: Local Chain (Template - Replicate for All)

> **📋 IMPORTANT:** This section shows the deployment for ONE local chain (Arbitrum).
>
> **Replicate these exact steps for each local chain:**
> - Arbitrum (shown below)
> - Optimism (replace ARBITRUM with OPTIMISM throughout)
> - Polygon (replace ARBITRUM with POLYGON throughout)
> - Avalanche (replace ARBITRUM with AVALANCHE throughout)
>
> Just swap the chain-specific variables:
> - `$ARBITRUM_MAINNET_RPC_URL` → `$OPTIMISM_MAINNET_RPC_URL`, etc.
> - `$ARBITRUM_MULTISIG` → `$OPTIMISM_MULTISIG`, etc.
> - `$ARBITRUM_EID` → `$OPTIMISM_EID`, etc.
> - `$ARBITRUM_USDC` → `$OPTIMISM_USDC`, etc.
> - Export variables: `ARBITRUM_LOWJC_IMPL` → `OPTIMISM_LOWJC_IMPL`, etc.

### 4.1 Deploy Local Chain Contracts (Arbitrum Template)

#### 4.1.1 Deploy LOWJC (UUPS)

- [ ] **Deploy LOWJC Implementation**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/lowjc.sol:LOWJC"
```

- [ ] **Record address:**
```bash
export ARBITRUM_LOWJC_IMPL="0x________________"
```

- [ ] **Deploy LOWJC Proxy**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $ARBITRUM_LOWJC_IMPL 0x
```

- [ ] **Record address:**
```bash
export ARBITRUM_LOWJC_PROXY="0x________________"
```

- [ ] **Initialize LOWJC**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOWJC_PROXY \
  "initialize(address,address,uint32,address,address,address)" \
  $ARBITRUM_MULTISIG \
  $ARBITRUM_USDC \
  $ARBITRUM_EID \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000
```

- [ ] **Verify:**
```bash
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOWJC_PROXY "owner()" | cast --to-address
```

#### 4.1.2 Deploy Athena Client (UUPS)

- [ ] **Deploy Athena Client Implementation**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/athena-client.sol:AthenaClient"
```

- [ ] **Record address:**
```bash
export ARBITRUM_ATHENA_CLIENT_IMPL="0x________________"
```

- [ ] **Deploy Athena Client Proxy**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/proxy.sol:UUPSProxy" \
  --constructor-args $ARBITRUM_ATHENA_CLIENT_IMPL 0x
```

- [ ] **Record address:**
```bash
export ARBITRUM_ATHENA_CLIENT_PROXY="0x________________"
```

- [ ] **Initialize Athena Client**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_ATHENA_CLIENT_PROXY \
  "initialize(address,address,address,address,uint32)" \
  $ARBITRUM_MULTISIG \
  0x0000000000000000000000000000000000000000 \
  $ARBITRUM_LOWJC_PROXY \
  0x0000000000000000000000000000000000000000 \
  $BASE_CCTP_DOMAIN
```

- [ ] **Verify:**
```bash
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_ATHENA_CLIENT_PROXY "owner()" | cast --to-address
```

#### 4.1.3 Deploy Local Bridge

- [ ] **Deploy Local Bridge**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/local-bridge.sol:LocalBridge" \
  --constructor-args $LZ_ENDPOINT $ARBITRUM_MULTISIG $BASE_EID
```

- [ ] **Record address:**
```bash
export ARBITRUM_LOCAL_BRIDGE="0x________________"
```

- [ ] **Verify:**
```bash
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOCAL_BRIDGE "owner()" | cast --to-address
```

#### 4.1.4 Deploy CCTP Transceiver

- [ ] **Deploy CCTP Transceiver**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/cctp-transceiver.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args $ARBITRUM_TOKEN_MESSENGER $ARBITRUM_MESSAGE_TRANSMITTER $ARBITRUM_USDC
```

- [ ] **Record address:**
```bash
export ARBITRUM_CCTP_TRANSCEIVER="0x________________"
```

- [ ] **Verify:**
```bash
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_CCTP_TRANSCEIVER "owner()" | cast --to-address
```

#### 4.1.5 Deploy Genesis Reader Helper

- [ ] **Deploy Genesis Reader Helper**
```bash
forge create --broadcast \
  --rpc-url $ARBITRUM_MAINNET_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/genesis-reader-helper.sol:GenesisReaderHelper" \
  --constructor-args $OPENWORK_GENESIS_PROXY
```

- [ ] **Record address:**
```bash
export ARBITRUM_GENESIS_READER="0x________________"
```

#### 4.1.6 Configure Arbitrum Contracts

- [ ] **LOWJC - Set Bridge**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOWJC_PROXY "setBridge(address)" $ARBITRUM_LOCAL_BRIDGE
```

- [ ] **LOWJC - Set CCTP Sender**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOWJC_PROXY "setCCTPSender(address)" $ARBITRUM_CCTP_TRANSCEIVER
```

- [ ] **LOWJC - Set CCTP Mint Recipient (NOWJC on Base)**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOWJC_PROXY "setCCTPMintRecipient(address)" $NOWJC_PROXY
```

- [ ] **LOWJC - Set Athena Client**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOWJC_PROXY "setAthenaClientContract(address)" $ARBITRUM_ATHENA_CLIENT_PROXY
```

- [ ] **Athena Client - Set Bridge**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_ATHENA_CLIENT_PROXY "setBridge(address)" $ARBITRUM_LOCAL_BRIDGE
```

- [ ] **Athena Client - Set CCTP Sender**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_ATHENA_CLIENT_PROXY "setCCTPSender(address)" $ARBITRUM_CCTP_TRANSCEIVER
```

- [ ] **Local Bridge - Authorize LOWJC**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOCAL_BRIDGE "authorizeContract(address,bool)" $ARBITRUM_LOWJC_PROXY true
```

- [ ] **Local Bridge - Authorize Athena Client**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOCAL_BRIDGE "authorizeContract(address,bool)" $ARBITRUM_ATHENA_CLIENT_PROXY true
```

- [ ] **Local Bridge - Set LOWJC**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOCAL_BRIDGE "setLowjcContract(address)" $ARBITRUM_LOWJC_PROXY
```

- [ ] **Local Bridge - Set Athena Client**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOCAL_BRIDGE "setAthenaClientContract(address)" $ARBITRUM_ATHENA_CLIENT_PROXY
```

---

## 5. Phase 4: Cross-Chain Configuration

### 5.1 LayerZero Peer Configuration (setPeer)

All bridges need to know about each other through LayerZero peers. This is bidirectional - each bridge must be set as a peer on the other.

#### 5.1.1 Main Bridge ↔ Native Bridge

- [ ] **Main Bridge → Native Bridge Peer**
```bash
cast send --rpc-url $ETHEREUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $MAIN_BRIDGE \
  "setPeer(uint32,bytes32)" \
  $BASE_EID \
  $(cast --to-bytes32 $NATIVE_BRIDGE)
```

- [ ] **Native Bridge → Main Bridge Peer**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE \
  "setPeer(uint32,bytes32)" \
  $ETHEREUM_EID \
  $(cast --to-bytes32 $MAIN_BRIDGE)
```

- [ ] **Verify:**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "peers(uint32)" $BASE_EID
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $ETHEREUM_EID
```

#### 5.1.2 Native Bridge ↔ Arbitrum Local Bridge

- [ ] **Native Bridge → Arbitrum Local Bridge Peer**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $NATIVE_BRIDGE \
  "setPeer(uint32,bytes32)" \
  $ARBITRUM_EID \
  $(cast --to-bytes32 $ARBITRUM_LOCAL_BRIDGE)
```

- [ ] **Arbitrum Local Bridge → Native Bridge Peer**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_LOCAL_BRIDGE \
  "setPeer(uint32,bytes32)" \
  $BASE_EID \
  $(cast --to-bytes32 $NATIVE_BRIDGE)
```

- [ ] **Verify:**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $ARBITRUM_EID
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOCAL_BRIDGE "peers(uint32)" $BASE_EID
```


> **🔁 REPLICATE FOR ALL LOCAL CHAINS:** Repeat section 5.1.2 for:
> - Optimism (replace ARBITRUM with OPTIMISM, $ARBITRUM_EID with $OPTIMISM_EID, etc.)
> - Polygon (replace ARBITRUM with POLYGON, $ARBITRUM_EID with $POLYGON_EID, etc.)
> - Avalanche (replace ARBITRUM with AVALANCHE, $ARBITRUM_EID with $AVALANCHE_EID, etc.)

---

### 5.2 CCTP Reward Pool Funding

Fund each CCTP Transceiver with ETH for dynamic gas-based rewards:

- [ ] **Fund Base CCTP Transceiver**
```bash
cast send --rpc-url $BASE_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $BASE_CCTP_TRANSCEIVER "fundRewardPool()" --value 5ether
```

- [ ] **Fund Arbitrum CCTP Transceiver (Template)**
```bash
cast send --rpc-url $ARBITRUM_MAINNET_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY \
  $ARBITRUM_CCTP_TRANSCEIVER "fundRewardPool()" --value 5ether
```

> **🔁 REPLICATE:** Fund CCTP Transceivers on all other local chains:
> - Optimism, Polygon, Avalanche
> - Use the same command pattern, replacing chain-specific variables

---

## 6. Phase 5: Final Verification

### 6.1 Main Chain (Ethereum) Verification

- [ ] **OpenWork Token**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $OPENWORK_TOKEN "owner()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $OPENWORK_TOKEN "totalSupply()"
```

- [ ] **Main DAO**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_DAO_PROXY "owner()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_DAO_PROXY "openWorkToken()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_DAO_PROXY "bridge()"
```

- [ ] **Main Rewards**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_REWARDS_PROXY "owner()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_REWARDS_PROXY "openWorkToken()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_REWARDS_PROXY "bridge()"
```

- [ ] **Main Bridge**
```bash
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "owner()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "mainDaoContract()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "mainRewardsContract()"
cast call --rpc-url $ETHEREUM_MAINNET_RPC_URL $MAIN_BRIDGE "peers(uint32)" $BASE_EID
```

---

### 6.2 Native Chain (Base) Verification

- [ ] **OpenWork Genesis**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $OPENWORK_GENESIS_PROXY "owner()"
```

- [ ] **Profile Genesis**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $PROFILE_GENESIS_PROXY "owner()"
```

- [ ] **Native DAO**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "owner()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "genesis()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "nowjc()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_DAO_PROXY "bridge()"
```

- [ ] **NOWJC**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "owner()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "genesis()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "bridge()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "nativeAthena()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NOWJC_PROXY "cctpReceiver()"
```

- [ ] **Native Athena**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "owner()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "genesis()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "nowjc()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "oracleManager()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_ATHENA_PROXY "bridge()"
```

- [ ] **Native Bridge**
```bash
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "owner()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "nativeDaoContract()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "nativeAthenaContract()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "nativeOpenWorkJobContract()"
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $ETHEREUM_EID
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $ARBITRUM_EID
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $OPTIMISM_EID
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $POLYGON_EID
cast call --rpc-url $BASE_MAINNET_RPC_URL $NATIVE_BRIDGE "peers(uint32)" $AVALANCHE_EID
```

---

### 6.3 Local Chains Verification

#### Local Chain Template (Arbitrum)

- [ ] **LOWJC**
```bash
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOWJC_PROXY "owner()"
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOWJC_PROXY "bridge()"
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOWJC_PROXY "cctpSender()"
```

- [ ] **Local Bridge**
```bash
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOCAL_BRIDGE "owner()"
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOCAL_BRIDGE "lowjcContract()"
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOCAL_BRIDGE "athenaClientContract()"
cast call --rpc-url $ARBITRUM_MAINNET_RPC_URL $ARBITRUM_LOCAL_BRIDGE "peers(uint32)" $BASE_EID
```

> **🔁 REPLICATE:** Run the same verification commands for all other local chains:
> - Optimism, Polygon, Avalanche
> - Replace ARBITRUM with the respective chain name in all commands

---

## 7. Post-Deployment: Finalize Documentation

### 7.1 Complete Contract Address Registry

- [ ] **Finalize the JSON address file**
```bash
# Review and complete deployed-contracts-YYYY-MM-DD.json
# Ensure ALL 51 contract addresses are recorded
# Double-check each address against deployment log
```

- [ ] **Create human-readable address document**
```bash
cat > DEPLOYED_ADDRESSES.md << 'EOF'
# OpenWork Mainnet Deployment - Contract Addresses

**Deployment Date:** YYYY-MM-DD
**Network:** Production Mainnet
**Deployer:** [Team/Name]

---

## Main Chain (Ethereum Mainnet)

| Contract | Type | Address | TX Hash |
|----------|------|---------|---------|
| OpenWork Token | ERC20 | `0x...` | `0x...` |
| Main DAO (Implementation) | UUPS | `0x...` | `0x...` |
| Main DAO (Proxy) | Proxy | `0x...` | `0x...` |
| Main Rewards (Implementation) | UUPS | `0x...` | `0x...` |
| Main Rewards (Proxy) | Proxy | `0x...` | `0x...` |
| Main Bridge | OApp | `0x...` | `0x...` |

## Native Chain (Base Mainnet)

[Complete table for all 19 Base contracts]

## Local Chains

### Arbitrum
[Complete table for all 7 Arbitrum contracts]

### Optimism
[Complete table for all 7 Optimism contracts]

### Polygon
[Complete table for all 7 Polygon contracts]

### Avalanche
[Complete table for all 7 Avalanche contracts]

---

## Block Explorer Links

### Ethereum
- Token: https://etherscan.io/address/0x...
- Main DAO: https://etherscan.io/address/0x...
[etc.]

### Base
- Genesis: https://basescan.org/address/0x...
[etc.]

EOF
```

### 7.2 Finalize Deployment Log

- [ ] **Add deployment summary to log**
```bash
cat >> $DEPLOYMENT_LOG << 'EOF'

---

## Deployment Summary

**Status:** ✅ Complete
**Total Contracts Deployed:** 51
**Total Chains:** 6
**Duration:** [X hours]
**Total Gas Spent:** [Record gas costs per chain]

### Key Addresses

**Main Chain (Ethereum):**
- OpenWork Token: `0x...`
- Main DAO Proxy: `0x...`
- Main Bridge: `0x...`

**Native Chain (Base):**
- Genesis Proxy: `0x...`
- NOWJC Proxy: `0x...`
- Native Bridge: `0x...`

**Local Chains:**
- Arbitrum LOWJC: `0x...`
- Optimism LOWJC: `0x...`
- Polygon LOWJC: `0x...`
- Avalanche LOWJC: `0x...`

### Issues Encountered

[Document any issues and how they were resolved]

### Next Steps

- [ ] Submit contracts for block explorer verification
- [ ] Transfer ownership to multisigs
- [ ] Update frontend with new contract addresses
- [ ] Notify team of successful deployment
- [ ] Archive deployment artifacts

---

**Deployment Completed:** $(date)
**Verified By:** [Name]

EOF
```

### 7.3 Create Verification Tracking Document

- [ ] **Create block explorer verification checklist**
```bash
cat > VERIFICATION_CHECKLIST.md << 'EOF'
# Contract Verification Checklist

Track verification status for all deployed contracts on block explorers.

## Main Chain (Ethereum - Etherscan)

- [ ] OpenWork Token - `0x...`
- [ ] Main DAO Implementation - `0x...`
- [ ] Main DAO Proxy - `0x...`
- [ ] Main Rewards Implementation - `0x...`
- [ ] Main Rewards Proxy - `0x...`
- [ ] Main Bridge - `0x...`

## Native Chain (Base - Basescan)

- [ ] OpenWork Genesis Implementation - `0x...`
- [ ] OpenWork Genesis Proxy - `0x...`
[Complete for all 19 Base contracts]

## Local Chains

### Arbitrum (Arbiscan)
[Checklist for all 7 contracts]

### Optimism (Optimistic Etherscan)
[Checklist for all 7 contracts]

### Polygon (Polygonscan)
[Checklist for all 7 contracts]

### Avalanche (Snowtrace)
[Checklist for all 7 contracts]

---

## Verification Commands

Use forge verify-contract for each:

```bash
forge verify-contract \
  --rpc-url $RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  0xContractAddress \
  src/path/to/Contract.sol:ContractName \
  --constructor-args $(cast abi-encode "constructor(type1,type2)" arg1 arg2)
```

EOF
```

### 7.4 Archive Deployment Artifacts

- [ ] **Collect all deployment artifacts**
```bash
# Create deployment archive
mkdir -p deployment-archive-$(date +%Y-%m-%d)
cd deployment-archive-$(date +%Y-%m-%d)

# Copy all documentation
cp ../$DEPLOYMENT_LOG ./
cp ../deployed-contracts-*.json ./
cp ../DEPLOYED_ADDRESSES.md ./
cp ../VERIFICATION_CHECKLIST.md ./

# Copy broadcast artifacts
cp -r ../broadcast ./

# Create README
cat > README.md << 'EOF'
# OpenWork Mainnet Deployment Archive

**Date:** $(date)

## Contents

- `deployment-log-*.md` - Complete deployment log with all commands and outputs
- `deployed-contracts-*.json` - Machine-readable contract addresses
- `DEPLOYED_ADDRESSES.md` - Human-readable address document
- `VERIFICATION_CHECKLIST.md` - Block explorer verification tracking
- `broadcast/` - Foundry broadcast artifacts

## Usage

This archive contains all artifacts from the mainnet deployment.
Keep this safe for:
- Future reference
- Audit trail
- Disaster recovery
- Upgrade planning

EOF

cd ..
tar -czf deployment-archive-$(date +%Y-%m-%d).tar.gz deployment-archive-$(date +%Y-%m-%d)

echo "✅ Deployment archive created: deployment-archive-$(date +%Y-%m-%d).tar.gz"
```

### 7.5 Final Checklist

- [ ] ✅ All 51 contracts deployed successfully
- [ ] ✅ All addresses recorded in JSON file
- [ ] ✅ All addresses recorded in markdown document
- [ ] ✅ Deployment log complete with all commands and outputs
- [ ] ✅ Verification checklist created
- [ ] ✅ Deployment artifacts archived
- [ ] ✅ Archive backed up to secure location
- [ ] ✅ Team notified of deployment completion
- [ ] ✅ Contract addresses shared with frontend team
- [ ] ✅ Next steps documented

### 7.6 Share with Team

Create a deployment announcement:

```markdown
# 🚀 OpenWork Mainnet Deployment Complete

**Date:** [Date]
**Network:** Production Mainnet (Ethereum, Base, Arbitrum, Optimism, Polygon, Avalanche)
**Status:** ✅ All 51 contracts successfully deployed

## Quick Links

- Contract Addresses: [Link to DEPLOYED_ADDRESSES.md]
- Deployment Log: [Link to deployment log]
- Block Explorers: [Links to verified contracts]

## Key Addresses

**Ethereum:**
- Token: `0x...`
- Main DAO: `0x...`

**Base:**
- Genesis: `0x...`
- NOWJC: `0x...`

[Complete key addresses list]

## Next Steps

1. Verify contracts on block explorers
2. Transfer ownership to multisigs
3. Update frontend configuration
4. Begin user testing

## Documentation

All deployment artifacts archived in: `deployment-archive-YYYY-MM-DD.tar.gz`

**Deployed by:** [Your Name]
**Verified by:** [Team Lead]
```

---

## Summary

**Total Contracts to Deploy:** 51
- **Main Chain (Ethereum):** 4 contracts
- **Native Chain (Base):** 19 contracts
- **Each Local Chain:** 7 contracts × 4 chains = 28 contracts

**Total Configuration Commands:** ~150+ commands (replicated across all local chains)

**Document Structure:**
- **Phases 1-2:** Full commands for Main Chain and Native Chain
- **Phase 3:** Template for ONE local chain (Arbitrum) - replicate for Optimism, Polygon, Avalanche
- **Phase 4-5:** Templates showing patterns for cross-chain config and verification

**Deployment Phases:**
1. ✅ Main Chain (Ethereum) - 4 deployments + configuration
2. ✅ Native Chain (Base) - 12 deployments + comprehensive configuration
3. ✅ Local Chains - Template shown (replicate for all 4 chains)
4. ✅ Cross-Chain Configuration - LayerZero peer setup (replicate for all local chains)
5. ✅ Final Verification - Complete system health checks (replicate for all local chains)

---

**⚠️ IMPORTANT NOTES:**

1. **Track All Addresses:** Export each deployed address immediately after deployment
2. **Sequential Execution:** Follow the exact order - dependencies matter
3. **Verify After Each Step:** Run verification commands before proceeding
4. **Backup:** Save all addresses and transaction hashes
5. **Multisig:** Transfer ownership to multisigs after deployment is complete and verified
6. **Gas Management:** Monitor gas prices, especially on Ethereum mainnet
7. **CCTP Funding:** Ensure CCTP transceivers have sufficient ETH for rewards
8. **LayerZero Peers:** All peer configurations must be bidirectional

---

**Document Status:** Ready for execution
**Last Updated:** 28-Dec-2025
