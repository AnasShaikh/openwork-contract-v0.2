# LayerZero Multi-Chain Deployment & Testing Commands

## 1. Deploy Contracts

```bash
# Deploy StringSender on Ethereum Sepolia
forge script script/deploy-bridge-test.s.sol --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --broadcast

# Deploy StringReceiver on Arbitrum Sepolia  
forge script script/deploy-bridge-test.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast

# Deploy StringReceiver on Optimism Sepolia
forge script script/deploy-bridge-test.s.sol --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --broadcast
```

## 2. Update Contract Addresses

Update addresses in `script/set-3-chain-peers.s.sol`:
```solidity
address constant ETH_SENDER = 0xE1Ba069CF6402c763097F3cE72C0AD973403c85B;
address constant ARB_RECEIVER = 0x5Ea4BC548FeDBDD7D5a5cB178f7bc0433FA34935;
address constant OP_RECEIVER = 0x8C47Aa93Ec73f686c94fAff1dC3E8D6e5e22ce52;
```

## 3. Set Peers (Bidirectional)

```bash
# Set peers on Ethereum Sepolia
forge script script/set-3-chain-peers.s.sol --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --broadcast

# Set peers on Arbitrum Sepolia
forge script script/set-3-chain-peers.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast

# Set peers on Optimism Sepolia
forge script script/set-3-chain-peers.s.sol --rpc-url $OPTIMISM_SEPOLIA_RPC_URL --broadcast
```

## 4. Verify Peer Setup

```bash
# Check ETH sender peers
cast call $ETH_SENDER "peers(uint32)" 40231 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
cast call $ETH_SENDER "peers(uint32)" 40232 --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Check ARB receiver peer
cast call $ARB_RECEIVER "peers(uint32)" 40161 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check OP receiver peer
cast call $OP_RECEIVER "peers(uint32)" 40161 --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

## 5. Test Single Chain Sending

```bash
# Send to Arbitrum
cast send $ETH_SENDER 'sendString(uint32,string,bytes)' 40231 'Hello ARB' '0x00030100110100000000000000000000000000030d40' --value 0.1ether --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Send to Optimism
cast send $ETH_SENDER 'sendString(uint32,string,bytes)' 40232 'Hello OP' '0x00030100110100000000000000000000000000030d40' --value 0.1ether --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

## 6. Verify Single Messages

```bash
# Check ARB receiver
cast call $ARB_RECEIVER 'latestMessage()' --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check OP receiver
cast call $OP_RECEIVER 'latestMessage()' --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

## 7. Test Two-Chain Batch Sending

```bash
# Get quote for two chains
cast call $ETH_SENDER 'quoteTwoChains(uint32,uint32,string,bytes,bytes)' 40231 40232 'Batch Hello!' '0x00030100110100000000000000000000000000030d40' '0x00030100110100000000000000000000000000030d40' --rpc-url $ETHEREUM_SEPOLIA_RPC_URL

# Send to both chains simultaneously
cast send $ETH_SENDER 'sendStringToTwoChains(uint32,uint32,string,bytes,bytes)' 40231 40232 'Batch Hello!' '0x00030100110100000000000000000000000000030d40' '0x00030100110100000000000000000000000000030d40' --value 0.0001ether --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

## 8. Test Multi-Chain Array Sending

```bash
# Send to multiple chains using arrays
cast send $ETH_SENDER 'sendStringToMultipleChains(uint32[],string,bytes[])' '[40231,40232]' 'Array Hello!' '[0x00030100110100000000000000000000000000030d40,0x00030100110100000000000000000000000000030d40]' --value 0.0001ether --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
```

## 9. Verify Batch Messages

```bash
# Check both receivers after batch send
cast call $ARB_RECEIVER 'latestMessage()' --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call $OP_RECEIVER 'latestMessage()' --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

## Key Parameters

- **LayerZero Options**: `0x00030100110100000000000000000000000000030d40` (200k gas)
- **Endpoint IDs**: ETH=40161, ARB=40231, OP=40232  
- **Minimum Fee**: ~0.00006-0.0001 ETH for two chains
- **Environment Variables**: PRIVATE_KEY, ETHEREUM_SEPOLIA_RPC_URL, ARBITRUM_SEPOLIA_RPC_URL, OPTIMISM_SEPOLIA_RPC_URL

## Troubleshooting

```bash
# Clean build if needed
forge clean && forge build

# Check balance
cast balance $YOUR_ADDRESS --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --ether
```