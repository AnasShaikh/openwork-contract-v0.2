# Team Tokens Deployment - Quick Checklist

**Date:** ________________
**Network:** ________________
**Deployer:** ________________

---

## Pre-Deployment Checklist

- [ ] Load environment variables: `source .env`
- [ ] Verify deployer wallet has sufficient gas
- [ ] Have all existing contract addresses ready:
  - [ ] NOWJC Proxy: `______________________________`
  - [ ] Genesis Proxy: `______________________________`
  - [ ] Native DAO Proxy: `______________________________`
  - [ ] Multisig Address: `______________________________`
  - [ ] Main DAO Address: `______________________________`

---

## Deployment Steps

### 1. Main Rewards (if needed)
- [ ] Deploy implementation
- [ ] Deploy proxy
- [ ] Initialize proxy
- [ ] **Address:** `______________________________`

### 2. Token v2
- [ ] Deploy with correct constructor params
- [ ] Verify 750M sent to main-rewards
- [ ] Verify 250M sent to DAO
- [ ] Verify 0 sent to owner
- [ ] **Address:** `______________________________`

### 3. Link Token to Main Rewards
- [ ] Call `setOpenworkToken(token)`
- [ ] Verify link

### 4. Native Rewards with Team Tokens
- [ ] Deploy implementation
- [ ] Deploy proxy
- [ ] Initialize proxy
- [ ] **Address:** `______________________________`

### 5. Update NOWJC
- [ ] Call `setRewardsContract(nativeRewards)`
- [ ] Verify link

---

## Configuration Steps

### 6. Set DAO Address
- [ ] Call `setNativeDAO(daoAddress)`
- [ ] Verify DAO address

### 7. Allocate Team Tokens
- [ ] Prepare allocation list
- [ ] Call `allocateTeamTokens(members, amounts)`
- [ ] Verify allocations:
  - [ ] Member 1: `____________` - `__________` tokens
  - [ ] Member 2: `____________` - `__________` tokens
  - [ ] Member 3: `____________` - `__________` tokens

---

## Verification Checklist

### Token Distribution
- [ ] Main Rewards balance = 750M
- [ ] DAO balance = 250M
- [ ] Owner balance = 0

### Team Token Config
- [ ] Pool size = 150M
- [ ] Unlock rate = 150k/action
- [ ] DAO address set

### Contract Links
- [ ] NOWJC → Native Rewards ✓
- [ ] Native Rewards → NOWJC ✓
- [ ] Main Rewards → Token ✓

### Team Members
- [ ] All members allocated
- [ ] Total allocation ≤ 150M
- [ ] All members are team members

---

## Testing Checklist

- [ ] Test 1: Token distribution verified
- [ ] Test 2: Configuration verified
- [ ] Test 3: Team member allocation verified
- [ ] Test 4: End-to-end claim flow tested
- [ ] Test 5: Non-member returns 0
- [ ] Test 6: Pool adjustment works
- [ ] Test 7: Rate adjustment works
- [ ] Test 8: Pool statistics correct

---

## Post-Deployment Actions

- [ ] Transfer ownership to multisig/timelock (if needed)
- [ ] Document all addresses in deployment log
- [ ] Verify contracts on block explorer
- [ ] Announce deployment to team
- [ ] Monitor first few claims

---

## Emergency Contacts

- Multisig: `______________________________`
- Timelock: `______________________________`
- Emergency Admin: `______________________________`

---

## Rollback Plan

If something goes wrong:

1. **Token Issue:**
   - Cannot rollback (tokens already distributed)
   - Deploy new token and redistribute manually

2. **Native Rewards Issue:**
   - Upgrade proxy to previous implementation
   - Or deploy new implementation and upgrade

3. **Config Issue:**
   - Call setter functions to fix
   - No upgrade needed

---

## Notes & Issues

_Use this space to track any issues encountered:_

```





```

---

**Completion Date:** ________________
**Status:** ✅ Success / ❌ Issues / ⚠️ Partial

**Final Deployed Addresses:**
- Token: `______________________________`
- Main Rewards: `______________________________`
- Native Rewards: `______________________________`
