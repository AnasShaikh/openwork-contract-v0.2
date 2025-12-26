# CCTP v2 Dynamic Rewards Upgrade - December 25, 2025

**Created**: December 25, 2025
**Status**: 🔴 REVERTED - Attestation Issues
**Goal**: Test new CCTP contract with existing system (reversible)

---

## Current State (After Rollback)

### Arbitrum Sepolia (Native Chain)
| Contract | Current CCTP Address | Notes |
|----------|---------------------|-------|
| **NOWJC** (Proxy) | `0x9E39B37275854449782F1a2a4524405cE79d6C1e` | `setCCTPTransceiver()` |
| **Current CCTP** | `0xB64f20A20F55D77bbe708Db107AA5E53a9E39063` | Original (no rewards) - RESTORED |

### OP Sepolia (Local Chain)
| Contract | Current CCTP Address | Notes |
|----------|---------------------|-------|
| **LOWJC** (Proxy) | `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C` | `setCCTPSender()` |
| **Athena Client** (Proxy) | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | `setCCTPSender()` |
| **Current CCTP** | `0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5` | Original - RESTORED |

### Ethereum Sepolia (Local Chain)
| Contract | Current CCTP Address | Notes |
|----------|---------------------|-------|
| **LOWJC** (Proxy) | `0x3b4cE6441aB77437e306F396c83779A2BC8E5134` | `setCCTPSender()` |
| **Athena Client** (Proxy) | `0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf` | `setCCTPSender()` |
| **Current CCTP** | `0x0ad0306EAfCBf121Ed9990055b89e1249011455F` | v2 dynamic rewards (Dec 16) |

---

## Standard CCTP Addresses (ALL Testnets)

| Contract | Address |
|----------|---------|
| **TokenMessenger** | `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` |
| **MessageTransmitter** | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` |

### USDC Per Chain
| Chain | USDC Address |
|-------|--------------|
| Arbitrum Sepolia | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| OP Sepolia | `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` |
| Ethereum Sepolia | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |
| Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

---

## Execution Log

### Phase 1: Query Rollback Points

**Query NOWJC (Arbitrum):**
```bash
source .env && cast call 0x9E39B37275854449782F1a2a4524405cE79d6C1e "cctpTransceiver()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `0xB64f20A20F55D77bbe708Db107AA5E53a9E39063`

**Query LOWJC (OP Sepolia):**
```bash
source .env && cast call 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "cctpSender()(address)" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** `0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5`

**Query LOWJC (Ethereum Sepolia):**
```bash
source .env && cast call 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 "cctpSender()(address)" --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```
**Result:** `0x0ad0306EAfCBf121Ed9990055b89e1249011455F`

---

### Phase 2: Deploy New CCTP Transceivers

**Deploy to Arbitrum Sepolia:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/cctp-v2-ft-transceiver-with-rewards-dynamic.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
```
**Result:**
- Deployed to: `0x325c6615Caec083987A5004Ce9110f932923Bd3A`
- TX Hash: `0x7668d9ca4cb93a33eb0009b8fc68b20e44f2f0fdc09ed9e59f06ce33d80c7f29`

**Deploy to OP Sepolia:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/cctp-v2-ft-transceiver-with-rewards-dynamic.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```
**Result:**
- Deployed to: `0xA5b076c247c0B64483962cCb08D2dD0005491B47`
- TX Hash: `0x254f4be7091a5a6c16c2612ccf68f78a07e9e7b7ff8e8bc7ea28c31cace5c2e6`

**Fund Reward Pools (0.002 ETH each):**
```bash
# Arbitrum
source .env && cast send 0x325c6615Caec083987A5004Ce9110f932923Bd3A --value 0.002ether --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# OP Sepolia
source .env && cast send 0xA5b076c247c0B64483962cCb08D2dD0005491B47 --value 0.002ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** Both funded successfully

---

### Phase 3: Update Contract References

**NOWJC (Arbitrum) - setCCTPTransceiver:**
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setCCTPTransceiver(address)" 0x325c6615Caec083987A5004Ce9110f932923Bd3A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0x49953134b2b6e15a5f5f3cd445a2d34f74d7ac858a4d2d5d15cd22844234e7f1`
- Status: Success

