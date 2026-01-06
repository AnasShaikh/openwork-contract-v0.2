# Deployment Log - Testnet - January 2, 2026

---

## 1. OpenworkGenesis (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis.sol:OpenworkGenesis"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b
Transaction hash: 0xa2e82ceb73e35018733db6684c2b38bafb871fadf5d33aa24904047279efbc42
```

---

## 2. UUPSProxy for OpenworkGenesis (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b $(cast calldata "initialize(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A)
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f
Transaction hash: 0x8ff9ec9afc671c0bfb40a3e75c2340ea2c70afe86831ac1a0dd928abe38bb4f5
```

---

## 3. Verify OpenworkGenesis Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge verify-contract 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b \
  "src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis.sol:OpenworkGenesis" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir
```

**Output:**
```
Response: OK
Details: Pass - Verified
URL: https://sepolia.arbiscan.io/address/0x3e4f48dfb659d0844abfdbddb307b8d28f24be7b
```

---

## 4. Verify UUPSProxy (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge verify-contract 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f \
  "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" \
  --chain arbitrum-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" 0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b $(cast calldata "initialize(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A))
```

**Output:**
```
Response: OK
Details: Pass - Verified
URL: https://sepolia.arbiscan.io/address/0xcfb3de1501a3d4619d9e57ceae75f5dc5d86497f
```

---

## 5. OpenWorkRewardsContract Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/native-rewards-mainnet.sol:OpenWorkRewardsContract"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xCc9b4b183AdB83FcB14f21bf50497852512fa6fA
Transaction hash: 0x33f25324b630a34e6851d0524101f16f869649ec7b79fa6d2ddb0c7052029c63
```

---

## 6. UUPSProxy for OpenWorkRewardsContract - UNINITIALIZED (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0xCc9b4b183AdB83FcB14f21bf50497852512fa6fA 0x
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x15CCa7C81A46059A46E794e6d0114c8cd9856715
Transaction hash: 0x9f9d89c1de16f43efdfa46e6002e7d8bcdac828645080437c70674e1c60e721c
```

**Note:** Deployed with empty init data (0x). Will initialize later when all Arbitrum contracts are deployed.

---

## 7. NativeOpenWorkJobContract / NOWJC Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/nowjc.sol:NativeOpenWorkJobContract"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xEA0a8DBA2A4A82a849d41AaCB31881Cce0dcF7F6
Transaction hash: 0xc0dd976df1de4f4edcdd5d23b3726876a2c5276d11c4f8c88885a91b4526ba24
```

---

## 8. UUPSProxy for NOWJC - UNINITIALIZED (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0xEA0a8DBA2A4A82a849d41AaCB31881Cce0dcF7F6 0x
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513
Transaction hash: 0x9575ac96a656fcecc63e7ce6ac015b40d6b12978030b8e33b391541e05721a16
```

**Note:** Deployed with empty init data (0x). Will initialize later when all Arbitrum contracts are deployed.

---

## 9. NativeChainBridge (Arbitrum Sepolia) - Non-Upgradeable

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/native-bridge.sol:NativeChainBridge" --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 40231
```

**Constructor Args:**
- `_endpoint`: `0x6EDCE65403992e310A62460808c4b910D972f10f` (LayerZero V2 Endpoint - Arbitrum Sepolia)
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_mainChainEid`: `40231` (Arbitrum Sepolia EID)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7
Transaction hash: 0x953adbb3598c90874ba4ce7577d9a2d20769293314489007342d175da2e88b36
```

---

## 10. CCTPv2TransceiverWithRewardsDynamic (Arbitrum Sepolia) - Non-Upgradeable

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver.sol:CCTPv2TransceiverWithRewardsDynamic" --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
```

**Constructor Args:**
- `_tokenMessenger`: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` (Circle TokenMessengerV2 - Arbitrum Sepolia)
- `_messageTransmitter`: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` (Circle MessageTransmitterV2 - Arbitrum Sepolia)
- `_usdc`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` (USDC - Arbitrum Sepolia)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xD22C85d18D188D37FD9D38974420a6BD68fFC315
Transaction hash: 0xfac6f2cbda618cf68c5154a6d2fc0a8b8dfbc6289fc5f385ec7b9935a136e845
```

---

## 11. Initialize NOWJC Proxy (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "initialize(address,address,address,address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d 0xD22C85d18D188D37FD9D38974420a6BD68fFC315 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_bridge`: `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` (NativeChainBridge)
- `_genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` (OpenworkGenesis Proxy)
- `_rewardsContract`: `0x15CCa7C81A46059A46E794e6d0114c8cd9856715` (OpenWorkRewardsContract Proxy)
- `_usdcToken`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` (USDC - Arbitrum Sepolia)
- `_cctpReceiver`: `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` (CCTPv2Transceiver)

**Output:**
```
status               1 (success)
transactionHash      0xc1b78a4392b2d4f9ce6b52346f208dca5d85b5cb2a2844dee09758a27843f650
blockNumber          229982690
gasUsed              188385
```

---

## 12. Initialize OpenWorkRewardsContract Proxy (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "initialize(address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_jobContract`: `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` (NOWJC Proxy)
- `_genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` (OpenworkGenesis Proxy)

**Output:**
```
status               1 (success)
transactionHash      0x1adde9a78009e7becb8e1fa6e41eab99e5f231b285ca50db29003883d0e8da28
blockNumber          229983086
gasUsed              1910520
```

---

