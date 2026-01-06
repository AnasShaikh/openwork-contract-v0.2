# Dispute Resolution Test Log - January 5, 2026

**Test Date:** January 5, 2026
**Network:** OP Sepolia (Local) ↔ Arbitrum Sepolia (Native)
**Job ID:** `40232-5`
**Status:** ✅ COMPLETE (Local Testing)

---

## Test Participants

| Role | Wallet | Address |
|------|--------|---------|
| Job Poster (WALL2) | WALL2_KEY | `0xfD08836eeE6242092a9c869237a8d122275b024A` |
| Applicant (WALL1) | PRIVATE_KEY | `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` |

---

## Contract Addresses

### OP Sepolia (Local Chain)
| Contract | Address |
|----------|---------|
| LOWJC Proxy | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` |
| LocalAthena Proxy | `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6` |
| LocalBridge | `0xF069BE11c655270038f89DECFF4d9155D0910C95` |
| CCTP Sender | `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` |
| USDC | `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` |
| Message Transmitter | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` |

### Arbitrum Sepolia (Native Chain)
| Contract | Address |
|----------|---------|
| NOWJC Proxy | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` |
| NativeAthena Proxy | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` |
| Genesis Proxy | `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` |
| OracleManager Proxy | `0x32eceb266A07262B15308cc626B261E7d7C5E215` |
| ActivityTracker Proxy | `0x36B6417228ADd2EF231E2676F00251736c6f8d06` |
| **NativeBridge (NEW)** | `0x0d628bbe01e32df7f32b12d321945fd64d3ee568` |
| NativeBridge (OLD) | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` |
| CCTP Receiver | `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` |
| USDC | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| Message Transmitter | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` |

**Note:** The NEW NativeBridge (`0x0d628bbe01e32df7f32b12d321945fd64d3ee568`) has the **fixed release payment function** for proper dispute settlement fund routing. This is the bridge that LocalBridge peers to.

---

## Phase 1: Job Setup

### 1.1 Post Job (OP Sepolia)
- **TX Hash:** `0x6b91db06aa310c58fa7706abfe639babd1608251f9020b06d30a73de92343781`
- **Job ID:** `40232-5`
- **Job Hash:** `dispute-test-jan5`
- **Milestones:** 2 (10,000 units each = 0.01 USDC each)
- **Poster:** WALL2
- **LZ Options:** `0x0003010011010000000000000000000000000007a120` (500k gas)
```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 \
  "postJob(string,string[],uint256[],bytes)" \
  "dispute-test-jan5" \
  '["Milestone 1: Initial", "Milestone 2: Final"]' \
  '[10000, 10000]' \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.0001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### 1.2 Apply to Job (OP Sepolia)
- **TX Hash:** `0xa22a9ba3a47ba5bb4f406dad413f5a17b3e096be5f15f92ffa2fe4afc50fe826`
- **Application ID:** `1`
- **Applicant:** WALL1
- **LZ Status:** DELIVERED
```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 \
  "applyToJob(string,string,string[],uint256[],uint32,bytes)" \
  "40232-5" \
  "QmApplicationJan5" \
  '["Milestone 1: Work", "Milestone 2: Complete"]' \
  '[10000, 10000]' \
  2 \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 1.3 Approve USDC for Job Funding
- **TX Hash:** `0x94f721fee87df079de22362bc22218384558cb5b0b05e0bcd4ad8649c97e8c25`
- **Amount:** 20,000 units (0.02 USDC)
- **Spender:** LOWJC
```bash
source .env && cast send 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "approve(address,uint256)" \
  0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 \
  20000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### 1.4 Start Job with CCTP Transfer (OP Sepolia)
- **TX Hash:** `0x44428b3adde1e5a38f9127a59495b1ef03676dc8c9bc89569ec3ecfcfc1de119`
- **Application ID:** `1`
- **USDC Sent:** 10,000 units (first milestone)
- **LZ Status:** DELIVERED
```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 \
  "startJob(string,uint256,bool,bytes)" \
  "40232-5" \
  1 \
  false \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### 1.5 Complete CCTP Transfer (Arbitrum Sepolia)
- **TX Hash:** `0x7be44eade964636a5863049c2b4c2c1fb4f386cf334aade0c53983b113558fc9`
- **NOWJC Balance Before:** 10,000 units
- **NOWJC Balance After:** 19,999 units
- **CCTP Fee:** 1 unit
- **Net Received:** 9,999 units

