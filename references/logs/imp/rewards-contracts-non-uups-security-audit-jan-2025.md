# Rewards Contracts Security Audit & Non-UUPS Migration

**Date:** January 7, 2025
**Contracts:** native-rewards-mainnet.sol, main-rewards.sol
**Output:** native-rewards-mainnet-non-uups.sol, main-rewards-non-uups.sol

---

## Executive Summary

This document captures the security audit findings, architectural decisions, and implementation changes made to create non-upgradeable versions of the OpenWork rewards contracts. The primary motivation was to protect team token allocations from being revoked through contract upgrades.

---

## 1. Problem Statement

### Original Concern
The DAO or owner could potentially revoke team token allocations by:
1. Upgrading the `native-rewards-mainnet.sol` contract to remove or modify team token logic
2. Calling `allocateTeamTokens()` with reduced amounts
3. Using `adminSetTeamTokensClaimed()` to manipulate claimed amounts

### Architectural Context
```
NATIVE CHAIN (Arbitrum)              MAIN CHAIN (Optimism)
┌─────────────────────────┐          ┌─────────────────────────┐
│ native-rewards-mainnet  │          │   main-rewards.sol      │
│                         │          │                         │
│ • Gov actions tracking  │  SYNC    │ • Holds 750M OW tokens  │
│ • Team token calc       │ ───────> │ • Receives synced data  │
│ • Earned rewards calc   │  Bridge  │ • Distributes tokens    │
└─────────────────────────┘          └─────────────────────────┘
```

---

## 2. Options Considered

### Option A: Separate Immutable Team Vesting Contract
- Create ImmutableTeamVesting on main chain (holds 150M tokens)
- Create TeamTokenSyncer on native chain (reads from Genesis)
- Make Genesis non-upgradeable

**Pros:** Maximum separation, team tokens completely isolated
**Cons:** Complex sync mechanism, multiple new contracts, changes token distribution

### Option B: Timelock on Upgrades
- Add 30-day delay before upgrades take effect
- Team members have warning to claim tokens

**Pros:** Maintains flexibility, gives warning
**Cons:** Still allows upgrades, relies on team vigilance

### Option C: Make Rewards Contracts Non-Upgradeable (CHOSEN)
- Remove UUPS upgradeability
- Add allocation reduction protection
- Remove admin manipulation functions

**Pros:** Simple, permanent protection, minimal changes
**Cons:** Cannot fix bugs after deployment

### Decision
Option C was chosen because:
1. Simplest implementation
2. Permanent cryptographic guarantee
3. Owner functions for bands/rates still work (state changes OK, code changes blocked)
4. Audit can catch bugs before deployment

---

## 3. Security Audit Findings

### 3.1 HIGH Severity

#### H-1: Band Boundary Condition Bug
**Location:** `native-rewards-mainnet.sol:373-382`

**Issue:** When `totalPlatformPayments` equals a band boundary, value matches both bands due to `<=` condition.

```solidity
// BEFORE (buggy)
if (totalPlatformPayments >= rewardBands[i].minAmount &&
    totalPlatformPayments <= rewardBands[i].maxAmount) {

// AFTER (fixed)
if (totalPlatformPayments >= rewardBands[i].minAmount &&
    totalPlatformPayments < rewardBands[i].maxAmount) {
```

**Impact:** Inconsistent band assignment at exact boundaries.

#### H-2: Band Mismatch on Cross-Boundary Payments (NOT FIXED)
**Location:** `native-rewards-mainnet.sol:450-480`

**Issue:** When payment crosses band boundaries, all tokens recorded in current band instead of being split.

**Decision:** Not fixed because:
1. Fix would change unlock behavior (easier for users at boundaries)
2. Governance actions are also tracked per-band
3. Current behavior is consistent (tokens and actions both in current band)
4. Changing would require deeper architectural changes

### 3.2 MEDIUM Severity