## 13. NativeDAO Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/native-dao.sol:NativeDAO"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x8E2aDec68c8115eF54Cc5186f1d294152fd4C4ED
Transaction hash: 0x9252c160b70324a489316b0e28d2daec7a6ace93b55826590a2e1dff880e8a1a
```

---

## 14. UUPSProxy for NativeDAO - WITH INITIALIZATION (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0x8E2aDec68c8115eF54Cc5186f1d294152fd4C4ED $(cast calldata "initialize(address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f)
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_bridge`: `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` (NativeChainBridge)
- `_genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` (OpenworkGenesis Proxy)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357
Transaction hash: 0x8e6f371ffe4ab660d1d46c176ab14292e3f6f802f349e5de20e5907cce4afb19
```

---

## 15. NativeAthena Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena.sol:NativeAthena"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x0ad0306EAfCBf121Ed9990055b89e1249011455F
Transaction hash: 0x59e4bddc51cc44717f159ac1cabca0cf9a982664774d234d45c260934539ecb3
```

---

## 16. UUPSProxy for NativeAthena - WITH INITIALIZATION (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0x0ad0306EAfCBf121Ed9990055b89e1249011455F $(cast calldata "initialize(address,address,address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d)
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_daoContract`: `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` (NativeDAO Proxy)
- `_genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` (OpenworkGenesis Proxy)
- `_nowjContract`: `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` (NOWJC Proxy)
- `_usdcToken`: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` (USDC - Arbitrum Sepolia)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x20Ec5833261d9956399c3885b22439837a6eD7b2
Transaction hash: 0x74ebc9039d6933b3aa36571dac9736152509b8da82fe3d7beb511516ebb62fca
```

---

## 17. NativeAthenaOracleManager Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager.sol:NativeAthenaOracleManager"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xaa877a0f6ad070A9BB110fD4d5eFcc606691D45F
Transaction hash: 0xd14824f5821b1c4c0fd0f0dbfafd7bc171154a5b5c3cd74494f73299692df3bb
```

---

## 18. UUPSProxy for NativeAthenaOracleManager - WITH INITIALIZATION (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0xaa877a0f6ad070A9BB110fD4d5eFcc606691D45F $(cast calldata "initialize(address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f 0x20Ec5833261d9956399c3885b22439837a6eD7b2)
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` (OpenworkGenesis Proxy)
- `_nativeAthena`: `0x20Ec5833261d9956399c3885b22439837a6eD7b2` (NativeAthena Proxy)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x32eceb266A07262B15308cc626B261E7d7C5E215
Transaction hash: 0xfc2a6ede4036aa87606c6c2e3830d1fd4203c9be2939c34adf560d40e860f3be
```

---

## 19. ProfileGenesis Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/profile-genesis.sol:ProfileGenesis"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xF749d2C217CFE08912768b23e84ec546aabDC4F0
Transaction hash: 0x2f11a9ca6e24fbc18babc43727cb54268db2253dcbe36025dc965e474fb329b0
```

---

## 20. UUPSProxy for ProfileGenesis - WITH INITIALIZATION (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0xF749d2C217CFE08912768b23e84ec546aabDC4F0 $(cast calldata "initialize(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A)
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e
Transaction hash: 0xbf4e99d70bfe6a8c14fd7ed77299819be4c725ec13dee9d16c2e193c9967ca4c
```

---

## 21. ProfileManager Implementation (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/profile-manager.sol:ProfileManager"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x90D9dFFDA90Cfe8138847F4F45994fD5d74A7270
Transaction hash: 0x5f6d77e5947e855d5138ccefa518fbd23725521162d81a615854464af5a6deec
```

---

## 22. UUPSProxy for ProfileManager - WITH INITIALIZATION (Arbitrum Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0x90D9dFFDA90Cfe8138847F4F45994fD5d74A7270 $(cast calldata "initialize(address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f)
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_bridge`: `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` (NativeChainBridge)
- `_genesis`: `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f` (OpenworkGenesis Proxy)

> ⚠️ **BUG:** Wrong genesis address used! Should be `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e` (ProfileGenesis Proxy), NOT OpenworkGenesis. ProfileManager manages user profiles via ProfileGenesis. Fixed via `setGenesis()` call during testing.

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D
Transaction hash: 0x02f1b360b33705eed83bae13f39a48364e81dd01c9bb48717b00d5fee21d8890
```

---

# Post-Deployment Configuration Phase

## Systematic Configuration Approach

After all contracts are deployed and initialized, we need to configure inter-contract dependencies. The approach is:

1. **For each contract:** Identify external dependencies not set during initialization
2. **Check setter functions:** Look for `set*` functions that configure optional dependencies
3. **Execute configuration:** Call setters with deployed contract addresses
4. **Verify configuration:** Confirm state variables are set correctly

---

## 23. OpenWorkRewardsContract - Set ProfileGenesis (Arbitrum Sepolia)

**Analysis:**
- Already set via init: `jobContract`, `genesis`
- Optional setters: `setProfileGenesis()`, `setNativeDAO()`

**Command:**
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "setProfileGenesis(address)" 0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Params:**
- `_profileGenesis`: `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e` (ProfileGenesis Proxy)

**Output:**
```
status               1 (success)
transactionHash      0x... (configuration transaction)
```

---

## 24. OpenWorkRewardsContract - Set NativeDAO (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x15CCa7C81A46059A46E794e6d0114c8cd9856715 "setNativeDAO(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Params:**
- `_nativeDAO`: `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` (NativeDAO Proxy)

**Output:**
```
status               1 (success)
transactionHash      0x... (configuration transaction)
```

---

## Configuration Status Summary

| Contract | Init Status | Configuration Status | Pending |
|----------|-------------|---------------------|---------|
| OpenworkGenesis | ✅ | ✅ | - |
| OpenWorkRewardsContract | ✅ | ✅ | - |
| NOWJC | ✅ | ✅ | - |
| NativeChainBridge | ✅ | ✅ | setPeer() ✅ (OP Sepolia) |
| CCTPv2Transceiver | ✅ | ✅ | No required config |
| NativeDAO | ✅ | ✅ | - |
| NativeAthena | ✅ | ✅ | - |
| NativeAthenaOracleManager | ✅ | ✅ | - |
| ProfileGenesis | ✅ | ✅ | - |
| ProfileManager | ✅ | ✅ | - |

---

## 25. NOWJC - Set Admin (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setAdmin(address,bool)" 0xfD08836eeE6242092a9c869237a8d122275b024A true --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0x6143cc765878c5b7a387cc388cda52096359741b7b9ed8b23cdced29256801db
```