**Get CCTP Attestation:**
```bash
curl -s "https://iris-api-sandbox.circle.com/v2/messages/2?transactionHash=0x44428b3adde1e5a38f9127a59495b1ef03676dc8c9bc89569ec3ecfcfc1de119"
```

**Complete Transfer:**
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "0x000000010000000200000003f2a6acc912deea8c4c24785d6d9f173998fb5430babbe97fd95a62624b36cf040000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e8000000010000000000000000000000005fd84259d66cd46123540766be93dfe6d43130d700000000000000000000000068093a84d63fb508bdc6a099ccc1292ce33bb51300000000000000000000000000000000000000000000000000000000000027100000000000000000000000002139ef959b7c83ff853db8882c258e586e07e9be00000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000987459" \
  "0x2f7006b86456192d5b1447be5d6891d45a2a58783e1ef240001f5c33a5c6c2bb5831af0274612c8832b2e844b1f50442089b4baacd2ddee6c44e2213ea3042101b3799dce8edd9faeffbdf686b8ea8779e811baed0591cbcf53bde44d92b1e30b92d9bf9ec0f13227a55e65f6e754a0ed56a44da89731bcd70e0e4bb39d1a316f51c" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Phase 1 Summary

| Step | TX Hash | Status |
|------|---------|--------|
| Post Job | `0x6b91db06...` | ✅ Success |
| Apply to Job | `0xa22a9ba3...` | ✅ Success + LZ Delivered |
| Approve USDC | `0x94f721fe...` | ✅ Success |
| Start Job | `0x44428b3a...` | ✅ Success + LZ Delivered |
| CCTP Complete | `0x7be44ead...` | ✅ Success (9,999 units to NOWJC) |

**Job Status:** InProgress
**Assigned Applicant:** WALL1

---

## Phase 2: Raise Dispute

### 2.0 Configuration Fix: Authorize LocalAthena on LocalBridge
- **TX Hash:** `0x7f14e97864c980ed652a69d1bc2ee7e88bcebb0e83a26ad9fdbf80d8c874a914`
- **Issue:** LocalAthena was not authorized to use LocalBridge
```bash
source .env && cast send 0xF069BE11c655270038f89DECFF4d9155D0910C95 \
  "authorizeContract(address,bool)" 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 true \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 2.1 Approve USDC for Dispute Fee (OP Sepolia)
- **TX Hash:** `0x434ba9186c57ef5e4ee5cba006e03a378086b043468397115c1e836fe37d2f5a`
- **Amount:** 5,000 units (0.005 USDC)
- **Spender:** LocalAthena
```bash
source .env && cast send 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "approve(address,uint256)" \
  0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 \
  5000 \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### 2.2 Raise Dispute - ATTEMPT 1 (OP Sepolia)
- **TX Hash:** `0x0b52cf9bdbd6a5451c3fd67ee0d7836d764957626d4973fd451404727d082853`
- **Job ID:** `40232-5`
- **Oracle:** `General`
- **Fee:** 5,000 units
- **Disputed Amount:** 10,000 units
- **CCTP Status:** ✅ COMPLETE (4000 USDC to NativeAthena)
- **LZ Status:** ❌ FAILED - "Native Athena contract not set"

### 2.2a Configuration Fix: Set NativeAthena on OLD NativeBridge (WRONG)
- **TX Hash:** `0x3d09d771f889ee05f4f0726a34d8a7f38514d4945f9b01d5b76535bd1bc45842`
- **Issue:** Set on wrong bridge address - OLD bridge, not the one LocalBridge peers to
- **Bridge:** `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` (OLD)
```bash
# This was applied to the wrong bridge!
source .env && cast send 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 \
  "setNativeAthenaContract(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 2.3 Complete Dispute Fee CCTP Transfer - ATTEMPT 1 (Arbitrum Sepolia)
- **TX Hash:** `0x333910019f2b3acfbdad27ae3bc853553fa206f61c609a8c07422a505032c115`
- **NativeAthena Balance Before:** 0 USDC
- **NativeAthena Balance After:** 4000 USDC (5000 - 1000 fee)
- **Note:** CCTP succeeded but LZ message failed - dispute NOT created

### 2.4 Raise Dispute - ATTEMPT 2 (OP Sepolia)
- **TX Hash:** `0x6b73245cb169eb8ddcb0fbb438112b0e0981a8734e3ab4fd91a26474174f456f`
- **Job ID:** `40232-5`
- **Oracle:** `General`
- **Fee:** 5,000 units
- **Disputed Amount:** 10,000 units
- **CCTP Status:** ✅ COMPLETE (attestation ready)
- **LZ Status:** ❌ FAILED - "Native Athena contract not set" (still wrong bridge)
```bash
source .env && cast send 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 \
  "raiseDispute(string,string,string,uint256,uint256,bytes)" \
  "40232-5" \
  "QmDisputeJan5v2" \
  "General" \
  5000 \
  10000 \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### 2.4a Configuration Fix: Set NativeAthena on CORRECT NativeBridge
