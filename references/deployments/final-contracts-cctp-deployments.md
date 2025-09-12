# Final Contracts + CCTP Deployments

## Deployment Date: 2025-01-10

### Arbitrum Sepolia Testnet
- **LowjcWithCCTP Implementation (OLD)**: `0x833a205058D32Ae6a3Cc460a08cF9bCb0b59289D`
  - Contract: `CrossChainLocalOpenWorkJobContract` (legacy CCTP interface)
  - Status: ❌ Deprecated (CCTP interface mismatch)

- **LowjcWithCCTP Implementation (FIXED)**: `0x8E01D2d7Cf06d13d6408eCc368F9d13DFE132a7D`
  - Contract: `CrossChainLocalOpenWorkJobContract` (fixed CCTP interface)
  - Status: ✅ Deployed with proper TokenMessenger integration

- **LowjcWithCCTP Proxy (OLD)**: `0x2eB7692Ea648C76B9eF244B618Aad068f8497Cdc`
  - Implementation: `0x833a205058D32Ae6a3Cc460a08cF9bCb0b59289D`
  - Status: ❌ Deprecated (incompatible with new implementation)

- **LowjcWithCCTP Proxy (DEPRECATED)**: `0xa72D2F0874DC5Eb81321a7005c54D4b85CC69e67`
  - Implementation: `0x8E01D2d7Cf06d13d6408eCc368F9d13DFE132a7D`
  - Status: ❌ Deprecated (complex CCTP integration issues)

- **LowjcWithCCTP Proxy (ACTIVE)**: `0xc9C6eF2dd5f1e461f9A5B7cB1A5b087Bd4C7fc9A`
  - Implementation: `0xadb867aeaF4b2744433c5828f9C5786F71DCCAe4`
  - Status: ✅ Deployed with simplified CCTP integration
  
- **Local Bridge**: `0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80`
  - Contract: `LayerZeroBridge`
  - Status: ✅ Deployed and initialized

### Optimism Sepolia Testnet
- **Native Bridge**: `0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8`
  - Contract: `NativeChainBridge`
  - Status: ✅ Deployed and initialized

- **NowjcWithoutCCTP Implementation**: `0x6Ce6B774400a45EbdEB30DaB6Ff9D839970E00Ba`
  - Contract: `NativeOpenWorkJobContract`
  - Status: ✅ Deployed (upgradeable - needs proxy + initialization)

- **NowjcWithoutCCTP Proxy**: `0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915`
  - Implementation: `0x6Ce6B774400a45EbdEB30DaB6Ff9D839970E00Ba`
  - Status: ✅ Deployed and initialized

- **CCTPEscrowManager Implementation**: `0x753c97e33e347DCCa4984102c8109157a5cEF924`
  - Contract: `CCTPEscrowManager`
  - Status: ✅ Deployed (upgradeable - needs proxy + initialization)

- **CCTPEscrowManager Proxy**: `0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD`
  - Implementation: `0x753c97e33e347DCCa4984102c8109157a5cEF924`
  - Status: ✅ Deployed and initialized

## Network Configuration

### Arbitrum Sepolia (Chain ID: 421614)
- RPC: `$ARBITRUM_SEPOLIA_RPC_URL`
- USDC: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- CCTP Message Transmitter: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- CCTP Token Messenger: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
- LayerZero Endpoint: `0x6EDCE65403992e310A62460808c4b910D972f10f`

### Optimism Sepolia (Chain ID: 11155420)
- RPC: `$OPTIMISM_SEPOLIA_RPC_URL`
- USDC: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
- CCTP Message Transmitter: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`
- CCTP Token Messenger: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
- LayerZero Endpoint: `0x6EDCE65403992e310A62460808c4b910D972f10f`

## Deployer Address
- **Wallet**: `0xfD08836eeE6242092a9c869237a8d122275b024A` (WALL2_ADDRESS)
- **Private Key**: `$WALL2_KEY`

## CCTP Interface Fix (January 27, 2025)
1. ✅ Fixed CCTP interface mismatch in LowjcWithCCTP
2. ✅ Updated contract to use proper TokenMessenger.depositForBurn()
3. ✅ Added MessageTransmitter.sendMessageWithCaller() integration
4. ✅ Deployed new implementation with CCTP fixes
5. ✅ Deployed new proxy due to storage incompatibility
6. ✅ Updated Local Bridge to point to new proxy
7. ✅ Set MessageTransmitter address in new contract

## Previous Steps (Completed)
1. ✅ Deploy remaining contracts (5/5 complete)
2. ✅ Resolve NowjcWithCCTP size limit issue (split into 2 contracts)
3. ✅ Initialize LowjcWithCCTP proxy
4. ✅ Initialize NowjcWithoutCCTP proxy
5. ✅ Initialize CCTPEscrowManager proxy
6. ✅ Configure cross-chain peers between bridges
7. ✅ Configure CCTP escrow manager in job contract
8. ✅ Wire all contracts together

## Contract Wiring Commands

### 1. Deploy Proxies
```bash
# Deploy CCTPEscrowManager proxy (Optimism Sepolia)
source .env && forge create --broadcast --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY "src/Final Set of Contracts/proxy.sol:UUPSProxy" --constructor-args 0x753c97e33e347DCCa4984102c8109157a5cEF924 0x

