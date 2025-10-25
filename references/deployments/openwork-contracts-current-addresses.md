# OpenWork System - Current Contract Addresses

**Last Updated**: October 25, 2025  
**Registry**: `0x8AbC0E626A8fC723ec6f27FE8a4157A186D5767D` (Arbitrum Sepolia)  
**Standard Deployer**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)

## Arbitrum Sepolia (Native Chain)

| Contract | Address | File Path | Verified |
|----------|---------|-----------|----------|
| **Native Athena** (Proxy) | `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-upg-dao-refund-fees-multi-dispute-voting period fix.sol` | ✅ |
| **Native Athena** (Implementation) | `0xf360c9a73536a1016d1d35f80f2333a16fb2a4d2` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-athena.sol` | ✅ |
| **Oracle Manager** (Proxy) | `0x70F6fa515120efeA3e404234C318b7745D23ADD4` | - | ✅ |
| **Oracle Manager** (Implementation) | `0xAdf1d61e5DeD34fAF507C8CEF24cdf46f46bF537` | - | ✅ |
| **NOWJC** (Proxy) | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/nowjc.sol` | ✅ |
| **NOWJC** (Implementation - Commission) | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 19 Oct/nowjc-commision.sol` | ✅ |
| **NOWJC** (Previous Implementation) | `0x9774723857b2bc0e3c353f6d0bb8b90f6e181604` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /nowjc-uncommented-apply-direct-job.sol` | 🔄 |
| **Native Bridge** | `0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-bridge-upgrade-fix.sol` | ✅ |
| **Native DAO** (Proxy) | `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5` | `src/openwork-full-contract-suite-layerzero+CCTP/native-dao-final.sol` | ✅ |
| **Native DAO** (Implementation) | `0x18d2eC7459eFf0De9495be21525E0742890B5065` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-dao.sol` | ✅ |
| **Native Rewards** (Proxy) | `0x1e6c32ad4ab15acd59c66fbcdd70cc442d64993e` | `src/openwork-full-contract-suite-layerzero+CCTP/native-rewards-final.sol` | ✅ |
| **Native Rewards** (Implementation) | `0xb2F64821EDde6d0c0AAD6B71945F94dEF928f363` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-rewards-profile-genesis.sol` | ✅ |
| **Native Rewards** (Previous Implementation) | `0x91852bbe9D41F329D1641C0447E0c2405825a95E` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-rewards.sol` | 🔄 |

### Modular Genesis Architecture (October 22, 2025) ✨

**Latest**: Split genesis into specialized UUPS contracts with batch getters

| Contract | Address | File Path | Verified |
|----------|---------|-----------|----------|
| **OpenworkGenesis** (Implementation) | `0xC1b2CC467f9b4b7Be3484a3121Ad6a8453dfB584` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 19 Oct/openwork-genesis-getAllOracles.sol` | ✅ |
| **OpenworkGenesis** (Proxy) | `0x1f23683C748fA1AF99B7263dea121eCc5Fe7564C` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 19 Oct/proxy.sol` | ✅ |
| **ProfileGenesis** (Implementation) | `0x16481537d0Bff65e591D3D44f6F4C38Fb8579d5d` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 19 Oct/profile-genesis-getallprofiles.sol` | ✅ |
| **ProfileGenesis** (Proxy) | `0xC37A9dFbb57837F74725AAbEe068f07A1155c394` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 19 Oct/proxy.sol` | ✅ |

**Features**: Jobs/Oracles/DAO (OpenworkGenesis) + Profiles/Ratings (ProfileGenesis) with efficient batch getters

### Legacy Genesis Contracts

| Contract | Address | File Path | Verified |
|----------|---------|-----------|----------|
| **Genesis Contract** (OLD - Use OpenworkGenesis) | `0xB4f27990af3F186976307953506A4d5759cf36EA` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /openwork-genesis.sol` | 🔄 |
| **ProfileGenesis** (OLD - Use new modular version) | `0xB3db1eFBd0180921Fb4d93B8BdaC7d55ee49175C` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /profile-genesis.sol` | 🔄 |
| **Contract Registry** | `0x8AbC0E626A8fC723ec6f27FE8a4157A186D5767D` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /openwork-contract-registry.sol` | ✅ |
| **New Native Bridge** | `0xd0b987355d7Bb6b1bC45C21b74F9326f239e9cfA` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-bridge-direct-job.sol` | ⚠️ (OLD) |
| **Native Bridge with ProfileManager** | `0x0422757839F37dcC1652b10843A5Ca1992489ADe` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-bridge-profile-manager.sol` | 🔄 |
| **Profile Editing Native Bridge** (NEW) | `0xE06D84d3941AB1f0c7A1d372d44293432208cb05` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-bridge-profile-edit.sol` | ✅ |
| **DirectContractManager** (Simple) | `0xa53B51eE6a66f1840935929a471B6E8B49C5f842` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /direct-contract-manager-simple.sol` | ⚠️ |
| **DirectContractManager** (Implementation) | `0x022AF2f70b3Eb0b09ab9410D023Bc05492989b76` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /direct-contract-manager.sol` | ⚠️ |
| **DirectContractManager** (Proxy) | `0xB5612e59C99ECd4BE9D5A8ee0fC1C513575CA238` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /proxy.sol` | ⚠️ |
| **ProfileManager** (Proxy) | `0xFc4dA60Ea9D88B81a894CfbD5941b7d0E3fEe401` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /proxy.sol` | ✅ |
| **ProfileManager** (Implementation) | `0x30aAA1f297711d10dFeC015704320Cf823DA5130` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /profile-manager-edit.sol` | ✅ |
| **ProfileManager** (Previous Implementation) | `0xB8C558B44f525212DD4895Aec614ED28ee344dd1` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /profile-manager.sol` | 🔄 |

## OP Sepolia (Local Chain)

| Contract | Address | File Path | Verified |
|----------|---------|-----------|----------|
| **LOWJC** (Proxy) | `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | ✅ |
| **LOWJC** (Implementation) | `0x2072AA3Fcdb7E393450896E2A4D44415922cF2d5` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc-profile-edit.sol` | ✅ |
| **LOWJC** (Previous Implementation) | `0xea2690d680a7f2bd35c504e15c4a4a97cfd77ca4` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc-fixed-milestone-inc-direct-job.sol` | 🔄 |
| **Local Bridge** | `0x6601cF4156160cf43fd024bac30851d3ee0F8668` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/local-bridge-upgrade-fix.sol` | ✅ |
| **Athena Client** (Proxy) | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | ✅ |
| **Athena Client** (Implementation) | `0xBccbf9633a42ACF4213a95f17B844B27408b2A21` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | ✅ |

## Base Sepolia (Main Chain)

| Contract | Address | File Path | Verified |
|----------|---------|-----------|----------|
| **OpenWork Token** | `0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /openwork-token.sol` | ✅ |
| **Main Chain Bridge** | `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` | `src/openwork-full-contract-suite-layerzero+CCTP/main-chain-bridge-final.sol` | ✅ |
| **Cross-Chain Rewards** (Proxy) | `0xd6bE0C187408155be99C4e9d6f860eDDa27b056B` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/main-rewards.sol` | ✅ |
| **Cross-Chain Rewards** (Implementation) | `0x58c1EA0d278252e8F48C46F470b601FcbF779346` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/main-rewards.sol` | ✅ |
| **Main DAO** (Proxy) | `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465` | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | ✅ |
| **Main DAO** (Implementation) | `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4` | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | ✅ |

## Ethereum Sepolia (Local Chain) - NEW DEPLOYMENT

**⚠️ Note**: These are the NEW correctly deployed addresses with WALL2 as deployer (October 9, 2025)

| Contract | Address | File Path | Verified |
|----------|---------|-----------|----------|
| **Local Bridge** | `0xb9AD7758d2B5c80cAd30b471D07a8351653d24eb` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /local-bridge.sol` | ⚠️ |
| **CCTPv2 Transceiver** | `0x6DB4326E2CD04481A7F558B40eb223E13c6C6e98` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /cctp-v2-ft-transceiver.sol` | ⚠️ |
| **Athena Client** (Implementation) | `0x3da42f82241977516568702E24B23989DD7c5fFD` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /athena-client.sol` | ⚠️ |
| **Athena Client** (Proxy) | `0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /proxy.sol` | ⚠️ |
| **LOWJC** (Implementation) | `0xB1C38C374e8589B7172541C678075FE31ca1044C` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc.sol` | ⚠️ |
| **LOWJC** (Proxy) | `0x3b4cE6441aB77437e306F396c83779A2BC8E5134` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /proxy.sol` | ⚠️ |