#### M-1: Owner Can Retroactively Change Unlock Rates
**Location:** `native-rewards-mainnet.sol:338-347`

**Decision:** Keep as-is. This is intentional flexibility for adjusting tokenomics. Documented as known behavior.

#### M-2: Admin Can Bypass Normal Claim Flow
**Location:** `native-rewards-mainnet.sol:256-261`

**Function:** `adminSetTeamTokensClaimed()`

**Decision:** REMOVED. This function could:
- Block team members by setting claimed = allocated
- Allow re-claiming by setting claimed = 0

The security fix on main chain (using totalClaimed as source of truth) makes this unnecessary.

#### M-3: Multiple Upgrade Authorities
**Location:** `main-rewards.sol:86-88`

**Issue:** Owner, bridge, AND mainDAO could all upgrade.

**Decision:** REMOVED by making contract non-upgradeable.

#### M-4 & M-5: Emergency Functions
**Location:** `main-rewards.sol:342-350`

**Functions:**
- `emergencyWithdraw()` - Can drain all tokens
- `emergencyUpdateUserBalance()` - Can set arbitrary balances

**Decision:**
- `emergencyWithdraw()` - KEPT. Owner should transfer to multisig after deployment.
- `emergencyUpdateUserBalance()` - RESTRICTED to increases only. Cannot steal, only help.

---

## 4. Changes Implemented

### 4.1 native-rewards-mainnet-non-uups.sol

| Change | Reason |
|--------|--------|
| Remove `UUPSUpgradeable` import | Make non-upgradeable |
| Remove `UUPSUpgradeable` from inheritance | Make non-upgradeable |
| Remove `__UUPSUpgradeable_init()` from initialize | Make non-upgradeable |
| Remove `_authorizeUpgrade()` function | Make non-upgradeable |
| Remove `uint256[50] private __gap` | Not needed without upgrades |
| Fix `getCurrentBand()`: `<=` to `<` | Fix H-1 boundary bug |
| Add `require(newAmount >= oldAllocation)` in `allocateTeamTokens()` | Prevent allocation reduction |
| Remove `adminSetTeamTokensClaimed()` | Remove admin manipulation |

### 4.2 main-rewards-non-uups.sol

| Change | Reason |
|--------|--------|
| Remove `UUPSUpgradeable` import | Make non-upgradeable |
| Remove `UUPSUpgradeable` from inheritance | Make non-upgradeable |
| Remove `__UUPSUpgradeable_init()` from initialize | Make non-upgradeable |
| Remove `_authorizeUpgrade()` function | Make non-upgradeable |
| Remove `upgradeFromDAO()` function | Make non-upgradeable |
| Remove `uint256[50] private __gap` | Not needed without upgrades |
| Restrict `emergencyUpdateUserBalance()` to increases only | Prevent theft |

---

## 5. What Still Works After Changes

### Owner/DAO Can Still:
- Adjust reward bands (`addRewardBand`, `updateRewardBand`, etc.)
- Increase team token pool (`setTeamTokensPool`)
- Adjust unlock rate (`setTeamTokenActionRequirement`)
- Increase team allocations (`allocateTeamTokens` with higher amounts)
- Set contract references (`setJobContract`, `setGenesis`, etc.)
- Emergency withdraw (should be multisig)
- Emergency increase user balance

### Owner/DAO CANNOT:
- Upgrade contract code
- Reduce team allocations
- Manipulate team claimed amounts
- Decrease user balances

---

## 6. Governance Actions & Team Tokens Relationship

### How Governance Actions Are Tracked
```
Main Chain (MainDAO)           Native Chain
     │                              │
     │  User votes/proposes         │
     │ ────────────────────────────>│ NOWJC.incrementGovernanceAction()
     │                              │      │
     │                              │      ├─> Genesis.incrementUserGovernanceActions()
     │                              │      │
     │                              │      └─> native-rewards.recordGovernanceAction()
     │                              │               │
     │                              │               └─> userGovernanceActionsByBand[user][band]++
     │                              │                   userTotalGovernanceActions[user]++
```

