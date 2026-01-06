# CCTP Transceiver Upgrade - January 6, 2026

## Purpose
Replace existing CCTP transceivers with fixed version that:
1. Adds return value check on `transferFrom` in `sendFast` (line 118)
2. Fixes broken `recoverUSDC` function (was using `transferFrom` instead of `transfer`)

## Source Contract
`src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver-post-audit-2.sol`

---

## ROLLBACK INFORMATION

### Current (OLD) CCTP Transceivers - SAVE THESE

| Chain | OLD Address | Constructor Args |
|-------|-------------|------------------|
| Arbitrum Sepolia | `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` | tokenMessenger=`0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`, messageTransmitter=`0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`, usdc=`0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| OP Sepolia | `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` | tokenMessenger=`0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`, messageTransmitter=`0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`, usdc=`0x5fd84259d66Cd46123540766Be93DFE6D43130D7` |

### Contracts That Reference CCTP Transceiver

| Chain | Contract | Proxy Address | Setter Function |
|-------|----------|---------------|-----------------|
| Arbitrum Sepolia | NOWJC | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` | `setCCTPTransceiver(address)` |
| OP Sepolia | LOWJC | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` | `setCCTPSender(address)` |

### To Rollback (if needed)

```bash
# Rollback Arbitrum Sepolia NOWJC to OLD transceiver
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setCCTPTransceiver(address)" 0xD22C85d18D188D37FD9D38974420a6BD68fFC315 --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $DEPLOYER_KEY

# Rollback OP Sepolia LOWJC to OLD transceiver
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "setCCTPSender(address)" 0x2139Ef959b7C83fF853DB8882C258E586e07E9BE --rpc-url $OP_SEPOLIA_RPC_URL --private-key $DEPLOYER_KEY
```

---

## UPGRADE EXECUTION LOG

### Step 1: Deploy NEW CCTP Transceiver on Arbitrum Sepolia

**Status:** COMPLETED

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver-post-audit-2.sol:CCTPv2TransceiverWithRewardsDynamic" --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
```

**Result:**
- NEW Address: `0xA7c1Eb1D2A539D58Ee82C923b10a6B32386bbA6f`
- TX Hash: `0xac784fe77de08fc9713dd0bc8b6ab140e588bedb6e95cde69eb65510b81a721e`

---

### Step 2: Update NOWJC to use NEW transceiver

**Status:** COMPLETED

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setCCTPTransceiver(address)" 0xA7c1Eb1D2A539D58Ee82C923b10a6B32386bbA6f --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result:**
- TX Hash: `0x849785faa0cb2e62a31e1755e57abf41ab35f58dedee9f1385685b5dacbe1105`

**Verification:**
```bash
source .env && cast call 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "cctpTransceiver()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Returns: 0x000000000000000000000000a7c1eb1d2a539d58ee82c923b10a6b32386bba6f ✓
```

---

### Step 3: Deploy NEW CCTP Transceiver on OP Sepolia

**Status:** COMPLETED

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver-post-audit-2.sol:CCTPv2TransceiverWithRewardsDynamic" --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

**Result:**
- NEW Address: `0xC06C04fE22798839F97665e0e40d8B2397e903f2`
- TX Hash: `0x5d4dbc635c80a38eb18032db1d8b965cdd95e6a8c5eb51c7031a1f810c794dfe`

---

### Step 4: Update LOWJC to use NEW transceiver

**Status:** COMPLETED

**Command:**
```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "setCCTPSender(address)" 0xC06C04fE22798839F97665e0e40d8B2397e903f2 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result:**
- TX Hash: `0x4845ced154ddce234927ff68aed9b005528148af1c84926dbcc740ef986b45f2`

**Verification:**
```bash
source .env && cast call 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "cctpSender()" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
# Returns: 0x000000000000000000000000c06c04fe22798839f97665e0e40d8b2397e903f2 ✓
```

---

### Step 5: Test Cross-Chain Transfer (Job Cycle)

**Status:** COMPLETED ✅

**Test:** Full job cycle with CCTP transfer from OP Sepolia to Arbitrum Sepolia

#### 5.1 Post Job
- **Job ID:** `40232-6`
- **TX (OP):** `0x15dd873d7d5eea0b3989f07f23f02d774210b48f553eb42ab39704220261df4b`
- **LZ Status:** DELIVERED

#### 5.2 Apply to Job
- **TX (OP):** `0x4e9636b8e3952491daf338354061f1d991d65d8671f44338a413215d6f42fda0`
- **LZ Status:** DELIVERED

#### 5.3 Start Job (CCTP Transfer)
- **TX (OP):** `0xe5ddeabe78fd29c877f020cb8bd6ab0d7ac392ffe297a979494c0be4b18a6a23`
- **Amount:** 1,000,000 (1 USDC)
- **Pre-balance (WALL1 OP):** 37,595,800
- **Post-balance (WALL1 OP):** 36,595,800
- **CCTP Burn:** ✅ Success via new transceiver `0xC06C04fE22798839F97665e0e40d8B2397e903f2`

**Conclusion:** New CCTP transceiver `sendFast` function works correctly with the return value check fix.

#### 5.4 CCTP Receive on Arbitrum
- **TX (Arb):** `0x18f95f3a787537d160fafcb2c0862056064a0fcfaf058de894e4b607e3b1dc06`
- **Contract Called:** Circle MessageTransmitter `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- **Amount Sent:** 1,000,000 USDC units
- **CCTP Fee:** 100 USDC units
- **Amount Received:** 999,900 USDC units
- **NOWJC Pre-balance:** 1,999 USDC units
- **NOWJC Post-balance:** 1,001,899 USDC units ✅

