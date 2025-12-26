# Ethereum Sepolia Upgrade Deployment - December 15, 2025

**Date**: December 15, 2025, 8:40 AM IST  
**Purpose**: Upgrade LOWJC and Athena Client contracts + Deploy new CCTP with rewards  
**Status**: ✅ Complete  
**Deployer**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)

## Summary

Upgraded existing Ethereum Sepolia contracts to latest versions from "2 Dec" suite with critical improvements:
- **CCTP**: New contract with dynamic gas-based rewards (2x multiplier)
- **LOWJC**: Enhanced cross-chain payment features
- **Athena Client**: Routes fees to native chain (Arbitrum) via CCTP

## Deployment Sequence

### 1. Deploy New CCTP Contract (with Dynamic Rewards)

**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/cctp-v2-ft-transceiver-with-rewards-dynamic.sol:CCTPv2TransceiverWithRewardsDynamic`

```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/cctp-v2-ft-transceiver-with-rewards-dynamic.sol:CCTPv2TransceiverWithRewardsDynamic" \
  --constructor-args 0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
```

**Constructor Parameters**:
- `_tokenMessenger`: `0x72d6EfeDdA70f9B4eD3FfF4BDd0844655AEa2bD5` (Token Messenger)
- `_messageTransmitter`: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` (Message Transmitter)
- `_usdc`: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` (USDC Token)

**Result**:
- **Address**: `0xf9F10a70923dA5d5d0e17AEA4ED0a645431A0eD7`
- **TX Hash**: `0xc1acb5ae033e0279be7a9ef70275158475051c9df78f7c9c69725b586f7151b4`
- **Status**: ✅ Deployed Successfully

**Features**:
- Dynamic gas-based rewards: `estimatedGas * tx.gasprice * 2`
- Safety cap: 0.001 ETH max reward
- Reward multiplier: 2x (configurable)
- Estimated gas usage: 200,000 (configurable)

### 2. Deploy New LOWJC Implementation

**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/lowjc.sol:CrossChainLocalOpenWorkJobContract`

```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/lowjc.sol:CrossChainLocalOpenWorkJobContract"
```

**Result**:
- **Address**: `0x1CC95A9F409667006F4C3f6c2721056EDE516Ec1`
- **TX Hash**: `0x4a1128aa085c861f8227971af37a60d9c8d02e4c79a6ef6206fee7a98709e766`
- **Status**: ✅ Deployed Successfully

**Key Improvements**:
- Enhanced cross-chain payment features
- `releasePaymentCrossChain()` for cross-chain releases
- Improved milestone management
- Better dispute resolution integration

### 3. Deploy New Athena Client Implementation

**Contract**: `src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/athena-client.sol:LocalAthena`

```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 2 Dec/athena-client.sol:LocalAthena"
```

**Result**:
- **Address**: `0x61CC8AEE524F2eFa7E9F7669eEDe71e513BdC347`
- **TX Hash**: `0x3edfa908d92c2851dec673683ef94d7e5c0920fed5225906f68604e2fa3b3b0f`
- **Status**: ✅ Deployed Successfully

**CRITICAL CHANGE**:
- Now routes fees to native chain (Arbitrum) via CCTP
- Fees no longer kept locally
- Uses `routeFeeToNative()` internal function
- Sends payment instructions via LayerZero to Native Athena

### 4. Upgrade LOWJC Proxy

**Proxy Address**: `0x3b4cE6441aB77437e306F396c83779A2BC8E5134`

```bash
source .env && cast send 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 \
  "upgradeToAndCall(address,bytes)" 0x1CC95A9F409667006F4C3f6c2721056EDE516Ec1 0x \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result**:
- **TX Hash**: `0x9f9b6ad602f059dafd8ad1e43c57dbcedb48cdad7789ddaff704f7499d7207a9`
- **Gas Used**: 37,711
- **Status**: ✅ Upgrade Successful

### 5. Upgrade Athena Client Proxy

**Proxy Address**: `0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf`

```bash
source .env && cast send 0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf \
  "upgradeToAndCall(address,bytes)" 0x61CC8AEE524F2eFa7E9F7669eEDe71e513BdC347 0x \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result**:
- **TX Hash**: `0xacd8b4c0531f6f2c38fa957c9bae25ee810aecfc38ed0a59b97f8bb1112d7aca`
- **Gas Used**: 37,536
- **Status**: ✅ Upgrade Successful

### 6. Update CCTP Sender in LOWJC

```bash
source .env && cast send 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 \
  "setCCTPSender(address)" 0xf9F10a70923dA5d5d0e17AEA4ED0a645431A0eD7 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result**:
- **TX Hash**: `0xa1d65f40f567e322c7efa6c5ecbc966c7bd4581bb268baa27ed915b858088bf7`
- **Gas Used**: 34,017
- **Status**: ✅ Configuration Updated

### 7. Update CCTP Sender in Athena Client

```bash
source .env && cast send 0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf \
  "setCCTPSender(address)" 0xf9F10a70923dA5d5d0e17AEA4ED0a645431A0eD7 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Result**:
- **TX Hash**: `0x683a783e48b23d7205a0bb1d6303733640db208f81d0ae8a002a6801f04c562c`
- **Gas Used**: 35,022
- **Status**: ✅ Configuration Updated

## Final Contract Summary

| Component | Type | Address | TX Hash | Status |
|-----------|------|---------|---------|--------|
| **CCTPv2 with Rewards** | New Contract | `0xf9F10a70923dA5d5d0e17AEA4ED0a645431A0eD7` | `0xc1acb5ae...` | ✅ Active |
| **LOWJC** | Implementation (New) | `0x1CC95A9F409667006F4C3f6c2721056EDE516Ec1` | `0x4a1128aa...` | ✅ Active |
| **LOWJC** | Proxy | `0x3b4cE6441aB77437e306F396c83779A2BC8E5134` | - | ✅ Upgraded |
| **Athena Client** | Implementation (New) | `0x61CC8AEE524F2eFa7E9F7669eEDe71e513BdC347` | `0x3edfa908...` | ✅ Active |
| **Athena Client** | Proxy | `0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf` | - | ✅ Upgraded |

## Previous Implementations (Rollback Available)

| Component | Previous Implementation | Deployed |
|-----------|------------------------|----------|
| **LOWJC** | `0xB1C38C374e8589B7172541C678075FE31ca1044C` | Oct 9, 2025 |
| **Athena Client** | `0x3da42f82241977516568702E24B23989DD7c5fFD` | Oct 9, 2025 |
| **CCTP (Old)** | `0x6DB4326E2CD04481A7F558B40eb223E13c6C6e98` | Oct 9, 2025 (no rewards) |

## Key Changes and Impact

### CCTP Contract
- ✅ **Dynamic Rewards**: Pays 2x gas costs to confirmers automatically
- ✅ **Safety Cap**: 0.001 ETH maximum to prevent over-spending
- ✅ **Configurable**: Owner can adjust gas estimates and multipliers
- ⚠️ **Non-upgradeable**: CCTP is a regular contract, not UUPS

### LOWJC Contract
- ✅ **Cross-Chain Payments**: New `releasePaymentCrossChain()` function
- ✅ **Better Milestone Tracking**: Improved logic for milestone completion
- ✅ **Updated CCTP Integration**: Now points to reward-enabled CCTP

### Athena Client Contract
- ⚠️ **CRITICAL**: Fees now route to Arbitrum, not kept locally
- ✅ **CCTP Integration**: Uses CCTP to send fees cross-chain
- ✅ **LayerZero Coordination**: Sends payment instructions to Native Athena
- 🔄 **Requires Native Athena Update**: Native Athena must be prepared to receive fees

## Configuration Status

✅ All configurations completed:
- LOWJC proxy upgraded to new implementation
- Athena Client proxy upgraded to new implementation
- Both contracts configured with new CCTP address
- CCTP deployed with reward system enabled

## Testing Recommendations

1. **Test CCTP Rewards**: Send a test transfer to verify dynamic reward calculation
2. **Test Cross-Chain Payments**: Use `releasePaymentCrossChain()` with a small amount
3. **Test Fee Routing**: Raise a test dispute to verify fees route to Arbitrum
4. **Verify Native Athena**: Ensure Native Athena receives and processes fees correctly

## Total Gas Costs

| Operation | Gas Used |
|-----------|----------|
| Deploy CCTP | ~1,500,000 |
| Deploy LOWJC Impl | ~3,000,000 |
| Deploy Athena Impl | ~2,500,000 |
| Upgrade LOWJC Proxy | 37,711 |
| Upgrade Athena Proxy | 37,536 |
| Configure LOWJC CCTP | 34,017 |
| Configure Athena CCTP | 35,022 |
| **Total** | ~7,144,286 |

## Next Steps

1. **Optional**: Fund CCTP reward pool with ETH for confirmer incentives
2. **Test**: Verify all functions work correctly with new implementations
3. **Monitor**: Watch for any issues with cross-chain fee routing
4. **Document**: Update main address reference file

## Emergency Rollback Commands

If issues arise, revert to previous implementations:

```bash
# Rollback LOWJC
source .env && cast send 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 \
  "upgradeToAndCall(address,bytes)" 0xB1C38C374e8589B7172541C678075FE31ca1044C 0x \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Rollback Athena Client
source .env && cast send 0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf \
  "upgradeToAndCall(address,bytes)" 0x3da42f82241977516568702E24B23989DD7c5fFD 0x \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

# Revert CCTP addresses
source .env && cast send 0x3b4cE6441aB77437e306F396c83779A2BC8E5134 \
  "setCCTPSender(address)" 0x6DB4326E2CD04481A7F558B40eb223E13c6C6e98 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

source .env && cast send 0xA08a6E73397EaE0A3Df9eb528d9118ae4AF80fcf \
  "setCCTPSender(address)" 0x6DB4326E2CD04481A7F558B40eb223E13c6C6e98 \
  --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

**Deployment Completed**: December 15, 2025, 8:43 AM IST  
**Network**: Ethereum Sepolia  
**All contracts deployed/upgraded by**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)  
**Status**: ✅ **ALL OPERATIONS SUCCESSFUL**
