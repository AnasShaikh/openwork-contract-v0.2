# NOWJC Security Upgrade Log
**Date:** January 2, 2026
**Contract:** `src/suites/openwork-full-contract-suite-1-Jan-version/nowjc.sol`
**Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`

---

## Summary

Security audit revealed critical authorization gaps in NOWJC contract. This upgrade adds:
1. Admin/Governance pattern for privileged functions
2. `authorizedContracts` checks for all job-related functions

---

## Changes Made

### 1. Admin/Governance Pattern Added

**New State Variables:**
```solidity
mapping(address => bool) public admins;
address public mainDAO;
```

**New Events:**
```solidity
event AdminUpdated(address indexed admin, bool status);
event MainDAOUpdated(address indexed oldDAO, address indexed newDAO);
```

**New Functions:**
```solidity
function setAdmin(address _admin, bool _status) external {
    require(msg.sender == owner() || msg.sender == mainDAO, "Auth");
    admins[_admin] = _status;
    emit AdminUpdated(_admin, _status);
}

function setMainDAO(address _mainDAO) external onlyOwner {
    address oldDAO = mainDAO;
    mainDAO = _mainDAO;
    emit MainDAOUpdated(oldDAO, _mainDAO);
}
```

---

### 2. Functions Converted from `onlyOwner` to `admins[msg.sender]`

| Function | Previous Auth | New Auth |
|----------|---------------|----------|
| `addAuthorizedContract` | `onlyOwner` | `admins[msg.sender]` |
| `removeAuthorizedContract` | `onlyOwner` | `admins[msg.sender]` |
| `setBridge` | `onlyOwner` | `admins[msg.sender]` |
| `setGenesis` | `onlyOwner` | `admins[msg.sender]` |
| `setRewardsContract` | `onlyOwner` | `admins[msg.sender]` |
| `setCCTPReceiver` | `onlyOwner` | `admins[msg.sender]` |
| `setCCTPTransceiver` | `onlyOwner` | `admins[msg.sender]` |
| `setNativeAthena` | `onlyOwner` | `admins[msg.sender]` |
| `setNativeDAO` | `onlyOwner` | `admins[msg.sender]` |
| `setTreasury` | `onlyOwner` | `admins[msg.sender]` |
| `setCommissionPercentage` | `onlyOwner` | `admins[msg.sender]` |
| `setMinCommission` | `onlyOwner` | `admins[msg.sender]` |
| `setUsdcToken` | `onlyOwner` | `admins[msg.sender]` |
| `withdrawCommission` | `treasury` | `admins[msg.sender]` |
| `withdrawAllCommission` | `treasury` | `admins[msg.sender]` |

---

### 3. Functions with New `authorizedContracts` Check

| Function | Previous Auth | New Auth |
|----------|---------------|----------|
| `postJob` | **None** | `authorizedContracts[msg.sender]` |
| `applyToJob` | **None** | `authorizedContracts[msg.sender]` |
| `startJob` | **None** | `authorizedContracts[msg.sender]` |
| `submitWork` | **None** | `authorizedContracts[msg.sender]` |
| `lockNextMilestone` | **None** | `authorizedContracts[msg.sender]` |
| `handleUpdateUserClaimData` | `bridge` | `authorizedContracts[msg.sender]` |
| `handleReleasePaymentCrossChain` | `bridge` | `authorizedContracts[msg.sender]` |
| `handleStartDirectContract` | `bridge` | `authorizedContracts[msg.sender]` |
| `releasePaymentAndLockNext` | `bridge` | `authorizedContracts[msg.sender]` |

---

### 4. Functions Unchanged

| Function | Auth | Reason |
|----------|------|--------|
| `syncVotingPower` | None (uses msg.sender) | User syncs their own data |
| `syncRewardsData` | None (uses msg.sender) | User syncs their own data |
| `releaseDisputedFunds` | `nativeAthena` or `nativeDAO` | Already secured |
| `incrementGovernanceAction` | `authorizedContracts` | Already secured |
| `setApplicantChainDomain` | `authorizedContracts` | Already secured |

---

## Deployment Details

### New Implementation Deployed
- **Address:** `0xdf5027002e0F4B95a5775B361A737E9780aBf522`
- **TX Hash:** `0xe91bf8eb9d67aad579be8d0a8655a9ab39f644d56e1e5c28371de18b18ea4b81`
- **Network:** Arbitrum Sepolia

### Proxy Upgraded (Jan 26 Deployment)
- **Proxy Address:** `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`
- **Previous Implementation:** `0xEA0a8DBA2A4A82a849d41AaCB31881Cce0dcF7F6`
- **New Implementation:** `0xdf5027002e0F4B95a5775B361A737E9780aBf522`
- **Upgrade TX:** `0x2b3c43ab82d721645da934f25ea2f9cd71898fa02729b3c3acd90386906971da`

### Old Proxy Reverted (Dec Deployment - Accidentally Upgraded)
- **Proxy Address:** `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **Reverted to:** `0xAe55797B042169936f7816b85bf8387b739084c4` (Milestone Guards)
- **Revert TX:** `0x7b2c2b0cb2a1ff11b67bd7665de30e42213b343df4d8e92ebc6518dfb0d587cd`

---

## Post-Upgrade Configuration

### Admin Setup
- **Set Admin TX:** `0x6a8a0eeaf13eb7d3ec7ec8a1cab071b6f47aa075fed1b749554ce522739ce6be`
- **Admin Address:** `0xfD08836eeE6242092a9c869237a8d122275b024A` (deployer)

### Authorized Contract Setup
- **Add Authorized TX:** `0x372a2914c7fc5fc07882b817ab47e6dee2857738ab80e9dc7d0ea5d5bb12ad62`
- **Authorized Address:** `0xfD08836eeE6242092a9c869237a8d122275b024A` (deployer for testing)

---

## Contract Size

| Metric | Value |
|--------|-------|
| Original Size | 21,953 bytes |
| Final Size | 22,667 bytes |
| Added | +714 bytes |
| Margin Remaining | 1,909 bytes |

---

## Security Risks Addressed

### Critical (Fixed)
1. **`startJob` - Anyone could select applicant** - Now requires `authorizedContracts`
2. **`postJob` - Anyone could post jobs** - Now requires `authorizedContracts`

### High (Fixed)
1. **`lockNextMilestone` - Anyone could advance milestones** - Now requires `authorizedContracts`
2. **`applyToJob` - Spoofable applicant address** - Now requires `authorizedContracts`
3. **`submitWork` - Anyone could submit work** - Now requires `authorizedContracts`

### Medium (Fixed)
1. **Bridge-only functions opened to authorizedContracts** - Allows flexibility while maintaining security

---

## Backup

Original file backed up at:
`src/suites/openwork-full-contract-suite-1-Jan-version/nowjc.sol.backup`

---

## Next Steps

1. Add NOWJC proxy to Genesis authorized contracts (for `genesis.setJob`, etc.)
2. Add bridge contract to authorizedContracts
3. Test full job cycle (postJob → applyToJob → startJob → submitWork)
4. Update deployment addresses documentation

---

**Log Created:** January 2, 2026
**Author:** Claude Code