---

## 26. NOWJC - Set CCTP Transceiver (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setCCTPTransceiver(address)" 0xD22C85d18D188D37FD9D38974420a6BD68fFC315 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0x4ebeb6ed10f1d8d9636b4b7b1df1911b453e2a5bb82cb9c92a8ee3214d935c6c
```

---

## 27. NOWJC - Set NativeAthena (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setNativeAthena(address)" 0x20Ec5833261d9956399c3885b22439837a6eD7b2 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0xd9d04a61525463863fd23315289562662b43d085f2259e42cd7d54a27a78301b
```

---

## 28. NOWJC - Set NativeDAO (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setNativeDAO(address)" 0xB7Fb55CC44547fa9143431B71946fAC16D9EE357 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0xd3a3fdbe23b55a21e78233a943c8b3ae8a1434be3af201c1909cd668b453b33c
```

---

## 29. NOWJC - Set Treasury (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "setTreasury(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0xd905b2187b31d7015ed33a02d397c06be5741a50821d57204450d6ef9c5a4891
```

---

## 30. NOWJC - Authorize NativeChainBridge (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "addAuthorizedContract(address)" 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0x6e5ef25c64de5480265d4e7aec4f308ab9de18035dbf787034c45ad2c921593a
```

---

## 31. NOWJC - Authorize Owner (Arbitrum Sepolia)

**Command:**
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "addAuthorizedContract(address)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Output:**
```
status               1 (success)
transactionHash      0x8453e838c3fdf4f89456f0c70324ebeddadd4e821d1e785a4e410ef2d1a6fbfe
```

---

# Configuration Checklist by Contract

## 1. OpenworkGenesis (Storage Contract)

**Proxy:** `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
**Init params:** `owner`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `authorizeContract(NOWJC, true)` | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` | ✅ |
| `authorizeContract(NativeDAO, true)` | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` | ✅ |
| `authorizeContract(NativeAthena, true)` | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` | ✅ |
| `authorizeContract(OracleManager, true)` | `0x32eceb266A07262B15308cc626B261E7d7C5E215` | ✅ |
| `authorizeContract(RewardsContract, true)` | `0x15CCa7C81A46059A46E794e6d0114c8cd9856715` | ✅ |
| `setAdmin(owner, true)` | Optional | - |
| `setMainDAO(NativeDAO)` | Optional | - |

### B. Config needed FROM other contracts:
None (central storage)

---

## 2. OpenWorkRewardsContract

**Proxy:** `0x15CCa7C81A46059A46E794e6d0114c8cd9856715`
**Init params:** `owner`, `jobContract`, `genesis`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setProfileGenesis(address)` | `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e` | ✅ |
| `setNativeDAO(address)` | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` | ✅ |
| `setTeamTokensPool(uint256)` | Optional | - |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ✅ |

---

## 3. NOWJC (NativeOpenWorkJobContract)

**Proxy:** `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`
**Init params:** `owner`, `bridge`, `genesis`, `rewardsContract`, `usdcToken`, `cctpReceiver`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(owner, true)` | `0xfD08836eeE6242092a9c869237a8d122275b024A` | ✅ |
| `setCCTPTransceiver(address)` | `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` | ✅ |
| `setNativeAthena(address)` | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` | ✅ |
| `setNativeDAO(address)` | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` | ✅ |
| `setTreasury(address)` | `0xfD08836eeE6242092a9c869237a8d122275b024A` | ✅ |
| `addAuthorizedContract(bridge)` | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` | ✅ |
| `addAuthorizedContract(owner)` | `0xfD08836eeE6242092a9c869237a8d122275b024A` | ✅ |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ✅ |

---

## 4. NativeChainBridge (LayerZero OApp)

**Address:** `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` (non-upgradeable)
**Constructor params:** `endpoint`, `owner`, `mainChainEid`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setNativeDaoContract(address)` | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` | ✅ |
| `setNativeAthenaContract(address)` | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` | ✅ |
| `setNativeOpenWorkJobContract(address)` | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` | ✅ |
| `setProfileManager(address)` | `0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D` | ✅ |
| `setNativeDAO(address)` | `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357` | ✅ |
| `authorizeContract(NOWJC, true)` | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` | ✅ |
| `setPeer(eid, bytes32)` | `0xF069BE11c655270038f89DECFF4d9155D0910C95` (LocalBridge - OP Sepolia, EID 40232) | ✅ |
| `addLocalChain(40232)` | OP Sepolia EID | ⚠️ MISSED - Fixed during testing |

