# Latest Contract Addresses - Minimal Reference

**Last Updated**: October 5, 2025  
**Status**: Current Active Deployments

## Recent Updates

**October 5, 2025 - Native Athena Cross-Chain Skill Verification Fix**
- **Action**: Fixed Genesis authorization issue preventing cross-chain skill verification
- **Issue**: New Native Athena proxy was not authorized in Genesis contract causing "Not authorized" errors
- **Solution**: Authorized new proxy in Genesis + configured Native Bridge to point to new proxy
- **Working Proxy**: `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd` (Arbitrum Sepolia)
- **Genesis Authorization TX**: `0x94e522791e873e75394a23b52ac1740bdadce88b9179036442deb1a5bdeef4c1`
- **Bridge Config TX**: `0x54cf464957a424797b6ef9d2316c587ea21b61dd8a2b44038ae4a0435c453875`
- **Test TX**: `0x196a14646f506f09e78a5be0bfa6f422916fc9798e94046de9474e583b7b5f4c` (OP Sepolia → Arbitrum)
- **Status**: ✅ **FULLY FUNCTIONAL** - Cross-chain skill verification working

**October 5, 2025 - New Native Athena Proxy Deployment**
- **Action**: Deployed new Native Athena proxy with corrected authorization for cross-chain upgrades
- **Issue**: Original proxy had authorization mismatch preventing bridge upgrades
- **New Proxy**: `0x46C17D706c5D5ADeF0831080190627E9bd234C78` (Arbitrum Sepolia)
- **Implementation**: `0x9Ae25Be5f20A61e84ad417673e94d59feE0Ec6A9` (latest working version)
- **Proxy TX**: `0xa8db49e451671b1944191e2e651533a944b61da3ba143ccb24c31b48170c3875`
- **Initialization TX**: `0x8c61c06b6665a56d5fdc558898705dee89a41a3cb5c50538a31f54804dd25d8c`
- **Bridge Config TX**: `0x8f2b30c4ce6ed47d4bcc8d1dc31f5e4c18046747e466077a95556b3d91946c87`
- **Status**: ⚠️ **SUPERSEDED** - Replaced by working proxy `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd`

**October 5, 2025 - Main Rewards Same-Chain Upgrade Authorization Fix**
- **Action**: Fixed Main Rewards authorization to support both same-chain and cross-chain upgrades
- **Issue**: Contract only allowed bridge upgrades, blocking Main DAO same-chain upgrades
- **Fix**: Added mainDAO authorization to `upgradeFromDAO()` and `_authorizeUpgrade()`
- **Bootstrap Implementation**: `0x3Ab360cfAec87Ad29CF6ffAeB8AA6aa92A1fb7a5` (corrected authorization)
- **Current Implementation**: `0x58c1EA0d278252e8F48C46F470b601FcbF779346` (tested working version)
- **Bootstrap TX**: `0xdefd8f919ce1b3e9fd4daeaf2d487e8cdd9e83bee13cbe929139ea017a419520`
- **Final Upgrade TX**: `0x410c9c317445dfed774c9bebaa438cdaf88fc52e92a64804fc7aa082a0ded566`
- **Status**: ✅ **ACTIVE** - Supports both same-chain and cross-chain upgrades

