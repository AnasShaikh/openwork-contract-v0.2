# CCTP V2 Fast Transfer Mainnet Deployment

## Deployed Contracts

### ARB → OP Fast Transfer
- **V2 Sender (ARB)**: `0x8109b099fBdc5C0708B4bc2870C8182dAA27cE1F`
- **V2 Receiver (OP)**: `0xbde733D64D8C2bcA369433E7dC96DC3ecFE414e4`
- **Deployment Date**: August 27, 2025

## Key Features
- **Fast Transfer**: Soft finality (1000 blocks) vs Hard finality (2000 blocks)
- **Hook Data**: Automatic processing of message data via `onCCTPReceive`
- **Message Support**: Text messages + number arrays
- **Gas Optimized**: Direct hook processing without manual correlation

## Contract Interfaces
```solidity
// Sender: depositForBurnWithHook()
function sendFastTransferToDefault(
    uint32 destinationDomain,
    uint256 amount,
    string calldata message,
    uint256[] calldata numbers,
    bool useFastTransfer
) external returns (uint64)

// Receiver: ICCTPHookReceiver
function onCCTPReceive(
    bytes32 sender,
    uint256 amount,
    bytes calldata hookData
) external returns (bool)
```

## Source Files
- Sender: `src/current/cctp/cctp-v2-fast-transfer-sender.sol`
- Receiver: `src/current/cctp/cctp-v2-fast-transfer-receiver.sol`