*TX: `0xae4a7343dcaa04cd4d5ba60d7906f550ec33663e6f95337e9282bef57d3eb887` (setPeer to LocalBridge)*

> ⚠️ **MISSED CONFIG:** `addLocalChain(40232)` was not in the original checklist. This is required for NativeChainBridge to accept messages from local chains (OP Sepolia). Fixed during createProfile testing.

### B. Config needed FROM other contracts:
None

---

## 5. CCTPv2Transceiver (CCTP Integration)

**Address:** `0xD22C85d18D188D37FD9D38974420a6BD68fFC315` (non-upgradeable)
**Constructor params:** `tokenMessenger`, `messageTransmitter`, `usdc`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(address, bool)` | Optional | - |
| `setMainDAO(address)` | Optional | - |
| `setMaxRewardAmount(uint256)` | Optional (default 0.001 ETH) | - |
| `setEstimatedGasUsage(uint256)` | Optional (default 200k) | - |
| `setRewardMultiplier(uint256)` | Optional (default 2x) | - |

### B. Config needed FROM other contracts:
None (standalone - NOWJC calls it directly via sendFast)

**Status:** ✅ No required configuration

---

## 6. NativeDAO (UPGRADED - Jan 2, 2026)

**Proxy:** `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357`
**Implementation:** `0x77B53c3927fea2A4ebbeC144344Bee8FF243D95c` (upgraded)
**Init params:** `owner`, `bridge`, `genesis`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setNOWJContract(address)` | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` | ✅ |
| `setAdmin(owner, true)` | `0xfD08836eeE6242092a9c869237a8d122275b024A` | ✅ |
| `addAuthorizedContract(bridge)` | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` | ✅ |

*Note: Security upgrade added `authorizedContracts` pattern. Bridge must be authorized to call `updateStakeData()`.*
*Upgrade TX: `0x0217c496fbe594e500176d291ea688b439314048485f5de4b4ba1f04c49cc6b0`*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ✅ |

---

## 7. NativeAthena

**Proxy:** `0x20Ec5833261d9956399c3885b22439837a6eD7b2`
**Init params:** `owner`, `daoContract`, `genesis`, `nowjContract`, `usdcToken`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setOracleManager(address)` | `0x32eceb266A07262B15308cc626B261E7d7C5E215` | ✅ |
| `setBridge(address)` | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` | ✅ |

*Note: `setGenesis`, `setNOWJContract`, `setDAOContract`, `setUSDCToken` already set via init*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ✅ |

---

## 8. NativeAthenaOracleManager

**Proxy:** `0x32eceb266A07262B15308cc626B261E7d7C5E215`
**Init params:** `owner`, `genesis`, `nativeAthena`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAuthorizedCaller(address, bool)` | `0x20Ec5833261d9956399c3885b22439837a6eD7b2` (NativeAthena) | ✅ |
| `setAdmin(address, bool)` | Optional | - |
| `setMainDAO(address)` | Optional | - |

*Note: `setGenesis`, `setNativeAthena` already set via init*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| OpenworkGenesis | `authorizeContract(this, true)` | ✅ |

---

## 9. ProfileGenesis (Storage Contract)

**Proxy:** `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e`
**Init params:** `owner`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `authorizeContract(ProfileManager, true)` | `0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D` | ⚠️ Marked ✅ but NOT executed - Fixed during testing |

> ⚠️ **MISSED CONFIG:** This was marked as complete in the original checklist but no transaction was logged. The command was never actually executed. Fixed during createProfile testing.

### B. Config needed FROM other contracts:
None (storage contract)

---

## 10. ProfileManager

**Proxy:** `0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D`
**Init params:** `owner`, `bridge`, `genesis`

> ⚠️ **NOTE:** Was initialized with wrong genesis (OpenworkGenesis instead of ProfileGenesis). See Section 22 for details. Fixed via `setGenesis()` during testing.

### A. Config ON this contract:
None required - `setBridge` and `setGenesis` already set via init

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| ProfileGenesis | `authorizeContract(this, true)` | ⚠️ Was missed - Fixed during testing |

**Status:** ⚠️ Required fixes during testing (see notes above)

---

# OP Sepolia Deployments (Local Chain)

## 32. LOWJC Implementation (OP Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/lowjc.sol:CrossChainLocalOpenWorkJobContract"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x130c9e93AA22ec3556BeBEbcDe9B257aADEC73B9
Transaction hash: 0x1b6007a3372a824b561893230561cea705bd329a262535ef9a97872b03db1196
```

---

## 33. UUPSProxy for LOWJC - UNINITIALIZED (OP Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0x130c9e93AA22ec3556BeBEbcDe9B257aADEC73B9 0x
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885
Transaction hash: 0x7968ab2ebc3203d28bbd1a2c1e1b3747176c2fa3e10d094ee59f85b1f4da7332
```

**Note:** Deployed with empty init data (0x). Will initialize later when all OP Sepolia contracts are deployed.

---

## 34. LocalAthena Implementation (OP Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/athena-client.sol:LocalAthena"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xb7891AD8f2C76f73f4f4097dD794e8def07f8f77
Transaction hash: 0x48302c1a8ae3531001f1418751cb3f223ca40d614097032509abb5df7c0b2f40
```

---

