# ActivityTracker Contract Implementation - January 5, 2026

**Date:** January 5, 2026
**Status:** CONTRACT CHANGES COMPLETE - PENDING DEPLOYMENT
**Network:** Arbitrum Sepolia (Native Chain)

---

## Executive Summary

### Problem Statement
The `isOracleActive()` function in NativeAthena (line 402-403) calls `genesis.oracleActiveStatus()` which **does not exist** in the current Genesis contract. This causes `handleRaiseDispute()` and `handleSubmitSkillVerification()` to revert, completely blocking dispute resolution functionality.

The Genesis contract is at the **24KB EIP-170 size limit** and cannot accommodate additional code.

### Solution
Create a separate **ActivityTracker** contract to handle oracle member activity tracking, decoupling this functionality from Genesis.

---

## Implementation Progress

### Completed (January 5, 2026)

| Task | Status | Notes |
|------|--------|-------|
| Create implementation document | DONE | This file |
| Create ActivityTracker contract | DONE | `activity-tracker.sol` |
| Update NativeAthena | DONE | Backup: `native-athena-backup-before-activity-tracker.sol` |
| Update NativeDAO | DONE | Backup: `native-dao-backup-before-activity-tracker.sol` |
| Update OracleManager | DONE | Backup: `native-athena-oracle-manager-backup-before-activity-tracker.sol` |
| Compile all contracts | DONE | `forge build --contracts src/suites/openwork-full-contract-suite-1-Jan-version/` |

### Pending

| Task | Status | Notes |
|------|--------|-------|
| Deploy ActivityTracker | PENDING | Implementation + Proxy |
| Deploy updated implementations | PENDING | NativeAthena, NativeDAO, OracleManager |
| Upgrade proxy contracts | PENDING | 3 proxies to upgrade |
| Configure authorizations | PENDING | Bi-directional references |
| Initialize WALL2 activity | PENDING | Existing oracle member |
| Update "General" oracle status | PENDING | Call updateOracleActiveStatus() |
| Test dispute resolution | PENDING | Full end-to-end test |

### Files Created/Modified

**New Files:**
- `src/suites/openwork-full-contract-suite-1-Jan-version/activity-tracker.sol` - New ActivityTracker contract

**Modified Files:**
- `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena.sol` - Added activityTracker integration
- `src/suites/openwork-full-contract-suite-1-Jan-version/native-dao.sol` - Added activityTracker integration
- `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol` - Added member activity initialization

**Backup Files:**
- `native-athena-backup-before-activity-tracker.sol`
- `native-dao-backup-before-activity-tracker.sol`
- `native-athena-oracle-manager-backup-before-activity-tracker.sol`

---

## System Architecture

### Current State (Broken)
```
NativeAthena ──────────► Genesis (NO-OP / MISSING FUNCTIONS)
     │
     └── isOracleActive() ──► genesis.oracleActiveStatus() ──► REVERTS!
```

### Target State (Working)
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   NativeDAO     │     │  NativeAthena   │     │  OracleManager  │
│                 │     │                 │     │                 │
│ - propose()     │     │ - vote()        │     │ - addOracle()   │
│ - _castVote()   │     │ - settleDispute │     │ - addMember()   │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │ updateMemberActivity  │ updateMemberActivity  │ initializeMember
         │                       │ setOracleActiveStatus │   Activity
         │                       │ memberLastActivity    │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ActivityTracker                             │
│                                                                 │
│  Storage:                                                       │
│  ├── memberLastActivity: mapping(address => uint256)           │
│  ├── oracleActiveStatus: mapping(string => bool)               │
│  └── authorizedCallers: mapping(address => bool)               │
│                                                                 │
│  Authorized Callers:                                            │
│  ├── NativeAthena (0x20Ec...eD7b2)                             │
│  ├── NativeDAO (0xB7Fb...C357)                                 │
│  └── OracleManager (0x32ec...E215)                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Activity Tracking Feature - Complete Specification

### Purpose
Track oracle member participation to ensure oracles remain "active" with engaged members.

### Activity Threshold
- **90 days** (configurable via `memberActivityThresholdDays` in NativeAthena)
- Members who haven't participated within 90 days are considered **inactive**
- Oracles need a minimum number of active members to be considered "active"

### What Counts as Activity
| Action | Contract | Triggers Activity Update |
|--------|----------|-------------------------|
| Cast vote on DAO proposal | NativeDAO | Yes |
| Create DAO proposal | NativeDAO | Yes |
| Vote on dispute | NativeAthena | Yes |
| Vote on skill verification | NativeAthena | Yes |
| Vote on Ask Athena | NativeAthena | Yes |

