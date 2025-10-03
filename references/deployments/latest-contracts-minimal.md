# Latest Contract Addresses - Minimal Reference

**Last Updated**: October 3, 2025  
**Status**: Current Active Deployments

## Recent Updates

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

| Contract | Address | Chain | Deployer | File Path | TX Hash |
|----------|---------|-------|----------|-----------|---------|
| **Native Athena** (Proxy) | `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` | Arbitrum Sepolia | WALL2 | `src/current/New working contracts - 26 sep/native-athena-production-cctp.sol` | - |
| **Native Athena** (Implementation) | `0x85598B4918001476b2B7d9745Cf45DEDF09F385b` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-athena.sol` | `0xecfab1d0cbc0dc3db38c0ee7d923f0fef5a385dcf5a420eb37e4ec27c3144042` |
| **Oracle Manager** (Proxy) | `0x70F6fa515120efeA3e404234C318b7745D23ADD4` | Arbitrum Sepolia | WALL2 | - | - |
| **Oracle Manager** (Implementation) | `0xAdf1d61e5DeD34fAF507C8CEF24cdf46f46bF537` | Arbitrum Sepolia | WALL2 | - | - |
| **NOWJC** (Proxy) | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/nowjc.sol` | - |
| **NOWJC** (Implementation) | `0x7398476bC21cb9A0D751b63ECc5a76Ce1d2977Ff` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/nowjc.sol` | `0x9b104620fd527c7c5493234e73564a9385d90117b29eb5bd848b490e7f9f6aaf` |
| **Native Bridge** | `0xD3614cF325C3b0c06BC7517905d14e467b9867A8` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/native-bridge.sol` | `0xce43247868f68aef1f7af0ed750e47530867d7338174e391e0db43606cd0d400` |
| **Native DAO** (Proxy) | `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5` | Arbitrum Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/native-dao-final.sol` | - |
| **Native DAO** (Implementation) | `0x86C63B9BB781E01a1F3704d0Be7cb2b6A9B2d2eB` | Arbitrum Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/native-dao-final.sol` | - |
| **Native Rewards** | `0x1e6c32ad4ab15acd59c66fbcdd70cc442d64993e` | Arbitrum Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/native-rewards-final.sol` | - |
| **Genesis Contract** | `0xB4f27990af3F186976307953506A4d5759cf36EA` | Arbitrum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/openwork-genesis.sol` | `0x1a837ed54caeca6ec5a99ccb997c6121400b27098c539d51cb1f8cf03b9fe457` |

## Local Chain Contracts

| Contract | Address | Chain | Deployer | File Path | TX Hash |
|----------|---------|-------|----------|-----------|---------|
| **LOWJC** (Proxy) | `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | - |
| **LOWJC** (Implementation) | `0x1aF480964b074Ca8bae0c19fb0DED4884a459f14` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | `0x41ed121906a431fbd8858e706b633dd326dff722d9ce683d606ba281f342a12a` |
| **Local Bridge** | `0xaff9967c6000ee6feec04d29a39cc7a4ecff4bc0` | OP Sepolia | WALL2 | - | - |
| **Athena Client** (Proxy) | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | - |
| **Athena Client** (Implementation) | `0x835ee526415511264EE454f8513258D3A82F067c` | OP Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | - |
| **LOWJC** (Proxy) | `0x325c6615Caec083987A5004Ce9110f932923Bd3A` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | - |
| **LOWJC** (Implementation) | `0xE99B5baB1fc02EbD6f1e4a3789079381a40cddD0` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/lowjc.sol` | `0xe448bb94fd036eefc0ed3a65802e3c7d0351e212dfcc7eabee1832d942709d4c` |
| **Local Bridge** | `0xa47e34C6FAb67f9489D22531f2DD572006058ae7` | Ethereum Sepolia | WALL2 | - | - |
| **Athena Client** (Proxy) | `0xAdE5F9637F1DB4D6773fA49bE43Bc2480040E0dB` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | `0xd7518f53694aea37120d447d01a2ab65645c6a65bda4182eeffdb6ce6eb25bb1` |
| **Athena Client** (Implementation) | `0xFd59109B4d45bAC4FF649C836C1204CE0D249294` | Ethereum Sepolia | WALL2 | `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/athena-client.sol` | `0xed2100165767fc1e56488e7a69fe48ed7020a1eb4af3d7c114f7e2e021fa5019` |

## Main Chain Contracts

| Contract | Address | Chain | Deployer | File Path | TX Hash |
|----------|---------|-------|----------|-----------|---------|
| **OpenWork Token (OW)** | `0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/openwork-token.sol` | `0x21c2b66d7b56430f636c9f909fc8707aa40d6aae65f6f6009aa74cdb0c69a3d3` |
| **Main Chain Bridge** | `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-chain-bridge-final.sol` | `0x79b61edff6e7a417fffa2e70ea5434fd5cb7c3ff1dc989655af396a600bf9ed0` |
| **Cross-Chain Rewards** (Proxy) | `0xd6bE0C187408155be99C4e9d6f860eDDa27b056B` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-rewards-final.sol` | - |
| **Cross-Chain Rewards** (Implementation) | `0x55a0FE495c61d36F4Ac93D440DD13d146fb68f53` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-rewards-final.sol` | `0xb4a7c021669c436a828b4e67757f6e0eb66bde2cbab0095d74760b03c892d5b2` |
| **Main DAO** (Proxy) | `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | `0x3d110d32eae8ef68244de5455751f166f0e09b5e0fc1c2fcdb86586e9c10ef99` |
| **Main DAO** (Implementation) | `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4` | Base Sepolia | WALL2 | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | `0x62935cac5f3d411f9d9081e45216e0a2b9b09de6372817b85208d9dacb655d7a` |

## Infrastructure

| Service | Address | Chain | Purpose |
|---------|---------|-------|---------|
| **USDC Token** | `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d` | Arbitrum Sepolia | Native chain USDC |
| **USDC Token** | `0x5fd84259d66cd46123540766be93dfe6d43130d7` | OP Sepolia | Local chain USDC |
| **USDC Token** | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | Ethereum Sepolia | Local chain USDC |
| **CCTP Transceiver** | `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063` | Arbitrum Sepolia | Cross-chain USDC |
| **Message Transmitter** | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` | OP Sepolia | CCTP messaging |
| **Token Messenger** | `0x72d6efedda70f9b4ed3fff4bdd0844655aea2bd5` | OP Sepolia | CCTP sender |

## Key Notes

- **Deployer**: WALL2 = `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Latest Updates**: All contracts redeployed with latest implementation suite (Oct 2, 2025 Evening)
- **Latest NOWJC Fix**: Fixed race condition in job application duplicate checking (Oct 2, 2025)
- **Previous Fix**: Updated `setJobApplication` signature for cross-chain job applications
- **File Paths**: All refer to `src/suites/openwork-full-contract-suite-layerzero+CCTP 1 Oct Eve/` for latest implementations
- **Status**: All contracts operational with latest implementations and improved application consistency (October 2, 2025)