**October 4, 2025 - Native Athena Dispute Fee Refund Implementation**
- **Action**: Deployed Native Athena with automatic dispute fee refund functionality
- **Feature**: Auto-refund dispute fees when no votes are cast, with cross-chain support
- **Deployment**: New Native Athena implementation `0x4D32ad58f769C96dA500b1f481D9A00Bac528acA`
- **Deployment TX**: `0x421748b7e4b779a9e42936644d3a467361654cb3a0a1543d5bc88484a771cbd4`
- **Upgrade TX**: `0xb32f48d210c3d140446a77c7a875124acfb1f75cbaedc536ef739c88b4c36a31`
- **File Path**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-refund-fees-multi-dispute-voting period fix.sol`

**October 3, 2025 - Native Athena Implementation Update**
- **Action**: Deployed new Native Athena implementation with latest contract suite version
- **Deployment**: New Native Athena implementation `0x85598B4918001476b2B7d9745Cf45DEDF09F385b`
- **Deployment TX**: `0xecfab1d0cbc0dc3db38c0ee7d923f0fef5a385dcf5a420eb37e4ec27c3144042`
- **Upgrade TX**: `0x7ca4a1a28dd6336246c2fcc5f1220e99b4477fd7407fe2a06184e7b33ff7b517`

**October 2, 2025 - NOWJC Application Consistency Fix**
- **Issue**: Race condition in job application duplicate checking causing intermittent failures
- **Fix**: Updated duplicate check logic to use local mapping instead of Genesis array
- **Deployment**: New NOWJC implementation `0xC6F8D5f181D619D3c6156309cb6972160Da00901`
- **Upgrade TX**: `0x44b6e037bbcc963567502877388e6f5afea7818aee142565346af2e097210d36`

**October 2, 2025 - Latest NOWJC Implementation Update (Evening)**
- **Action**: Redeployed NOWJC with latest contract suite version
- **Deployment**: New NOWJC implementation `0x7398476bC21cb9A0D751b63ECc5a76Ce1d2977Ff`
- **Deployment TX**: `0x9b104620fd527c7c5493234e73564a9385d90117b29eb5bd848b490e7f9f6aaf`
- **Upgrade TX**: `0x192ea72d99401faf92906158b7f0c14015d323e0fdc97207b275ef5dd279a6b1`

**October 2, 2025 - Ethereum Sepolia LOWJC Update**
- **Issue**: Missing implementation entry for Ethereum Sepolia LOWJC
- **Action**: Deployed and upgraded to latest LOWJC implementation
- **Deployment**: New LOWJC implementation `0xeb1883f4dbEd1c8F728C112B2D1EA1ec15D3c4fB`
- **Upgrade TX**: `0xad352b89dd2dfc5837b072006a81eab3dbf1744fdf9fecc4603da9d4cdd40b56`

**October 2, 2025 - Latest LOWJC Implementation Updates (Evening)**
- **Action**: Redeployed LOWJC contracts with latest contract suite version
- **Ethereum Sepolia**: New implementation `0x594523C7c846f09d8bc41d7761DD1e478DB40e9F`
- **Ethereum Deployment TX**: `0x2bd44377e1819ccc8581383ea2cdf2e93c2998b2cf12b9515d3b49d2e93a8c9f`
- **Ethereum Upgrade TX**: `0x3c51e467ae94e05f853545b9dfcb0bf31700bdfa4710b892ddd29289b56559c3`
- **OP Sepolia**: New implementation `0x144dabf481d380648590dDf214107457266E7792`
- **OP Deployment TX**: `0x8b5999800cde314128756a44ee5f1d80788ff62b84047b20690dde8fd6b51ac9`
- **OP Upgrade TX**: `0x7d83e27b5341451d4c620a443b57af5f33cdc2109c863e2e3c4b9565cc078eef`

**October 2, 2025 - Second LOWJC Implementation Update (Late Evening)**
- **Action**: Redeployed LOWJC contracts again with latest fixes
- **OP Sepolia**: New implementation `0x1aF480964b074Ca8bae0c19fb0DED4884a459f14`
- **OP Deployment TX**: `0x41ed121906a431fbd8858e706b633dd326dff722d9ce683d606ba281f342a12a`
- **OP Upgrade TX**: `0xe879454d7ab0996bc718d53d0c4c0d2390b5bbf17b8768912c793fc4605efdd9`
- **Ethereum Sepolia**: New implementation `0xE99B5baB1fc02EbD6f1e4a3789079381a40cddD0`
- **Ethereum Deployment TX**: `0xe448bb94fd036eefc0ed3a65802e3c7d0351e212dfcc7eabee1832d942709d4c`
- **Ethereum Upgrade TX**: `0x0a7f5718d37cfc2187caad43645278832ef543e5c7f8418d431742a62e72cba3`

**October 2, 2025 - Ethereum Sepolia Athena Client Deployment**
- **Issue**: Missing Athena Client contracts for Ethereum Sepolia
- **Action**: Deployed complete Athena Client (LocalAthena) with proxy
- **Implementation**: `0xFd59109B4d45bAC4FF649C836C1204CE0D249294`
- **Proxy**: `0xAdE5F9637F1DB4D6773fA49bE43Bc2480040E0dB`
- **Implementation TX**: `0xed2100165767fc1e56488e7a69fe48ed7020a1eb4af3d7c114f7e2e021fa5019`
- **Proxy TX**: `0xd7518f53694aea37120d447d01a2ab65645c6a65bda4182eeffdb6ce6eb25bb1`

## Core Contracts

| Contract | Address | Chain | Deployer | File Path | TX Hash | Verified |
|----------|---------|-------|----------|-----------|---------|---------|
| **🔥 Native Athena** (Proxy) | `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-upg-dao-refund-fees-multi-dispute-voting period fix.sol` | `0x421a014a4248507703c36c49066198d559131573e298b6c20505ff127c2f90d1` | ✅ |
| **Native Athena (Backup)** (Proxy) | `0x46C17D706c5D5ADeF0831080190627E9bd234C78` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-upg-dao-refund-fees-multi-dispute-voting period fix.sol` | `0xa8db49e451671b1944191e2e651533a944b61da3ba143ccb24c31b48170c3875` |
| **🔥 Native Athena** (Implementation) | `0xf360c9a73536a1016d1d35f80f2333a16fb2a4d2` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-athena.sol` | - | ✅ |
| **Native Athena (Legacy)** (Proxy) | `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-refund-fees-multi-dispute-voting period fix.sol` | - |
| **Native Athena (Legacy)** (Implementation) | `0x4D32ad58f769C96dA500b1f481D9A00Bac528acA` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena-refund-fees-multi-dispute-voting period fix.sol` | `0x421748b7e4b779a9e42936644d3a467361654cb3a0a1543d5bc88484a771cbd4` |
| **Oracle Manager** (Proxy) | `0x70F6fa515120efeA3e404234C318b7745D23ADD4` | Arbitrum Sepolia | WALL2 | - | - | ✅ |
| **Oracle Manager** (Implementation) | `0xAdf1d61e5DeD34fAF507C8CEF24cdf46f46bF537` | Arbitrum Sepolia | WALL2 | - | - | ✅ |
| **NOWJC** (Proxy) | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/nowjc.sol` | - | ✅ |
| **NOWJC** (Implementation) | `0x44fb5fD2d48473347715FD1133b55de27B87647F` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /nowjc.sol` | - | ✅ |
| **Native Bridge** (Legacy) | `0xD3614cF325C3b0c06BC7517905d14e467b9867A8` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-bridge.sol` | `0xce43247868f68aef1f7af0ed750e47530867d7338174e391e0db43606cd0d400` |
| **🔥 Native Bridge** (Working) | `0x3b2AC1d1281cA4a1188d9F09A5Af9a9E6a114D6c` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-bridge-upgrade-fix.sol` | `0x4709221a23d74da3f6ed2a45ceeddfe2a7ad01be5022600268750e32f981bdbc` | ✅ |
| **Native DAO** (Proxy) | `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5` | Arbitrum Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/native-dao-final.sol` | - | ✅ |
| **Native DAO** (Implementation) | `0x18d2eC7459eFf0De9495be21525E0742890B5065` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-dao.sol` | - | ✅ |
| **Native Rewards** (Proxy) | `0x1e6c32ad4ab15acd59c66fbcdd70cc442d64993e` | Arbitrum Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/native-rewards-final.sol` | - | ✅ |
| **Native Rewards** (Implementation) | `0x91852bbe9D41F329D1641C0447E0c2405825a95E` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /native-rewards.sol` | - | ✅ |
| **Genesis Contract** | `0xB4f27990af3F186976307953506A4d5759cf36EA` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /openwork-genesis.sol` | `0x1a837ed54caeca6ec5a99ccb997c6121400b27098c539d51cb1f8cf03b9fe457` | ✅ |
| **🔥 OpenWork Contract Registry** | `0x8AbC0E626A8fC723ec6f27FE8a4157A186D5767D` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /openwork-contract-registry.sol` | `0xfac8d64b783c3de1ff853cd88e97c8a7c64e3ce3e378202de98d363dae451cf2` | ✅ |