**Full E2E Conclusion:** New CCTP transceivers work correctly:
1. ✅ `sendFast` on OP Sepolia burns USDC with return value check
2. ✅ Circle attestation received successfully
3. ✅ `receiveMessage` on Arbitrum mints USDC to NOWJC

---

### Step 6: Test Reverse CCTP Flow (Arb → OP via releasePayment)

**Status:** COMPLETED ✅

**Test:** Release payment from NOWJC on Arbitrum back to worker on OP Sepolia

#### 6.1 Pre-Release Balances

```bash
# WALL2 USDC on OP Sepolia
source .env && cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 "balanceOf(address)(uint256)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
# Result: 11,267,963 USDC units

# NOWJC USDC on Arb Sepolia
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "balanceOf(address)(uint256)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Result: 1,001,899 USDC units
```

#### 6.2 Release Payment Cross-Chain

**Command:**
```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 \
  "releasePaymentCrossChain(string,uint32,address,bytes)" \
  "40232-6" \
  2 \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  "0x000301001101000000000000000000000000000F4240" \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Parameters:**
- Job ID: `40232-6`
- Target Chain Domain: `2` (OP Sepolia CCTP domain)
- Target Recipient: `0xfD08836eeE6242092a9c869237a8d122275b024A` (WALL2)
- LZ Options: `0x000301001101000000000000000000000000000F4240` (1M gas)

**Result:**
- **TX (OP Sepolia):** `0x24ce020a810aa9228cdec2cce48236fcbf4d28443370d34403d5518d20c8e87b`

#### 6.3 LayerZero Message Delivery

```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/0x24ce020a810aa9228cdec2cce48236fcbf4d28443370d34403d5518d20c8e87b" | jq '.data[0].status, .data[0].destination.tx.txHash'
```

**Result:**
- **LZ Status:** DELIVERED
- **Destination TX (Arb):** `0xc83ee8f71d39623f1038255f5dd9eedb57ad9053825ab1817ded8626bd21578a`

#### 6.4 CCTP Attestation (Arb → OP)

```bash
curl -s "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=0xc83ee8f71d39623f1038255f5dd9eedb57ad9053825ab1817ded8626bd21578a" | jq '.'
```

**Result:**
- **Status:** complete
- **Source Domain:** 3 (Arbitrum)
- **Destination Domain:** 2 (OP Sepolia)
- **Mint Recipient:** `0xfd08836eee6242092a9c869237a8d122275b024a` (WALL2)
- **Amount:** 1,000,899 USDC units
- **Message Sender:** `0xa7c1eb1d2a539d58ee82c923b10a6b32386bba6f` (NEW Arb transceiver) ✅

#### 6.5 CCTP Receive on OP Sepolia

**Command:**
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "MESSAGE_FROM_API" \
  "ATTESTATION_FROM_API" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Result:**
- **TX (OP Sepolia):** `0xc39ad0ddbfdbce42964fe2742ebab6c6152d76ba39c525d72bdca547de18891f`

#### 6.6 Post-Release Balances

```bash
# WALL2 USDC on OP Sepolia
source .env && cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 "balanceOf(address)(uint256)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
# Result: 12,268,762 USDC units (+1,000,799)

# NOWJC USDC on Arb Sepolia
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "balanceOf(address)(uint256)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
# Result: 1,000 USDC units (-1,000,899)
```

#### 6.7 Reverse Flow Summary

| Metric | Value |
|--------|-------|
| WALL2 Pre-balance (OP) | 11,267,963 USDC units |
| WALL2 Post-balance (OP) | 12,268,762 USDC units |
| **WALL2 Received** | **+1,000,799 USDC units** |
| NOWJC Pre-balance (Arb) | 1,001,899 USDC units |
| NOWJC Post-balance (Arb) | 1,000 USDC units |
| **NOWJC Burned** | **1,000,899 USDC units** |
| CCTP Fee | 100 USDC units |

**Reverse Flow Conclusion:** New CCTP transceiver on Arbitrum (`0xA7c1Eb1D...`) correctly:
1. ✅ Burns USDC via `sendFast` with return value check
2. ✅ Circle attestation received successfully
3. ✅ `receiveMessage` on OP Sepolia mints USDC to worker

---

## Summary

### Deployed Contracts

| Chain | Component | OLD Address | NEW Address | Status |
|-------|-----------|-------------|-------------|--------|
| Arb Sepolia | CCTP Transceiver | `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` | `0xA7c1Eb1D2A539D58Ee82C923b10a6B32386bbA6f` | ✅ LIVE |
| OP Sepolia | CCTP Transceiver | `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` | `0xC06C04fE22798839F97665e0e40d8B2397e903f2` | ✅ LIVE |

### E2E Test Results

| Direction | Flow | Transceiver Used | TX Hashes | Status |
|-----------|------|------------------|-----------|--------|
| OP → Arb | startJob (1 USDC) | OP `0xC06C04fE...` | Source: `0xe5ddeabe...` / CCTP: `0x18f95f3a...` | ✅ |
| Arb → OP | releasePayment (~1 USDC) | Arb `0xA7c1Eb1D...` | Source: `0x24ce020a...` / CCTP: `0xc39ad0dd...` | ✅ |

### Security Fixes Validated

| Fix | Description | Test Result |
|-----|-------------|-------------|
| H-1 | `require(usdc.transferFrom(...))` in `sendFast` | ✅ Both directions |
| H-2 | `usdc.transfer()` in `recoverUSDC` | ✅ Ready (not tested, admin function) |

## Upgrade Complete - January 6, 2026

All CCTP transceivers have been upgraded with security fixes and tested bidirectionally. Rollback commands are documented above if needed.
