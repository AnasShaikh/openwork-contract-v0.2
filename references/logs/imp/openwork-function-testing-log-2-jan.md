# Cross-Chain Function Testing Log

**Date:** January 3, 2026
**Network:** Testnet (Arbitrum Sepolia, OP Sepolia, ETH Sepolia)

---

## Contract Addresses

| Contract | Chain | Address |
|----------|-------|---------|
| LOWJC | OP Sepolia | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` |
| LocalBridge | OP Sepolia | `0xF069BE11c655270038f89DECFF4d9155D0910C95` |
| NativeChainBridge | Arb Sepolia | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` |
| ProfileManager | Arb Sepolia | `0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D` |
| ProfileGenesis | Arb Sepolia | `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e` |

---

## 1. createProfile (Cross-Chain)

**Flow:** LOWJC (OP Sepolia) → LocalBridge → NativeChainBridge (Arb) → ProfileManager → ProfileGenesis

### 1.1 Failed Attempts (200k gas)

Multiple attempts with 200k gas option failed with `SIMULATION_REVERTED`.

**LZ Options (200k gas):** `0x00030100110100000000000000000000000000030d40`

---

### 1.2 Configuration Fixes Required

Before cross-chain calls worked, these configurations were missing:

#### Fix 1: Add Local Chain to NativeChainBridge
```bash
source .env && cast send 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 "addLocalChain(uint32)" 40232 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** ✅ Success

#### Fix 2: Set ProfileGenesis on ProfileManager
```bash
source .env && cast send 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D "setGenesis(address)" 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** ✅ Success

#### Fix 3: Authorize ProfileManager on ProfileGenesis
```bash
source .env && cast send 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e "authorizeContract(address,bool)" 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** ✅ Success

---

### 1.3 Verify Configurations

```bash
# Check ProfileManager.genesis()
source .env && cast call 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D "genesis()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e` ✅

```bash
# Check ProfileGenesis.authorizedContracts(ProfileManager)
source .env && cast call 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e "authorizedContracts(address)" 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `true` ✅

```bash
# Check ProfileManager.bridge()
source .env && cast call 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D "bridge()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` ✅

---

### 1.4 Direct Local Test (ProfileManager)

To isolate the issue, tested ProfileManager directly by temporarily setting bridge to wallet.

#### Step 1: Set bridge to wallet temporarily
```bash
source .env && cast send 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D "setBridge(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX:** `0x719e9dc171355eae7c4236d2205d259c8e15dce4c23f516a35772aba52cc1e05`
**Result:** ✅ Success

#### Step 2: Call createProfile directly
```bash
source .env && cast send 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D "createProfile(address,string,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A "QmTestProfileHash123" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX:** `0xb66e391c8728833dc02d001748e3503c9def5a6851cc2c7f3ca40738f0bd95c4`
**Result:** ✅ Success - ProfileCreated event emitted

#### Step 3: Restore bridge to NativeChainBridge
```bash
source .env && cast send 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D "setBridge(address)" 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**TX:** `0x37344a1a9ac485c80274fb3230171533519ef4719c0ce248c71db61148b325ba`
**Result:** ✅ Success

**Conclusion:** ProfileManager → ProfileGenesis path works correctly. Issue was insufficient gas for cross-chain execution.

---

### 1.5 Successful Cross-Chain Test (1M gas)

**LZ Options (1M gas):** `0x000301001101000000000000000000000000000F4240`

```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "createProfile(string,address,bytes)" "QmNewProfileHash456" 0x0000000000000000000000000000000000000000 0x000301001101000000000000000000000000000F4240 --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Parameters:**
- IPFS Hash: `QmNewProfileHash456`
- Referrer: `0x0000000000000000000000000000000000000000` (none)
- LZ Options: `0x000301001101000000000000000000000000000F4240` (1M gas)
- Value: 0.001 ETH
- Wallet: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`

**Source TX (OP Sepolia):** `0xb7a92bfe55763c85267942041b98322f7b19cdc407f628c4ca5b1c813da74c77`
**Destination TX (Arb Sepolia):** `0x7f44b09510349a58fdc948874a11a237d149b3f191c612296af842c15ff3a2a1`

**LZ Message Status:** ✅ DELIVERED - SUCCEEDED

---

### 1.6 Verify Profile Created

```bash
# Check hasProfile
source .env && cast call 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e "hasProfile(address)" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `true` ✅

