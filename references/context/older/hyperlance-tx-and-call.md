# Foundry Deployment Guide - Hyperlane Transfer and Call Demo

## Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
cast --version
```

## Project Setup

```bash
# Create new project
forge init hyperlane-demo
cd hyperlane-demo

# Install dependencies
forge install openzeppelin/openzeppelin-contracts
forge install hyperlane-xyz/hyperlane-monorepo
```

### Add to `foundry.toml`:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
]

[rpc_endpoints]
base_sepolia = "https://sepolia.base.org"
arbitrum_sepolia = "https://sepolia-rollup.arbitrum.io/rpc"

[etherscan]
base_sepolia = { key = "${BASESCAN_API_KEY}", url = "https://api-sepolia.basescan.org/api" }
arbitrum_sepolia = { key = "${ARBISCAN_API_KEY}", url = "https://api-sepolia.arbiscan.io/api" }
```

## Required Addresses

### Testnet Addresses:

**Base Sepolia:**
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- Warp Route: `0x[YOUR_DEPLOYED_HWR_ADDRESS]`
- ICA Router: `0x[HYPERLANE_ICA_ROUTER_ADDRESS]`
- Domain ID: `84532`

**Arbitrum Sepolia:**
- USDC: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- Warp Route: `0x[YOUR_DEPLOYED_HWR_ADDRESS]`
- ICA Router: `0x[HYPERLANE_ICA_ROUTER_ADDRESS]`
- Domain ID: `421614`

> **Note**: You need to deploy Hyperlane Warp Routes first using the Hyperlane CLI (see previous tutorial)

## Deployment Scripts

### 1. Deploy Target Contract (Base Sepolia)

Create `script/DeployTarget.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/DemoTargetContract.sol";

contract DeployTarget is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Base Sepolia USDC
        address usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        
        DemoTargetContract target = new DemoTargetContract(usdc);
        
        console.log("DemoTargetContract deployed at:", address(target));
        
        vm.stopBroadcast();
    }
}
```

### 2. Deploy Demo Contract (Arbitrum Sepolia)

Create `script/DeployDemo.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/MinimalTransferAndCallDemo.sol";

contract DeployDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Arbitrum Sepolia addresses
        address usdc = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
        address warpRoute = 0x[YOUR_ARBITRUM_HWR_ADDRESS]; // Replace with actual
        address icaRouter = 0x[HYPERLANE_ICA_ROUTER_ADDRESS]; // Replace with actual
        
        MinimalTransferAndCallDemo demo = new MinimalTransferAndCallDemo(
            usdc,
            warpRoute,
            icaRouter
        );
        
        console.log("MinimalTransferAndCallDemo deployed at:", address(demo));
        
        vm.stopBroadcast();
    }
}
```

## Environment Setup

Create `.env`:
```bash
PRIVATE_KEY=0x...
BASESCAN_API_KEY=...
ARBISCAN_API_KEY=...
```

## Deployment Commands

### Step 1: Deploy Target Contract on Base Sepolia
```bash
forge script script/DeployTarget.s.sol:DeployTarget \
    --rpc-url base_sepolia \
    --broadcast \
    --verify
```

**Save the deployed address!**

### Step 2: Deploy Demo Contract on Arbitrum Sepolia
```bash
# Update the script with actual addresses first
forge script script/DeployDemo.s.sol:DeployDemo \
    --rpc-url arbitrum_sepolia \
    --broadcast \
    --verify
```

**Save the deployed address!**

## Setup Connection

### Step 3: Get ICA Address

```bash
# Get the Interchain Account address
cast call [DEMO_CONTRACT_ADDRESS] "getICA(uint32)" 84532 \
    --rpc-url arbitrum_sepolia
```

**Save this ICA address!**

### Step 4: Authorize ICA on Target Contract

```bash
# Authorize the ICA to call target contract
cast send [TARGET_CONTRACT_ADDRESS] \
    "authorizeICA(address,bool)" \
    [ICA_ADDRESS] \
    true \
    --rpc-url base_sepolia \
    --private-key $PRIVATE_KEY
```

## Test Transfer

### Step 5: Get Test USDC

**Base Sepolia Faucet:** https://faucet.quicknode.com/base/sepolia  
**Arbitrum Sepolia Faucet:** https://faucet.quicknode.com/arbitrum/sepolia

### Step 6: Approve USDC on Demo Contract

```bash
# Approve demo contract to spend your USDC
cast send 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d \
    "approve(address,uint256)" \
    [DEMO_CONTRACT_ADDRESS] \
    1000000000 \
    --rpc-url arbitrum_sepolia \
    --private-key $PRIVATE_KEY
```

### Step 7: Quote Gas Fees

```bash
# Get gas fees for the transfer
cast call [DEMO_CONTRACT_ADDRESS] \
    "quoteFees(uint32)" \
    84532 \
    --rpc-url arbitrum_sepolia
```

### Step 8: Execute Transfer and Call

```bash
# Execute the cross-chain escrow
cast send [DEMO_CONTRACT_ADDRESS] \
    "escrowOnDestination(string,uint256,uint32,address)" \
    "job-123" \
    1000000 \
    84532 \
    [TARGET_CONTRACT_ADDRESS] \
    --value [QUOTED_GAS_FEE] \
    --rpc-url arbitrum_sepolia \
    --private-key $PRIVATE_KEY
```

## Verification

### Check Escrow on Base Sepolia

```bash
# Check if escrow was successful
cast call [TARGET_CONTRACT_ADDRESS] \
    "getEscrowedAmount(string)" \
    "job-123" \
    --rpc-url base_sepolia

# Should return: 1000000 (1 USDC in 6 decimals)
```

### Release Escrow

```bash
# Release escrow to recipient
cast send [TARGET_CONTRACT_ADDRESS] \
    "releaseEscrow(string,address)" \
    "job-123" \
    [RECIPIENT_ADDRESS] \
    --rpc-url base_sepolia \
    --private-key $PRIVATE_KEY
```

## Troubleshooting

### Common Issues:

**"Insufficient gas payment"**
```bash
# Get accurate gas quote
cast call [DEMO_CONTRACT_ADDRESS] "quoteFees(uint32)" 84532 --rpc-url arbitrum_sepolia
```

**"Not authorized ICA"**
```bash
# Check if ICA is authorized
cast call [TARGET_CONTRACT_ADDRESS] "isAuthorizedICA(address)" [ICA_ADDRESS] --rpc-url base_sepolia

# Re-authorize if needed
cast send [TARGET_CONTRACT_ADDRESS] "authorizeICA(address,bool)" [ICA_ADDRESS] true --rpc-url base_sepolia --private-key $PRIVATE_KEY
```

**"Transfer failed"**
- Ensure USDC approval is sufficient
- Check Warp Route has liquidity
- Verify contract addresses are correct

## Helper Scripts

### Check Balances
```bash
# USDC balance
cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "balanceOf(address)" [YOUR_ADDRESS] --rpc-url arbitrum_sepolia

# ETH balance
cast balance [YOUR_ADDRESS] --rpc-url arbitrum_sepolia
```

### Monitor Transactions
```bash
# Check transaction status
cast tx [TX_HASH] --rpc-url arbitrum_sepolia

# Check logs
cast logs --from-block [BLOCK_NUMBER] --to-block latest --address [CONTRACT_ADDRESS] --rpc-url arbitrum_sepolia
```

