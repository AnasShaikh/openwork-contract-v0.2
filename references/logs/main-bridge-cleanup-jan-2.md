# MainBridge Contract Cleanup - January 2, 2026

## Summary

Removed unused `athenaClientChainEid` and `lowjcChainEid` variables and related functions from MainBridge contract before deployment on ETH Sepolia.

## Rationale

Analysis showed that neither MainDAO nor MainRewardsContract use these chain endpoints:
- Both contracts only call `bridge.sendToNativeChain()` and `bridge.quoteNativeChain()`
- `sendToSpecificChain(uint32 _dstEid, ...)` provides flexibility to send to any chain when needed

## Changes Made

### Removed Storage Variables
- `uint32 public athenaClientChainEid`
- `uint32 public lowjcChainEid`

### Removed Functions
| Function | Purpose |
|----------|---------|
| `sendToAthenaClientChain()` | Never called by any contract |
| `sendToLowjcChain()` | Never called by any contract |
| `quoteAthenaClientChain()` | Never called by any contract |
| `quoteLowjcChain()` | Never called by any contract |
| `updateAthenaClientChainEid()` | Setter for removed variable |
| `updateLowjcChainEid()` | Setter for removed variable |
| `updateChainEndpoints()` | Multi-param setter (removed) |

### Constructor Change
```solidity
// Before (5 params)
constructor(
    address _endpoint,
    address _owner,
    uint32 _nativeChainEid,
    uint32 _athenaClientChainEid,
    uint32 _lowjcChainEid
)

// After (3 params)
constructor(
    address _endpoint,
    address _owner,
    uint32 _nativeChainEid
)
```

### Additional Fix
- Updated deprecated `transfer()` to modern `call{value:}` pattern in `withdraw()` function

## Retained Functionality

| Function | Status | Notes |
|----------|--------|-------|
| `sendToNativeChain()` | Kept | Used by MainDAO & MainRewardsContract |
| `quoteNativeChain()` | Kept | Used by MainDAO & MainRewardsContract |
| `sendToSpecificChain()` | Kept | Flexible fallback for any chain |
| `quoteSpecificChain()` | Kept | Quote for any chain |
| `sendUpgradeCommand()` | Kept | Takes explicit chain ID |
| `sendToTwoChains()` | Kept | Takes explicit EIDs |
| `sendToThreeChains()` | Kept | Takes explicit EIDs |
| `updateNativeChainEid()` | Kept | Single setter |

## Benefits
- Reduced deployment gas cost (fewer storage slots)
- Simpler constructor (3 params vs 5)
- No dead code
- Future flexibility preserved via `sendToSpecificChain()`

## Verification
```bash
forge build --contracts src/suites/openwork-full-contract-suite-1-Jan-version/main-chain-bridge.sol
# Result: Compiler run successful!
```

## File Modified
- `src/suites/openwork-full-contract-suite-1-Jan-version/main-chain-bridge.sol`

---
*Logged: January 2, 2026*
