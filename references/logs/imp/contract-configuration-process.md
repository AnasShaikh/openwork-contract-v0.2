# Systematic Contract Configuration Process

## Overview

After deploying all contracts with their proxies and initial parameters, a systematic configuration phase is required to wire up inter-contract dependencies. This document outlines the process.

## Configuration Methodology

### Step 1: Analyze Each Contract

For each deployed contract, examine:
1. **Init parameters** - What was set during `initialize()`?
2. **Admin setter functions** - What `set*()` functions exist?
3. **Authorization requirements** - Does it need to be authorized by other contracts?

### Step 2: Identify Dependencies

Create a dependency matrix showing:
- What each contract needs configured
- What contracts need to authorize this contract

### Step 3: Execute in Logical Order

Configure contracts in order of dependencies:
1. Storage contracts first (authorize consumers)
2. Core logic contracts second
3. Bridge/external integration contracts last

---

## Arbitrum Sepolia Configuration Checklist

### Contract Addresses Reference

| Contract | Proxy Address |
|----------|---------------|
| OpenworkGenesis | `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` |
| OpenWorkRewardsContract | `0x15CCa7C81A46059A46E794e6d0114c8cd9856715` |
| NOWJC | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` |
| NativeChainBridge | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` |
| CCTPv2Transceiver | `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` |
| NativeDAO | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` |
| NativeAthena | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` |
| NativeAthenaOracleManager | `0x32eceb266A07262B15308cc626B261E7d7C5E215` |
| ProfileGenesis | `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e` |
| ProfileManager | `0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D` |

---

## Contract-by-Contract Configuration

### 1. OpenworkGenesis (Storage Contract)

**Type:** Pure storage contract with authorization pattern

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`

**Required Configuration:**
Authorize all contracts that write to Genesis storage:

```bash
# Authorize NOWJC
source .env && cast send 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f "authorizeContract(address,bool)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Authorize NativeDAO
source .env && cast send 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f "authorizeContract(address,bool)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Authorize NativeAthena
source .env && cast send 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f "authorizeContract(address,bool)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Authorize NativeAthenaOracleManager
source .env && cast send 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f "authorizeContract(address,bool)" 0x32eceb266A07262B15308cc626B261E7d7C5E215 true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Authorize OpenWorkRewardsContract
source .env && cast send 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f "authorizeContract(address,bool)" 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ❌ Pending

---

### 2. OpenWorkRewardsContract

**Type:** Rewards/payment distribution

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `jobContract`: `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` (NOWJC)
- `genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`

**Required Configuration:**
```bash
# Set ProfileGenesis ✅ DONE
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "setProfileGenesis(address)" 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Set NativeDAO ✅ DONE
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "setNativeDAO(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ✅ Configured

---

### 3. NOWJC (NativeOpenWorkJobContract)

**Type:** Core job lifecycle management

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `bridge`: `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`
- `genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- `rewardsContract`: `0x15CCa7C81A46059A46E794e6d0114c8cd9856715`
- `usdcToken`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- `cctpReceiver`: `0xD22C85d18D188D37FD9D38974420a6BD68fFC315`

**Required Configuration:**
- Check for `setAthena()` if dispute resolution needed
- Check for `setDAO()` if governance needed

**Status:** ❌ Check needed

---

### 4. NativeChainBridge

**Type:** LayerZero OApp for cross-chain messaging

**Constructor Params Set:**
- `endpoint`: `0x6EDCE65403992e310A62460808c4b910D972f10f` (LZ V2)
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `mainChainEid`: `40231` (Arbitrum Sepolia)

**Required Configuration:**
```bash
# Set Job Contract
source .env && cast send 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 "setJobContract(address)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Set Profile Manager
source .env && cast send 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 "setProfileManager(address)" 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Set Peer (for cross-chain - needs remote chain bridge address)
# source .env && cast send 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 "setPeer(uint32,bytes32)" <REMOTE_EID> <REMOTE_BRIDGE_BYTES32> --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ❌ Pending

---

### 5. CCTPv2Transceiver

**Type:** Circle CCTP V2 integration for USDC transfers

**Constructor Params Set:**
- `tokenMessenger`: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
- `messageTransmitter`: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- `usdc`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`

**Required Configuration:**
```bash
# Set NOWJC (for receiving USDC payments)
source .env && cast send 0xD22C85d18D188D37FD9D38974420a6BD68fFC315 "setNOWJC(address)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Set destination domain (for cross-chain - needs remote chain CCTP domain)
# source .env && cast send 0xD22C85d18D188D37FD9D38974420a6BD68fFC315 "setDestinationDomain(uint32,uint32)" <CHAIN_ID> <CCTP_DOMAIN> --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ❌ Pending

---

### 6. NativeDAO

**Type:** Governance and fee management

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `bridge`: `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`
- `genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`

**Required Configuration:**
```bash
# Set Athena (for dispute resolution)
source .env && cast send 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 "setAthena(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ❌ Pending

---

### 7. NativeAthena

**Type:** AI-powered dispute resolution

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `daoContract`: `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357`
- `genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- `nowjContract`: `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`
- `usdcToken`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`

**Required Configuration:**
```bash
# Set Oracle Manager
source .env && cast send 0x20Ec5833261d9956399c3885b22439837a6eD7b2 "setOracleManager(address)" 0x32eceb266A07262B15308cc626B261E7d7C5E215 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ❌ Pending

---

### 8. NativeAthenaOracleManager

**Type:** Oracle management for Athena

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- `nativeAthena`: `0x20Ec5833261d9956399c3885b22439837a6eD7b2`

**Required Configuration:**
- Check for additional setters

**Status:** ❌ Check needed

---

### 9. ProfileGenesis (Storage Contract)

**Type:** Pure storage contract for profile data

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`

**Required Configuration:**
```bash
# Authorize ProfileManager
source .env && cast send 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e "authorizeContract(address,bool)" 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Status:** ❌ Pending

---

### 10. ProfileManager

**Type:** Profile management logic

**Init Params Set:**
- `owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `bridge`: `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`
- `genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`

**Required Configuration:**
- None (uses OpenworkGenesis, not ProfileGenesis - may need `setGenesis()` to ProfileGenesis)

**Status:** ✅ Check if ProfileGenesis needed

---

## Configuration Order

Recommended order for configuration:

1. **Storage contracts authorize consumers:**
   - OpenworkGenesis → authorize all writing contracts
   - ProfileGenesis → authorize ProfileManager

2. **Set cross-references:**
   - OpenWorkRewardsContract.setProfileGenesis() ✅
   - OpenWorkRewardsContract.setNativeDAO() ✅
   - NativeDAO.setAthena()
   - NativeAthena.setOracleManager()

3. **Bridge configuration:**
   - NativeChainBridge.setJobContract()
   - NativeChainBridge.setProfileManager()
   - CCTPv2Transceiver.setNOWJC()

4. **Cross-chain (after remote deployment):**
   - NativeChainBridge.setPeer()
   - CCTPv2Transceiver.setDestinationDomain()

---

## Verification Commands

After configuration, verify state:

```bash
# Check OpenworkGenesis authorization
cast call 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f "authorizedContracts(address)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check RewardsContract profileGenesis
cast call 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "profileGenesis()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check RewardsContract nativeDAO
cast call 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "nativeDAO()" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```