### Oracle Active Status Calculation
```solidity
function updateOracleActiveStatus(string memory _oracleName) public {
    address[] memory members = genesis.getOracleMembers(_oracleName);
    uint256 activeCount = 0;
    uint256 threshold = memberActivityThresholdDays * 1 days; // 90 days

    for (uint256 i = 0; i < members.length; i++) {
        uint256 lastActivity = activityTracker.memberLastActivity(members[i]);
        if (lastActivity > 0 && (block.timestamp - lastActivity) <= threshold) {
            activeCount++;
        }
    }

    bool isActive = activeCount >= minOracleMembers;
    activityTracker.setOracleActiveStatus(_oracleName, isActive);
}
```

### Bootstrap Problem & Solution
**Problem:** New oracle members have `lastActivity = 0`, meaning they're treated as inactive.

**Solution:** OracleManager initializes member activity to `block.timestamp` when adding members to oracles.

---

## Contract Specifications

### ActivityTracker Contract

**File:** `src/suites/openwork-full-contract-suite-1-Jan-version/activity-tracker.sol`

**Dependencies:**
- OpenZeppelin Contracts Upgradeable v5.x
- UUPS Proxy Pattern

**Storage Layout:**
```solidity
// Slot 0-N: OwnableUpgradeable storage
// Slot N+1: memberLastActivity mapping
mapping(address => uint256) public memberLastActivity;

// Slot N+2: oracleActiveStatus mapping
mapping(string => bool) public oracleActiveStatus;

// Slot N+3: authorizedCallers mapping
mapping(address => bool) public authorizedCallers;

// Slot N+4: admins mapping
mapping(address => bool) public admins;

// Slots N+5 to N+54: Storage gap for future upgrades
uint256[50] private __gap;
```

**Functions:**

| Function | Access | Description |
|----------|--------|-------------|
| `updateMemberActivity(address)` | Authorized | Sets member's lastActivity to block.timestamp |
| `updateMemberActivities(address[])` | Authorized | Batch version |
| `initializeMemberActivity(address)` | Authorized | Sets activity only if currently 0 |
| `initializeMemberActivities(address[])` | Authorized | Batch version |
| `setOracleActiveStatus(string, bool)` | Authorized | Sets oracle's active status |
| `setAuthorizedCaller(address, bool)` | Owner | Manage authorized callers |
| `setAdmin(address, bool)` | Owner | Manage upgrade admins |
| `setMemberActivityOverride(address, uint256)` | Owner | Emergency: set specific timestamp |
| `setOracleActiveStatusOverride(string, bool)` | Owner | Emergency: force oracle status |

**Events:**
```solidity
event MemberActivityUpdated(address indexed member, uint256 timestamp);
event MemberActivityInitialized(address indexed member, uint256 timestamp);
event OracleActiveStatusUpdated(string indexed oracleName, bool isActive);
event AuthorizedCallerUpdated(address indexed caller, bool authorized);
event AdminUpdated(address indexed admin, bool status);
```

---

## Contract Changes Required

### 1. NativeAthena Changes

**File:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena.sol`

**Add Interface (at top, after other interfaces):**
```solidity
interface IActivityTracker {
    function memberLastActivity(address member) external view returns (uint256);
    function oracleActiveStatus(string memory oracleName) external view returns (bool);
    function updateMemberActivity(address member) external;
    function setOracleActiveStatus(string memory oracleName, bool isActive) external;
}
```

**Add State Variable (in storage section, consume from __gap):**
```solidity
IActivityTracker public activityTracker;
```

**Add Setter Function:**
```solidity
function setActivityTracker(address _activityTracker) external onlyOwner {
    activityTracker = IActivityTracker(_activityTracker);
}
```

**Replace Genesis Calls:**
| Line | Old Code | New Code |
|------|----------|----------|
| 385 | `genesis.memberLastActivity(members[i])` | `activityTracker.memberLastActivity(members[i])` |
| 392 | `genesis.setOracleActiveStatus(_oracleName, isActive)` | `activityTracker.setOracleActiveStatus(_oracleName, isActive)` |
| 403 | `genesis.oracleActiveStatus(_oracleName)` | `activityTracker.oracleActiveStatus(_oracleName)` |
| 431 | `genesis.memberLastActivity(members[i])` | `activityTracker.memberLastActivity(members[i])` |
| 645 | `genesis.updateMemberActivity(msg.sender)` | `activityTracker.updateMemberActivity(msg.sender)` |
| 686 | `genesis.updateMemberActivity(msg.sender)` | `activityTracker.updateMemberActivity(msg.sender)` |
| 719 | `genesis.updateMemberActivity(msg.sender)` | `activityTracker.updateMemberActivity(msg.sender)` |

**Remove from IOpenworkGenesis Interface (lines 199-202):**
```solidity
// DELETE THESE:
function memberLastActivity(address member) external view returns (uint256);
function oracleActiveStatus(string memory oracleName) external view returns (bool);
function updateMemberActivity(address member) external;
function setOracleActiveStatus(string memory oracleName, bool isActive) external;
```

---

### 2. NativeDAO Changes

**File:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-dao.sol`

