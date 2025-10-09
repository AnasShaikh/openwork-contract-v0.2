# Contract Verification Guide - OP Sepolia

Quick reference for verifying OpenWork contracts on OP Sepolia Etherscan.

## Prerequisites

1. **New Etherscan Multichain API Key** (Required)
   - Old chain-specific keys (OPSCAN_API_KEY) are deprecated
   - Get from: https://etherscan.io/apis
   - Set as `ETHERSCAN_API_KEY` in `.env`

2. **Updated Foundry** 
   ```bash
   foundryup
   forge --version  # Should be 1.3.5+ for v2 API support
   ```

## Verification Steps

### 1. Check UUPS Proxy Implementation Address

**CRITICAL**: Always check the actual implementation address before verification!

#### Method 1: ERC1967 Storage Slot (Most Reliable)
```bash
# Get implementation address from storage slot 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
cast storage [PROXY_ADDRESS] 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url [RPC_URL]

# Example for OP Sepolia:
cast storage 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url https://sepolia.optimism.io
```

#### Method 2: getImplementation() Function Call
```bash
# Call getImplementation() if available on proxy
cast call [PROXY_ADDRESS] "getImplementation()" --rpc-url [RPC_URL]

# Example for OP Sepolia:
cast call 0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7 "getImplementation()" --rpc-url https://sepolia.optimism.io
```

#### Method 3: Etherscan API Check
```bash
# Check if contracts are already verified
source .env && curl "https://api-sepolia-optimistic.etherscan.io/api?module=contract&action=getabi&address=[ADDRESS]&apikey=$ETHERSCAN_API_KEY"
```

**⚠️ Important Notes:**
- Implementation addresses in documentation may be outdated
- Always verify the current implementation before proceeding
- Storage slot method is most reliable for UUPS proxies
- Different chains use different RPC URLs

#### Common RPC URLs:
```bash
# OP Sepolia
https://sepolia.optimism.io

# Arbitrum Sepolia  
https://arbitrum-sepolia.infura.io/v3/c74477fe73794a5b897b6037f564c7d0

# Base Sepolia
https://base-sepolia.g.alchemy.com/v2/ECvjGU_6M0Jrw6wlFkPo2ZbonbfW5oIZ
```

### 2. Verify Implementation Contract
```bash
source .env && forge verify-contract [IMPLEMENTATION_ADDRESS] \
  "src/suites/[SUITE_FOLDER]/athena-client.sol:LocalAthena" \
  --chain optimism-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir
```

### 3. Verify Proxy Contract  
```bash
source .env && forge verify-contract [PROXY_ADDRESS] \
  "src/suites/[SUITE_FOLDER]/proxy.sol:UUPSProxy" \
  --chain optimism-sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version 0.8.29 \
  --optimizer-runs 200 \
  --via-ir \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" [IMPLEMENTATION_ADDRESS] 0x)
```

### 4. Check Verification Status
```bash
source .env && forge verify-check [GUID] --chain optimism-sepolia --etherscan-api-key $ETHERSCAN_API_KEY
```

## Common Issues & Solutions

### ❌ "Invalid API Key"
- **Solution**: Use new Etherscan multichain API key, not old OPSCAN_API_KEY

### ❌ "Bytecode does not match"  
- **Solution**: Try compiler version 0.8.29 instead of 0.8.22
- Check foundry.toml settings match deployment

### ❌ "V1 endpoint deprecated"
- **Solution**: Update Foundry with `foundryup`

### ❌ "Implementation address mismatch"
- **Problem**: Documentation shows old implementation addresses after upgrades
- **Solution**: Always check current implementation using storage slot method
- **Example**: LOWJC and Native Athena had different implementations than documented

### ❌ "Wrong contract name in verification"
- **Problem**: Contract name in source file differs from expected name
- **Solution**: Check actual contract name in .sol file (e.g., `LayerZeroBridge` not `LocalBridge`)

### ❌ "Non-upgradeable contract assumed to have proxy"
- **Problem**: Not all contracts use UUPS proxy pattern
- **Solution**: Check deployment pattern - some contracts like Local Bridge are deployed directly

## Current Verified Contracts (OP Sepolia)

| Contract | Address | Status |
|----------|---------|---------|
| **LocalAthena** (Implementation) | `0xBccbf9633a42ACF4213a95f17B844B27408b2A21` | ✅ Verified |
| **UUPSProxy** | `0x45E51B424c87Eb430E705CcE3EcD8e22baD267f7` | ✅ Verified |

## Foundry Config

Ensure `foundry.toml` has:
```toml
[etherscan]
optimism_sepolia = { key = "${ETHERSCAN_API_KEY}", url = "https://api-sepolia-optimistic.etherscan.io/api" }
```

## Quick Command Reference

```bash
# Get contract addresses from deployment docs
cat references/deployments/latest-contracts-8-Oct.md | grep -A 5 "OP Sepolia"

# Check if already verified
curl "https://api-sepolia-optimistic.etherscan.io/api?module=contract&action=getabi&address=[ADDRESS]&apikey=$ETHERSCAN_API_KEY"
```

---
*Last updated: Oct 8, 2025*  
*Works with: Foundry 1.3.5+, Etherscan Multichain API*