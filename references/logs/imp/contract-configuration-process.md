# Systematic Contract Configuration Process

## Overview

After deploying all contracts with their proxies and initial parameters, a systematic configuration phase is required to wire up inter-contract dependencies. This document outlines the process.

## Configuration Methodology

### Step 1: Analyze Each Contract

For each deployed contract, examine:
1. **Init parameters** - What was set during `initialize()`?
2. **Admin setter functions** - What `set*()` functions exist?
3. **Authorization requirements** - Does it need to be authorized by other contracts?

### Step 2: Identify Dependencies

Create a dependency matrix showing:
- What each contract needs configured
- What contracts need to authorize this contract

### Step 3: Execute in Logical Order

Configure contracts in order of dependencies:
1. Storage contracts first (authorize consumers)
2. Core logic contracts second
3. Bridge/external integration contracts last

---

## Contract Addresses Reference

| Contract | Proxy Address |
|----------|---------------|
| OpenworkGenesis | `<GENESIS_PROXY>` |
| OpenWorkRewardsContract | `<REWARDS_PROXY>` |
| NOWJC | `<NOWJC_PROXY>` |
| NativeChainBridge | `<NATIVE_BRIDGE>` |
| CCTPv2Transceiver | `<CCTP_TRANSCEIVER>` |
| NativeDAO | `<NATIVE_DAO_PROXY>` |
| NativeAthena | `<NATIVE_ATHENA_PROXY>` |
| NativeAthenaOracleManager | `<ORACLE_MANAGER_PROXY>` |
| ProfileGenesis | `<PROFILE_GENESIS_PROXY>` |
| ProfileManager | `<PROFILE_MANAGER_PROXY>` |
| ActivityTracker | `<ACTIVITY_TRACKER_PROXY>` |

---

## Contract-by-Contract Configuration

### 1. OpenworkGenesis (Storage Contract)

**Type:** Pure storage contract with authorization pattern

**Init Params Set:**
- `owner`

**Required Configuration:**
Authorize all contracts that write to Genesis storage:

```bash
# Authorize NOWJC
source .env && cast send <GENESIS_PROXY> "authorizeContract(address,bool)" <NOWJC_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NativeDAO
source .env && cast send <GENESIS_PROXY> "authorizeContract(address,bool)" <NATIVE_DAO_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NativeAthena
source .env && cast send <GENESIS_PROXY> "authorizeContract(address,bool)" <NATIVE_ATHENA_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NativeAthenaOracleManager
source .env && cast send <GENESIS_PROXY> "authorizeContract(address,bool)" <ORACLE_MANAGER_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize OpenWorkRewardsContract
source .env && cast send <GENESIS_PROXY> "authorizeContract(address,bool)" <REWARDS_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 2. OpenWorkRewardsContract

**Type:** Rewards/payment distribution

**Init Params Set:**
- `owner`
- `jobContract` (NOWJC)
- `genesis`

**Required Configuration:**
```bash
# Set ProfileGenesis
source .env && cast send <REWARDS_PROXY> "setProfileGenesis(address)" <PROFILE_GENESIS_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set NativeDAO
source .env && cast send <REWARDS_PROXY> "setNativeDAO(address)" <NATIVE_DAO_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 3. NOWJC (NativeOpenWorkJobContract)

**Type:** Core job lifecycle management

**Init Params Set:**
- `owner`
- `bridge`
- `genesis`
- `rewardsContract`
- `usdcToken`
- `cctpReceiver`