```bash
# Get profile details
source .env && cast call 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e "getProfile(address)" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** Profile struct with `QmNewProfileHash456` ✅

---

## LZ Message Status API

```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/<TX_HASH>" | jq '.data[0].status, .data[0].destination'
```

---

## Key Findings

| Issue | Root Cause | Solution |
|-------|------------|----------|
| Cross-chain SIMULATION_REVERTED | Insufficient gas (200k) | Use 1M gas in LZ options |
| ProfileManager → ProfileGenesis failed | Wrong genesis address at init | `setGenesis()` to ProfileGenesis |
| ProfileGenesis rejected ProfileManager | Missing authorization | `authorizeContract(ProfileManager, true)` |
| NativeChainBridge rejected messages | Missing local chain config | `addLocalChain(40232)` |

---

## LZ Options Reference

| Gas Amount | Hex Options |
|------------|-------------|
| 200,000 (200k) | `0x00030100110100000000000000000000000000030d40` |
| 1,000,000 (1M) | `0x000301001101000000000000000000000000000F4240` |

**Format:** `0x0003 01 0011 01 <32-byte gas value>`

---

## 2. postJob (Cross-Chain)

**Flow:** LOWJC (OP Sepolia) → LocalBridge → NativeChainBridge (Arb) → NOWJC

### 2.1 Gas Estimation for LZ Options

To determine optimal LZ gas options, simulate destination gas and add a buffer:

```bash
# Step 1: Estimate destination gas (simulate from bridge address)
source .env && cast estimate 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "postJob(string,address,string,string[],uint256[])" "40232-1" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef "QmTestJobDetailHash123" '["Milestone 1","Milestone 2"]' '[1000000,2000000]' --from 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** 337,261 gas

**Calculation:** 337,261 × 2 (buffer) ≈ 700,000 gas → Options: `0x000301001101000000000000000000000000000AAE60`

### 2.2 Quote LZ Fee

```bash
source .env && cast call 0xF069BE11c655270038f89DECFF4d9155D0910C95 "quoteNativeChain(bytes,bytes)(uint256)" $(cast abi-encode "f(string,string,address,string,string[],uint256[])" "postJob" "40232-test1" "0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef" "QmTestJobDetailHash" '["Milestone 1","Milestone 2"]' '[1000000,2000000]') "0x000301001101000000000000000000000000000AAE60" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** ~0.0000293 ETH

### 2.3 Execute postJob Cross-Chain

```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "postJob(string,string[],uint256[],bytes)" "QmTestJobDetailHash123" '["Milestone 1","Milestone 2"]' '[1000000,2000000]' "0x000301001101000000000000000000000000000AAE60" --value 0.0001ether --private-key $PRIVATE_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Parameters:**
- Job Detail Hash: `QmTestJobDetailHash123`
- Milestones: `["Milestone 1", "Milestone 2"]`
- Amounts: `[1000000, 2000000]`
- LZ Options: `0x000301001101000000000000000000000000000AAE60` (700k gas)
- Value: 0.0001 ETH
- Wallet: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`

**Source TX (OP Sepolia):** `0x2a21d595e7cb252536ed0d6f31c5167244d7b987602d1f4f3285fa7a88eb0c1a`
**Destination TX (Arb Sepolia):** `0xafbf91c85a73cb9436514abe0c371616af62de780b0e5b5a80803decc6bd902b`

**LZ Message Status:** ✅ DELIVERED

### 2.4 Verify Job Created

```bash
source .env && cast call 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "getJob(string)" "40232-1" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Result:**
- Job ID: `40232-1`
- Job Giver: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- Job Detail Hash: `QmTestJobDetailHash123`
- Milestones: 1,000,000 / 2,000,000
- Status: Open ✅

---

## 3. applyToJob (Cross-Chain)

**Flow:** LOWJC (OP Sepolia) → LocalBridge → NativeChainBridge (Arb) → NOWJC

### 3.1 Gas Estimation

```bash
source .env && cast estimate 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "applyToJob(address,string,string,string[],uint256[],uint32)" 0xfD08836eeE6242092a9c869237a8d122275b024A "40232-1" "QmApplicationHash123" '["App Milestone 1","App Milestone 2"]' '[500000,1500000]' 3 --from 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** 435,610 gas

**Calculation:** 435,610 × 2 (buffer) ≈ 900,000 gas → Options: `0x000301001101000000000000000000000000000DBBA0`

### 3.2 Quote LZ Fee

```bash
source .env && cast call 0xF069BE11c655270038f89DECFF4d9155D0910C95 "quoteNativeChain(bytes,bytes)(uint256)" $(cast abi-encode "f(string,address,string,string,string[],uint256[],uint32)" "applyToJob" "0xfD08836eeE6242092a9c869237a8d122275b024A" "40232-1" "QmApplicationHash123" '["App Milestone 1","App Milestone 2"]' '[500000,1500000]' 3) "0x000301001101000000000000000000000000000DBBA0" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** ~0.0000354 ETH

