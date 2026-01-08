# Contract Naming Standardization - Jan 2026

## Naming Convention
- **Native Chain (Arbitrum):** Prefix with `Native`
- **ETH Chain (ETH Sepolia):** Prefix with `ETH`
- **Local Chain (OP Sepolia):** Prefix with `Local`

---

## Contracts

| Filename | Current | Ideal | Status |
|----------|---------|-------|--------|
| activity-tracker-admin.sol | NativeAthenaActivityTracker | NativeAthenaActivityTracker | DONE |
| athena-client-admin.sol | LocalAthena | LocalAthena | OK |
| cctp-transceiver-admin.sol | CCTPTransceiver | CCTPTransceiver | DONE |
| genesis-reader-helper.sol | NativeGenesisReader | NativeGenesisReader | DONE |
| local-bridge-admin.sol | LocalLZOpenworkBridge | LocalLZOpenworkBridge | DONE |
| lowjc-admin.sol | LocalOpenWorkJobContract | LocalOpenWorkJobContract | DONE |
| main-chain-bridge-admin.sol | ETHLZOpenworkBridge | ETHLZOpenworkBridge | DONE |
| main-dao.sol | ETHOpenworkDAO | ETHOpenworkDAO | DONE |
| main-rewards-non-uups+admin.sol | ETHRewardsContract | ETHRewardsContract | DONE |
| native-athena-admin.sol | NativeAthena | NativeAthena | OK |
| native-athena-oracle-manager-admin.sol | NativeAthenaOracleManager | NativeAthenaOracleManager | OK |
| native-bridge-admin.sol | NativeLZOpenworkBridge | NativeLZOpenworkBridge | DONE |
| native-dao.sol | NativeOpenworkDAO | NativeOpenworkDAO | DONE |
| native-rewards-mainnet-non-uups-admin.sol | NativeRewardsContract | NativeRewardsContract | DONE |
| nowjc-admin.sol | NativeOpenWorkJobContract | NativeOpenWorkJobContract | OK |
| openwork-contract-registry-admin.sol | NativeContractRegistry | NativeContractRegistry | DONE |
| openwork-genesis-admin.sol | NativeOpenworkGenesis | NativeOpenworkGenesis | DONE |
| openwork-token.sol | OpenworkToken | OpenworkToken | OK |
| profile-genesis-admin.sol | NativeProfileGenesis | NativeProfileGenesis | DONE |
| profile-manager-admin.sol | NativeProfileManager | NativeProfileManager | DONE |
| proxy.sol | UUPSProxy | UUPSProxy | OK |

---

## Summary
- **All 16 renames completed**
- **All contracts compile successfully**
