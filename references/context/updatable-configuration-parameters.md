# Updatable Configuration Parameters - All Contracts

**Last Updated**: November 29, 2025  
**Purpose**: Comprehensive list of all configurable parameters that can be updated post-deployment

---

## 🏛️ **MAIN DAO** (Base Sepolia)
**Contract**: `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465`

### Governance Parameters
| Parameter | Type | Update Function | Updated By | Current/Default Value |
|-----------|------|-----------------|------------|----------------------|
| `proposalThresholdAmount` | uint256 | `updateProposalThreshold()` | onlyGovernance | 100 * 10^18 OW |
| `votingThresholdAmount` | uint256 | `updateVotingThreshold()` | onlyGovernance | 50 * 10^18 OW |
| `unstakeDelay` | uint256 | `updateUnstakeDelay()` | onlyGovernance | 24 hours |

### Contract References
| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `bridge` | address | `setBridge()` | onlyOwner |
| `openworkToken` | address | N/A | Set on init only |

---

## 🏛️ **NATIVE DAO** (Arbitrum Sepolia)
**Contract**: `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5`

### Governance Thresholds
| Parameter | Type | Update Function | Updated By | Default Value |
|-----------|------|-----------------|------------|---------------|
| `proposalStakeThreshold` | uint256 | `updateProposalStakeThreshold()` | onlyGovernance | 100 * 10^18 |
| `votingStakeThreshold` | uint256 | `updateVotingStakeThreshold()` | onlyGovernance | 50 * 10^18 |
| `proposalRewardThreshold` | uint256 | `updateProposalRewardThreshold()` | onlyGovernance | 100 * 10^18 |
| `votingRewardThreshold` | uint256 | `updateVotingRewardThreshold()` | onlyGovernance | 100 * 10^18 |

### Contract References
| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `nowjContract` | address | `setNOWJContract()` | onlyOwner |
| `bridge` | address | `setBridge()` | onlyOwner |
| `genesis` | address | `setGenesis()` | onlyOwner |

---

## ⚖️ **NATIVE ATHENA** (Arbitrum Sepolia)
**Contract**: `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd`

### Voting Configuration
| Parameter | Type | Update Function | Updated By | Default Value |
|-----------|------|-----------------|------------|---------------|
| `minOracleMembers` | uint256 | `updateMinOracleMembers()` | onlyOwner | 3 |
| `votingPeriodMinutes` | uint256 | `updateVotingPeriod()` | onlyOwner | 60 minutes |
| `minStakeRequired` | uint256 | `updateMinStakeRequired()` | onlyOwner | 100 |
| `memberActivityThresholdDays` | uint256 | `updateMemberActivityThreshold()` | onlyOwner | 90 days |

### Contract References
| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `genesis` | address | `setGenesis()` | onlyOwner |
| `nowjContract` | address | `setNOWJContract()` | onlyOwner |
| `oracleManager` | address | `setOracleManager()` | onlyOwner |
| `daoContract` | address | `setDAOContract()` | onlyOwner |
| `usdcToken` | address | `setUSDCToken()` | onlyOwner |
| `bridge` | address | `setBridge()` | onlyOwner |

---

## 💼 **NOWJC** (Arbitrum Sepolia)
**Contract**: `0x9E39B37275854449782F1a2a4524405cE79d6C1e`

### Commission Settings
| Parameter | Type | Update Function | Updated By | Current Value |
|-----------|------|-----------------|------------|---------------|
| `commissionPercentage` | uint256 | `setCommissionPercentage()` | onlyOwner | 100 (1%) |
| `minCommission` | uint256 | `setMinCommission()` | onlyOwner | 1e6 (1 USDC) |
| `treasury` | address | `setTreasury()` | onlyOwner | - |