## Local Chain Contracts

| Contract | Address | Chain | Deployer | File Path | TX Hash | Verified |
|----------|---------|-------|----------|-----------|---------|---------|
| **LOWJC** (Proxy) | `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | - | ✅ |
| **LOWJC** (Implementation) | `0x2eb97f2bb35f8f5b5d31090e9ef1915aaa431966` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc.sol` | - | ✅ |
| **Local Bridge** (Legacy) | `0xaff9967c6000ee6feec04d29a39cc7a4ecff4bc0` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/local-bridge.sol` | - |
| **🔥 Local Bridge** (Working) | `0x6601cF4156160cf43fd024bac30851d3ee0F8668` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/local-bridge-upgrade-fix.sol` | `0xc88c8af5f1bc1e785d902b60bd9d928f8ccdefa802697abdbf6708edfe5cdcaa` | ✅ |
| **Athena Client** (Proxy) | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | - | ✅ |
| **Athena Client** (Implementation) | `0xBccbf9633a42ACF4213a95f17B844B27408b2A21` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | `0xf3b409b0f4df77263d77c764f8b94d757659e75cca917514d8adefa815b31fba` | ✅ |
| **LOWJC** (Proxy) | `0x325c6615Caec083987A5004Ce9110f932923Bd3A` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | - |
| **LOWJC** (Implementation) | `0x0ED13e09658bA8F5D4E6e9bEc1677eA3ecB646A1` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc.sol` | `0xf92f4c7078b76805728d2e0d00361eb98f50812896d45ef17844798570817444` | ✅ |
| **🔥 Local Bridge** (Working) | `0xA7B5EAE830D62E9824612080D3Abf94Ee3600B76` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /local-bridge.sol` | `0xc703aa12e3de9667c7401c43068bdc25c4df5b4fdca6e0b4fd92998ab848c7cd` | ✅ |
| **🔥 Athena Client** (Proxy) | `0x23300f3816eE2eabB1f1dCBeE087233A67818B5d` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /athena-client.sol` | `0xd21ab96ad5c279f5bae047aa0843cb8284c8e839660f9efd5a32986a5d50bcb7` | ✅ |
| **🔥 Athena Client** (Implementation) | `0xC44177cB6a8a45ff83556Cda60Be73e3f77E854c` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /athena-client.sol` | `0x4b7c78945d4fa99db2de1e553289f0eb01b81056a0decdc9cdccbce19d9dec57` | ✅ |
| **Athena Client (Legacy)** (Proxy) | `0xAdE5F9637F1DB4D6773fA49bE43Bc2480040E0dB` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | `0xd7518f53694aea37120d447d01a2ab65645c6a65bda4182eeffdb6ce6eb25bb1` |
| **Athena Client (Legacy)** (Implementation) | `0xFd59109B4d45bAC4FF649C836C1204CE0D249294` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | `0xed2100165767fc1e56488e7a69fe48ed7020a1eb4af3d7c114f7e2e021fa5019` |

