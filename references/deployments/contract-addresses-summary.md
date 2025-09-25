# Contract Addresses Summary

**Last Updated**: September 25, 2025 - 8:45PM  
**Status**: Current Active Deployments - **Genesis Struct Fix Applied**

## Core Contracts

| Contract | Network | Type | Address | Status |
|----------|---------|------|---------|---------|
| **Native Athena** | Arbitrum Sepolia | Proxy | `0xedeb7729F5E62192FC1D0E43De0ee9C7Bd5cbFBE` | ✅ Active |
| **Native Athena** | Arbitrum Sepolia | Implementation | `0x91Dce45efeFeD9D6146Cda4875b18ec57dAb2E90` | ✅ **Genesis Fix - 25-Sep** |
| **NOWJC** | Arbitrum Sepolia | Proxy | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | ✅ Active |
| **NOWJC** | Arbitrum Sepolia | Implementation | `0x16Af454B3A858B1De693D7E6A61DeD302FC5a1aC` | ✅ Current |
| **Enhanced Native Bridge** | Arbitrum Sepolia | Contract | `0xAe02010666052571E399b1fe9E2c39B37A3Bc3A7` | ✅ Active |
| **LOWJC** | OP Sepolia | Proxy | `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` | ✅ Active |
| **Local Bridge** | OP Sepolia | Contract | `0xaff9967c6000ee6feec04d29a39cc7a4ecff4bc0` | ✅ Active |
| **Athena Client** | OP Sepolia | Proxy | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | ✅ Active |
| **LOWJC** | Ethereum Sepolia | Proxy | `0x325c6615Caec083987A5004Ce9110f932923Bd3A` | ✅ Active |
| **Local Bridge** | Ethereum Sepolia | Contract | `0xa47e34C6FAb67f9489D22531f2DD572006058ae7` | ✅ Active |

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
| **Arbitrum Sepolia** | 40231 | 3 | Native Chain |
| **OP Sepolia** | 40232 | 2 | Local Chain |
| **Ethereum Sepolia** | 40161 | 0 | Local Chain |

## Implementation Sources

| Contract | Source File | Class |
|----------|-------------|-------|
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

### September 25, 2025 - Genesis Struct Fix ✅
- **Native Athena Implementation**: `0x91Dce45efeFeD9D6146Cda4875b18ec57dAb2E90`
- **Fix Applied**: Genesis Job struct interface mismatch resolved
- **Status**: ✅ End-to-end automated dispute resolution working
- **Test Log**: `references/logs/25-sep-genesis-struct-fix-success.md`
- **Deploy TX**: `0xd41d6be63d9d2e94efb74eff01a0b9e8efb2d63fcd92cd8f9febf09d8fd72705`
- **Upgrade TX**: `0xc76f5c98954e05f92cabfdb042ba6d3b6307867ea7932c7177bd80f5352887cc`