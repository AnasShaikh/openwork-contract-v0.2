# LayerZero V2 Options Determination Guide

## Overview

This guide explains how to determine the correct gas options value for LayerZero V2 cross-chain messages.

## LZ Options Format

```
0x0003 01 0011 01 <32-byte gas value>
│      │   │   │  └─ Gas limit in hex (padded to 32 bytes)
│      │   │   └─ Gas option type
│      │   └─ Option length (17 bytes)
│      └─ Executor worker ID
└─ Options type 3
```

## Step-by-Step Process

### 1. Simulate Destination Gas

Run `cast estimate` on the destination function to get actual gas usage:

```bash
cast estimate <DEST_CONTRACT> "<FUNCTION_SIGNATURE>" <ARGS> \
  --from <BRIDGE_ADDRESS> \
  --rpc-url <DEST_RPC_URL>
```

**Example (postJob on NOWJC):**
```bash
cast estimate 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 \
  "postJob(string,address,string,string[],uint256[])" \
  "40232-1" \
  0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef \
  "QmTestJobDetailHash123" \
  '["Milestone 1","Milestone 2"]' \
  '[1000000,2000000]' \
  --from 0xbCB4401e000bBbc9918030807c164d50d4dF9bc7 \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

Result: **337,261 gas**

### 2. Add Safety Buffer

| Buffer | Multiplier | Use Case |
|--------|------------|----------|
| Conservative | 1.5x | Simple operations |
| Safe | 2x | Complex operations (recommended) |
| Very Safe | 3x | First-time testing |

Example: 337,261 × 2 = **674,522 gas** → round to **700,000**

### 3. Convert to Hex Options

| Gas Limit | Hex Value | Full Options String |
|-----------|-----------|---------------------|
| 200,000 | 0x30D40 | `0x00030100110100000000000000000000000000030D40` |
| 500,000 | 0x7A120 | `0x00030100110100000000000000000000000000007A120` |
| 700,000 | 0xAAE60 | `0x000301001101000000000000000000000000000AAE60` |
| 1,000,000 | 0xF4240 | `0x000301001101000000000000000000000000000F4240` |

### 4. Quote the Fee

Always quote before sending to get the exact fee:

```bash
cast call <LOCAL_BRIDGE> \
  "quoteNativeChain(bytes,bytes)(uint256)" \
  <ENCODED_PAYLOAD> \
  <OPTIONS> \
  --rpc-url <SOURCE_RPC_URL>
```

**Example:**
```bash
cast call 0xF069BE11c655270038f89DECFF4d9155D0910C95 \
  "quoteNativeChain(bytes,bytes)(uint256)" \
  $(cast abi-encode "f(string,string,address,string,string[],uint256[])" \
    "postJob" "40232-test1" "0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef" \
    "QmTestJobDetailHash" '["Milestone 1","Milestone 2"]' '[1000000,2000000]') \
  "0x000301001101000000000000000000000000000AAE60" \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL
```

## Quick Reference

| Function | Estimated Gas | Recommended Options |
|----------|---------------|---------------------|
| createProfile | ~400k | 1M (`0x...0F4240`) |
| postJob | ~337k | 700k (`0x...0AAE60`) |
| Simple calls | <100k | 200k (`0x...030D40`) |

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `SIMULATION_REVERTED` | Insufficient gas | Increase gas in options |
| `OutOfGas` | Options too low | Double the gas value |

---

*Created: January 3, 2026*
