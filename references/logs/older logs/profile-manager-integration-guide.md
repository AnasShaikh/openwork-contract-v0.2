# ProfileManager Integration Guide

**Date**: October 18, 2025  
**Purpose**: Integration guide for ProfileManager contract  
**Contract**: `profile-manager.sol`

---

## Overview

ProfileManager is a UUPS upgradeable contract that handles:
- User profile creation (cross-chain via bridge)
- Portfolio management
- User rating system after job completion

**Key Feature**: Operates independently from NOWJC, both reading/writing to Genesis storage.

---

## Architecture

```
         ┌─────────────┐
         │   Bridge    │
         └──────┬──────┘
                │
        ┌───────┴────────┐
        ▼                ▼
  ┌─────────┐      ┌──────────────┐
  │  NOWJC  │      │ProfileManager│
  └────┬────┘      └──────┬───────┘
       │                  │
       └─────────┬────────┘
                 ▼
         ┌──────────────┐
         │   Genesis    │
         │  (Storage)   │
         └──────────────┘
```

---

## Deployment Steps

### 1. Deploy Implementation

```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /profile-manager.sol:ProfileManager"
```

**Save the deployed address** (e.g., `0xNEW_IMPLEMENTATION`)

### 2. Deploy Proxy

Use the same UUPS proxy pattern as NOWJC:

```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy" \
  --constructor-args 0xNEW_IMPLEMENTATION $(cast abi-encode "initialize(address,address,address)" $WALL2_ADDRESS $BRIDGE_ADDRESS $GENESIS_ADDRESS)
```

**Save the proxy address** (e.g., `0xPROFILE_MANAGER_PROXY`)

### 3. Configure Genesis Permissions

Grant ProfileManager write access to Genesis:

```bash
source .env && cast send $GENESIS_ADDRESS \
  "addAuthorizedContract(address)" \
  0xPROFILE_MANAGER_PROXY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Bridge Integration

### Required Changes to Native Bridge

Add ProfileManager to the bridge's message routing:

```solidity
// Add to contract state
address public profileManager;

// Add setter function
function setProfileManager(address _profileManager) external onlyOwner {
    profileManager = _profileManager;
}

// Update _lzReceive routing
else if (keccak256(bytes(functionName)) == keccak256(bytes("createProfile"))) {
    require(profileManager != address(0), "ProfileManager not set");
    (, address user, string memory ipfsHash, address referrer) = abi.decode(
        _message, 
        (string, address, string, address)
    );
    IProfileManager(profileManager).createProfile(user, ipfsHash, referrer);
}
else if (keccak256(bytes(functionName)) == keccak256(bytes("addPortfolio"))) {
    require(profileManager != address(0), "ProfileManager not set");
    (, address user, string memory portfolioHash) = abi.decode(
        _message,
        (string, address, string)
    );
    IProfileManager(profileManager).addPortfolio(user, portfolioHash);
}
else if (keccak256(bytes(functionName)) == keccak256(bytes("rate"))) {
    require(profileManager != address(0), "ProfileManager not set");
    (, address rater, string memory jobId, address userToRate, uint256 rating) = abi.decode(
        _message,
        (string, address, string, address, uint256)
    );
    IProfileManager(profileManager).rate(rater, jobId, userToRate, rating);
}
```

### Add ProfileManager Interface to Bridge

```solidity
interface IProfileManager {
    function createProfile(address user, string memory ipfsHash, address referrer) external;
    function addPortfolio(address user, string memory portfolioHash) external;
    function rate(address rater, string memory jobId, address userToRate, uint256 rating) external;
}
```

### Configure Bridge with ProfileManager Address

```bash
source .env && cast send $BRIDGE_ADDRESS \
  "setProfileManager(address)" \
  0xPROFILE_MANAGER_PROXY \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Usage Examples

### Create Profile (from LOWJC on OP Sepolia)

Existing LOWJC code works unchanged:

```bash
source .env && cast send $LOWJC_ADDRESS \
  "createProfile(string,address,bytes)" \
  "QmProfileIPFSHash" \
  $REFERRER_ADDRESS \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

**Flow:**
1. LOWJC → Bridge (LayerZero message)
2. Bridge → ProfileManager.createProfile()
3. ProfileManager → Genesis.setProfile()

### Add Portfolio (from LOWJC)

```bash
source .env && cast send $LOWJC_ADDRESS \
  "addPortfolio(string,bytes)" \
  "QmPortfolioItemHash" \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

### Rate User (from LOWJC)

```bash
source .env && cast send $LOWJC_ADDRESS \
  "rate(string,address,uint256,bytes)" \
  "40232-203" \
  $USER_TO_RATE \
  5 \
  0x0003010011010000000000000000000000000007a120 \
  --value 0.001ether \
  --rpc-url $OPTIMISM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## View Functions

### Get Profile

```bash
cast call $PROFILE_MANAGER_PROXY \
  "getProfile(address)" \
  $USER_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Get User Rating

```bash
cast call $PROFILE_MANAGER_PROXY \
  "getUserRating(address)" \
  $USER_ADDRESS \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### Get Profile Count

```bash
cast call $PROFILE_MANAGER_PROXY \
  "getProfileCount()" \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Upgrade Process

### Deploy New Implementation

```bash
source .env && forge create --broadcast \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY \
  "src/suites/openwork-full-contract-suite-layerzero+CCTP 5 Oct /profile-manager.sol:ProfileManager"
```

### Upgrade Proxy

```bash
source .env && cast send $PROFILE_MANAGER_PROXY \
  "upgradeToAndCall(address,bytes)" \
  0xNEW_IMPLEMENTATION \
  0x \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $WALL2_KEY
```

---

## Contract Addresses (To Be Filled After Deployment)

**Arbitrum Sepolia:**
- Implementation: `TBD`
- Proxy: `TBD`

**Dependencies:**
- Genesis: `[Existing Genesis Address]`
- Bridge: `[Existing Bridge Address]`

---

## Important Notes

1. **No NOWJC Changes Required**: NOWJC continues to work as-is
2. **Bridge Routing Required**: Bridge must route profile/rating messages to ProfileManager
3. **Genesis Permissions**: ProfileManager needs write access to Genesis
4. **Rating Authorization**: Only job givers can rate takers and vice versa
5. **Profile Uniqueness**: One profile per address enforced

---

## Testing Checklist

- [ ] Deploy ProfileManager implementation
- [ ] Deploy ProfileManager proxy
- [ ] Grant Genesis permissions to ProfileManager
- [ ] Update bridge routing
- [ ] Test profile creation from LOWJC
- [ ] Test portfolio addition
- [ ] Test rating system with valid job
- [ ] Verify all view functions
- [ ] Test upgrade process

---

**Status**: ✅ Contract created and ready for deployment  
**Next Steps**: Deploy to testnet and update bridge routing