### Contract References
| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `bridge` | address | `setBridge()` | onlyOwner |
| `genesis` | address | `setGenesis()` | onlyOwner |
| `rewardsContract` | address | `setRewardsContract()` | onlyOwner |
| `usdtToken` | address | `setUSDTToken()` | onlyOwner |
| `cctpReceiver` | address | `setCCTPReceiver()` | onlyOwner |
| `cctpTransceiver` | address | `setCCTPTransceiver()` | onlyOwner |
| `nativeAthena` | address | `setNativeAthena()` | onlyOwner |

---

## 🎁 **NATIVE REWARDS** (Arbitrum Sepolia)
**Contract**: `0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De`

### Reward Bands (Dynamic Management)
| Feature | Update Function | Updated By | Description |
|---------|-----------------|------------|-------------|
| Add Band | `addRewardBand(min, max, rate)` | onlyOwner | Add new reward tier |
| Update Band | `updateRewardBand(index, min, max, rate)` | onlyOwner | Modify existing tier |
| Remove Band | `removeLastRewardBand()` | onlyOwner | Remove last tier |
| Reset All | `resetRewardBands()` | onlyOwner | Emergency reset |
| Clear All | `clearAllRewardBands()` | onlyOwner | Delete all tiers |

**Current**: 20 reward bands with diminishing returns (300 OW/$ → 0.011 OW/$)

### Contract References
| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `jobContract` | address | `setJobContract()` | onlyOwner |
| `genesis` | address | `setGenesis()` | onlyOwner |
| `profileGenesis` | address | `setProfileGenesis()` | onlyOwner |

---

## 💰 **MAIN REWARDS** (Base Sepolia)
**Contract**: `0xd6bE0C187408155be99C4e9d6f860eDDa27b056B`

### Contract References
| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `bridge` | address | `setBridge()` | onlyOwner |
| `openworkToken` | address | `setOpenworkToken()` | onlyOwner |
| `mainDAO` | address | `setMainDAO()` | onlyOwner |

### Authorized Chains
| Feature | Update Function | Updated By |
|---------|-----------------|------------|
| `authorizedChains` | `updateAuthorizedChain(chainEid, bool, name)` | onlyOwner |

---

## 🌉 **BRIDGES**

### Main Chain Bridge (Base Sepolia)
**Contract**: `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `nativeChainEid` | uint32 | `updateNativeChainEid()` | onlyOwner |
| `athenaClientChainEid` | uint32 | `updateAthenaClientChainEid()` | onlyOwner |
| `lowjcChainEid` | uint32 | `updateLowjcChainEid()` | onlyOwner |
| `mainDaoContract` | address | `setMainDaoContract()` | onlyOwner |
| `rewardsContract` | address | `setRewardsContract()` | onlyOwner |

### Native Bridge (Arbitrum Sepolia)
**Contract**: `0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `mainChainEid` | uint32 | `updateMainChainEid()` | onlyOwner |
| `localChainEids` | uint32[] | `addLocalChain()`, `removeLocalChain()` | onlyOwner |
| `nativeDaoContract` | address | `setNativeDaoContract()` | onlyOwner |
| `nativeAthenaContract` | address | `setNativeAthenaContract()` | onlyOwner |
| `nativeOpenWorkJobContract` | address | `setNativeOpenWorkJobContract()` | onlyOwner |
| `directContractManager` | address | `setDirectContractManager()` | onlyOwner |
| `profileManager` | address | `setProfileManager()` | onlyOwner |

### Local Bridge (OP/ETH Sepolia)
**Contract**: `0x6601cF4156160cf43fd024bac30851d3ee0F8668`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `nativeChainEid` | uint32 | `updateNativeChainEid()` | onlyOwner |
| `mainChainEid` | uint32 | `updateMainChainEid()` | onlyOwner |
| `thisLocalChainEid` | uint32 | `updateThisLocalChainEid()` | onlyOwner |
| `athenaClientContract` | address | `setAthenaClientContract()` | onlyOwner |
| `lowjcContract` | address | `setLowjcContract()` | onlyOwner |

---

## 🔧 **LOCAL CHAIN CONTRACTS**