### 3.3 Execute applyToJob Cross-Chain

```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "applyToJob(string,string,string[],uint256[],uint32,bytes)" "40232-1" "QmApplicationHash123" '["App Milestone 1","App Milestone 2"]' '[500000,1500000]' 3 "0x000301001101000000000000000000000000000DBBA0" --value 0.0001ether --private-key $WALL2_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Parameters:**
- Job ID: `40232-1`
- Application Hash: `QmApplicationHash123`
- Milestones: `["App Milestone 1", "App Milestone 2"]`
- Amounts: `[500000, 1500000]`
- Preferred Chain Domain: `3` (Arbitrum)
- LZ Options: `0x000301001101000000000000000000000000000DBBA0` (900k gas)
- Value: 0.0001 ETH
- Wallet: `0xfD08836eeE6242092a9c869237a8d122275b024A`

**Source TX (OP Sepolia):** `0x76aa7870146f64b41ef3e58f8d738bf3a241795727889d9e8391e2f8ce463844`
**Destination TX (Arb Sepolia):** `0x3878c93fd531dd4913022cda8fa2f9632c724cbcecc46bbb00718912e1663a8d`

**LZ Message Status:** ✅ DELIVERED

---

## 4. startJob (Cross-Chain)

**Flow:** LOWJC (OP Sepolia) → LocalBridge → NativeChainBridge (Arb) → NOWJC + CCTP USDC transfer

### 4.1 Gas Estimation

```bash
source .env && cast estimate 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "startJob(address,string,uint256,bool)" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef "40232-1" 1 false --from 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** 346,299 gas

**Calculation:** 346,299 × 2 (buffer) ≈ 700,000 gas → Options: `0x000301001101000000000000000000000000000AAE60`

### 4.2 Quote LZ Fee

```bash
source .env && cast call 0xF069BE11c655270038f89DECFF4d9155D0910C95 "quoteNativeChain(bytes,bytes)(uint256)" $(cast abi-encode "f(string,address,string,uint256,bool)" "startJob" "0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef" "40232-1" 1 false) "0x000301001101000000000000000000000000000AAE60" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** ~0.0000291 ETH

### 4.3 Check USDC Balance & Approve

**USDC on OP Sepolia:** `0x5fd84259d66cd46123540766be93dfe6d43130d7`

```bash
# Check balance
source .env && cast call 0x5fd84259d66cd46123540766be93dfe6d43130d7 "balanceOf(address)(uint256)" 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** 41,595,800 (~41.59 USDC)

```bash
# Approve USDC to LOWJC
source .env && cast send 0x5fd84259d66cd46123540766be93dfe6d43130d7 "approve(address,uint256)" 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 3000000 --private-key $PRIVATE_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Approve TX:** `0x44cbc11012929dfb8ffd2e52fa31344c18df83b52637b7ca6c2dd6321e060d20` ✅

### 4.4 Execute startJob Cross-Chain

```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "startJob(string,uint256,bool,bytes)" "40232-1" 1 false "0x000301001101000000000000000000000000000AAE60" --value 0.0001ether --private-key $PRIVATE_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Parameters:**
- Job ID: `40232-1`
- Application ID: `1`
- Use App Milestones: `false`
- LZ Options: `0x000301001101000000000000000000000000000AAE60` (700k gas)
- Value: 0.0001 ETH
- Wallet: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` (Job Giver)
- First milestone locked: 1,000,000 USDC

**Source TX (OP Sepolia):** `0xeab7f00eb16ff5bb86f4f3653f7e1bd77336f206a316a00d9dd44f21d0e35401`
**Destination TX (Arb Sepolia):** `0x9ae9caed6047ceaeea18f9f3b30726f90c4bbe77464fb77d450ca46787e91570`

**LZ Message Status:** ✅ DELIVERED

---

## 5. submitWork (Cross-Chain)

**Flow:** LOWJC (OP Sepolia) → LocalBridge → NativeChainBridge (Arb) → NOWJC

### 5.1 Gas Estimation

```bash
source .env && cast estimate 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "submitWork(address,string,string)" 0xfD08836eeE6242092a9c869237a8d122275b024A "40232-1" "QmWorkSubmissionHash123" --from 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** 159,414 gas

**Calculation:** 159,414 × 2 (buffer) ≈ 350,000 gas → Options: `0x00030100110100000000000000000000000000055730`

### 5.2 Quote LZ Fee

