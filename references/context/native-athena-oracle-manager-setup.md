# Native Athena Oracle Manager Setup Guide

## Contract Overview

**Main Contract:** `NativeAthenaProductionCCTP` (21,873 bytes)
**Oracle Manager:** `NativeAthenaOracleManager` (7,046 bytes)

## Deployment Sequence

### 1. Deploy Oracle Manager First
```solidity
// Deploy: NativeAthenaOracleManager
// Constructor parameters:
// - No constructor parameters (uses initializer)
```

### 2. Deploy Main Contract
```solidity
// Deploy: NativeAthenaProductionCCTP  
// Constructor parameters:
// - No constructor parameters (uses initializer)
```

## Post-Deployment Setup Functions

### 3. Initialize Oracle Manager
```solidity
// Call on Oracle Manager contract:
function initialize(
    address _owner,           // Owner address
    address _genesis,         // Genesis contract address
    address _nativeAthena     // Main Native Athena contract address
) public initializer
```

### 4. Initialize Main Contract
```solidity
// Call on Main contract:
function initialize(
    address _owner,           // Owner address
    address _daoContract,     // DAO contract address  
    address _genesis,         // Genesis contract address
    address _nowjContract,    // NOWJ contract address
    address _usdcToken        // USDC token address
) public initializer
```

### 5. Connect Oracle Manager to Main Contract
```solidity
// Call on Main contract:
function setOracleManager(address _oracleManager) external onlyOwner
// Parameters: Oracle Manager contract address
```

### 6. Authorize Main Contract in Oracle Manager
```solidity
// Call on Oracle Manager contract:
function setAuthorizedCaller(address _caller, bool _authorized) external onlyOwner
// Parameters: 
// - _caller: Main Native Athena contract address
// - _authorized: true
```

## Function Delegation

The following functions in the main contract now delegate to Oracle Manager:

### Oracle Management Functions (Main → Oracle Manager)
- `addOrUpdateOracle()` → `oracleManager.addOrUpdateOracle()`
- `addSingleOracle()` → `oracleManager.addSingleOracle()`  
- `addMembers()` → `oracleManager.addMembers()`
- `removeMemberFromOracle()` → `oracleManager.removeMemberFromOracle()`
- `removeOracle()` → `oracleManager.removeOracle()`

### Dependencies (Oracle Manager → Main Contract)
- Oracle Manager calls back to main contract for:
  - `nativeAthena.canVote(address)` - Member eligibility validation
  - `nativeAthena.minOracleMembers()` - Minimum member requirements

## Verification Steps

After setup, verify connections:

1. **Check Oracle Manager is set:**
   ```solidity
   // Call on Main contract:
   oracleManager() // Should return Oracle Manager address
   ```

2. **Check authorization:**
   ```solidity
   // Call on Oracle Manager:
   authorizedCallers(MAIN_CONTRACT_ADDRESS) // Should return true
   ```

3. **Test oracle creation:**
   ```solidity
   // Call on Main contract (should delegate successfully):
   addSingleOracle(name, members, description, hash, skillVerified)
   ```

## File Locations
- **Main Contract:** `src/current/athena testers/native-athena-production-cctp-dispute-updated+fee-settle.sol`
- **Oracle Manager:** `src/current/athena testers/NativeAthenaOracleManager.sol`

## Access Control
- **Main Contract:** Uses `onlyOwner` and `onlyDAO` modifiers
- **Oracle Manager:** Uses `onlyAuthorized` modifier (allows owner + authorized callers)