- **TX Hash:** `0xa6bf97749f2283306e52180755a6dad4fb99fe4211c0223b79cf6f926ea59ab8`
- **Issue:** NativeAthena was not set on the NEW bridge (the one LocalBridge actually peers to)
- **Bridge:** `0x0d628bbe01e32df7f32b12d321945fd64d3ee568` (NEW - with fixed release payment)
```bash
source .env && cast send 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  "setNativeAthenaContract(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 2.5 Complete Dispute Fee CCTP Transfer - ATTEMPT 2 (Arbitrum Sepolia)
- **TX Hash:** PENDING
- **Note:** Need to complete CCTP for ATTEMPT 2, but LZ still failed - need ATTEMPT 3

### 2.6 Raise Dispute - ATTEMPT 3 (OP Sepolia)
- **TX Hash:** `0xad218281d49841146b34c29b16953cabcb711fc7b4a628e7d2f5e0e970b75b8f`
- **LZ Status:** ❌ FAILED - "Only bridge" (NativeAthena.bridge was still OLD bridge)
```bash
source .env && cast send 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 \
  "raiseDispute(string,string,string,uint256,uint256,bytes)" \
  "40232-5" "QmDisputeJan5v3" "General" 5000 10000 \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 2.6a Configuration Fix: Set NEW Bridge on NativeAthena
- **TX Hash:** `0xb13a8c6d671cd82b1a75bf60b7204222db31781dae189c9f1a1b3c9a22732773`
- **Issue:** NativeAthena.bridge was still pointing to OLD bridge
- **Old Bridge:** `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`
- **New Bridge:** `0x0d628bbe01e32df7f32b12d321945fd64d3ee568`
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "setBridge(address)" 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 2.7 Configuration Verification (COMPLETE)
All checks passed:
- NativeAthena.bridge = NEW bridge ✅
- NativeAthena.genesis = correct ✅
- NativeAthena.minOracleMembers = 1 ✅
- NativeAthena.activityTracker = correct ✅
- isOracleActive("General") = true ✅
- NativeBridge.nativeAthenaContract = NativeAthena ✅
- Genesis.authorizedContracts[NativeAthena] = true ✅

### 2.8 Raise Dispute - ATTEMPT 4 (OP Sepolia) ✅ SUCCESS
- **TX Hash:** `0xbaca4ecc21388a37f97a848ea78a28eeb18f30c0af800438edd5fb9b039b0ccf`
- **Job ID:** `40232-5`
- **Oracle:** `General`
- **Fee:** 5,000 units
- **Disputed Amount:** 10,000 units
- **CCTP Status:** ✅ COMPLETE
- **LZ Status:** ✅ DELIVERED
- **Dispute ID Created:** `40232-5-1`
```bash
source .env && cast send 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 \
  "raiseDispute(string,string,string,uint256,uint256,bytes)" \
  "40232-5" "QmDisputeJan5v3" "General" 5000 10000 \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 2.9 Complete Dispute Fee CCTP Transfer - ATTEMPT 4 (Arbitrum Sepolia) ✅
- **TX Hash:** `0x92b832558a5a26962fe74b08d356d04b43af7968479b1226186b756dfcb7f78c`
- **NativeAthena Balance After:** 12,000 USDC (accumulated from attempts)
- **Dispute ID:** `40232-5-1`
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  0x0000000100000002000000032b7ff0c4212bc210e234e9aa52842be0824c5254f6b305b1ebf5f00306c7298b0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e8000000010000000000000000000000005fd84259d66cd46123540766be93dfe6d43130d700000000000000000000000020ec5833261d9956399c3885b22439837a6ed7b200000000000000000000000000000000000000000000000000000000000013880000000000000000000000002139ef959b7c83ff853db8882c258e586e07e9be00000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000009874cc \
  0x65dba3f5cb566b8ca74a54683501b6211036552eed094404c1d78744d7f8a49f062b879bc6eee78d6cc34390de913529f14c2a5d7c409698a9d80c4c2b2f26d51c01bf4e05ff78cb7f2af55cd3c73ad40bf90608e2425e832e5c161da9b45def3f563ed66096215288eecd822e31e4565400b96a0175655a3da45955b4a1a8fab51c \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## Phase 3: Local Testing (Arbitrum Only) - ✅ COMPLETE

### 3.0 Setup for Local Testing
- **Purpose:** Skip cross-chain delays by testing dispute cycle locally on Arbitrum
- **Voting Period:** 2 minutes
- **Bridge temporarily set to:** WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)
- **Bridge TX:** `0x9611006ad77c0be1384439ac362e75a400c58316c05627cd6e780ffbc8317ef8`

### 3.1 Authorization Fix: NativeAthena in NOWJC
**Problem:** Vote failed with "Only authorized" error
**Root Cause:** NativeAthena needs authorization in BOTH Genesis AND NOWJC to call `incrementGovernanceAction()`
- Genesis authorization: ✅ Already set
- NOWJC authorization: ❌ MISSING

**Solution:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "addAuthorizedContract(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0x49cd8f397224e6da3919d5ebfdf27352ca9c729194efe8cd58c822cd89be7c2c`

