# Successful startDirectContract Call - October 18, 2025

## Overview
Successfully executed `startDirectContract` function on OP Sepolia LOWJC contract to create direct job contracts with both 2 and 3 milestones.

## Working Commands

### 2 Milestones (Original)
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startDirectContract(address,string,string[],uint256[],uint32,bytes)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  "QmTestDirectContract123" \
  "[\"milestone1\",\"milestone2\"]" \
  "[500000,500000]" \
  2 \
  0x000301001101000000000000000000000000000F4240 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### 3 Milestones (Higher Options)
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startDirectContract(address,string,string[],uint256[],uint32,bytes)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  "QmTestDirectContract123" \
  "[\"milestone1\",\"milestone2\",\"milestone3\"]" \
  "[400000,400000,400000]" \
  2 \
  0x00030100110100000000000000000000000000186A00 \
  --value 0.002ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```
- **Transaction Hash**: `0x95ba81700a8989a8182510d57b9278649e6b2e818ab529650ef1fe61f8a12de4`
- **Job ID**: `40232-227`
- **Gas Used**: 1,217,741

### 4 Milestones (0.001 ETH)
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startDirectContract(address,string,string[],uint256[],uint32,bytes)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  "QmTestDirectContract123" \
  "[\"milestone1\",\"milestone2\",\"milestone3\",\"milestone4\"]" \
  "[300000,300000,300000,300000]" \
  2 \
  0x00030100110100000000000000000000000000186A00 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```
- **Transaction Hash**: `0xb4913c09f84219ec62e27de6142b5ff221a40250bc9f8a30e2349b3bc3fa128b`
- **Job ID**: `40232-228`
- **Gas Used**: 1,359,945

### 5 Milestones (0.001 ETH)
```bash
source .env && cast send 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C \
  "startDirectContract(address,string,string[],uint256[],uint32,bytes)" \
  0xfD08836eeE6242092a9c869237a8d122275b024A \
  "QmTestDirectContract123" \
  "[\"milestone1\",\"milestone2\",\"milestone3\",\"milestone4\",\"milestone5\"]" \
  "[240000,240000,240000,240000,240000]" \
  2 \
  0x00030100110100000000000000000000000000186A00 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```
- **Transaction Hash**: `0x2513670e83c6cfc00a4236c2ccb5c97588106a5debe8fdf2f94a03aa2eca3455`
- **Job ID**: `40232-229`
- **Gas Used**: 1,502,153

## Transaction Results

### 2 Milestones Result
- **Transaction Hash**: `0xb759aec4814a794cf70ab5df8c027454203af33e50a9993af29fbca02b7f8c2a`
- **Block Number**: 34,504,290
- **Status**: ✅ SUCCESS
- **Gas Used**: 1,075,565
- **Network**: OP Sepolia
- **Job ID Created**: `40232-225`

### 3 Milestones Result
- **Transaction Hash**: `0x95ba81700a8989a8182510d57b9278649e6b2e818ab529650ef1fe61f8a12de4`
- **Block Number**: 34,504,548
- **Status**: ✅ SUCCESS
- **Gas Used**: 1,217,741
- **Network**: OP Sepolia
- **Job ID Created**: `40232-227`

### 4 Milestones Result
- **Transaction Hash**: `0xb4913c09f84219ec62e27de6142b5ff221a40250bc9f8a30e2349b3bc3fa128b`
- **Block Number**: 34,504,718
- **Status**: ✅ SUCCESS
- **Gas Used**: 1,359,945
- **Network**: OP Sepolia
- **Job ID Created**: `40232-228`

### 5 Milestones Result
- **Transaction Hash**: `0x2513670e83c6cfc00a4236c2ccb5c97588106a5debe8fdf2f94a03aa2eca3455`
- **Block Number**: 34,504,807
- **Status**: ✅ SUCCESS
- **Gas Used**: 1,502,153
- **Network**: OP Sepolia
- **Job ID Created**: `40232-229`

## Parameter Breakdown

### Contract Address
- **Value**: `0x896a3Bc6ED01f549Fe20bD1F25067951913b793C`
- **Description**: LOWJC (Local OpenWork Job Contract) Proxy on OP Sepolia
- **Source**: `references/deployments/openwork-contracts-current-addresses.md`

### Function Parameters

1. **Job Taker Address** (address)
   - **Value**: `0xfD08836eeE6242092a9c869237a8d122275b024A`
   - **Description**: Wallet address of job taker (WALL2)
   - **Purpose**: Immediately assigns job to this address without application process

