# ActivityTracker Deployment Log - January 5, 2026

**Network:** Arbitrum Sepolia
**Deployer:** WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)

---

## Deployment Summary

| Contract | Address | Status |
|----------|---------|--------|
| ActivityTracker Impl | `0x206b2999000e45fA981698AA4F3E6dA6fcc0F711` | Deployed |
| ActivityTracker Proxy | `0x36B6417228ADd2EF231E2676F00251736c6f8d06` | Deployed |
| NativeAthena Impl | `0x91cA073936A5EEe39f597D545ccE0A1AF63FeFF8` | Deployed |
| NativeDAO Impl | `0xccce7077eC511B93BF4eff26eA0E093d6eF9F9fe` | Deployed |
| OracleManager Impl | `0x5Ce4790511A7313AB55d678C4bCa7e910dD56324` | Deployed |

---

## Transaction Log

### 1. Deploy ActivityTracker Implementation
- **Deployer:** WALL1 (`0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`)
- **Address:** `0x206b2999000e45fA981698AA4F3E6dA6fcc0F711`
- **Note:** Implementation deployed by WALL1, proxy by WALL2
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/activity-tracker.sol:ActivityTracker"
```

### 2. Deploy ActivityTracker Proxy
- **TX Hash:** `0x444314fe013e7e752a7d7c302948d706b90006b9bce0b13257dd47fc387163d8`
- **Deployer:** WALL2
- **Proxy Address:** `0x36B6417228ADd2EF231E2676F00251736c6f8d06`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`
```bash
# Generate init calldata
cast calldata "initialize(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A

# Deploy proxy
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy" \
  --constructor-args 0x206b2999000e45fA981698AA4F3E6dA6fcc0F711 \
  0xc4d66de8000000000000000000000000fd08836eee6242092a9c869237a8d122275b024a
```

### 3. Deploy NativeAthena Implementation
- **TX Hash:** `0x6f85c110a5e1ded7bda1dc7137f0f7f136f2deaea71cb1b0ae1aea189bc05995`
- **Deployer:** WALL2
- **Address:** `0x91cA073936A5EEe39f597D545ccE0A1AF63FeFF8`
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena.sol:NativeAthena"
```

### 4. Deploy NativeDAO Implementation
- **TX Hash:** `0x60a4df1530e2b30add24c37a596fec26296b0ea7ad92f989f27b45735c8550b0`
- **Deployer:** WALL2
- **Address:** `0xccce7077eC511B93BF4eff26eA0E093d6eF9F9fe`
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-dao.sol:NativeDAO"
```

### 5. Deploy OracleManager Implementation
- **TX Hash:** `0x876c8e9ce6b3c1da18e216c68d9a8f3be9703470a509f41e454d87e4ccebe61f`
- **Deployer:** WALL2
- **Address:** `0x5Ce4790511A7313AB55d678C4bCa7e910dD56324`
```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol:NativeAthenaOracleManager"
```

### 6. Upgrade NativeAthena Proxy
- **TX Hash:** `0xc4c75a2c6a05217213698f493f97ca7548b045bbb8ef2d57da521d9575766ffe`
- **Proxy:** `0x20Ec5833261d9956399c3885b22439837a6eD7b2`
- **New Impl:** `0x91cA073936A5EEe39f597D545ccE0A1AF63FeFF8`
- **Previous Impl:** `0x0ad0306EAfCBf121Ed9990055b89e1249011455F`
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "upgradeToAndCall(address,bytes)" 0x91cA073936A5EEe39f597D545ccE0A1AF63FeFF8 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 7. Upgrade NativeDAO Proxy
- **TX Hash:** `0x871cfaa8765501556e068d9e562d8808dc94f3f608aae57cf7e4260975277a5f`
- **Proxy:** `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357`
- **New Impl:** `0xccce7077eC511B93BF4eff26eA0E093d6eF9F9fe`
- **Previous Impl:** `0x77B53c3927fea2A4ebbeC144344Bee8FF243D95c`
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "upgradeToAndCall(address,bytes)" 0xccce7077eC511B93BF4eff26eA0E093d6eF9F9fe 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 8. Upgrade OracleManager Proxy
- **TX Hash:** `0x5c50e0c05a66766f7c502df7cea116647ae57304346a888a31654e1ca1af19ee`
- **Proxy:** `0x32eceb266A07262B15308cc626B261E7d7C5E215`
- **New Impl:** `0x5Ce4790511A7313AB55d678C4bCa7e910dD56324`
- **Previous Impl:** `0xd8Ba6A37Ba9ee222593e6CbF005273897dd06c98`
```bash
source .env && cast send 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "upgradeToAndCall(address,bytes)" 0x5Ce4790511A7313AB55d678C4bCa7e910dD56324 0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 9. Add WALL2 as Admin on NativeAthena
- **TX Hash:** `0x8260dd22983d57cd26b4b86811bee8b275a2e14830116ac5d0f64a6ca83cde11`
- **Note:** Required because admin pattern was added but admins mapping empty after upgrade
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "setAdmin(address,bool)" 0xfD08836eeE6242092a9c869237a8d122275b024A true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## Configuration (COMPLETE)

### 10. Set ActivityTracker on NativeAthena
- **TX Hash:** `0x0d3a1fc845c52001806ab2560a96e5114555d26b7539a333a0a34161fbb6ffcf`
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "setActivityTracker(address)" 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 11. Add WALL2 as Admin on NativeDAO
- **TX Hash:** `0x99f2e53d02e0dbdfcf0daa9aa2d6cc155b987d46bee9d737c76fd3b2ec6b32bd`
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "setAdmin(address,bool)" 0xfD08836eeE6242092a9c869237a8d122275b024A true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 12. Set ActivityTracker on NativeDAO
- **TX Hash:** `0xcea11644a818bd127b553e4c7b19e0f6ef1c79a40c2df91b782ae8dc55ded255`
```bash
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 \
  "setActivityTracker(address)" 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 13. Set ActivityTracker on OracleManager