## Main Chain Contracts

| Contract | Address | Chain | Deployer | File Path | TX Hash | Verified |
|----------|---------|-------|----------|-----------|---------|---------|
| **OpenWork Token (OW)** | `0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679` | Base Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /openwork-token.sol` | `0x21c2b66d7b56430f636c9f909fc8707aa40d6aae65f6f6009aa74cdb0c69a3d3` | ✅ |
| **Main Chain Bridge** | `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-chain-bridge-final.sol` | `0x79b61edff6e7a417fffa2e70ea5434fd5cb7c3ff1dc989655af396a600bf9ed0` | ✅ |
| **🔥 Cross-Chain Rewards** (Proxy) | `0xd6bE0C187408155be99C4e9d6f860eDDa27b056B` | Base Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/main-rewards.sol` | - | ✅ |
| **🔥 Cross-Chain Rewards** (Implementation) | `0x58c1EA0d278252e8F48C46F470b601FcbF779346` | Base Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/main-rewards.sol` | `0x7df0fbb48700398804240f86c1181735b83b001a73474c386b86da7829331889` | ✅ |
| **Cross-Chain Rewards (Legacy)** (Implementation) | `0x55a0FE495c61d36F4Ac93D440DD13d146fb68f53` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-rewards-final.sol` | `0xb4a7c021669c436a828b4e67757f6e0eb66bde2cbab0095d74760b03c892d5b2` |
| **Main DAO** (Proxy) | `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | `0x3d110d32eae8ef68244de5455751f166f0e09b5e0fc1c2fcdb86586e9c10ef99` | ✅ |
| **Main DAO** (Implementation) | `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | `0x62935cac5f3d411f9d9081e45216e0a2b9b09de6372817b85208d9dacb655d7a` | ✅ |