## 35. UUPSProxy for LocalAthena - UNINITIALIZED (OP Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0xb7891AD8f2C76f73f4f4097dD794e8def07f8f77 0x
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6
Transaction hash: 0x7f2ed883f6cec4e7f064d57f6950d3716ccedc0091bdecdd4a5a80c4416b0110
```

**Note:** Deployed with empty init data (0x). Will initialize later when all OP Sepolia contracts are deployed.

---

## 36. LocalBridge / LayerZeroBridge (OP Sepolia) - Non-Upgradeable

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/local-bridge.sol:LayerZeroBridge" --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 40231 40161 40232
```

**Constructor Args:**
- `_endpoint`: `0x6EDCE65403992e310A62460808c4b910D972f10f` (LayerZero V2 Endpoint - OP Sepolia)
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_nativeChainEid`: `40231` (Arbitrum Sepolia)
- `_mainChainEid`: `40161` (Ethereum Sepolia)
- `_thisLocalChainEid`: `40232` (OP Sepolia)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xF069BE11c655270038f89DECFF4d9155D0910C95
Transaction hash: 0xc02502d8bb8970defac30b9b414d72f1bea4a65d9fcb6104755e9aee78a0038a
```

---

## 37. CCTPv2TransceiverWithRewardsDynamic (OP Sepolia) - Non-Upgradeable

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver.sol:CCTPv2TransceiverWithRewardsDynamic" --constructor-args 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

**Constructor Args:**
- `_tokenMessenger`: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` (Circle TokenMessengerV2 - OP Sepolia)
- `_messageTransmitter`: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` (Circle MessageTransmitterV2 - OP Sepolia)
- `_usdc`: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` (USDC - OP Sepolia)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x2139Ef959b7C83fF853DB8882C258E586e07E9BE
Transaction hash: 0xf87d268deda981d367d588d1463b0d9e759ccae4d034474d232720d3c5f23c7d
```

---

## 38. LOWJC Proxy Initialization (OP Sepolia)

**Command:**
```bash
source .env && cast send 0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885 "initialize(address,address,uint32,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 40232 0xF069BE11c655270038f89DECFF4d9155D0910C95 0x2139Ef959b7C83fF853DB8882C258E586e07E9BE --private-key $WALL2_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_usdcToken`: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` (USDC - OP Sepolia)
- `_chainId`: `40232` (LayerZero EID - OP Sepolia)
- `_bridge`: `0xF069BE11c655270038f89DECFF4d9155D0910C95` (LocalBridge - OP Sepolia)
- `_cctpSender`: `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` (CCTPv2Transceiver - OP Sepolia)

**Output:**
```
Transaction hash: 0xbaa265b6da9fb1d5b3357d5bc4c789459c56e557523a03fc33d181a8e27ca705
Block: 37783724
Status: success
Gas Used: 188186
```

---

## 39. LocalAthena Proxy Initialization (OP Sepolia)

**Command:**
```bash
source .env && cast send 0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6 "initialize(address,address,uint32,address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 40232 0xF069BE11c655270038f89DECFF4d9155D0910C95 0x2139Ef959b7C83fF853DB8882C258E586e07E9BE 0x20Ec5833261d9956399c3885b22439837a6eD7b2 --private-key $WALL2_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_usdcToken`: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7` (USDC - OP Sepolia)
- `_chainId`: `40232` (LayerZero EID - OP Sepolia)
- `_bridge`: `0xF069BE11c655270038f89DECFF4d9155D0910C95` (LocalBridge - OP Sepolia)
- `_cctpSender`: `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` (CCTPv2Transceiver - OP Sepolia)
- `_nativeAthenaRecipient`: `0x20Ec5833261d9956399c3885b22439837a6eD7b2` (NativeAthena Proxy - Arbitrum Sepolia)

**Output:**
```
Transaction hash: 0x9d8289a56e6f379bc80069f7753c93412c402232b2744e669e6067182be38fa8
Block: 37783752
Status: success
Gas Used: 210168
```

---

## OP Sepolia Contract Summary