### LOWJC (OP Sepolia)
**Contract**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `usdtToken` | address | `setUSDTToken()` | onlyOwner |
| `bridge` | address | `setBridge()` | onlyOwner |
| `cctpSender` | address | `setCCTPSender()` | onlyOwner |
| `cctpMintRecipient` | address | `setCCTPMintRecipient()` | onlyOwner |
| `athenaClientContract` | address | `setAthenaClientContract()` | onlyOwner |

### Athena Client (OP Sepolia)
**Contract**: `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `minDisputeFee` | uint256 | `setMinDisputeFee()` | onlyOwner |
| `bridge` | address | `setBridge()` | onlyOwner |
| `jobContract` | address | `setJobContract()` | onlyOwner |
| `cctpSender` | address | `setCCTPSender()` | onlyOwner |
| `nativeAthenaRecipient` | address | `setNativeAthenaRecipient()` | onlyOwner |
| `nativeChainDomain` | uint32 | `setNativeChainDomain()` | onlyOwner |

---

## 👤 **PROFILE MANAGER** (Arbitrum Sepolia)
**Contract**: `0xFc4dA60Ea9D88B81a894CfbD5941b7d0E3fEe401`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `bridge` | address | `setBridge()` | onlyOwner |
| `genesis` | address | `setGenesis()` | onlyOwner |

---

## 🔮 **ORACLE MANAGER** (Arbitrum Sepolia)
**Contract**: `0x70F6fa515120efeA3e404234C318b7745D23ADD4`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `genesis` | address | `setGenesis()` | onlyOwner |
| `nativeAthena` | address | `setNativeAthena()` | onlyOwner |
| `authorizedCallers` | mapping | `setAuthorizedCaller(address, bool)` | onlyOwner |

---

## 📦 **GENESIS CONTRACTS**

### OpenworkGenesis (Arbitrum Sepolia)
**Contract**: `0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `authorizedContracts` | mapping | `authorizeContract(address, bool)` | onlyOwner |
| `owner` | address | `transferOwnership(address)` | onlyOwner |

### ProfileGenesis (Arbitrum Sepolia)
**Contract**: `0xC37A9dFbb57837F74725AAbEe068f07A1155c394`

| Parameter | Type | Update Function | Updated By |
|-----------|------|-----------------|------------|
| `authorizedContracts` | mapping | `authorizeContract(address, bool)` | onlyOwner |
| `owner` | address | `transferOwnership(address)` | onlyOwner |

---

## 🪙 **OPENWORK TOKEN** (Base Sepolia)
**Contract**: `0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679`

**Note**: No updatable parameters - standard ERC20Votes token
- Only minting allowed (owner only)
- Total supply starts at 1B tokens

---

## 💳 **CCTP TRANSCEIVER** (Arbitrum Sepolia)
**Contract**: `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063`

**Note**: Immutable contract - no updatable parameters
- All CCTP addresses set in constructor
- Cannot be modified post-deployment

---

## 📋 **SUMMARY BY CATEGORY**

### **Governance Parameters (DAO Controlled)**
1. **Main DAO**:
   - Proposal threshold (min OW to propose)
   - Voting threshold (min OW to vote)
   - Unstake delay period

2. **Native DAO**:
   - Proposal stake threshold
   - Voting stake threshold
   - Proposal reward threshold
   - Voting reward threshold

### **Voting/Dispute Parameters (Owner Controlled)**
1. **Native Athena**:
   - Min oracle members required
   - Voting period duration
   - Min stake for voting
   - Oracle activity threshold

2. **Athena Client**:
   - Minimum dispute fee
   - Native chain domain (CCTP)

### **Economic Parameters (Owner Controlled)**
1. **NOWJC**:
   - Commission percentage (currently 1%)
   - Minimum commission (1 USDC)
   - Treasury address

2. **Native Rewards**:
   - Reward band structure (20 bands)
   - Can add/update/remove bands dynamically

