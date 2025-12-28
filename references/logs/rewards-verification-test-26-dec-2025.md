# OW Community Token Rewards Verification Test - December 26, 2025

**Date**: December 26, 2025
**Purpose**: Verify OW token rewards are calculated and allocated correctly, including referrer rewards
**Status**: ✅ **COMPLETE - REWARDS VERIFIED**

---

## Known Issues (TO FIX LATER)

1. **LOWJC local profile check**: Each chain's LOWJC maintains its own `hasProfile` mapping. Users must create profiles on each chain separately. Should be fixed to either sync profiles cross-chain or remove local check.

2. **CCTP same-chain payment bug**: When applicant sets `preferredPaymentChainDomain` to the same chain as NOWJC (e.g., domain 3 for Arbitrum), the release fails with "No TokenMessenger for domain" because CCTP can't send to itself. Contract should detect same-chain payments and do direct transfer instead.

---

## Test Setup

### Participants
| Wallet | Address | Role |
|--------|---------|------|
| **WALL1** | `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` | Job Giver |
| **WALL2** | `0xfD08836eeE6242092a9c869237a8d122275b024A` | Job Taker + WALL1's Referrer |

### Referrer Relationship
- WALL1's referrer = **WALL2**
- WALL2's referrer = None

### Contract Addresses
| Contract | Network | Address |
|----------|---------|---------|
| **LOWJC** (Proxy) | Ethereum Sepolia | `0x3b4cE6441aB77437e306F396c83779A2BC8E5134` |
| **NOWJC** (Proxy) | Arbitrum Sepolia | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` |
| **Native Rewards** | Arbitrum Sepolia | `0x947cAd64a26Eae5F82aF68b7Dbf8b457a8f492De` |
| **Profile Genesis** | Arbitrum Sepolia | `0xC37A9dFbb57837F74725AAbEe068f07A1155c394` |
| **USDC** | Ethereum Sepolia | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |

---

## Reward Calculation (Band 0: $0 - $100k)

**Rate**: 300 OW per dollar

**Job Value**: 1,000,000 USDC units = **$1.00 USDC**

### Expected Distribution
| Recipient | Role | Share | Amount | OW Tokens |
|-----------|------|-------|--------|-----------|
| WALL1 | Job Giver | 90% | $0.90 | **270 OW** |
| WALL2 | Referrer | 10% | $0.10 | **30 OW** |
| **Total** | | 100% | $1.00 | **300 OW** |

**Formula**: `job_value_in_dollars × 300 OW/dollar`

---

## Pre-Balance Snapshot

**Timestamp**: December 26, 2025

| Wallet | OW Tokens (wei) | OW Tokens |
|--------|-----------------|-----------|
| WALL1 | 270,000,000,000,000,000,000 | **270 OW** |
| WALL2 | 11,910,000,000,000,000,000,000 | **11,910 OW** |

**Platform Total Payments**: 48,600,000 USDC units ($48.60)

---

## Execution Log

### Step 1: Post Job from WALL1 (Ethereum Sepolia)
**Status**: ✅ COMPLETE
- Job ID: `40161-11`
- TX Hash: `0xe269b530703741d93b04c640f1de609717bd8281c1cfe2764ee2da04b8c233d4`
- LayerZero: DELIVERED

---

### Step 2: Apply to Job from WALL2
**Status**: ✅ COMPLETE
- Application ID: `1`
- TX Hash: `0xb698c32ad414ee0b17d806082a50f582d34a109d70d1fb450ffdd8b26b8101c7`
- LayerZero: DELIVERED
- Note: Required creating profile for WALL2 on Eth Sepolia first (see Known Issue #1)

---

### Step 3: Approve USDC from WALL1
**Status**: ✅ COMPLETE
- TX Hash: `0xd2c77c08cf67857a224c7144b950baf1f683ba532cac8aec0d41145a048829c9`
- Amount: 1,000,000 USDC units

---

### Step 4: Start Job from WALL1 (CCTP Transfer)
**Status**: ✅ COMPLETE
- TX Hash: `0x6a58733de514260b9237a331f56e5912e654deba24b697d7e4a0bff563e4aeea`
- LayerZero: DELIVERED
- CCTP: Attestation complete (~60 seconds)

---

### Step 5: Complete CCTP Receive on Arbitrum
**Status**: ✅ COMPLETE
- TX Hash: `0xebf2061409dd88fa7b174fd4cecb29c7098ca10c4e55b881c002ce79932d3425`
- USDC Minted to NOWJC: 999,900 units (fee: 100)

---

### Step 6: Release Payment (TRIGGERS REWARDS)
**Status**: ✅ COMPLETE

**First Attempt** (via LOWJC cross-chain): FAILED
- Error: "No TokenMessenger for domain" - applicant used domain 3 (Arbitrum) as payment chain but NOWJC is already on Arbitrum. CCTP can't send to same chain.
- See Known Issue #2

**Workaround**: Called `releasePaymentCrossChain` directly on NOWJC (Arbitrum)
- TX Hash: `0x5cd6a92db19f4081506b0639a14acc111be6b734682b5741e0edf9688270a913`
- Called by: WALL2 (WALL1 had no ETH on Arbitrum)
- Target domain: 0 (Ethereum Sepolia)

---

## Post-Balance Snapshot

**Timestamp**: December 26, 2025

| Wallet | Pre-Balance | Post-Balance | Change | Expected | Status |
|--------|-------------|--------------|--------|----------|--------|
| WALL1 | 270 OW | **540 OW** | **+270 OW** | +270 OW | ✅ MATCH |
| WALL2 | 11,910 OW | **11,940 OW** | **+30 OW** | +30 OW | ✅ MATCH |

**Platform Total Payments**: 49,600,000 USDC units ($49.60) ✅

---

## Verification Results

### WALL1 (Job Giver - 90%)
- **Expected**: +270 OW (90% of 300 OW)
- **Actual**: +270 OW
- **Match**: ✅ **EXACT MATCH**

### WALL2 (Referrer - 10%)
- **Expected**: +30 OW (10% of 300 OW)
- **Actual**: +30 OW
- **Match**: ✅ **EXACT MATCH**

### Platform Total
- **Expected**: +1,000,000 USDC units (+$1.00)
- **Actual**: +1,000,000 USDC units (+$1.00)
- **Match**: ✅ **EXACT MATCH**

---

## Conclusion

**Status**: ✅ **SUCCESS**
**Rewards Working Correctly**: ✅ **YES**

The OW community token rewards system is functioning exactly as designed:

1. **Job giver receives 90%** of rewards (after referrer deduction)
2. **Referrer receives 10%** bonus for referring the job giver
3. **Band 0 rate (300 OW/dollar)** is correctly applied
4. **Platform total** is correctly incremented

### Key Observations
- Rewards are triggered when payment is released via `releasePaymentCrossChain()` on NOWJC
- The `_processRewardsForPayment()` function correctly calls `rewardsContract.processJobPayment()`
- Referrer lookup via ProfileGenesis is working correctly
- Token distribution matches the expected 90/10 split

---

## Transaction Summary

| Step | TX Hash | Network | Status |
|------|---------|---------|--------|
| Post Job | `0xe269b530...` | Eth Sepolia | ✅ |
| Apply | `0xb698c32a...` | Eth Sepolia | ✅ |
| Approve USDC | `0xd2c77c08...` | Eth Sepolia | ✅ |
| Start Job | `0x6a58733d...` | Eth Sepolia | ✅ |
| CCTP Receive | `0xebf20614...` | Arb Sepolia | ✅ |
| Release Payment | `0x5cd6a92d...` | Arb Sepolia | ✅ |

---

**Test Started**: December 26, 2025
**Test Completed**: December 26, 2025