| Contract | Type | Address | Status |
|----------|------|---------|--------|
| LOWJC Implementation | UUPS | `0x130c9e93AA22ec3556BeBEbcDe9B257aADEC73B9` | ✅ Deployed |
| LOWJC Proxy | UUPS | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` | ✅ Initialized |
| LocalAthena Implementation | UUPS | `0xb7891AD8f2C76f73f4f4097dD794e8def07f8f77` | ✅ Deployed |
| LocalAthena Proxy | UUPS | `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6` | ✅ Initialized |
| LocalBridge | Non-UUPS | `0xF069BE11c655270038f89DECFF4d9155D0910C95` | ✅ Deployed |
| CCTPv2Transceiver | Non-UUPS | `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` | ✅ Deployed |

---

# OP Sepolia Configuration Checklist (Local Chain)

## 1. LOWJC (CrossChainLocalOpenWorkJobContract)

**Proxy:** `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885`
**Init params:** `owner`, `usdcToken`, `chainId`, `bridge`, `cctpSender`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAthenaClientContract(address)` | `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6` | ✅ |
| `setCCTPMintRecipient(address)` | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` (NOWJC - Arb Sepolia) | ✅ |

*TX: `0x9a78b1281f57dcb218d0ece745012ec51a8e20eef2266b3bfedc71a13cc8e854` (setAthenaClientContract)*
*TX: `0xaa9ac587f2a06c1e61b068d02d3f981e966d00753a2d990584c71ec9058b6369` (setCCTPMintRecipient)*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| LocalBridge | `authorizeContract(this, true)` | ✅ |

---

## 2. LocalAthena

**Proxy:** `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6`
**Init params:** `owner`, `usdcToken`, `chainId`, `bridge`, `cctpSender`, `nativeAthenaRecipient`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setJobContract(address)` | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` (LOWJC Proxy) | ✅ |

*TX: `0xebdb85166970e480d6ab1a4c2b8cc349cdc9031028df81da5b7ab5952b0adfe1`*

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| LOWJC | `setAthenaClientContract(this)` | ✅ |

---

## 3. LocalBridge (LayerZero OApp)

**Address:** `0xF069BE11c655270038f89DECFF4d9155D0910C95` (non-upgradeable)
**Constructor params:** `endpoint`, `owner`, `nativeChainEid`, `mainChainEid`, `thisLocalChainEid`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAthenaClientContract(address)` | `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6` (LocalAthena) | ✅ |
| `setLowjcContract(address)` | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` (LOWJC) | ✅ |
| `authorizeContract(LOWJC, true)` | `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885` | ✅ |
| `setPeer(eid, bytes32)` | Cross-chain (Native Bridge on Arb Sepolia) | ✅ |

*TX: `0x7f77a6cc6e0623839b9e132af5b5d885534aa68de1da7a1809333af38ba49738` (setAthenaClientContract)*
*TX: `0x004f0b1903cf51f4024324ded1e5c9efe8396cf5dc50496ce85142b43edcdc16` (setLowjcContract)*
*TX: `0xb03b0f1a80a20483fb91d141776ceedb293e200b41a9c9c3b2007c0bfdbaf47f` (authorizeContract)*
*TX: `0xd45951a5a5afc6e53203ec87ea475368d1f46dcecddccb58e30a686b69a91261` (setPeer to NativeChainBridge)*

### B. Config needed FROM other contracts:
None

---

## 4. CCTPv2Transceiver (CCTP Integration)

**Address:** `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE` (non-upgradeable)
**Constructor params:** `tokenMessenger`, `messageTransmitter`, `usdc`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(address, bool)` | Optional | - |
| `setMainDAO(address)` | Optional | - |
| `setMaxRewardAmount(uint256)` | Optional (default 0.001 ETH) | - |
| `setEstimatedGasUsage(uint256)` | Optional (default 200k) | - |
| `setRewardMultiplier(uint256)` | Optional (default 2x) | - |

### B. Config needed FROM other contracts:
None (standalone - LOWJC calls it directly via sendFast)

**Status:** ✅ No required configuration

---

## Local Chain Configuration Order

1. **LocalBridge setup:**
   - LocalBridge.setAthenaClientContract()
   - LocalBridge.setLowjcContract()
   - LocalBridge.authorizeContract(LOWJC)

2. **LOWJC setup:**
   - LOWJC.setAthenaClientContract()
   - LOWJC.setCCTPMintRecipient()

3. **LocalAthena setup:**
   - LocalAthena.setJobContract()

4. **Cross-chain (after Native Chain deployment):**
   - LocalBridge.setPeer(nativeChainEid, nativeBridgeBytes32)
   - NativeChainBridge.setPeer(localChainEid, localBridgeBytes32)

---

## 40. Cross-Chain Peer Setup (OP Sepolia ↔ Arbitrum Sepolia)

### LocalBridge → NativeChainBridge

**Command:**
```bash
source .env && cast send 0xF069BE11c655270038f89DECFF4d9155D0910C95 "setPeer(uint32,bytes32)" 40231 0x000000000000000000000000bCB4401e000bBbc9918030807c164d50d4dF9bc7 --private-key $WALL2_KEY --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

**Params:**
- `eid`: `40231` (Arbitrum Sepolia LayerZero EID)
- `peer`: `0x000000000000000000000000bCB4401e000bBbc9918030807c164d50d4dF9bc7` (NativeChainBridge as bytes32)

**Output:**
```
Transaction hash: 0xd45951a5a5afc6e53203ec87ea475368d1f46dcecddccb58e30a686b69a91261
Status: success
```

---

### NativeChainBridge → LocalBridge

**Command:**
```bash
source .env && cast send 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 "setPeer(uint32,bytes32)" 40232 0x000000000000000000000000F069BE11c655270038f89DECFF4d9155D0910C95 --private-key $WALL2_KEY --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

**Params:**
- `eid`: `40232` (OP Sepolia LayerZero EID)
- `peer`: `0x000000000000000000000000F069BE11c655270038f89DECFF4d9155D0910C95` (LocalBridge as bytes32)

**Output:**
```
Transaction hash: 0xae4a7343dcaa04cd4d5ba60d7906f550ec33663e6f95337e9282bef57d3eb887
Status: success
```

---

## Cross-Chain Status Summary

| From | To | EID | Peer Address | TX | Status |
|------|-----|-----|--------------|-----|--------|
| LocalBridge (OP Sepolia) | NativeChainBridge (Arb Sepolia) | 40231 | `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7` | `0xd459...1261` | ✅ |
| NativeChainBridge (Arb Sepolia) | LocalBridge (OP Sepolia) | 40232 | `0xF069BE11c655270038f89DECFF4d9155D0910C95` | `0xae4a...b887` | ✅ |

**LayerZero cross-chain messaging is now configured bidirectionally between OP Sepolia and Arbitrum Sepolia.**

---

# Ethereum Sepolia Deployments (Main Chain)