## Infrastructure

| Service | Address | Chain | Purpose |
|---------|---------|-------|---------|
| **USDC Token** | `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d` | Arbitrum Sepolia | Native chain USDC |
| **USDC Token** | `0x5fd84259d66cd46123540766be93dfe6d43130d7` | OP Sepolia | Local chain USDC |
| **USDC Token** | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | Ethereum Sepolia | Local chain USDC |
| **CCTP Transceiver** | `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063` | Arbitrum Sepolia | Cross-chain USDC |

## Registry Access

**View All Contracts**:
```solidity
// Get all registered contracts
ContractInfo[] memory contracts = IOpenworkRegistry(0x8AbC0E626A8fC723ec6f27FE8a4157A186D5767D).getAllContracts();

// Get specific contract
ContractInfo memory contract = IOpenworkRegistry(0x8AbC0E626A8fC723ec6f27FE8a4157A186D5767D).getContract("Native Athena Proxy");
```

**Total Contracts**: 26 contracts across 4 chains  
**All deployed by**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)

## Direct Contract Feature (October 17, 2025)

**Latest Deployment**: UUPS DirectContractManager with cross-chain orchestration capability

### **Feature Components**:
- **New Native Bridge**: Routes "startDirectContract" messages to DirectContractManager
- **DirectContractManager (Simple)**: Non-UUPS version for testing
- **DirectContractManager (UUPS)**: Production-ready upgradeable version
- **Updated LOWJC**: Includes `startDirectContract()` function

