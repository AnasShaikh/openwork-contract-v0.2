#!/bin/bash

# LayerZero CreateProfile Cost Calculation Commands
# Replace with your actual contract addresses and RPC URLs

LOWJC_CONTRACT="0xYOUR_LOWJC_CONTRACT"
BRIDGE_CONTRACT="0xYOUR_BRIDGE_CONTRACT"
RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"

# 1. Deploy cost calculator (one-time)
echo "=== Deploying Cost Calculator ==="
forge create layerzero-cost-calculator.sol:LayerZeroCostCalculator \
  --constructor-args $BRIDGE_CONTRACT \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

CALCULATOR="0xDEPLOYED_CALCULATOR_ADDRESS"

# 2. Get minimal options for cost optimization
echo "=== Getting Minimal Options ==="
MINIMAL_OPTIONS=$(cast call $CALCULATOR \
  "getMinimalOptions(uint128)" \
  100000 \
  --rpc-url $RPC_URL)

echo "Minimal options: $MINIMAL_OPTIONS"

# 3. Quote single createProfile cost
echo "=== Quoting Single CreateProfile ==="
USER_ADDRESS="0xUserAddressHere"
IPFS_HASH="QmExampleHash"
REFERRER_ADDRESS="0x0000000000000000000000000000000000000000"

SINGLE_COST=$(cast call $CALCULATOR \
  "quoteCCreateProfile(address,string,address,bytes)" \
  $USER_ADDRESS \
  "$IPFS_HASH" \
  $REFERRER_ADDRESS \
  $MINIMAL_OPTIONS \
  --rpc-url $RPC_URL)

echo "Single createProfile cost: $SINGLE_COST wei"
echo "Single createProfile cost: $(cast --to-unit $SINGLE_COST ether) ETH"

# 4. Quote batch createProfile (for multiple users)
echo "=== Quoting Batch CreateProfile ==="
# Example for 3 users - adjust arrays as needed
cast call $CALCULATOR \
  "quoteBatchCreateProfile(address[],string[],address[],bytes)" \
  "[$USER_ADDRESS,0xUser2,0xUser3]" \
  "[\"QmHash1\",\"QmHash2\",\"QmHash3\"]" \
  "[0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000]" \
  $MINIMAL_OPTIONS \
  --rpc-url $RPC_URL

# 5. Execute createProfile with exact quoted amount
echo "=== Executing CreateProfile with Quoted Fee ==="
cast send $LOWJC_CONTRACT \
  "createProfile(string,address,bytes)" \
  "$IPFS_HASH" \
  $REFERRER_ADDRESS \
  $MINIMAL_OPTIONS \
  --value $SINGLE_COST \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --gas-estimate-multiplier 110

# 6. Check current LayerZero gas prices across chains
echo "=== Current LayerZero Network Fees ==="
# Ethereum -> Arbitrum (example)
cast call $BRIDGE_CONTRACT \
  "quoteNativeChain(bytes,bytes)" \
  "0x00000000" \
  $MINIMAL_OPTIONS \
  --rpc-url $RPC_URL

echo "=== Gas Cost Optimization Tips ==="
echo "1. Use minimal options (100k gas limit)"
echo "2. Batch multiple profiles when possible"
echo "3. Monitor destination chain gas prices"
echo "4. Use standard gas limit (not excess)"
echo "5. Execute during low network congestion"