## 41. MainRewardsContract Implementation (ETH Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/main-rewards.sol:MainRewardsContract"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xbe3606c54926b8d8125a7Cb5bcA4Ea8D442A23Da
Transaction hash: 0xa238330d48ee72a8e2643e325861ebf58a8206a5d7f9ec8939ad5681960daeff
```

---

## 42. UUPSProxy for MainRewardsContract - UNINITIALIZED (ETH Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0xbe3606c54926b8d8125a7Cb5bcA4Ea8D442A23Da 0x
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C
Transaction hash: 0xc3b6a534d47e9f1717240d886f071e451c8151004f34c54abd62995154dc8679
```

**Note:** Deployed with empty init data (0x). Will initialize after OpenworkToken deployment.

---

## 43. MainDAO Implementation (ETH Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/main-dao.sol:MainDAO"
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x2b3eE2E9627AB40F6cBE083B7966381c5e226747
Transaction hash: 0xdf640ee66640281a2103b7c0003c0ba06374ceae5f78f346a9486c9b5c06fc8f
```

---

## 44. UUPSProxy for MainDAO - UNINITIALIZED (ETH Sepolia)

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol:UUPSProxy" --constructor-args 0x2b3eE2E9627AB40F6cBE083B7966381c5e226747 0x
```

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0x43eBB3d1db00AEb3af1689b231EaEF066273805f
Transaction hash: 0x032eab2265d051b842764f1b2dac3396a32f29f7d2cbf26d9bb036d454b895bf
```

**Note:** Deployed with empty init data (0x). Will initialize after OpenworkToken deployment.

---

## 45. OpenworkToken (ETH Sepolia) - Non-Upgradeable

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/openwork-token.sol:OpenworkToken" --constructor-args 0xfD08836eeE6242092a9c869237a8d122275b024A 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C 0x43eBB3d1db00AEb3af1689b231EaEF066273805f
```

**Constructor Args:**
- `initialOwner`: `0xfD08836eeE6242092a9c869237a8d122275b024A` (deployer - gets ownership, receives ZERO tokens)
- `mainRewardsContract`: `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C` (MainRewardsContract Proxy - receives 750M)
- `daoAddress`: `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` (MainDAO Proxy - receives 250M)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd
Transaction hash: 0xce35b30751a90da380e8bcd41e9d4b50c2bffc394fede7079b1e2ef2475ed11c
```

---

## 46. OpenworkToken Distribution Verification

**Verification Commands:**
```bash
# MainRewardsContract Proxy balance (expected: 750M)
cast call 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd "balanceOf(address)(uint256)" 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# MainDAO Proxy balance (expected: 250M)
cast call 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd "balanceOf(address)(uint256)" 0x43eBB3d1db00AEb3af1689b231EaEF066273805f --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Owner wallet balance (expected: 0)
cast call 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd "balanceOf(address)(uint256)" 0xfD08836eeE6242092a9c869237a8d122275b024A --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

**Verification Results:**

| Recipient | Expected | Actual (wei) | Status |
|-----------|----------|--------------|--------|
| MainRewardsContract Proxy | 750,000,000 OWORK | `750000000000000000000000000` (7.5e26) | ✅ Correct |
| MainDAO Proxy | 250,000,000 OWORK | `250000000000000000000000000` (2.5e26) | ✅ Correct |
| Owner Wallet | 0 OWORK | `0` | ✅ Correct (Legal Compliance) |

**Token Distribution Summary:**
- **Total Supply:** 1,000,000,000 OWORK (1 billion)
- **75% (750M)** → MainRewardsContract Proxy (earned rewards + team locked)
- **25% (250M)** → MainDAO Proxy (preseed + treasury + team free)
- **0%** → Owner wallet (legal compliance - no tokens to deployer)

---

## ETH Sepolia Contract Summary (So Far)

| Contract | Type | Address | Status |
|----------|------|---------|--------|
| MainRewardsContract Implementation | UUPS | `0xbe3606c54926b8d8125a7Cb5bcA4Ea8D442A23Da` | ✅ Deployed |
| MainRewardsContract Proxy | UUPS | `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C` | ⏳ Uninitialized |
| MainDAO Implementation | UUPS | `0x2b3eE2E9627AB40F6cBE083B7966381c5e226747` | ✅ Deployed |
| MainDAO Proxy | UUPS | `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` | ⏳ Uninitialized |
| OpenworkToken | Non-UUPS | `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd` | ✅ Deployed & Verified |
| MainBridge | Non-UUPS | `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` | ✅ Deployed |

---

## 47. MainBridge (ETH Sepolia) - Non-Upgradeable

**Command:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/suites/openwork-full-contract-suite-1-Jan-version/main-chain-bridge.sol:MainBridge" --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f 0xfD08836eeE6242092a9c869237a8d122275b024A 40231
```

**Constructor Args:**
- `_endpoint`: `0x6EDCE65403992e310A62460808c4b910D972f10f` (LayerZero V2 Endpoint - ETH Sepolia)
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_nativeChainEid`: `40231` (Arbitrum Sepolia)

**Output:**
```
Deployer: 0xfD08836eeE6242092a9c869237a8d122275b024A
Deployed to: 0xa3346fF590717664efEc8424B2890aC3a7Bd1161
Transaction hash: 0xf51d42807b37456758313a3b27c3da9b2e8521f86cffdc9c4351e807865fb38c
```

**Note:** Contract was cleaned up before deployment - removed unused `athenaClientChainEid` and `lowjcChainEid` variables (see `references/logs/imp/main-bridge-cleanup-jan-2.md`).

---

## 48. Initialize MainRewardsContract Proxy (ETH Sepolia)

**Command:**
```bash
source .env && cast send 0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C "initialize(address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_openworkToken`: `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd` (OpenworkToken)
- `_bridge`: `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` (MainBridge)