### **Cross-Chain Flow**:
```
LOWJC (OP Sepolia) → LayerZero → New Native Bridge (Arbitrum) → DirectContractManager → NOWJC
```

### **Authorization Requirements**:
- DirectContractManager authorized in NOWJC: ✅
- DirectContractManager authorized in Genesis: ✅
- Bridge addresses configured correctly: ✅

## Profile Editing Feature (October 19, 2025)

**Latest Deployment**: Complete profile editing system with cross-chain support

### **New Feature Components**:
- **ProfileGenesis**: Dedicated contract for profile/portfolio/rating data only
- **Profile Editing Native Bridge**: Enhanced bridge supporting profile edit messages
- **Enhanced ProfileManager**: Added profile editing functions (updateProfile, updatePortfolioItem, removePortfolioItem)
- **Enhanced LOWJC**: User-facing profile editing functions with cross-chain messaging
- **Enhanced Native Rewards**: Dual Genesis support (ProfileGenesis + old Genesis)

### **Cross-Chain Profile Edit Flow**:
```
LOWJC (OP Sepolia) → Local Bridge → Profile Editing Native Bridge (Arbitrum) → ProfileManager → ProfileGenesis
```

### **Architecture Changes**:
- **ProfileManager**: Now points to ProfileGenesis instead of old Genesis
- **Native Rewards**: Uses ProfileGenesis for referrer data, old Genesis for platform data
- **Clean Separation**: Profile data (ProfileGenesis) vs. Job/Oracle data (old Genesis)

### **Available Profile Editing Functions**:
1. `updateProfile(string newIpfsHash)` - Update main profile IPFS hash
2. `updatePortfolioItem(uint256 index, string newHash)` - Update specific portfolio item
3. `removePortfolioItem(uint256 index)` - Remove portfolio item
4. `addPortfolio(string portfolioHash)` - Add new portfolio item (existing)

### **Rollback Safety**:
All previous implementations preserved for emergency rollback:
- ProfileManager: `0xB8C558B44f525212DD4895Aec614ED28ee344dd1` 🔄
- LOWJC: `0xea2690d680a7f2bd35c504e15c4a4a97cfd77ca4` 🔄  
- Native Rewards: `0x91852bbe9D41F329D1641C0447E0c2405825a95E` 🔄

**Legend**: ✅ Active | 🔄 Previous Version | ⚠️ Deprecated

## Modular Genesis Architecture (October 22, 2025)

**New Deployment**: Split monolithic genesis into specialized UUPS upgradeable contracts with batch getters

### Architecture Overview:
```
OLD: Single Genesis Contract (all data in one place)
     ├── Profiles, Portfolios, Ratings
     ├── Jobs, Applications  
     ├── Oracles
     ├── Disputes, Voting
     ├── DAO Data
     └── Rewards

NEW: Modular Genesis (specialized contracts)
     ├── ProfileGenesis (Profiles + Ratings + Batch Getters)
     └── OpenworkGenesis (Jobs + Oracles + DAO + Batch Getters)
```

### Key Benefits:
- ✅ **Batch Getters**: Efficient pagination for profiles (`getAllProfileAddresses`, `getProfileAddressesBatch`) and oracles (`getAllOracleNames`, `getOracleNamesBatch`)
- ✅ **Modular Design**: Cleaner separation of concerns
- ✅ **Gas Optimization**: Smaller contracts = better optimization
- ✅ **Independent Upgrades**: Update profiles without affecting job data
- ✅ **Better Scalability**: Each domain can grow independently

### Integration Status:

**OpenworkGenesis Connections:**
- ✅ NOWJC → OpenworkGenesis (connected & authorized)
- ✅ Native Athena → OpenworkGenesis (connected & authorized)
- ✅ Oracle Manager → OpenworkGenesis (connected & authorized)
- ✅ Native DAO → OpenworkGenesis (connected & authorized)
- ✅ Native Rewards → OpenworkGenesis (connected & authorized)

**ProfileGenesis Connections:**
- ✅ ProfileManager ↔ ProfileGenesis (bidirectional, fully integrated)

### Data Migration Status:
- ✅ **Profiles**: 3 profiles migrated (WALL2 + 2 test wallets)
- ✅ **Oracles**: 2 oracles migrated ("General", "TestOracle")
- ⏳ **Jobs**: Migration pending (5 jobs identified)

### Deployment Details:
- **Deployment Date**: October 22, 2025, 8:20 AM IST
- **Deployer**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)
- **Full Documentation**: `references/deployments/genesis-contracts-deployment-22-oct.md`

### Emergency Rollback:
All contracts maintain references to previous implementations for quick rollback if needed.