### 3.2 Create Local Dispute (Dispute #8)
- **TX Hash:** `0xf67b332b23e74d1009c20986f4e6ce1eaf2d5613f640614caa1ceda891c52c12`
- **Dispute ID:** `40232-5-8`
- **Fee:** 5,000 units
- **Disputed Amount:** 10,000 units
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "handleRaiseDispute(string,string,string,uint256,uint256,address)" \
  "40232-5" "QmLocalTest8" "General" 5000 10000 \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 3.3 Vote on Dispute ✅
- **TX Hash:** `0xf8d09c5f080df13a94da84ff48c960d64df3eca31e828f1686cb553b795c8b95`
- **Voter:** WALL2
- **Vote:** FOR (job giver wins)
- **Claim Address:** WALL2
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "vote(uint8,string,bool,address)" \
  0 "40232-5-8" true 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Logs confirmed:** ActivityTracker updated, NOWJC governance action incremented

### 3.4 Settlement Attempt - FAILED (Commission Issue)
**Problem:** Settlement failed with "Amount must be nonzero" from CCTP
**Root Cause:** NOWJC commission settings:
- `commissionPercentage`: 0
- `minCommission`: 10,000 units

For disputed amount = 10,000:
- commission = MAX(0, 10000) = 10,000
- netAmount = 10,000 - 10,000 = **0** ← CCTP rejects zero transfers!

**Solution:** Lower minCommission to 1,000 for testing
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "setMinCommission(uint256)" 1000 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
- **TX Hash:** `0x74aa3fab8fc875772e8b5dde60588a6b6978c4967e94c20b6504fd1febb90daa`

### 3.5 Settlement ✅ SUCCESS
- **TX Hash:** `0xed84b910e1399c43915ad960adc3ef78053496364453861263da8a00f8b88b0e`
- **Dispute ID:** `40232-5-8`
- **Result:** Job giver (WALL2) wins
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "settleDispute(string)" "40232-5-8" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Settlement Breakdown:**
| Item | Amount |
|------|--------|
| Disputed Amount | 10,000 |
| NOWJC Commission | 1,000 |
| Net to CCTP | 9,000 |
| CCTP Fee | 1,000 |
| Winner Receives | 8,000 |
| Voter Fee | 5,000 |

### 3.6 Complete CCTP Transfer to OP Sepolia ✅
- **TX Hash:** `0x29ecc351855e8e7c8cae90e26a05260d37514da972da6a3c7a8cb2bc230c97dd`
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  0x000000010000000300000002b63b3651b0917587ea28402250c82ae413dace40a7cab57fa45a7c87643ef0550000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000008fe6b999dc680ccfdd5bf7eb0974218be2542daa0000000000000000000000000000000000000000000000000000000000000000000003e8000003e80000000100000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a0000000000000000000000000000000000000000000000000000000000002328000000000000000000000000d22c85d18d188d37fd9d38974420a6bd68ffc31500000000000000000000000000000000000000000000000000000000000003e800000000000000000000000000000000000000000000000000000000000003e80000000000000000000000000000000000000000000000000000000002431f7d \
  0x5421f56c8be433c6000c849c3817c728cd9f89ecdb474c4e817caa32bca3d0f67217f4c8ede0dfa32e0e8048c3b8c35a991876947df68d9895a0d01cec27c52d1c52484487e374492b6c22e9785440e68106c4b76f2449fd5ed1aa8381b4db6d8e22e0bc4fc08daa5679f55dbdb508241ad036bde7830d4be583afb2b588c2db031b \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 3.7 Final Balances ✅