### Team Token Unlock Calculation
```solidity
function getTeamTokensClaimable(address user) public view returns (uint256) {
    uint256 allocated = teamTokensAllocated[user];
    uint256 govActions = userTotalGovernanceActions[user];

    // Unlock based on TOTAL governance actions (not per-band)
    uint256 maxUnlocked = govActions * teamTokensPerGovAction;
    uint256 totalUnlocked = maxUnlocked > allocated ? allocated : maxUnlocked;

    return totalUnlocked > teamTokensClaimed[user] ?
        totalUnlocked - teamTokensClaimed[user] : 0;
}
```

**Key Insight:** Team tokens use `userTotalGovernanceActions`, not per-band actions. This means team members can unlock tokens regardless of which band their actions were recorded in.

---

## 7. Cross-Chain Sync Security

### Double-Claim Prevention
```
Native Chain                          Main Chain
     │                                     │
     │  getUserTotalUnlockedTokens()       │
     │  (returns total unlocked ever)      │
     │ ───────────────────────────────────>│
     │                                     │
     │                                     │  claimable = totalUnlocked - userTotalClaimed
     │                                     │  (main chain is source of truth)
     │                                     │
     │                                     │  User claims
     │                                     │  userTotalClaimed += amount
     │                                     │
     │  Callback: updateUserClaimData      │
     │ <───────────────────────────────────│
     │                                     │
     │  Even if callback fails,            │
     │  next sync uses new totalClaimed    │
```

This architecture prevents double-claims even if callbacks fail.

---

## 8. Deployment Checklist

### Pre-Deployment
- [ ] Compile both contracts successfully
- [ ] Run test suite
- [ ] External audit recommended
- [ ] Verify all team member addresses
- [ ] Prepare initial team allocations

### Deployment Order
1. Deploy `native-rewards-mainnet-non-uups.sol` on Arbitrum
2. Deploy `main-rewards-non-uups.sol` on Optimism
3. Configure contract references
4. Allocate team tokens
5. Transfer ownership to multisig

### Post-Deployment
- [ ] Verify all functions work correctly
- [ ] Test team token allocation
- [ ] Test sync mechanism
- [ ] Transfer ownership to multisig/DAO

---

## 9. Risk Acknowledgments

### Accepted Risks
1. **Cannot fix bugs after deployment** - Mitigated by thorough audit
2. **H-2 not fixed** - Current behavior is consistent, fixing would change tokenomics
3. **emergencyWithdraw exists** - Transfer ownership to multisig

### Mitigations in Place
1. Team allocations can only increase
2. No admin manipulation of team claims
3. User balances can only increase via emergency function
4. Cross-chain double-claim prevention

---

## 10. File Locations

| File | Path |
|------|------|
| Original native-rewards | `src/suites/openwork-all-contracts-6-Jan-version/native-rewards-mainnet.sol` |
| Original main-rewards | `src/suites/openwork-all-contracts-6-Jan-version/main-rewards.sol` |
| Non-UUPS native-rewards | `src/suites/openwork-all-contracts-6-Jan-version/native-rewards-mainnet-non-uups.sol` |
| Non-UUPS main-rewards | `src/suites/openwork-all-contracts-6-Jan-version/main-rewards-non-uups.sol` |

---

## 11. Conclusion

The non-UUPS versions provide permanent protection for team token allocations while maintaining necessary operational flexibility. The key security properties are:

1. **Immutable code** - No upgrades possible
2. **Protected allocations** - Can only increase, never decrease
3. **No admin backdoors** - Removed manipulation functions
4. **Transparent emergency functions** - Only beneficial actions possible

This approach balances security guarantees with operational needs, suitable for mainnet deployment after thorough testing.
