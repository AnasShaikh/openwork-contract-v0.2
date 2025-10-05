# Deploy and Upgrade Tutorial

## Prerequisites

```bash
# Load environment variables
source .env
```

Required environment variables:
- `OPTIMISM_SEPOLIA_RPC_URL`
- `ARBITRUM_SEPOLIA_RPC_URL` 
- `ETHEREUM_SEPOLIA_RPC_URL`
- `WALL2_KEY` (deployer private key)

## Deploy Implementation Pattern

### Standard Implementation Deployment

```bash
# Deploy new implementation contract
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/path/to/contract.sol:ContractName"
```

**Example - NOWJC Implementation:**
```bash
source .env && forge create --broadcast --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/unlocking unique contracts 19 sep/nowjc-final-unlocking-minttocontract-fixed.sol:NativeOpenWorkJobContract"
```

**Success Output:**
```
New Implementation: 0x52D74D2Da2329e47BCa284dC0558236062D36A28
TX Hash: 0xaca08447a629c815c80459982ba3d2b141d3dd35204cac435640ca16614333eb
```

### Cross-Chain Implementation Deployment

**OP Sepolia LOWJC:**
```bash
source .env && forge create --broadcast --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/unlocking unique contracts 19 sep/lowjc-final-cross-chain-release.sol:CrossChainLocalOpenWorkJobContract"
```

**Ethereum Sepolia LOWJC:**
```bash
source .env && forge create --broadcast --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY "src/current/unlocking unique contracts 19 sep/lowjc-final-cross-chain-release.sol:CrossChainLocalOpenWorkJobContract"
```

## Upgrade Pattern

### Standard Proxy Upgrade

```bash
# Upgrade proxy to new implementation
source .env && cast send PROXY_ADDRESS "upgradeToAndCall(address,bytes)" NEW_IMPLEMENTATION_ADDRESS 0x --rpc-url RPC_URL --private-key $WALL2_KEY
```

**Example - NOWJC Proxy Upgrade:**
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "upgradeToAndCall(address,bytes)" 0x52D74D2Da2329e47BCa284dC0558236062D36A28 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**Success Output:**
```
TX Hash: 0x848ec7fe7b4f5222e167c856747a9263a178e62c4446a8ca2a412a5fc5fe6f49
```

### Multi-Chain Upgrade Sequence

**1. Arbitrum Sepolia (NOWJC):**
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "upgradeToAndCall(address,bytes)" NEW_IMPLEMENTATION 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**2. OP Sepolia (LOWJC):**
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C "upgradeToAndCall(address,bytes)" NEW_IMPLEMENTATION 0x --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

**3. Ethereum Sepolia (LOWJC):**
```bash
source .env && cast send 0x325c6615Caec083987A5004Ce9110f932923Bd3A "upgradeToAndCall(address,bytes)" NEW_IMPLEMENTATION 0x --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

## Contract Addresses Reference

### Proxy Addresses (Never Change)
- **NOWJC (Arbitrum Sepolia):** `0x9E39B37275854449782F1a2a4524405cE79d6C1e`
- **LOWJC (OP Sepolia):** `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **LOWJC (Ethereum Sepolia):** `0x325c6615Caec083987A5004Ce9110f932923Bd3A`

### Key Implementation Examples
- **NOWJC Working Implementation:** `0x52D74D2Da2329e47BCa284dC0558236062D36A28`
- **NOWJC Direct Payment:** `0xA47aE86d4733f093DE77b85A14a3679C8CA3Aa45`
- **LOWJC Cross-Chain Fixed:** `0x958e1CDd20108B874FB6F3833dA7E2EC5d745267`

## Complete Deploy-Upgrade Workflow

### Step 1: Deploy Implementation
```bash
source .env && forge create --broadcast --rpc-url $TARGET_RPC_URL --private-key $WALL2_KEY "src/path/to/contract.sol:ContractName"
```

### Step 2: Record Implementation Address
Save the deployment output address for upgrade command.

### Step 3: Upgrade Proxy
```bash
source .env && cast send PROXY_ADDRESS "upgradeToAndCall(address,bytes)" IMPLEMENTATION_ADDRESS 0x --rpc-url $TARGET_RPC_URL --private-key $WALL2_KEY
```

### Step 4: Verify Upgrade
Check that functions work as expected on the upgraded proxy.

## Emergency Revert Pattern

```bash
# Revert to previous working implementation
source .env && cast send PROXY_ADDRESS "upgradeToAndCall(address,bytes)" PREVIOUS_WORKING_IMPLEMENTATION 0x --rpc-url $TARGET_RPC_URL --private-key $WALL2_KEY
```

**Example - Emergency Revert:**
```bash
source .env && cast send 0x9E39B37275854449782F1a2a4524405cE79d6C1e "upgradeToAndCall(address,bytes)" 0x1a437E2abd28379f0D794f480f94E0208d708971 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

## Critical Notes

1. **Always test implementations** before upgrading production proxies
2. **Record all implementation addresses** for potential reverts
3. **Deploy before upgrade** - never upgrade to non-existent addresses
4. **Use consistent private key** (`$WALL2_KEY`) for all operations
5. **Verify RPC URLs** match target networks
6. **Keep proxy addresses constant** - only implementation addresses change