## Infrastructure

| Service | Address | Chain | Purpose |
|---------|---------|-------|---------|
| **USDC Token** | `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d` | Arbitrum Sepolia | Native chain USDC |
| **USDC Token** | `0x5fd84259d66cd46123540766be93dfe6d43130d7` | OP Sepolia | Local chain USDC |
| **USDC Token** | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | Ethereum Sepolia | Local chain USDC |
| **CCTP Transceiver** | `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063` | Arbitrum Sepolia | Cross-chain USDC | ✅ |
| **CCTP Transceiver** | `0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5` | OP Sepolia | Cross-chain USDC | ✅ |
| **CCTP Transceiver** | `0x65bf76589B9e9B0768181e7b7B8dB1A2d230091d` | Ethereum Sepolia | Cross-chain USDC | ✅ |
| **Message Transmitter** | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` | OP Sepolia | CCTP messaging |
| **Token Messenger** | `0x72d6efedda70f9b4ed3fff4bdd0844655aea2bd5` | OP Sepolia | CCTP sender |

## 🔥 Simplified Bridge Updates - October 5, 2025

### Cross-Chain Upgrade Functionality Implementation

**Objective**: Enable cross-chain contract upgrades from Main DAO via LayerZero messaging

**Key Changes**:
- **Simplified upgrade handling**: Removed complex validation and try/catch blocks
- **Direct decode & call pattern**: Matches working cross-chain functions
- **Enhanced reliability**: Eliminates upgrade-specific failure points

### Bridge Differences

| Feature | Legacy Bridges | 🔥 Simplified Bridges |
|---------|---------------|----------------------|
| **Upgrade Validation** | Complex validation with try/catch | ✅ No validation - direct call |
| **Source Chain Check** | Validates origin chain | ❌ Removed for simplicity |
| **Address Validation** | Checks for zero addresses | ❌ Removed for simplicity |
| **Function Existence Check** | Validates target has upgrade function | ❌ Removed for simplicity |
| **Error Handling** | Multiple try/catch blocks | ✅ Simple direct execution |
| **File Paths** | `*-bridge.sol` | `*-bridge-upgrade-fix.sol` |
| **Status** | Legacy - Complex | ✅ Active - Simplified |

### Successfully Tested Upgrades

1. **✅ LOWJC Cross-Chain Upgrade**: Main DAO (Base) → LOWJC (OP Sepolia)
   - **TX**: `0xa0183dd50a2f04b8f51fdc19647bc53ce11e0d756cdc2a85874fbbf6425a8f38`
   - **Implementation**: `0x1aF480964b074Ca8bae0c19fb0DED4884a459f14` → `0xa7190077d51A40d0a61c6C346F76cD0135430551`

2. **✅ Native Athena Cross-Chain Upgrade**: Main DAO (Base) → Native Athena (Arbitrum)
   - **TX**: `0xf7cef1928173d35797bbe0c01d53945c248ad40578d4bca43b45bad72c0cf257`
   - **Target**: `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` → `0x73a2a697639b55959045AEDC3E4039E3D8C22afD`

### Active Configuration

**Working Upgrade Path**:
```
Main DAO (Base) → Main Bridge (Base) → Simplified Bridges → Target Contracts
```

## Key Notes

- **Deployer**: WALL2 = `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **🔥 Latest Feature**: Cross-chain contract upgrades via simplified bridges (Oct 5, 2025)
- **Latest Updates**: Native Athena upgraded with dispute fee refund functionality (Oct 4, 2025)
- **Latest Native Athena Feature**: Automatic fee refund when no votes cast on disputes, with cross-chain support
- **Latest NOWJC Fix**: Fixed race condition in job application duplicate checking (Oct 2, 2025)
- **Previous Fix**: Updated `setJobApplication` signature for cross-chain job applications
- **File Paths**: All refer to `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/` for latest implementations
- **Status**: Cross-chain upgrades operational with simplified bridges (October 5, 2025)