**Required Configuration:**
```bash
# Set Admin
source .env && cast send <NOWJC_PROXY> "setAdmin(address,bool)" <ADMIN_ADDRESS> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set CCTP Transceiver
source .env && cast send <NOWJC_PROXY> "setCCTPTransceiver(address)" <CCTP_TRANSCEIVER> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set NativeAthena
source .env && cast send <NOWJC_PROXY> "setNativeAthena(address)" <NATIVE_ATHENA_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set NativeDAO
source .env && cast send <NOWJC_PROXY> "setNativeDAO(address)" <NATIVE_DAO_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set Treasury
source .env && cast send <NOWJC_PROXY> "setTreasury(address)" <TREASURY_ADDRESS> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NativeChainBridge
source .env && cast send <NOWJC_PROXY> "addAuthorizedContract(address)" <NATIVE_BRIDGE> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize Owner/Admin
source .env && cast send <NOWJC_PROXY> "addAuthorizedContract(address)" <ADMIN_ADDRESS> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 4. NativeChainBridge

**Type:** LayerZero OApp for cross-chain messaging

**Constructor Params Set:**
- `endpoint` (LZ V2)
- `owner`
- `mainChainEid`

**Required Configuration:**
```bash
# Set NativeDAO Contract
source .env && cast send <NATIVE_BRIDGE> "setNativeDaoContract(address)" <NATIVE_DAO_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set NativeAthena Contract
source .env && cast send <NATIVE_BRIDGE> "setNativeAthenaContract(address)" <NATIVE_ATHENA_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set NativeOpenWorkJobContract
source .env && cast send <NATIVE_BRIDGE> "setNativeOpenWorkJobContract(address)" <NOWJC_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set Profile Manager
source .env && cast send <NATIVE_BRIDGE> "setProfileManager(address)" <PROFILE_MANAGER_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NOWJC
source .env && cast send <NATIVE_BRIDGE> "authorizeContract(address,bool)" <NOWJC_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Add Local Chain (for each local chain EID)
source .env && cast send <NATIVE_BRIDGE> "addLocalChain(uint32)" <LOCAL_CHAIN_EID> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set Peer (for cross-chain - needs remote chain bridge address as bytes32)
source .env && cast send <NATIVE_BRIDGE> "setPeer(uint32,bytes32)" <REMOTE_EID> <REMOTE_BRIDGE_BYTES32> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 5. CCTPv2Transceiver

**Type:** Circle CCTP V2 integration for USDC transfers

**Constructor Params Set:**
- `tokenMessenger`
- `messageTransmitter`
- `usdc`

**Required Configuration:**
```bash
# Set NOWJC (for receiving USDC payments)
source .env && cast send <CCTP_TRANSCEIVER> "setNOWJC(address)" <NOWJC_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set destination domain (for cross-chain - needs remote chain CCTP domain)
source .env && cast send <CCTP_TRANSCEIVER> "setDestinationDomain(uint32,uint32)" <CHAIN_ID> <CCTP_DOMAIN> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 6. NativeDAO

**Type:** Governance and fee management

**Init Params Set:**
- `owner`
- `bridge`
- `genesis`

**Required Configuration:**
```bash
# Set NOWJ Contract
source .env && cast send <NATIVE_DAO_PROXY> "setNOWJContract(address)" <NOWJC_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set Admin
source .env && cast send <NATIVE_DAO_PROXY> "setAdmin(address,bool)" <ADMIN_ADDRESS> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NativeBridge (for cross-chain stake sync)
source .env && cast send <NATIVE_DAO_PROXY> "addAuthorizedContract(address)" <NATIVE_BRIDGE> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set ActivityTracker
source .env && cast send <NATIVE_DAO_PROXY> "setActivityTracker(address)" <ACTIVITY_TRACKER_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 7. NativeAthena

**Type:** AI-powered dispute resolution

**Init Params Set:**
- `owner`
- `daoContract`
- `genesis`
- `nowjContract`
- `usdcToken`

**Required Configuration:**
```bash
# Set Oracle Manager
source .env && cast send <NATIVE_ATHENA_PROXY> "setOracleManager(address)" <ORACLE_MANAGER_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set Bridge
source .env && cast send <NATIVE_ATHENA_PROXY> "setBridge(address)" <NATIVE_BRIDGE> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set Admin
source .env && cast send <NATIVE_ATHENA_PROXY> "setAdmin(address,bool)" <ADMIN_ADDRESS> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set ActivityTracker
source .env && cast send <NATIVE_ATHENA_PROXY> "setActivityTracker(address)" <ACTIVITY_TRACKER_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 8. NativeAthenaOracleManager

**Type:** Oracle management for Athena

**Init Params Set:**
- `owner`
- `genesis`
- `nativeAthena`

**Required Configuration:**
```bash
# Set Authorized Caller (NativeAthena)
source .env && cast send <ORACLE_MANAGER_PROXY> "setAuthorizedCaller(address,bool)" <NATIVE_ATHENA_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Set ActivityTracker
source .env && cast send <ORACLE_MANAGER_PROXY> "setActivityTracker(address)" <ACTIVITY_TRACKER_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 9. ProfileGenesis (Storage Contract)

