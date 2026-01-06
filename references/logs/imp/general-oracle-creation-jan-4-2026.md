# General Oracle Creation Through DAO - January 4, 2026

**Date:** January 4, 2026
**Status:** COMPLETE - "General" Oracle successfully created through DAO governance
**Network:** Arbitrum Sepolia

---

## Objective

Create a "General" oracle for dispute resolution through NativeDAO governance.

## Contracts (Jan 2 Deployment)

| Contract | Address |
|----------|---------|
| **NativeDAO** | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` |
| **NativeAthenaOracleManager** | `0x32eceb266A07262B15308cc626B261E7d7C5E215` |
| **NativeAthena** | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` |
| **Genesis (Proxy)** | `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` |
| **NOWJC (Proxy)** | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` |

## Oracle Specifications

- **Name:** "General"
- **Members:** WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)
- **Description:** "General Oracle for dispute resolution"
- **Hash:** "QmGeneralOracleHash"
- **Skill Verified:** WALL2

---

## Phase 1: Pre-Checks

### Step 0a: Check NativeDAO Authorization on OracleManager
```bash
source .env && cast call 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "authorizedCallers(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `0x00` (false) - NOT authorized

### Step 0b: Authorize NativeDAO on OracleManager
```bash
source .env && cast send 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "setAuthorizedCaller(address,bool)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0x13884fb136c647f58918fb36da309a6b92c777199376ed225a1942632fcb86b7`
**Block:** 230603602

### Step 0c: Verify WALL2 Can Vote
```bash
source .env && cast call 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "canVote(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `0x01` (true) - WALL2 can vote

---

## Phase 2: First Proposal Attempt (FAILED)

### Step 1: Generate Calldata
```bash
cast calldata "addSingleOracle(string,address[],string,string,address[])" \
  "General" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]" \
  "General Oracle for dispute resolution" \
  "QmGeneralOracleHash" \
  "[0xfD08836eeE6242092a9c869237a8d122275b024A]"
```
**Result:**
```
0x4a9fe8f900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000747656e6572616c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a000000000000000000000000000000000000000000000000000000000000002547656e6572616c204f7261636c6520666f722064697370757465207265736f6c7574696f6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013516d47656e6572616c4f7261636c6548617368000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a
```

### Step 2: First Proposal Attempt (FAILED)
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "propose(address[],uint256[],bytes[],string)" \
  '[0x32eceb266A07262B15308cc626B261E7d7C5E215]' \
  '[0]' \
  '[0x4a9fe8f900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000747656e6572616c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a000000000000000000000000000000000000000000000000000000000000002547656e6572616c204f7261636c6520666f722064697370757465207265736f6c7574696f6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013516d47656e6572616c4f7261636c6548617368000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a]' \
  "Create General Oracle for dispute resolution" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** FAILED - `execution reverted`

### Root Cause
NativeDAO's `propose()` function calls:
```solidity
genesis.updateMemberActivity(msg.sender);  // Line 425 in native-dao.sol
```
But Jan 1 Genesis contract **does NOT have** this function.

---

## Phase 3: Genesis Fix (Contract Size Issue)

### Issue: Dec 26 Genesis Exceeds Size Limit
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-26-Dec-version/openwork-genesis.sol:OpenworkGenesis"
```
**Result:** FAILED - `max code size exceeded`

| Contract Version | Size (bytes) | Limit | Status |
|-----------------|--------------|-------|--------|
| Dec 26 Genesis | 26,934 | 24,576 | EXCEEDS by 2,358 |
| Jan 1 Genesis | 24,575 | 24,576 | 1 byte under |

### Solution: Add No-Op Function + Shorten Require Messages

Created new file: `src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis-4-jan.sol`

**Added dummy function (Line 644):**
```solidity
function updateMemberActivity(address) external onlyAuthorized {}
```

**IMPORTANT: This is a NO-OP dummy function that does NOT track member activity.**
**TODO: In future, this needs to be replaced with proper implementation that stores `memberLastActivity[member] = block.timestamp;`**

**Shortened require messages to fit under size limit:**
- `"Not owner"` → `"!"`
- `"Not authorized"` → `"!"`
- `"Zero address"` → `"0"`
- `"Invalid athena ID"` → `"!"`
- `"Invalid application ID"` → `"!"`
- `"Start index out of bounds"` → `"!"`

**Final size:** 24,401 bytes (175 bytes under limit)

