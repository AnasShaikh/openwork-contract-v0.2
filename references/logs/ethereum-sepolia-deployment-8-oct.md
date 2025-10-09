# Ethereum Sepolia Deployment Commands - October 8, 2024

This document records the exact deployment commands used for deploying contracts to Ethereum Sepolia testnet.

## Environment Variables Used
```bash
ETHEREUM_SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0
PRIVATE_KEY=f1f8c89679dcbbe72d5e79be4cb301575f1c43c603196f9e546e5b951dc0389d
OWNER_ADDRESS=0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef
ETHERSCAN_API_KEY=ZSTW4J27DSINYUY8KR98WN7C34CX5GFIQW
```

## Deployed Contracts

### 1. LayerZero Bridge (Local Bridge)
**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /local-bridge.sol:LayerZeroBridge`
**Deployed Address**: `0xE6EEeaf9D48CafEbE19F8e906B8bBfe13d7b11e6`

```bash
forge create "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /local-bridge.sol:LayerZeroBridge" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args 0x6EDCE65403992e310A62460808c4b910D972f10f $OWNER_ADDRESS 40231 \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast
```

**Constructor Parameters**:
- `endpoint`: `0x6EDCE65403992e310A62460808c4b910D972f10f` (LayerZero Endpoint)
- `owner`: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef` (Owner Address)
- `nativeChainId`: `40231` (Native Chain ID)

**Verification Status**: ✅ Verified

---

### 2. CCTPv2 Transceiver
**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /cctp-v2-ft-transceiver.sol:CCTPv2Transceiver`
**Deployed Address**: `0x65bf76589B9e9B0768181e7b7B8dB1A2d230091d`

```bash
forge create "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /cctp-v2-ft-transceiver.sol:CCTPv2Transceiver" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast
```

**Constructor Parameters**: None (default constructor)

**Verification Status**: ✅ Verified

---

### 3. Athena Client (with UUPS Proxy)

#### 3.1 Implementation Contract
**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /athena-client.sol:LocalAthena`
**Deployed Address**: `0x06BB8cD93DD18b0C2b74F26E70DF6a37C47bb1C8`

```bash
forge create "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /athena-client.sol:LocalAthena" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast
```

**Verification Status**: ✅ Verified

#### 3.2 UUPS Proxy Contract
**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /proxy.sol:UUPSProxy`
**Deployed Address**: `0x4D1F94eFc5088B53b072C6c0a61aD24B85DD1b07`

```bash
forge create "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /proxy.sol:UUPSProxy" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args 0x06BB8cD93DD18b0C2b74F26E70DF6a37C47bb1C8 0x485cc955000000000000000000000000aa6816876280c5a685baf3d9c214a092c7f3f6ef000000000000000000000000098e52aff44aead944aff86f4a5b90dbaf5b86bd0000000000000000000000006edce65403992e310a62460808c4b910d972f10f \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast
```

**Constructor Parameters**:
- `implementation`: `0x06BB8cD93DD18b0C2b74F26E70DF6a37C47bb1C8` (LocalAthena implementation)
- `data`: `0x485cc955000000000000000000000000aa6816876280c5a685baf3d9c214a092c7f3f6ef000000000000000000000000098e52aff44aead944aff86f4a5b90dbaf5b86bd0000000000000000000000006edce65403992e310a62460808c4b910d972f10f`

**Initialization Call**: `initialize(address,address,address)`
- `owner`: `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- `daoContract`: `0x098E52Aff44AEAd944AFf86F4A5b90dbAF5B86bd`
- `bridge`: `0x6EDCE65403992e310A62460808c4b910D972f10f`

**Verification Status**: ✅ Verified

---

### 4. LOWJC (Cross Chain Local OpenWork Job Contract) - Upgrade

#### 4.1 New Implementation Contract
**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc.sol:CrossChainLocalOpenWorkJobContract`
**Deployed Address**: `0x0ED13e09658bA8F5D4E6e9bEc1677eA3ecB646A1`

```bash
forge create "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc.sol:CrossChainLocalOpenWorkJobContract" \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast
```

**Verification Status**: ✅ Verified

#### 4.2 Proxy Upgrade Command
**Existing Proxy Address**: `0x6d2FE4c7E7d98D24B54F863E8b3b1f2A7F8C5E90`

```bash
cast send 0x6d2FE4c7E7d98D24B54F863E8b3b1f2A7F8C5E90 \
  "upgradeToAndCall(address,bytes)" \
  0x0ED13e09658bA8F5D4E6e9bEc1677eA3ecB646A1 \
  0x \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Upgrade Parameters**:
- `newImplementation`: `0x0ED13e09658bA8F5D4E6e9bEc1677eA3ecB646A1`
- `data`: `0x` (empty bytes for no additional initialization)

**Status**: ✅ Successfully upgraded

---

## Key Notes

1. **Critical Flag**: All deployments used the `--broadcast` flag which is essential for proper deployment and verification
2. **Chain**: All contracts deployed to Ethereum Sepolia testnet
3. **Verification**: All contracts successfully verified on Etherscan using API v2
4. **Date**: October 8, 2024
5. **Gas**: All deployments used default gas settings (auto-estimation)

## Environment Setup Commands

```bash
# Source environment variables
source .env

# Verify connection
cast chain-id --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Check balance
cast balance $OWNER_ADDRESS --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

---

*This log was generated on October 8, 2024, documenting the successful deployment of OpenWork contracts to Ethereum Sepolia testnet.*