# Deploy NowjcWithoutCCTP proxy (Optimism Sepolia)
source .env && forge create --broadcast --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY "src/Final Set of Contracts/proxy.sol:UUPSProxy" --constructor-args 0x6Ce6B774400a45EbdEB30DaB6Ff9D839970E00Ba 0x

# Deploy LowjcWithCCTP proxy (Arbitrum Sepolia)
source .env && forge create --broadcast --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY "src/Final Set of Contracts/proxy.sol:UUPSProxy" --constructor-args 0x833a205058D32Ae6a3Cc460a08cF9bCb0b59289D 0x
```

### 2. Initialize Proxies
```bash
# Initialize CCTPEscrowManager (Optimism Sepolia)
source .env && cast send 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD "initialize(address,address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 0x5fd84259d66Cd46123540766Be93DFE6D43130D7 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY

# Initialize NowjcWithoutCCTP (Optimism Sepolia)
source .env && cast send 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 "initialize(address,address,address,address,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8 0xC456977804e94eb507b9D5655E1aD58A04b9D5fd 0xAdC2c53174d9E1DdD478e231E50B71A993B90e54 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY

# Initialize LowjcWithCCTP (Arbitrum Sepolia)
source .env && cast send 0x2eB7692Ea648C76B9eF244B618Aad068f8497Cdc "initialize(address,address,uint32,address,address,uint32,address)" 0xfD08836eeE6242092a9c869237a8d122275b024A 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d 421614 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 2 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY
```

### 3. Configure Same-Chain Connections (Optimism Sepolia)
```bash
# Authorize job contract to release funds from escrow
source .env && cast send 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD "authorizeReleaseContract(address,bool)" 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 true --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY

# Authorize escrow manager in job contract
source .env && cast send 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 "addAuthorizedContract(address)" 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY

# Authorize Local Bridge as CCTP sender
source .env && cast send 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD "authorizeCCTPSender(address,bool)" 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 true --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY
```

### 4. Configure Cross-Chain Bridge Connections
```bash
# Set Native Bridge as peer in Local Bridge (Arbitrum -> Optimism)
source .env && cast send 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 "setPeer(uint32,bytes32)" 40267 0x000000000000000000000000f084d5C9CA6C5954a0531Bfc397FDd6E062551B8 --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY

# Set Local Bridge as peer in Native Bridge (Optimism -> Arbitrum)
source .env && cast send 0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8 "setPeer(uint32,bytes32)" 40231 0x0000000000000000000000002Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY

# Set LowjcWithCCTP proxy address in Local Bridge
source .env && cast send 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 "setLowjcContract(address)" 0x2eB7692Ea648C76B9eF244B618Aad068f8497Cdc --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY

# Set NowjcWithoutCCTP proxy address in Native Bridge
source .env && cast send 0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8 "setNativeOpenWorkJobContract(address)" 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY
```

### 5. Authorize Bridge Contracts
```bash
# Authorize LowjcWithCCTP in Local Bridge
source .env && cast send 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 "authorizeContract(address,bool)" 0x2eB7692Ea648C76B9eF244B618Aad068f8497Cdc true --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY

# Authorize NowjcWithoutCCTP in Native Bridge
source .env && cast send 0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8 "authorizeContract(address,bool)" 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 true --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY
```

### 6. Verification Commands
```bash
# Verify authorizations
source .env && cast call 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 "authorizedContracts(address)" 0x2eB7692Ea648C76B9eF244B618Aad068f8497Cdc --rpc-url https://sepolia-rollup.arbitrum.io/rpc
source .env && cast call 0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8 "authorizedContracts(address)" 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 --rpc-url https://sepolia.optimism.io
source .env && cast call 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD "authorizedCCTPSenders(address)" 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 --rpc-url https://sepolia.optimism.io

# Verify bridge peers
source .env && cast call 0x2Cca2c1d1e25193288cDf4FF45Be5A815d43cf80 "peers(uint32)" 40267 --rpc-url https://sepolia-rollup.arbitrum.io/rpc
source .env && cast call 0xf084d5C9CA6C5954a0531Bfc397FDd6E062551B8 "peers(uint32)" 40231 --rpc-url https://sepolia.optimism.io

# Verify proxy initialization
source .env && cast call 0x2eB7692Ea648C76B9eF244B618Aad068f8497Cdc "owner()" --rpc-url https://sepolia-rollup.arbitrum.io/rpc
source .env && cast call 0xfAaef11b256DB8F6c9d6FDbB9059bEE252DC3915 "owner()" --rpc-url https://sepolia.optimism.io
source .env && cast call 0x2184F9ad5CD0c4eC14d5Ff3Da8a88043A58133BD "owner()" --rpc-url https://sepolia.optimism.io
```

## Bridge Configuration Required
- Local Bridge (Arbitrum) → Native Bridge (Optimism)
- Native Bridge (Optimism) → Local Bridge (Arbitrum)
- CCTP Domain IDs: Arbitrum Sepolia (3), Optimism Sepolia (2)