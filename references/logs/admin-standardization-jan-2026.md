# Admin Standardization Progress - Jan 2026

## Dashboard

| Contract | Chain | Action Required | Status | Size Before | Size After |
|----------|-------|-----------------|--------|-------------|------------|
| main-rewards-non-uups+admin.sol | Main | Add admins + mainDAO | DONE | 9,328 | 8,081 |
| activity-tracker-admin.sol | Native | Add nativeDAO to setAdmin | DONE | 4,778 | 5,041 |
| profile-manager-admin.sol | Native | Add admins + nativeDAO | DONE | 8,643 | 9,148 |
| athena-client-admin.sol | Local | Add admins (owner-only) | DONE | 12,616 | 12,872 |
| lowjc-admin.sol | Local | Add admins (owner-only) | DONE | 22,692 | 22,952 |
| local-bridge-admin.sol | Local | Owner-only setAdmin (removed mainDAO) | DONE | - | 9,416 |
| native-rewards-mainnet-non-uups-admin.sol | Native | Add admins + nativeDAO | DONE | - | 13,040 |
| nowjc-admin.sol | Native | Consolidate to nativeDAO | DONE | 23,021 | 22,851 |
| native-athena-admin.sol | Native | Rename mainDAO -> nativeDAO | DONE | 23,878 | 23,878 |
| openwork-genesis-admin.sol | Native | Rename mainDAO -> nativeDAO | DONE | 24,401 | 24,401 |
| main-chain-bridge-admin.sol | Main | Add setAdmin + mainDAO | DONE | - | 9,040 |
| native-bridge-admin.sol | Native | Already consistent | DONE | - | 17,879 |
| cctp-transceiver-admin.sol | Local+Native | Owner-only setAdmin (removed mainDAO) | DONE | - | 5,883 |
| openwork-contract-registry-admin.sol | Native | Rename mainDAO -> nativeDAO | DONE | - | 4,845 |
| profile-genesis-admin.sol | Native | Add admins + nativeDAO | DONE | - | 7,466 |
| native-athena-oracle-manager-admin.sol | Native | Rename mainDAO -> nativeDAO | DONE | - | 8,009 |

## Pattern Reference

**Native Chain (Arbitrum):** `owner || nativeDAO`
**Main Chain (ETH Sepolia):** `owner || mainDAO`
**Local Chain (OP Sepolia):** `onlyOwner` (no DAO)

## Notes

- Local chain contracts now have admin pattern with owner-only setAdmin (no DAO)
- local-bridge: removed mainDAO variable (not used for upgrades, only cross-chain messages)
- Size-critical contracts (nowjc, native-athena, openwork-genesis) - rename only, no additions
- All three bridges now have consistent admin patterns:
  - native-bridge-admin.sol: owner || nativeDAO (was already correct)
  - main-chain-bridge-admin.sol: owner || mainDaoContract (added setAdmin)
  - local-bridge-admin.sol: onlyOwner (removed mainDAO)