**LOWJC (OP Sepolia) - setCCTPSender:**
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "setCCTPSender(address)" 0xA5b076c247c0B64483962cCb08D2dD0005491B47 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0x66820bec178a0c16c5d17a7d54a87d92ec14b96c93c3a1c8c8f2bb38e8d35a1a`
- Status: Success

**Athena Client (OP Sepolia) - setCCTPSender:**
```bash
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "setCCTPSender(address)" 0xA5b076c247c0B64483962cCb08D2dD0005491B47 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0xcf6984b6e26a6d05c66c8e62d0b3e1d04e2cfb7e2a9c5ae2b7c4f71d1a8e9f32`
- Status: Success

---

### Phase 4: Testing (FAILED)

**Test: Direct CCTP sendFast**

**Step 1 - Approve USDC:**
```bash
source .env && cast send 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "approve(address,uint256)" 0xA5b076c247c0B64483962cCb08D2dD0005491B47 1000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0x759cae2545d822fb930fd2882973a757d8ebebab5a27cac7368ea39ebd7d2ee7`
- Status: Success

**Step 2 - Call sendFast:**
```bash
source .env && cast send 0xA5b076c247c0B64483962cCb08D2dD0005491B47 \
  "sendFast(uint256,uint32,bytes32,uint256)" \
  1000 3 0x000000000000000000000000fD08836eeE6242092a9c869237a8d122275b024A 100 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Parameters:**
- amount: 1000 (0.001 USDC)
- destinationDomain: 3 (Arbitrum Sepolia)
- recipient: WALL2 address as bytes32
- maxFee: 100

**Result:**
- TX Hash: `0x86bda28b0d432d74b6fb6db75b4e74874a19010d7320f02320b1cd9a3615e1d7`
- Status: Success (USDC burned, message sent)
- Gas Used: 156,166

**Step 3 - Check Attestation:**
```bash
curl -s "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=0x86bda28b0d432d74b6fb6db75b4e74874a19010d7320f02320b1cd9a3615e1d7" | jq .
```
**Result:**
```json
{
  "messages": [{
    "attestation": "PENDING",
    "message": "0x",
    "eventNonce": "0xd6c785084d3ff5c456aaeb848dfcea638340e461588b368d748ceb7a2f9b932c",
    "cctpVersion": 2,
    "status": "pending_confirmations",
    "decodedMessage": null,
    "delayReason": null
  }]
}
```
**Problem:** Attestation stuck on `pending_confirmations` - never progressed to `complete`

---

### Phase 5: Rollback

**NOWJC (Arbitrum) - Revert to old CCTP:**
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e \
  "setCCTPTransceiver(address)" 0xB64f20A20F55D77bbe708Db107AA5E53a9E39063 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0x7619d87b1be7796ad8147504a973699025643548530edcb8e6decb1b124d6289`
- Gas Used: 34,817
- Status: Success

**LOWJC (OP Sepolia) - Revert to old CCTP:**
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "setCCTPSender(address)" 0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0x5af40980f7051e2ea62e1bf89a42286dab9c087d8231cb5ee2966420a16456b1`
- Gas Used: 34,017
- Status: Success

**Athena Client (OP Sepolia) - Revert to old CCTP:**
```bash
source .env && cast send 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 \
  "setCCTPSender(address)" 0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:**
- TX Hash: `0x1912ae79e084736de3e84b16f26db9dd8dc68932d6c97d1b4e564ff3016b0ebe`
- Gas Used: 35,022
- Status: Success

---

## New CCTP Deployments (Available for Future Use)

| Chain | Address | Status |
|-------|---------|--------|
| Arbitrum Sepolia | `0x325c6615Caec083987A5004Ce9110f932923Bd3A` | Deployed, funded 0.002 ETH |
| OP Sepolia | `0xA5b076c247c0B64483962cCb08D2dD0005491B47` | Deployed, funded 0.002 ETH |
| Ethereum Sepolia | `0x0ad0306EAfCBf121Ed9990055b89e1249011455F` | Active (Dec 16) |

---

## Issues Encountered

### CCTP Attestation Not Completing
- Direct sendFast resulted in `pending_confirmations` status
- Attestation never progressed to `complete` after multiple checks
- Possible causes to investigate:
  1. Circle's sandbox API may have delays/issues
  2. Something with the new CCTP transceiver contract
  3. Network-specific configuration issue

---

## Contract Source
**File**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/cctp-v2-ft-transceiver-with-rewards-dynamic.sol`

**Features**:
- Dynamic gas-based rewards: `gasUsed * tx.gasprice * 2`
- Capped at 0.001 ETH max
- Reentrancy protected
- Owner can tune: `setMaxRewardAmount()`, `setRewardMultiplier()`

---

## References
- [CCTP Quick Guide](../context/cctp-attestation-quick-guide.md)
- [CCTP Complete Guide](./CCTP-CONFIRMATION-REWARDS-COMPLETE-GUIDE.md)
- [Ethereum Sepolia CCTP Fix](./ethereum-sepolia-cctp-fix-16-dec-2025.md)
- [Current Addresses](../deployments/openwork-contracts-current-addresses.md)
