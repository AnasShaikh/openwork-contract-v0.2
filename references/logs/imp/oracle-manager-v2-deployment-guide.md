# Oracle Manager v2 - Allow Empty Members Deployment Guide

**Date**: November 30, 2025  
**Purpose**: Deploy and upgrade Oracle Manager to allow oracle creation with empty member arrays  
**Contract**: `native-athena-oracle-manager-v2-allow-empty-members.sol`  
**Change**: Modified `addSingleOracle()` line 123 to allow empty member arrays

---

## What Changed

### Line 123 Modification:
```solidity
// OLD (v1):
require(_members.length >= nativeAthena.minOracleMembers(), "Not enough members for oracle");

// NEW (v2):
require(_members.length == 0 || _members.length >= nativeAthena.minOracleMembers(), "Not enough members for oracle");
```

### Impact:
- ✅ DAO proposals can now create oracles with 0 members using `addSingleOracle()`
- ✅ When members ARE provided, validation still enforces minimum count
- ✅ No other functionality changed

---

## Step 1: Deploy New Implementation

```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-layerzero+CCTP 20 Nov/native-athena-oracle-manager-v2-allow-empty-members.sol:NativeAthenaOracleManager"
```

### Record Deployment Output:

**New Implementation Address**: `0x92F3DDba7Cd5c5734a772ABD53C524b3a4acc179` ✅

**Deployment TX Hash**: `0x98ca0e63252572153c7062a8ed08c33ec72efdfc0302ee59fa30b7755fc8d218` ✅

**Block Number**: `220488527` ✅

**Timestamp**: `November 30, 2025, 7:45 PM IST` ✅

---

## Step 2: Upgrade Proxy

```bash
source .env && cast send 0x70F6fa515120efeA3e404234C318b7745D23ADD4 "upgradeToAndCall(address,bytes)" NEW_IMPLEMENTATION_ADDRESS 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

Replace `NEW_IMPLEMENTATION_ADDRESS` with the address from Step 1.

### Record Upgrade Output:

**Upgrade TX Hash**: `0x4bcfb990c1ba486e010f7cb583e0e90b738d60e3084a546d0aca61b3e63d440b` ✅

**Block Number**: `220488527` ✅

**Timestamp**: `November 30, 2025, 7:45 PM IST` ✅

---

## Step 3: Verify Upgrade

Test oracle creation with empty members:

```javascript
// Via DAO proposal or direct call
await nativeAthena.addSingleOracle(
  "TestEmptyOracle",
  [],  // Empty members - should now work
  "Test oracle with no members",
  "QmTestHash",
  []
);
```

**Test TX Hash**: `0x_____________________________` ← FILL THIS IN

**Result**: ✅ Success / ❌ Failed

---

## Step 4: Update Contract Addresses Document

Add to `references/deployments/openwork-contracts-current-addresses.md`:

```markdown
| **Oracle Manager** (Proxy) | `0x70F6fa515120efeA3e404234C318b7745D23ADD4` | - | ✅ |
| **Oracle Manager** (Implementation v2 - Allow Empty) | `0x_____________________________` | `src/suites/openwork-full-contract-suite-layerzero+CCTP 20 Nov/native-athena-oracle-manager-v2-allow-empty-members.sol` | ✅ |
| **Oracle Manager** (Previous Implementation v1) | `0xAdf1d61e5DeD34fAF507C8CEF24cdf46f46bF537` | - | 🔄 |
```

---

## Emergency Rollback

If issues arise, revert to previous implementation:

```bash
source .env && cast send 0x70F6fa515120efeA3e404234C318b7745D23ADD4 "upgradeToAndCall(address,bytes)" 0xAdf1d61e5DeD34fAF507C8CEF24cdf46f46bF537 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Rollback TX Hash (if needed)**: `0x_____________________________`

---

## Post-Deployment Checklist

- [ ] Implementation deployed
- [ ] Proxy upgraded
- [ ] Test oracle creation with empty members successful
- [ ] Contract addresses document updated
- [ ] Team notified of upgrade
- [ ] Frontend updated to use `addSingleOracle()` with empty arrays

---

## Frontend Integration

After deployment, frontend can use:

```javascript
// Via DAO proposal encoding
const calldata = web3.eth.abi.encodeFunctionCall({
  name: 'addSingleOracle',
  type: 'function',
  inputs: [
    { type: 'string', name: '_name' },
    { type: 'address[]', name: '_members' },
    { type: 'string', name: '_shortDescription' },
    { type: 'string', name: '_hashOfDetails' },
    { type: 'address[]', name: '_skillVerifiedAddresses' }
  ]
}, [
  "NewOracle",
  [],  // ✅ Empty array now works!
  "Description",
  "QmHash",
  []
]);

// Submit as DAO proposal targeting Native Athena
await daoContract.createProposal(
  nativeAthenaAddress,
  0,
  calldata,
  "Create oracle with no initial members"
);
```

---

## Notes

- **Deployment Cost**: ~1.5M gas (~$0.15 on Arbitrum Sepolia)
- **Upgrade Cost**: ~50k gas (~$0.005 on Arbitrum Sepolia)
- **Breaking Changes**: None - backward compatible
- **Testing**: Test on testnet before production
- **Verification**: Remember to verify contract on Arbiscan

---

**Deployed By**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)  
**Network**: Arbitrum Sepolia  
**Status**: ✅ DEPLOYED & UPGRADED