- **TX Hash:** `0xbc48e451a6cf03f394ac3da0656d56e88f471c962be5be89cb63bba0596bcac8`
```bash
source .env && cast send 0x32eceb266A07262B15308cc626B261E7d7C5E215 \
  "setActivityTracker(address)" 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 14. Authorize NativeAthena on ActivityTracker
- **TX Hash:** `0xd8e3fa036ec6d54b33053bb6612139862e13b611f715ab66c801bda4c1153e69`
```bash
source .env && cast send 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  "setAuthorizedCaller(address,bool)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 15. Authorize NativeDAO on ActivityTracker
- **TX Hash:** `0xebe6a2d59a4089d1041979e2f18b2264ae92874325eaf049a4197d364eabfcb1`
```bash
source .env && cast send 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  "setAuthorizedCaller(address,bool)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 16. Authorize OracleManager on ActivityTracker
- **TX Hash:** `0x139872501d0ca6601e998b72d8d18cffa1f48007d354ba712a501262d80a4dd8`
```bash
source .env && cast send 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  "setAuthorizedCaller(address,bool)" 0x32eceb266A07262B15308cc626B261E7d7C5E215 true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 17. Initialize WALL2 Activity
- **TX Hash:** `0x1a6b0e5aab1e863decfee94dd1e53c96e2968fb9577355799f3166c82dfb6070`
- **Member:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Timestamp:** `0x695bb678`
```bash
source .env && TIMESTAMP=$(cast block latest --field timestamp --rpc-url $ARBITRUM_SEPOLIA_RPC_URL) && \
cast send 0x36B6417228ADd2EF231E2676F00251736c6f8d06 \
  "setMemberActivityOverride(address,uint256)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A $TIMESTAMP \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 18. Update General Oracle Active Status
- **TX Hash:** `0x5642b21ccc1214d4fb9a173476d8e13ed4c33869174fd2dd9fdb5d633fb7ce17`
- **Oracle:** "General"
- **Result:** Active = `true`
```bash
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 \
  "updateOracleActiveStatus(string)" "General" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## Upgrade Notes

### NativeAthena Changes
- Added ActivityTracker integration
- Added admin pattern (`admins` mapping + `mainDAO`)
- Restricted `updateOracleActiveStatus()` to admins/OracleManager
- Shortened error messages to fit 24KB limit

### NativeDAO Changes
- Added ActivityTracker integration for member activity tracking

### OracleManager Changes
- Added ActivityTracker integration
- Auto-activate oracle on creation with members (`addSingleOracle`)
- Initialize member activity when adding to oracles

---

## Verification Commands

```bash
# Verify ActivityTracker owner
source .env && cast call 0x36B6417228ADd2EF231E2676F00251736c6f8d06 "owner()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Verify NativeAthena implementation
source .env && cast storage 0x20Ec5833261d9956399c3885b22439837a6eD7b2 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Verify WALL2 is admin on NativeAthena
source .env && cast call 0x20Ec5833261d9956399c3885b22439837a6eD7b2 "admins(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
