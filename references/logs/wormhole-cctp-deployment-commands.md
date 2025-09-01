# Wormhole+CCTP Deployment Commands

## Contract: MinimalWormholeCCTP

### Deployment Commands

**Arbitrum Sepolia:**
```bash
source .env && forge create --broadcast --rpc-url https://sepolia-rollup.arbitrum.io/rpc --private-key $WALL2_KEY src/current/mainnet-test/minimal-wormhole-cctp.sol:MinimalWormholeCCTP --constructor-args 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470 0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
```

**Optimism Sepolia:**
```bash
source .env && forge create --broadcast --rpc-url https://sepolia.optimism.io --private-key $WALL2_KEY src/current/mainnet-test/minimal-wormhole-cctp.sol:MinimalWormholeCCTP --constructor-args 0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE 0x31377888146f3253211EFEf5c676D41ECe7D58Fe 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA 0x5fd84259d66Cd46123540766Be93DFE6D43130D7
```

### Constructor Parameters Order:
1. wormholeRelayer
2. wormhole  
3. circleMessageTransmitter
4. circleTokenMessenger
5. usdc

### Deployed Addresses:
- **Arbitrum Sepolia:** 0x09c719cCb85B099E60E54eAF3206e261886eE686
- **Optimism Sepolia:** 0x2A5af1db6130D3B94eC3eFc65C5398f1734a9f72
- **Deployer:** 0xfD08836eeE6242092a9c869237a8d122275b024A

### Key Notes:
- Must run `source .env` to load private keys
- Contract inherits from CCTPSender (not CCTPBase directly)
- Imports: CCTPSender, CCTPBase, IERC20 from wormhole-solidity-sdk
- Demonstrates ONE atomic transaction for USDC + message transfer