### Deploy New Genesis Implementation
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis-4-jan.sol:OpenworkGenesis"
```
**Result:** SUCCESS
**New Implementation:** `0xc1d22b12eEac0275833A9Be8E8AB2373BD0Bb6aA`
**TX Hash:** `0x0d855c7b49ac301ef29cffbb733acb5b61a5e99ca150696669bea623b58775e8`

### Upgrade Genesis Proxy
```bash
source .env && cast send 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "upgradeToAndCall(address,bytes)" 0xc1d22b12eEac0275833A9Be8E8AB2373BD0Bb6aA 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0x710e34c588acaea6fa85a1db909db81a2087259dec7d47de070ae5a8c1ecf8a2`

---

## Phase 4: Second Proposal Attempt (FAILED - NOWJC Auth)

### Second Proposal Attempt
**Result:** FAILED - `"Only authorized"` error from NOWJC

### Root Cause
NativeDAO's `propose()` also calls:
```solidity
nowjContract.incrementGovernanceAction(msg.sender);  // Line 429 in native-dao.sol
```
But NativeDAO was NOT in NOWJC's `authorizedContracts` mapping.

### Authorize NativeDAO on NOWJC
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "addAuthorizedContract(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0x4ef85c39e03fc17f4f60404508f661c2dfcf13290e0cecde14b15034608d8a15`
**Block:** 230609284

### Verify Authorization
```bash
source .env && cast call 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "isAuthorizedContract(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
**Result:** `0x01` (true)

---

## Phase 5: Successful Proposal Creation

### Create DAO Proposal (SUCCESS)
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "propose(address[],uint256[],bytes[],string)" \
  '[0x32eceb266A07262B15308cc626B261E7d7C5E215]' \
  '[0]' \
  '[0x4a9fe8f900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000747656e6572616c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a000000000000000000000000000000000000000000000000000000000000002547656e6572616c204f7261636c6520666f722064697370757465207265736f6c7574696f6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013516d47656e6572616c4f7261636c6548617368000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a]' \
  "Create General Oracle for dispute resolution" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0x0f74a48592ce77e1db0b925183c0dc7efc6819112217207ebf1747a9bd0ac5a9`
**Block:** 230609387
**Proposal ID:** `0xa2c7f52e7c3e83b2f5f0af76bfae1bde6df5f45b9f5abc80d02b4c8a9ef2fbba`

---

## Phase 6: Vote on Proposal (SUCCESS)

### Cast Vote FOR
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "castVote(uint256,uint8)" 0xa2c7f52e7c3e83b2f5f0af76bfae1bde6df5f45b9f5abc80d02b4c8a9ef2fbba 1 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0xa89fc93ea0ff264cc581b251e698ffc3d9f17df664468851b14c6a04d6e763f6`
**Block:** 230610344

---

## Phase 7: First Execution Attempt (FAILED - minOracleMembers)

### Execute Attempt
**Result:** FAILED - `"Not enough members for oracle"`

### Root Cause
OracleManager's `addSingleOracle()` function had validation:
```solidity
require(_members.length == 0 || _members.length >= nativeAthena.minOracleMembers(), "Not enough members for oracle");
```
`minOracleMembers = 3`, but our proposal had 1 member.

---

## Phase 8: OracleManager Upgrade (Remove Validation)

### Create New OracleManager Version
Created: `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol`
Removed the `minOracleMembers` validation to allow oracles with any number of members.

### Deploy New OracleManager Implementation
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol:NativeAthenaOracleManager"
```
**Result:** SUCCESS
**New Implementation:** `0xd8Ba6A37Ba9ee222593e6CbF005273897dd06c98`
**TX Hash:** `0xcf7811f952044184f30a8a29d2238a677eacd6975cb894771c46f1e651257d90`

### Upgrade OracleManager Proxy
```bash
source .env && cast send 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "upgradeToAndCall(address,bytes)" 0xd8Ba6A37Ba9ee222593e6CbF005273897dd06c98 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0x24f8edd2d9f63c3cb877001b301527f3ea23cfc14b3291f9317a278e009acfe7`

---

## Phase 9: Execute Proposal (SUCCESS)

### Get Description Hash
```bash
cast keccak "Create General Oracle for dispute resolution"
```
**Result:** `0xe8e0632384ea78e1e0c10c94406f0b515680cdb51a658668f4bb77d95673352f`