**Type:** Pure storage contract for profile data

**Init Params Set:**
- `owner`

**Required Configuration:**
```bash
# Authorize ProfileManager
source .env && cast send <PROFILE_GENESIS_PROXY> "authorizeContract(address,bool)" <PROFILE_MANAGER_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 10. ProfileManager

**Type:** Profile management logic

**Init Params Set:**
- `owner`
- `bridge`
- `genesis` (should be ProfileGenesis, not OpenworkGenesis)

**Required Configuration:**
```bash
# Set Genesis to ProfileGenesis (if incorrectly set during init)
source .env && cast send <PROFILE_MANAGER_PROXY> "setGenesis(address)" <PROFILE_GENESIS_PROXY> --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

### 11. ActivityTracker

**Type:** Oracle member activity tracking

**Init Params Set:**
- `owner`

**Required Configuration:**
```bash
# Authorize NativeAthena as caller
source .env && cast send <ACTIVITY_TRACKER_PROXY> "setAuthorizedCaller(address,bool)" <NATIVE_ATHENA_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize NativeDAO as caller
source .env && cast send <ACTIVITY_TRACKER_PROXY> "setAuthorizedCaller(address,bool)" <NATIVE_DAO_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

# Authorize OracleManager as caller
source .env && cast send <ACTIVITY_TRACKER_PROXY> "setAuthorizedCaller(address,bool)" <ORACLE_MANAGER_PROXY> true --rpc-url $RPC_URL --private-key $DEPLOYER_KEY
```

**Status:** -

---

## Configuration Order

Recommended order for configuration:

1. **Storage contracts authorize consumers:**
   - OpenworkGenesis → authorize all writing contracts
   - ProfileGenesis → authorize ProfileManager

2. **Set cross-references:**
   - OpenWorkRewardsContract.setProfileGenesis()
   - OpenWorkRewardsContract.setNativeDAO()
   - NativeDAO.setNOWJContract()
   - NativeDAO.setActivityTracker()
   - NativeAthena.setOracleManager()
   - NativeAthena.setBridge()
   - NativeAthena.setActivityTracker()
   - OracleManager.setActivityTracker()

3. **Bridge configuration:**
   - NativeChainBridge.setNativeDaoContract()
   - NativeChainBridge.setNativeAthenaContract()
   - NativeChainBridge.setNativeOpenWorkJobContract()
   - NativeChainBridge.setProfileManager()
   - NativeChainBridge.addLocalChain()
   - CCTPv2Transceiver.setNOWJC()

4. **ActivityTracker configuration:**
   - ActivityTracker.setAuthorizedCaller(NativeAthena)
   - ActivityTracker.setAuthorizedCaller(NativeDAO)
   - ActivityTracker.setAuthorizedCaller(OracleManager)

5. **Cross-chain (after remote deployment):**
   - NativeChainBridge.setPeer()
   - CCTPv2Transceiver.setDestinationDomain()

---

## Verification Commands

After configuration, verify state:

```bash
# Check OpenworkGenesis authorization
cast call <GENESIS_PROXY> "authorizedContracts(address)" <NOWJC_PROXY> --rpc-url $RPC_URL

# Check RewardsContract profileGenesis
cast call <REWARDS_PROXY> "profileGenesis()" --rpc-url $RPC_URL

# Check RewardsContract nativeDAO
cast call <REWARDS_PROXY> "nativeDAO()" --rpc-url $RPC_URL

# Check NativeDAO activityTracker
cast call <NATIVE_DAO_PROXY> "activityTracker()" --rpc-url $RPC_URL

# Check NativeAthena activityTracker
cast call <NATIVE_ATHENA_PROXY> "activityTracker()" --rpc-url $RPC_URL

# Check ActivityTracker authorizedCallers
cast call <ACTIVITY_TRACKER_PROXY> "authorizedCallers(address)" <NATIVE_ATHENA_PROXY> --rpc-url $RPC_URL
```
