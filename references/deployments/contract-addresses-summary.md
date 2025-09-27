# Contract Addresses Summary

**Last Updated**: September 27, 2025 - 9:15AM  
**Status**: Current Active Deployments - **Base Sepolia Main Chain Added**

## Core Contracts

| Contract | Network | Type | Address | Status |
|----------|---------|------|---------|---------|
| **Native Athena** | Arbitrum Sepolia | Proxy | `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` | ✅ Active |
| **Native Athena** | Arbitrum Sepolia | Implementation | `0x91Dce45efeFeD9D6146Cda4875b18ec57dAb2E90` | ✅ **Genesis Fix - 25-Sep** |
| **NOWJC** | Arbitrum Sepolia | Proxy | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | ✅ Active |
| **NOWJC** | Arbitrum Sepolia | Implementation | `0x324A012c2b853F98cd557648b06400502b69Ef04` | ✅ **CCTP Integration - 25-Sep** |
| **Enhanced Native Bridge** | Arbitrum Sepolia | Contract | `0xAe02010666052571E399b1fe9E2c39B37A3Bc3A7` | ✅ Active |
| **Native DAO** | Arbitrum Sepolia | Proxy | `0x21451dCE07Ad3Ab638Ec71299C1D2BD2064b90E5` | ✅ **NEW - 27-Sep** |
| **Native DAO** | Arbitrum Sepolia | Implementation | `0x86C63B9BB781E01a1F3704d0Be7cb2b6A9B2d2eB` | ✅ **NEW - 27-Sep** |
| **Native Rewards** | Arbitrum Sepolia | Contract | `0x1e6c32ad4ab15acd59c66fbcdd70cc442d64993e` | ✅ Active |
| **LOWJC** | OP Sepolia | Proxy | `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` | ✅ Active |
| **LOWJC** | OP Sepolia | Implementation | `0x70303c2B9c71163F2278545BfB34d11504b3b602` | ✅ **Milestone Logic Fix - 25-Sep** |
| **Local Bridge** | OP Sepolia | Contract | `0xaff9967c6000ee6feec04d29a39cc7a4ecff4bc0` | ✅ Active |
| **Athena Client** | OP Sepolia | Proxy | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | ✅ Active |
| **LOWJC** | Ethereum Sepolia | Proxy | `0x325c6615Caec083987A5004Ce9110f932923Bd3A` | ✅ Active |
| **Local Bridge** | Ethereum Sepolia | Contract | `0xa47e34C6FAb67f9489D22531f2DD572006058ae7` | ✅ Active |
| **OpenWork Token (OW)** | Base Sepolia | Contract | `0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679` | ✅ **NEW - 27-Sep** |
| **Main Chain Bridge** | Base Sepolia | Contract | `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` | ✅ **NEW - 27-Sep** |
| **Cross-Chain Rewards** | Base Sepolia | Proxy | `0xd6bE0C187408155be99C4e9d6f860eDDa27b056B` | ✅ **NEW - 27-Sep** |
| **Cross-Chain Rewards** | Base Sepolia | Implementation | `0x55a0FE495c61d36F4Ac93D440DD13d146fb68f53` | ✅ **NEW - 27-Sep** |
| **Main DAO** | Base Sepolia | Proxy | `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465` | ✅ **NEW - 27-Sep** |
| **Main DAO** | Base Sepolia | Implementation | `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4` | ✅ **NEW - 27-Sep** |

## Infrastructure

| Service | Network | Address | Purpose |
|---------|---------|---------|---------|
| **USDC Token** | Arbitrum Sepolia | `0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d` | Native chain USDC |
| **USDC Token** | OP Sepolia | `0x5fd84259d66cd46123540766be93dfe6d43130d7` | Local chain USDC |
| **USDC Token** | Ethereum Sepolia | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` | Local chain USDC |
| **CCTP Transceiver** | Arbitrum Sepolia | `0xB64f20A20F55D77bbe708Db107AA5E53a9e39063` | Cross-chain USDC |
| **Message Transmitter** | OP Sepolia | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` | CCTP messaging |
| **Token Messenger** | OP Sepolia | `0x72d6efedda70f9b4ed3fff4bdd0844655aea2bd5` | CCTP sender |
| **Genesis Contract** | Arbitrum Sepolia | `0x85e0162a345ebfcbeb8862f67603f93e143fa487` | Data storage |

## Chain Configuration