**Add Interface (at top):**
```solidity
interface IActivityTracker {
    function updateMemberActivity(address member) external;
}
```

**Add State Variable (in storage section, consume from __gap):**
```solidity
IActivityTracker public activityTracker;
```

**Add Setter Function:**
```solidity
function setActivityTracker(address _activityTracker) external onlyOwner {
    activityTracker = IActivityTracker(_activityTracker);
}
```

**Replace Genesis Calls:**
| Line | Old Code | New Code |
|------|----------|----------|
| 398 | `genesis.updateMemberActivity(account)` | `activityTracker.updateMemberActivity(account)` |
| 425 | `genesis.updateMemberActivity(msg.sender)` | `activityTracker.updateMemberActivity(msg.sender)` |

**Remove from IOpenworkGenesis Interface (line 59):**
```solidity
// DELETE THIS:
function updateMemberActivity(address member) external;
```

---

### 3. OracleManager Changes

**File:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol`

**Add Interface (at top):**
```solidity
interface IActivityTracker {
    function initializeMemberActivity(address member) external;
    function initializeMemberActivities(address[] calldata members) external;
}
```

**Add State Variable:**
```solidity
IActivityTracker public activityTracker;
```

**Add Setter Function:**
```solidity
function setActivityTracker(address _activityTracker) external onlyOwner {
    activityTracker = IActivityTracker(_activityTracker);
}
```

**Modify addSingleOracle() - After line 159 (after genesis.setOracle):**
```solidity
// Initialize member activities for new oracle members
if (address(activityTracker) != address(0) && _members.length > 0) {
    activityTracker.initializeMemberActivities(_members);
}
```

**Modify addMembers() - After line 171 loop (after adding all members):**
```solidity
// Initialize activity for new members
if (address(activityTracker) != address(0)) {
    activityTracker.initializeMemberActivities(_members);
}
```

---

## Deployment Sequence

### Phase 1: Deploy ActivityTracker

**Step 1.1: Deploy Implementation**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/activity-tracker.sol:ActivityTracker"
```
**Record:** `ACTIVITY_IMPL_ADDRESS`

**Step 1.2: Generate Initialize Calldata**
```bash
cast calldata "initialize(address)" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef
```
**Record:** `INIT_DATA`

**Step 1.3: Deploy Proxy**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy" \
  --constructor-args $ACTIVITY_IMPL_ADDRESS $INIT_DATA
```
**Record:** `ACTIVITY_PROXY_ADDRESS`

---

### Phase 2: Deploy Updated Contracts

**Step 2.1: Deploy NativeAthena Implementation**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena.sol:NativeAthena"
```
**Record:** `ATHENA_IMPL_ADDRESS`

**Step 2.2: Upgrade NativeAthena Proxy**
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "upgradeToAndCall(address,bytes)" $ATHENA_IMPL_ADDRESS 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 2.3: Deploy NativeDAO Implementation**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-dao.sol:NativeDAO"
```
**Record:** `DAO_IMPL_ADDRESS`

**Step 2.4: Upgrade NativeDAO Proxy**
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "upgradeToAndCall(address,bytes)" $DAO_IMPL_ADDRESS 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 2.5: Deploy OracleManager Implementation**
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol:NativeAthenaOracleManager"
```
**Record:** `ORACLE_MGR_IMPL_ADDRESS`

**Step 2.6: Upgrade OracleManager Proxy**
```bash
source .env && cast send 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "upgradeToAndCall(address,bytes)" $ORACLE_MGR_IMPL_ADDRESS 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

### Phase 3: Configure Contracts

**Step 3.1: Set ActivityTracker on NativeAthena**
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "setActivityTracker(address)" $ACTIVITY_PROXY_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 3.2: Set ActivityTracker on NativeDAO**
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "setActivityTracker(address)" $ACTIVITY_PROXY_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 3.3: Set ActivityTracker on OracleManager**
```bash
source .env && cast send 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "setActivityTracker(address)" $ACTIVITY_PROXY_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 3.4: Authorize NativeAthena on ActivityTracker**
```bash
source .env && cast send $ACTIVITY_PROXY_ADDRESS \
  "setAuthorizedCaller(address,bool)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 3.5: Authorize NativeDAO on ActivityTracker**
```bash
source .env && cast send $ACTIVITY_PROXY_ADDRESS \
  "setAuthorizedCaller(address,bool)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 3.6: Authorize OracleManager on ActivityTracker**