### **Cross-Chain Parameters (Owner Controlled)**
1. **All Bridges**:
   - Chain endpoint IDs (LayerZero)
   - Contract addresses for routing

2. **Main Rewards**:
   - Authorized chains (can add/remove)

### **Contract References (Owner Controlled)**
**Every contract** can update its references to other contracts:
- Bridge addresses
- Genesis addresses
- DAO addresses
- Token addresses
- CCTP addresses

---

## 🔐 **ACCESS CONTROL SUMMARY**

### Parameters Updated By **Governance** (Proposal Required)
- Main DAO: proposal/voting thresholds, unstake delay
- Native DAO: all stake/reward thresholds

### Parameters Updated By **Owner** (Direct Control)
- Native Athena: all voting rules
- NOWJC: commission rates, treasury
- Rewards: reward band management
- All bridges: chain endpoints
- All contracts: contract references

### Immutable Values (Cannot Change)
- Token addresses (once set)
- CCTP infrastructure addresses
- Initial supply values
- Contract logic (requires upgrade, not parameter update)

---

## 📊 **CRITICAL VALUES TO MONITOR**

### **User Impact**
1. DAO voting thresholds (affects who can participate)
2. Voting period (affects how long users can vote)
3. Commission rates (affects payment amounts)
4. Unstake delay (affects withdrawal timing)

### **System Stability**
1. Min oracle members (affects dispute resolution availability)
2. Oracle activity threshold (affects oracle active status)
3. Reward bands (affects token distribution)
4. Chain endpoints (affects cross-chain messaging)

### **Economic Model**
1. Commission percentage (platform revenue)
2. Reward band rates (token inflation)
3. Min stake requirements (governance participation barrier)

---

## 🛠️ **BEST PRACTICES**

### Before Updating Parameters:
1. **Test on testnet** with various scenarios
2. **Calculate impact** on existing users
3. **Document reasoning** for the change
4. **Notify community** if governance-related
5. **Have rollback plan** if needed

### Governance Changes:
- Require proposal + voting period
- Higher scrutiny than owner changes
- Affect core platform economics

### Owner Changes:
- Can be immediate
- Use for technical/operational updates
- Still require testing first

---

## 📝 **FUNCTION CALL EXAMPLES**

### Update DAO Threshold (Governance)
```bash
# Main DAO - requires governance proposal
cast send 0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465 \
  "updateProposalThreshold(uint256)" \
  200000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $GOVERNANCE_KEY
```

### Update Voting Period (Owner)
```bash
# Native Athena
source .env && cast send 0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd \
  "updateVotingPeriod(uint256)" \
  60 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### Update Commission Rate (Owner)
```bash
# NOWJC
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setCommissionPercentage(uint256)" \
  150 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### Add Reward Band (Owner)
```bash
# Native Rewards
source .env && cast send 0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De \
  "addRewardBand(uint256,uint256,uint256)" \
  52428800000000000 \
  104857600000000000 \
  1144409179687500 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## ⚠️ **PARAMETER CONSTRAINTS**

### Main DAO
- `proposalThresholdAmount`: Must be > 0
- `votingThresholdAmount`: Must be > 0
- `unstakeDelay`: No explicit max (use common sense)

### Native Athena
- `minOracleMembers`: Must be ≥ 1 (recommended ≥ 3)
- `votingPeriodMinutes`: Must be > 0 (recommended ≥ 60)
- `minStakeRequired`: Must be > 0
- `memberActivityThresholdDays`: Must be > 0

### NOWJC
- `commissionPercentage`: Max 1000 (10%) - safety cap
- `minCommission`: Must be > 0
- `treasury`: Cannot be zero address

### Native Rewards
- `owPerDollar` in bands: Must be > 0
- Band ranges: Must not overlap
- Band order: Must be sequential

---

**Total Updatable Parameters**: 40+ across all contracts  
**Contracts With Parameters**: 13 of 20 contracts  
**Governance-Controlled**: 7 parameters  
**Owner-Controlled**: 35+ parameters