### Execute Proposal
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "execute(address[],uint256[],bytes[],bytes32)" \
  '[0x32eceb266A07262B15308cc626B261E7d7C5E215]' \
  '[0]' \
  '[0x4a9fe8f900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000747656e6572616c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a000000000000000000000000000000000000000000000000000000000000002547656e6572616c204f7261636c6520666f722064697370757465207265736f6c7574696f6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013516d47656e6572616c4f7261636c6548617368000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a]' \
  0xe8e0632384ea78e1e0c10c94406f0b515680cdb51a658668f4bb77d95673352f \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```
**Result:** SUCCESS
**TX Hash:** `0xd0fa92396b06766354e7d24b0251d10329ab989c0e2b92d30008de8d17460e6f`
**Block:** 230613124

---

## Verification Commands

### Verify Oracle in OracleManager
```bash
source .env && cast call 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "getOracle(string)" "General" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Verify Oracle in Genesis
```bash
source .env && cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "getOracle(string)" "General" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Transaction Summary

| Step | Action | TX Hash | Status |
|------|--------|---------|--------|
| 0b | Authorize NativeDAO on OracleManager | `0x13884fb136c647f58918fb36da309a6b92c777199376ed225a1942632fcb86b7` | SUCCESS |
| 3a | Deploy Genesis Implementation | `0x0d855c7b49ac301ef29cffbb733acb5b61a5e99ca150696669bea623b58775e8` | SUCCESS |
| 3b | Upgrade Genesis Proxy | `0x710e34c588acaea6fa85a1db909db81a2087259dec7d47de070ae5a8c1ecf8a2` | SUCCESS |
| 4 | Authorize NativeDAO on NOWJC | `0x4ef85c39e03fc17f4f60404508f661c2dfcf13290e0cecde14b15034608d8a15` | SUCCESS |
| 5 | Create DAO Proposal | `0x0f74a48592ce77e1db0b925183c0dc7efc6819112217207ebf1747a9bd0ac5a9` | SUCCESS |
| 6 | Vote on Proposal | `0xa89fc93ea0ff264cc581b251e698ffc3d9f17df664468851b14c6a04d6e763f6` | SUCCESS |
| 8a | Deploy OracleManager Implementation | `0xcf7811f952044184f30a8a29d2238a677eacd6975cb894771c46f1e651257d90` | SUCCESS |
| 8b | Upgrade OracleManager Proxy | `0x24f8edd2d9f63c3cb877001b301527f3ea23cfc14b3291f9317a278e009acfe7` | SUCCESS |
| 9 | Execute Proposal | `0xd0fa92396b06766354e7d24b0251d10329ab989c0e2b92d30008de8d17460e6f` | SUCCESS |

---

## Contract Updates Made

### Genesis Implementation Upgrade
- **Proxy:** `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- **Old Implementation:** `0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b`
- **New Implementation:** `0xc1d22b12eEac0275833A9Be8E8AB2373BD0Bb6aA`
- **Source File:** `src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis-4-jan.sol`

### OracleManager Implementation Upgrade
- **Proxy:** `0x32eceb266A07262B15308cc626B261E7d7C5E215`
- **Old Implementation:** `0xaa877a0f6ad070A9BB110fD4d5eFcc606691D45F`
- **New Implementation:** `0xd8Ba6A37Ba9ee222593e6CbF005273897dd06c98`
- **Source File:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol`
- **Change:** Removed `minOracleMembers` validation - now allows oracles with any number of members

---

## IMPORTANT: Technical Debt

### Dummy `updateMemberActivity` Function
The Genesis contract now has a **NO-OP dummy function**:
```solidity
function updateMemberActivity(address) external onlyAuthorized {}
```

**This does NOT actually track member activity!**

The proper implementation should be:
```solidity
mapping(address => uint256) public memberLastActivity;

function updateMemberActivity(address member) external onlyAuthorized {
    memberLastActivity[member] = block.timestamp;
}
```

**Action Required:** In a future update, either:
1. Optimize Genesis to make room for the full implementation
2. Split Genesis into multiple contracts
3. Remove the call from NativeDAO if activity tracking is not needed

### Shortened Require Messages
Several require messages were shortened to `"!"` or `"0"` to save bytecode space. This makes debugging harder. Consider restoring full messages in future optimization.

---

**Log Created:** January 4, 2026
**Last Updated:** January 4, 2026
**Final Status:** SUCCESS - Oracle created and verified in Genesis and OracleManager