| Chain | EID | CCTP Domain | Status |
|-------|-----|-------------|---------|
| **Base Sepolia** | 40245 | N/A | **Main Chain** |
| **Arbitrum Sepolia** | 40231 | 3 | Native Chain |
| **OP Sepolia** | 40232 | 2 | Local Chain |
| **Ethereum Sepolia** | 40161 | 0 | Local Chain |

## Implementation Sources

| Contract | Source File | Class |
|----------|-------------|-------|
| **OpenWork Token** | `src/openwork-full-contract-suite-layerzero+CCTP/openwork-token.sol` | `VotingToken` |
| **Main Chain Bridge** | `src/openwork-full-contract-suite-layerzero+CCTP/main-chain-bridge-final.sol` | `ThirdChainBridge` |
| **Cross-Chain Rewards** | `src/openwork-full-contract-suite-layerzero+CCTP/main-rewards-final.sol` | `CrossChainRewardsContract` |
| **Main DAO** | `src/openwork-full-contract-suite-layerzero+CCTP/main-dao-final.sol` | `MainDAO` |
| **Native DAO** | `src/openwork-full-contract-suite-layerzero+CCTP/native-dao-final.sol` | `NativeDAO` |
| **UUPS Proxy** | `src/openwork-full-contract-suite-layerzero+CCTP/proxy.sol` | `UUPSProxy` |
| **Native Athena** | `src/current/testable-athena/25-sep/manual/native-athena-anas.sol` | `NativeAthenaTestable` |
| **NOWJC** | `src/current/testable-athena/nowjc-minimal-dispute-interface-fixed.sol` | `NativeOpenWorkJobContract` |
| **Enhanced Native Bridge** | `src/current/unlocking unique contracts 19 sep/native-bridge-final-unlocking.sol` | `NativeChainBridge` |

## Test Wallets

| Name | Address | Purpose |
|------|---------|---------|
| **WALL2** | `0xfD08836eeE6242092a9c869237a8d122275b024A` | Job Giver |
| **WALL1** | `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` | Job Applicant |

---

**Note**: Native Athena has enhanced dispute resolution with cross-chain fund release and **Genesis struct interface fix** (25-Sep). NOWJC uses proven working implementation for CCTP disputed funds functionality. Enhanced Native Bridge provides cross-chain payment routing capabilities.

## Recent Updates

### September 27, 2025 - Base Sepolia Main Chain Deployment ✅
- **OpenWork Token**: `0x5f24747d5e59F9CCe5a9815BC12E2fB5Ae713679` - Deploy TX: `0x21c2b66d7b56430f636c9f909fc8707aa40d6aae65f6f6009aa74cdb0c69a3d3`
- **Main Chain Bridge**: `0x70d30e5dAb5005b126C040f1D9b0bDDBc16679b0` - Deploy TX: `0x79b61edff6e7a417fffa2e70ea5434fd5cb7c3ff1dc989655af396a600bf9ed0`
- **Cross-Chain Rewards**: `0x55a0FE495c61d36F4Ac93D440DD13d146fb68f53` - Deploy TX: `0xb4a7c021669c436a828b4e67757f6e0eb66bde2cbab0095d74760b03c892d5b2`
- **Main DAO Implementation**: `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4` - Deploy TX: `0x62935cac5f3d411f9d9081e45216e0a2b9b09de6372817b85208d9dacb655d7a`
- **Main DAO Proxy**: `0xc3579BDC6eC1fAad8a67B1Dc5542EBcf28456465` - Deploy TX: `0x3d110d32eae8ef68244de5455751f166f0e09b5e0fc1c2fcdb86586e9c10ef99`
- **Status**: ✅ **Main Chain Infrastructure Complete** - Ready for governance and rewards
- **Configuration**: LayerZero EID 40245, connected to Arbitrum (40231), OP (40232), Ethereum (40161)

### September 25, 2025 - Genesis Struct Fix ✅
- **Native Athena Implementation**: `0x91Dce45efeFeD9D6146Cda4875b18ec57dAb2E90`
- **Fix Applied**: Genesis Job struct interface mismatch resolved
- **Status**: ✅ End-to-end automated dispute resolution working
- **Test Log**: `references/logs/25-sep-genesis-struct-fix-success.md`
- **Deploy TX**: `0xd41d6be63d9d2e94efb74eff01a0b9e8efb2d63fcd92cd8f9febf09d8fd72705`
- **Upgrade TX**: `0xc76f5c98954e05f92cabfdb042ba6d3b6307867ea7932c7177bd80f5352887cc`