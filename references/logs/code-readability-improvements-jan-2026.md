# Code Readability Improvements - Jan 2026

## Overview
Improve code readability and documentation across the 8-Jan contract suite.

---

## Task Status

| Task | Priority | Status | Notes |
|------|----------|--------|-------|
| Add NatSpec to all public functions | P1 | ✓ COMPLETE | All 12 contracts documented |
| Magic numbers → named constants | P3 | DEFERRED | Flag for later - needs careful consideration |
| Duplicated structs cleanup | P2 | PENDING | Copy to /extra folder first, test changes there |
| Complex function breakdown | P2 | PENDING | Copy to /extra folder first, test changes there |
| Error messages | N/A | SKIPPED | Already terse due to contract size limits |

---

## P1: NatSpec Documentation

### Contracts to Document

| Contract | File | Status |
|----------|------|--------|
| NativeOpenWorkJobContract | native-openwork-job-contract.sol | ✓ DONE |
| NativeAthena | native-athena.sol | ✓ DONE |
| NativeLZOpenworkBridge | native-lz-openwork-bridge.sol | ✓ DONE |
| ETHLZOpenworkBridge | eth-lz-openwork-bridge.sol | ✓ DONE |
| ETHOpenworkDAO | eth-openwork-dao.sol | ✓ DONE |
| ETHRewardsContract | eth-rewards-contract.sol | ✓ DONE |
| LocalLZOpenworkBridge | local-lz-openwork-bridge.sol | ✓ DONE |
| LocalAthena | local-athena.sol | ✓ DONE |
| NativeRewardsContract | native-rewards-contract.sol | ✓ DONE |
| NativeOpenworkDAO | native-openwork-dao.sol | ✓ DONE |
| NativeOpenworkGenesis | native-openwork-genesis.sol | ✓ DONE |
| CCTPTransceiver | cctp-transceiver.sol | ✓ DONE |

### NatSpec Template
```solidity
/// @title Contract Title
/// @notice What this contract does (user-facing)
/// @dev Technical implementation notes

/// @notice What this function does
/// @param paramName Description of parameter
/// @return returnName Description of return value
```

---

## P2: Structural Improvements (in /extra folder)

### Duplicated Structs
Files with duplicated struct definitions that could be consolidated:
- `native-openwork-job-contract.sol` - has Job, Profile, Application structs duplicated from interface
- `native-athena.sol` - has Oracle, Dispute structs duplicated

**Approach:**
1. Copy file to `/extra` folder
2. Remove duplicated structs, use interface types
3. Verify compilation
4. Name file with `-refactored` suffix

### Complex Function Breakdown
Functions that could be broken into smaller pieces:
- `_lzReceive` in bridges (20+ conditions)
- `settleDispute` in NativeAthena
- `releasePayment` in NOWJC

**Approach:**
1. Copy file to `/extra` folder
2. Extract handler functions
3. Use function dispatch pattern where applicable
4. Name file with `-refactored` suffix

---

## P3: Magic Numbers (DEFERRED)

Flag for future work - numbers to potentially make configurable:

| Contract | Value | Current | Suggested Constant |
|----------|-------|---------|-------------------|
| NativeAthena | 3 | minOracleMembers | MIN_ORACLE_QUORUM |
| NativeAthena | 60 | votingPeriodMinutes | DEFAULT_VOTING_PERIOD |
| NativeAthena | 90 | memberActivityThresholdDays | ACTIVITY_THRESHOLD_DAYS |
| NOWJC | 100 | commissionPercentage (basis points) | COMMISSION_BPS |
| NOWJC | 1e6 | minCommission | MIN_COMMISSION_USDC |
| ETHOpenworkDAO | 100 * 10**18 | MIN_STAKE | Already constant |

---

## Progress Log

### Jan 8, 2026
- Created task doc
- Created /extra folder for experimental changes
- Starting NatSpec documentation
- Completed NatSpec for all bridge contracts:
  - eth-lz-openwork-bridge.sol ✓
  - local-lz-openwork-bridge.sol ✓
  - native-lz-openwork-bridge.sol ✓
- Completed NatSpec for:
  - cctp-transceiver.sol ✓
  - eth-rewards-contract.sol ✓
  - eth-openwork-dao.sol ✓
  - local-athena.sol ✓
  - native-openwork-job-contract.sol ✓
  - native-athena.sol ✓
  - native-rewards-contract.sol ✓
  - native-openwork-dao.sol ✓
  - native-openwork-genesis.sol ✓
- **P1 NatSpec documentation COMPLETE** - All 12 contracts documented