2. **Job Detail Hash** (string)
   - **Value**: `"QmTestDirectContract123"`
   - **Description**: IPFS hash or identifier for job description
   - **Note**: Placeholder value; use actual IPFS hash in production

3. **Milestone Descriptions** (string[])
   - **2 Milestones**: `["milestone1","milestone2"]`
   - **3 Milestones**: `["milestone1","milestone2","milestone3"]`
   - **Description**: Array of description strings for each milestone
   - **Note**: Should be IPFS hashes or detailed descriptions in production
   - **Must Match**: Number of milestone amounts

4. **Milestone Amounts** (uint256[])
   - **2 Milestones**: `[500000,500000]` = 1.0 USDC total
   - **3 Milestones**: `[400000,400000,400000]` = 1.2 USDC total
   - **Description**: Payment amounts in USDC (6 decimals)
   - **Note**: First milestone is immediately locked and sent via CCTP

5. **Job Taker Chain Domain** (uint32)
   - **Value**: `2`
   - **Description**: CCTP domain ID for OP Sepolia
   - **Options**:
     - `2` = OP Sepolia
     - `3` = Arbitrum Sepolia
     - `10` = Ethereum Sepolia

6. **LayerZero Options** (bytes)
   - **Value**: `0x000301001101000000000000000000000000000F4240`
   - **Description**: Encoded options for LayerZero message delivery
   - **Breakdown**:
     - `0003`: Options type 3
     - `0100`: Message type
     - `1101`: Additional flags
     - `000000000000000000000000000F4240`: Gas limit (1,000,000 in hex)

### Transaction Flags

- **--value**: `0.001ether`
  - ETH sent to pay for LayerZero cross-chain message fees
  
- **--rpc-url**: `$OPTIMISM_SEPOLIA_RPC_URL`
  - RPC endpoint from environment variable
  
- **--private-key**: `$WALL2_KEY`
  - Private key from environment variable

## What Happened

1. **Job Created**: Job ID `40232-225` on OP Sepolia
2. **USDC Transferred**: 500,000 USDC (first milestone) sent via CCTP to Arbitrum Sepolia
3. **LayerZero Message Sent**: Cross-chain message to Native Bridge on Arbitrum Sepolia
4. **Job Status**: Automatically set to `InProgress`
5. **Job Taker Assigned**: `0xfD08836eeE6242092a9c869237a8d122275b024A`

## Key Events Emitted

- `FundsSent`: USDC sent via CCTP
- `JobPosted`: Job created with details
- `JobApplication`: Auto-application created
- `JobStarted`: Job immediately started
- `JobStatusChanged`: Status set to InProgress
- `MilestoneLocked`: First milestone locked

## Verification Links

- **LayerZero Scan**: https://testnet.layerzeroscan.com/tx/0xb759aec4814a794cf70ab5df8c027454203af33e50a9993af29fbca02b7f8c2a
- **OP Sepolia Explorer**: https://sepolia-optimism.etherscan.io/tx/0xb759aec4814a794cf70ab5df8c027454203af33e50a9993af29fbca02b7f8c2a

## Important Notes

### Why This Command Works

1. **No --gas-limit flag**: Let the RPC estimate gas automatically
2. **Proper array formatting**: Escaped quotes in bash `[\"item1\",\"item2\"]`
3. **Matching arrays**: Same number of descriptions and amounts
4. **USDC approval**: Contract has approval to spend USDC
5. **USDC balance**: Wallet has sufficient USDC (500,000 for first milestone)
6. **ETH for gas**: 0.001 ETH covers LayerZero message fees

### Contract Flow

```
OP Sepolia (LOWJC)
    ↓
    ├─→ Lock first milestone (500,000 USDC)
    ├─→ Send USDC via CCTP to Arbitrum Sepolia
    └─→ Send LayerZero message to Native Bridge
            ↓
        Arbitrum Sepolia (Native Bridge)
            ↓
        Process on native chain (NOWJC)
```

## Related Files

- Contract: `src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /lowjc-fixed-milestone-inc-direct-job.sol`
- Deployments: `references/deployments/openwork-contracts-current-addresses.md`

## Created By

- **Date**: October 18, 2025, 11:42 PM IST
- **Deployer**: WALL2 (`0xfD08836eeE6242092a9c869237a8d122275b024A`)
- **Network**: OP Sepolia Testnet