```bash
source .env && cast send $ACTIVITY_PROXY_ADDRESS \
  "setAuthorizedCaller(address,bool)" 0x32eceb266A07262B15308cc626B261E7d7C5E215 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

### Phase 4: Initialize Data

**Step 4.1: Initialize WALL2's Activity (Existing Oracle Member)**
```bash
# Get current timestamp
CURRENT_TIMESTAMP=$(cast block latest --field timestamp --rpc-url $ARBITRUM_SEPOLIA_RPC_URL)

# Set WALL2's activity
source .env && cast send $ACTIVITY_PROXY_ADDRESS \
  "setMemberActivityOverride(address,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  $CURRENT_TIMESTAMP \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 4.2: Update "General" Oracle Active Status**
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "updateOracleActiveStatus(string)" "General" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Verification Commands

### Verify ActivityTracker Deployment
```bash
# Check owner
source .env && cast call $ACTIVITY_PROXY_ADDRESS "owner()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check implementation (should return non-zero address)
source .env && cast storage $ACTIVITY_PROXY_ADDRESS 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Verify WALL2 Activity
```bash
source .env && cast call $ACTIVITY_PROXY_ADDRESS \
  "memberLastActivity(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Verify "General" Oracle Status
```bash
source .env && cast call 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "isOracleActive(string)" "General" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Verify Authorizations
```bash
# NativeAthena authorized?
source .env && cast call $ACTIVITY_PROXY_ADDRESS \
  "authorizedCallers(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# NativeDAO authorized?
source .env && cast call $ACTIVITY_PROXY_ADDRESS \
  "authorizedCallers(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# OracleManager authorized?
source .env && cast call $ACTIVITY_PROXY_ADDRESS \
  "authorizedCallers(address)" 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Verify ActivityTracker Set on Contracts
```bash
# On NativeAthena
source .env && cast call 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "activityTracker()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# On NativeDAO
source .env && cast call 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "activityTracker()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# On OracleManager
source .env && cast call 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "activityTracker()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Contract Addresses Reference

### Arbitrum Sepolia (Native Chain)
| Contract | Proxy Address | Current Implementation |
|----------|---------------|----------------------|
| **NativeAthena** | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` | TBD (after upgrade) |
| **NativeDAO** | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` | TBD (after upgrade) |
| **OracleManager** | `0x32eceb266A07262B15308cc626B261E7d7C5E215` | `0xd8Ba6A37Ba9ee222593e6CbF005273897dd06c98` |
| **Genesis** | `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` | `0xc1d22b12eEac0275833A9Be8E8AB2373BD0Bb6aA` |
| **ActivityTracker** | TBD | TBD |

### Test Wallets
| Wallet | Address | Role |
|--------|---------|------|
| **WALL1** | `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` | Owner / Deployer |
| **WALL2** | `0xfD08836eeE6242092a9c869237a8d122275b024A` | Oracle Member / Voter |

---

## Security Considerations

### Authorization Model
- **Owner:** Full control over ActivityTracker (add/remove authorized callers, emergency overrides)
- **Admins:** Can upgrade the contract
- **Authorized Callers:** Can update member activity and oracle status

### Potential Risks
1. **Compromised Authorized Caller:** Could mark all oracles as inactive/active
2. **Owner Key Compromise:** Full system control
3. **Upgrade Risk:** Malicious upgrade could drain data or change logic

### Mitigations
- Multi-sig for owner address in production
- Time-locked upgrades in production
- Event monitoring for suspicious activity patterns

---

## Rollback Plan

If issues occur after deployment:

1. **Revert NativeAthena:** Deploy old implementation, upgrade proxy back
2. **Revert NativeDAO:** Deploy old implementation, upgrade proxy back
3. **Revert OracleManager:** Deploy old implementation, upgrade proxy back
4. **Note:** Genesis no-op function remains, so old code paths won't fully work but won't crash

---

## Post-Implementation: Dispute Resolution Test

After ActivityTracker is deployed and configured, proceed with dispute resolution testing as documented in the main plan file.

---

**Document Created:** January 5, 2026
**Last Updated:** January 5, 2026
**Status:** CONTRACT CHANGES COMPLETE - PENDING DEPLOYMENT