```bash
source .env && cast call 0xF069BE11c655270038f89DECFF4d9155D0910C95 "quoteNativeChain(bytes,bytes)(uint256)" $(cast abi-encode "f(string,address,string,string)" "submitWork" "0xfD08836eeE6242092a9c869237a8d122275b024A" "40232-1" "QmWorkSubmissionHash123") "0x00030100110100000000000000000000000000055730" --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```
**Result:** ~0.000021 ETH

### 5.3 Execute submitWork Cross-Chain

```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "submitWork(string,string,bytes)" "40232-1" "QmWorkSubmissionHash123" "0x00030100110100000000000000000000000000055730" --value 0.0001ether --private-key $WALL2_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Parameters:**
- Job ID: `40232-1`
- Submission Hash: `QmWorkSubmissionHash123`
- LZ Options: `0x00030100110100000000000000000000000000055730` (350k gas)
- Value: 0.0001 ETH
- Wallet: `0xfD08836eeE6242092a9c869237a8d122275b024A` (Applicant/Job Taker)

**Source TX (OP Sepolia):** `0xf6d595dc38d9b5664a99d70d7d2c22142db681264b070f3e527ac00bf8e3e83a`
**Destination TX (Arb Sepolia):** `0x238f59aebfedb45234acac163d10923b876cc5a5fcc08f8f86523f06321a180e`

**LZ Message Status:** ✅ DELIVERED

---

## LZ Options Reference (Updated)

| Gas Amount | Hex Value | Full Options | Use Case |
|------------|-----------|--------------|----------|
| 200,000 | 0x30D40 | `0x00030100110100000000000000000000000000030D40` | Simple calls |
| 350,000 | 0x55730 | `0x00030100110100000000000000000000000000055730` | submitWork |
| 500,000 | 0x7A120 | `0x000301001101000000000000000000000000007A120` | Medium complexity |
| 700,000 | 0xAAE60 | `0x000301001101000000000000000000000000000AAE60` | postJob, startJob |
| 900,000 | 0xDBBA0 | `0x000301001101000000000000000000000000000DBBA0` | applyToJob |
| 1,000,000 | 0xF4240 | `0x000301001101000000000000000000000000000F4240` | createProfile |

**Gas Estimation Method:**
1. Run `cast estimate` on destination function (from bridge address)
2. Apply 2x buffer for safety
3. Convert to hex and pad to 32 bytes

---

## All Transactions Summary

| Function | Source TX (OP Sepolia) | Dest TX (Arb Sepolia) | Status |
|----------|------------------------|----------------------|--------|
| createProfile | `0xb7a92bfe55763c85267942041b98322f7b19cdc407f628c4ca5b1c813da74c77` | `0x7f44b09510349a58fdc948874a11a237d149b3f191c612296af842c15ff3a2a1` | ✅ |
| postJob | `0x2a21d595e7cb252536ed0d6f31c5167244d7b987602d1f4f3285fa7a88eb0c1a` | `0xafbf91c85a73cb9436514abe0c371616af62de780b0e5b5a80803decc6bd902b` | ✅ |
| applyToJob | `0x76aa7870146f64b41ef3e58f8d738bf3a241795727889d9e8391e2f8ce463844` | `0x3878c93fd531dd4913022cda8fa2f9632c724cbcecc46bbb00718912e1663a8d` | ✅ |
| approve USDC | `0x44cbc11012929dfb8ffd2e52fa31344c18df83b52637b7ca6c2dd6321e060d20` | N/A (local) | ✅ |
| startJob | `0xeab7f00eb16ff5bb86f4f3653f7e1bd77336f206a316a00d9dd44f21d0e35401` | `0x9ae9caed6047ceaeea18f9f3b30726f90c4bbe77464fb77d450ca46787e91570` | ✅ |
| submitWork | `0xf6d595dc38d9b5664a99d70d7d2c22142db681264b070f3e527ac00bf8e3e83a` | `0x238f59aebfedb45234acac163d10923b876cc5a5fcc08f8f86523f06321a180e` | ✅ |

---

## Jobs Created During Testing

| Job ID | Job Giver | Detail Hash | Status |
|--------|-----------|-------------|--------|
| `40232-1` | `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` | `QmTestJobDetailHash123` | InProgress |

## Applications Created During Testing

| Job ID | App ID | Applicant | Application Hash |
|--------|--------|-----------|------------------|
| `40232-1` | `1` | `0xfD08836eeE6242092a9c869237a8d122275b024A` | `QmApplicationHash123` |

## Profiles Created During Testing

| User | IPFS Hash | Method |
|------|-----------|--------|
| `0xfD08836eeE6242092a9c869237a8d122275b024A` | `QmTestProfileHash123` | Direct call |
| `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` | `QmNewProfileHash456` | Cross-chain |

---

*Testing completed: January 3, 2026*
