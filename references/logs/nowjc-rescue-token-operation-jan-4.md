# NOWJC Rescue Token Operation Log

**Date:** January 4, 2026
**Network:** Arbitrum Sepolia
**Purpose:** Drain leftover USDC from NOWJC contract to zero balance

---

## Key Addresses

| Contract | Address |
|----------|---------|
| NOWJC Proxy | `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513` |
| Original Implementation | `0xD9B0Ddd08aDde13ea582e3a4f367B0D7307093f3` |
| Rescue Implementation | `0x78461113AfC5cC3aBfe9128a14E1e5c75468Eb7F` |
| USDC (Arb Sepolia) | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| WALL2 (Operator) | `0xfD08836eeE6242092a9c869237a8d122275b024A` |

---

## Rescue Contract Location

```
src/suites/openwork-full-contract-suite-1-Jan-version/nowjc-rescue-temp.sol
```

**Key Function Added (line 292-299):**
```solidity
function rescueTokens(address _token, address _to, uint256 _amount) external onlyOwner {
    require(_to != address(0), "Invalid recipient");
    IERC20 token = IERC20(_token);
    uint256 balance = token.balanceOf(address(this));
    uint256 amountToRescue = _amount == 0 ? balance : _amount;
    require(amountToRescue <= balance, "Insufficient balance");
    token.safeTransfer(_to, amountToRescue);
}
```

---

## Operation Steps

### 1. Check Current Balance
```bash
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "balanceOf(address)(uint256)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### 2. Deploy Rescue Implementation
```bash
source .env && forge create --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY --broadcast src/suites/openwork-full-contract-suite-1-Jan-version/nowjc-rescue-temp.sol:NativeOpenWorkJobContract
```

### 3. Upgrade Proxy to Rescue Implementation
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "upgradeToAndCall(address,bytes)" <RESCUE_IMPL_ADDRESS> 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 4. Rescue All Tokens (amount=0 for entire balance)
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "rescueTokens(address,address,uint256)" 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d 0xfD08836eeE6242092a9c869237a8d122275b024A 0 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 5. Revert to Original Implementation
```bash
source .env && cast send 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 "upgradeToAndCall(address,bytes)" 0xD9B0Ddd08aDde13ea582e3a4f367B0D7307093f3 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

### 6. Verify Balance is Zero
```bash
source .env && cast call 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d "balanceOf(address)(uint256)" 0x68093a84D63FB508bdc6A099CCc1292CE33Bb513 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

---

## Transaction Hashes (Jan 4, 2026 Execution)

| Step | TX Hash |
|------|---------|
| Deploy Rescue Impl | `0xd104165edbc5b534dc27199a2bad4a4bb7c387d35fd99f07171e650d2d2ad257` |
| Upgrade to Rescue | `0x9d2df572878ea34ea29ded095a9f3169f072f2e8413b0b22c2889044fedd15d8` |
| Rescue USDC | `0x8bc68ab6baad0a5777e25d6ddb13f94c40095d1f83787ad2d0cb4d71251f6814` |
| Revert to Original | `0x16f90aa0e4e95fc21e5d240eae69c53682faf02d6c69a1fc66a64ba65883da4a` |

---

## Results

| Metric | Value |
|--------|-------|
| USDC Rescued | 1,009,900 (≈1.01 USDC) |
| Final NOWJC Balance | 0 |
| Recipient | WALL2 (`0xfD08836...`) |

---

## Quick Reference Commands

**Full rescue in one go (copy-paste ready):**
```bash
# Set variables
NOWJC_PROXY=0x68093a84D63FB508bdc6A099CCc1292CE33Bb513
ORIGINAL_IMPL=0xD9B0Ddd08aDde13ea582e3a4f367B0D7307093f3
USDC=0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
RECIPIENT=0xfD08836eeE6242092a9c869237a8d122275b024A

# 1. Deploy rescue implementation
source .env && forge create --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY --broadcast src/suites/openwork-full-contract-suite-1-Jan-version/nowjc-rescue-temp.sol:NativeOpenWorkJobContract

# 2. Copy the deployed address and use in next command
# RESCUE_IMPL=<paste deployed address>

# 3. Upgrade, rescue, revert
source .env && cast send $NOWJC_PROXY "upgradeToAndCall(address,bytes)" $RESCUE_IMPL 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

source .env && cast send $NOWJC_PROXY "rescueTokens(address,address,uint256)" $USDC $RECIPIENT 0 --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY

source .env && cast send $NOWJC_PROXY "upgradeToAndCall(address,bytes)" $ORIGINAL_IMPL 0x --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $WALL2_KEY
```

---

## Notes

- The rescue function uses `onlyOwner` modifier - only proxy owner can call
- Pass `_amount = 0` to rescue entire token balance
- Always revert to original implementation after rescue to maintain production state
- This same pattern can be used for LOWJC or any other upgradeable contract
