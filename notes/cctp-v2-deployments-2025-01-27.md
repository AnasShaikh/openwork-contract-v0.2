# CCTP V2 Fast Transfer Deployments - January 27, 2025

## 🎯 Today's Accomplishments

Successfully deployed CCTP V2 Fast Transfer contracts on both testnet and mainnet, plus completed end-to-end testing.

## 📋 Contract Deployments

### Testnet Deployments (Sepolia)

#### Arbitrum Sepolia
- **Contract**: `0x1EAa3fFe6aD9704DA48043e342927Eb1F4f815c2`
- **TX Hash**: `0x053f3d59398c6725580f503fb7c9732eed72fc7e64c15eb89c743b066b59468f`
- **USDC**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`

#### OP Sepolia  
- **Contract**: `0xAFE9E0E4e72Bb233f98FC4b094F580e7de279749`
- **TX Hash**: `0x8c8328159d9b08e8aa99ba756c740149659a1c9107336799f5ab0156c8ab2059`
- **USDC**: `0x5fd84259d66Cd46123540766Be93DFE6D43130D7`

### Mainnet Deployments

#### OP Mainnet
- **Contract**: `0x3C9D9A5F571F040ed7863A0C727f34d5Ee3Ce7f6`
- **TX Hash**: `0xe672295991514780546a490f12774532b79a46595c61a373b78e04df4312e2af`
- **USDC**: `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85`

#### Arbitrum Mainnet
- **Contract**: `0xA4Ec15F2dFDF999912Ff2843fB5A2e6FDc5b7B8F`
- **TX Hash**: `0xf508fd598dd7f991227953aba193ecb597ac5f500a672a02dce7acf56ef6170f`
- **USDC**: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`

## 🧪 Testing Results

### Successful Fast Transfer Test (Testnet)
- **Route**: OP Sepolia → Arbitrum Sepolia
- **Amount Sent**: 250,000 wei USDC (0.25 USDC)
- **Amount Received**: 249,975 wei USDC (0.249975 USDC)
- **Fee Charged**: 25 wei USDC (0.000025 USDC)
- **Transfer Time**: ~60 seconds end-to-end
- **Burn TX**: `0x0ccdcc51aca3bf816d5b5b3323dbec6f9baf578f166af840aa9073726fdaa8e1`
- **Mint TX**: `0x12be46c4308abffc1c9509c274e932d46965f024dd8f126b23ed8d132a8d0590`

### Key Debugging Insights
- **Issue 1**: Wrong API endpoint format initially
- **Issue 2**: Insufficient fee (maxFee: 0) caused "delayReason: insufficient_fee"
- **Solution**: Use proper API format `/v2/messages/DOMAIN?transactionHash=TX` and set maxFee > 0

## 📚 Documentation Created

1. **Tutorial**: `notes/cctp-v2-fast-transfer-tutorial.md` - Complete step-by-step guide
2. **Today's Deployments**: This file

## 🔧 Constructor Parameters Used

### Testnet (Sepolia)
- **TokenMessenger**: `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`
- **MessageTransmitter**: `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`

### Mainnet
- **TokenMessenger**: `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`
- **MessageTransmitter**: `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`

## 💰 Current Balances
- **Arbitrum Sepolia USDC**: 249,975 wei (from successful test)
- **Arbitrum Mainnet USDC**: 2,892,594 wei (available for mainnet testing)
- **OP Sepolia USDC**: ~250,000 wei remaining
- **OP Mainnet USDC**: 0

## ✅ Status

**All deployments complete and ready for use!**

- ✅ Testnet contracts deployed and tested successfully  
- ✅ Mainnet contracts deployed and ready
- ✅ Fast transfer flow verified end-to-end
- ✅ API integration working correctly
- ✅ Fee mechanism understood and documented
- ✅ Comprehensive tutorial created

**Next**: Ready for production mainnet testing with small amounts.