**Output:**
```
status               1 (success)
transactionHash      0x6eb9321ffddf83200a15ab8ebdb3866cef6390933b9dc6863bb3b03971fe1d10
blockNumber          9966095
gasUsed              276572
```

---

## 49. Initialize MainDAO Proxy (ETH Sepolia)

**Command:**
```bash
source .env && cast send 0x43eBB3d1db00AEb3af1689b231EaEF066273805f "initialize(address,address,uint32,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd 40161 0xa3346fF590717664efEc8424B2890aC3a7Bd1161 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Init Params:**
- `_owner`: `0xfD08836eeE6242092a9c869237a8d122275b024A`
- `_openworkToken`: `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd` (OpenworkToken)
- `_chainId`: `40161` (ETH Sepolia LayerZero EID)
- `_bridge`: `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` (MainBridge)

**Output:**
```
status               1 (success)
transactionHash      0x09efa2c8f8f6a1ecf539fe5230e3152258439ec484288208e0b2b50a7c167044
blockNumber          9966096
gasUsed              354937
```

---

## ETH Sepolia Contract Summary (Updated)

| Contract | Type | Address | Status |
|----------|------|---------|--------|
| MainRewardsContract Implementation | UUPS | `0xbe3606c54926b8d8125a7Cb5bcA4Ea8D442A23Da` | ✅ Deployed |
| MainRewardsContract Proxy | UUPS | `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C` | ✅ Initialized |
| MainDAO Implementation | UUPS | `0x2b3eE2E9627AB40F6cBE083B7966381c5e226747` | ✅ Deployed |
| MainDAO Proxy | UUPS | `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` | ✅ Initialized |
| OpenworkToken | Non-UUPS | `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd` | ✅ Deployed |
| MainBridge | Non-UUPS | `0xa3346fF590717664efEc8424B2890aC3a7Bd1161` | ✅ Deployed |

---

# ETH Sepolia Configuration Checklist (Main Chain)

## 1. MainRewardsContract

**Proxy:** `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setMainDAO(address)` | `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` | ✅ `0x4ec96c72...` |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| MainBridge | `authorizeContract(this, true)` | ✅ `0x73bf7f30...` |

---

## 2. MainDAO

**Proxy:** `0x43eBB3d1db00AEb3af1689b231EaEF066273805f`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setAdmin(owner, true)` | `0xfD08836eeE6242092a9c869237a8d122275b024A` | - (auto in init) |

### B. Config needed FROM other contracts:

| Contract | Function | Status |
|----------|----------|--------|
| MainBridge | `setMainDaoContract(this)` | ✅ `0x6bddc14e...` |
| MainBridge | `authorizeContract(this, true)` | ✅ `0xaea519fe...` |

---

## 3. OpenworkToken

**Address:** `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd`

**Status:** ✅ No configuration required (immutable ERC20)

---

## 4. MainBridge

**Address:** `0xa3346fF590717664efEc8424B2890aC3a7Bd1161`

### A. Config ON this contract:

| Function | Target | Status |
|----------|--------|--------|
| `setMainDaoContract(address)` | `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` | ✅ `0x6bddc14e...` |
| `setRewardsContract(address)` | `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C` | ✅ `0x04ba1d9d...` |
| `authorizeContract(MainDAO, true)` | `0x43eBB3d1db00AEb3af1689b231EaEF066273805f` | ✅ `0xaea519fe...` |
| `authorizeContract(MainRewards, true)` | `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C` | ✅ `0x73bf7f30...` |
| `setAllowedSourceChain(40231, true)` | Arbitrum Sepolia | ✅ `0xeeaf76bf...` |
| `setAllowedSourceChain(40232, true)` | OP Sepolia | ✅ `0x8c16a06d...` |
| `setPeer(40231, bytes32)` | NativeChainBridge | ✅ `0x5394aae7...` |

### B. Config needed FROM other contracts:

None

---

## Main Chain Configuration Order

1. **MainBridge setup:** ✅ COMPLETE
2. **MainRewardsContract setup:** ✅ COMPLETE
3. **Cross-chain peers:** ✅ COMPLETE

---

## Cross-Chain Peer Summary (All Chains)

| From | To | EID | Status |
|------|-----|-----|--------|
| NativeBridge (Arb) | LocalBridge (OP) | 40232 | ✅ |
| LocalBridge (OP) | NativeBridge (Arb) | 40231 | ✅ |
| MainBridge (ETH) | NativeBridge (Arb) | 40231 | ✅ `0x5394aae7...` |
| NativeBridge (Arb) | MainBridge (ETH) | 40161 | ✅ `0xac8acb5b...` |

---

# ⚠️ Mainnet Deployment Caution

Before deploying to mainnet, update the following values:

| Parameter | Testnet | Mainnet |
|-----------|---------|---------|
| **USDC Address** | Per-chain testnet USDC | Official Circle USDC contracts |
| **LayerZero Endpoint** | `0x6EDCE65403992e310A62460808c4b910D972f10f` | Mainnet LZ V2 endpoints |
| **Chain EIDs** | 40231 (Arb), 40232 (OP), 40161 (ETH) | 30110 (Arb), 30111 (OP), 30101 (ETH) |
| **CCTP Addresses** | Testnet TokenMessenger/Transmitter | Mainnet Circle CCTP contracts |

**Always verify:**
- Correct USDC decimals and contract addresses per chain
- LayerZero peer addresses use proper bytes32 padding
- CCTP domain IDs match target chains

---

*Deployment completed: January 2, 2026*