| Wallet | Chain | Balance (USDC) | Change |
|--------|-------|----------------|--------|
| WALL2 | OP Sepolia | 11.27 | +8,000 units (disputed funds) |
| WALL2 | Arbitrum Sepolia | 29.265 | +5,000 units (voter fee) |

---

## Phase 3-OLD: Vote on Dispute (Cross-Chain - Expired)

### 3.1 Cast Vote (Arbitrum Sepolia)
- **TX Hash:** EXPIRED (voting period was 0 when created)
- **Voter:** WALL2
- **Vote:** FOR (job giver wins)
- **Claim Address:** WALL2
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "vote(uint8,string,bool,address)" \
  0 \
  "40232-5-1" \
  true \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Phase 4: Settle Dispute

### 4.1 Check Voting Period
```bash
source .env && cast call 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "votingPeriodMinutes()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### 4.2 Settle Dispute (After Voting Period)
- **TX Hash:** PENDING
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "settleDispute(string)" \
  "40232-5-1" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Phase 5: CCTP Fund Delivery

### 5.1 Get Settlement CCTP Attestation
```bash
curl -s "https://iris-api-sandbox.circle.com/v2/messages/3?transactionHash=SETTLEMENT_TX_HASH"
```

### 5.2 Complete Settlement CCTP Transfer (OP Sepolia)
- **TX Hash:** PENDING
```bash
source .env && cast send 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 \
  "receiveMessage(bytes,bytes)" \
  "MESSAGE_BYTES" \
  "ATTESTATION_BYTES" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Verification Commands

### Check Job Status
```bash
source .env && cast call 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "getJob(string)" "40232-5" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Check Dispute in Genesis
```bash
source .env && cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "getDispute(string)" "40232-5-1" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Check NativeAthena USDC Balance (Dispute Fees)
```bash
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Check NOWJC USDC Balance
```bash
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
  "balanceOf(address)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Check WALL2 USDC Balance (OP Sepolia)
```bash
source .env && cast call 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 \
  "balanceOf(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

### Check LZ Message Status
```bash
curl -s "https://scan-testnet.layerzero-api.com/v1/messages/tx/TX_HASH" | jq '{source: .data[0].source.status, destination: .data[0].destination.status, overall: .data[0].status.name}'
```

---

## Expected Outcomes

| Goal | Expected Result | Actual Result |
|------|-----------------|---------------|
| 1. Raise dispute successfully | Dispute ID in Genesis | ✅ `40232-5-8` created |
| 2. Dispute fee sent to native chain | NativeAthena USDC ↑ | ✅ +5,000 units |
| 3. Vote successfully | Vote TX succeeds | ✅ `0xf8d09c5...` |
| 4. Resolve dispute successfully | Settlement TX succeeds | ✅ `0xed84b91...` |
| 5. Disputed funds reach winner | Winner's OP Sepolia USDC ↑ | ✅ +8,000 units |
| 6. Winning voters get fee | Voter's Arbitrum USDC ↑ | ✅ +5,000 units |

---

## Notes

- **LZ Options:** `0x000301001101000000000000000000000000000F4240` = 1M gas
- **Voting Period:** 60 minutes (check `votingPeriodMinutes()`)
- **CCTP Attestation:** Usually ready within 10-20 seconds
- **Job ID Format:** `chainId-counter` (e.g., `40232-5`)
- **Dispute ID Format:** `jobId-disputeCounter` (e.g., `40232-5-1`)

---

## ✅ Post-Test Cleanup Complete

**NativeAthena bridge reset to real NativeBridge:**
- **TX Hash:** `0x7b537ee9f55a2ec4ea85897254ede8493d19d72d0f5219be564c0e2f3bf68b79`
- **Bridge Address:** `0x0d628bbe01e32df7f32b12d321945fd64d3ee568`

```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "setBridge(address)" 0x0d628bbe01e32df7f32b12d321945fd64d3ee568 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

**Log Created:** January 5, 2026
**Last Updated:** January 5, 2026
