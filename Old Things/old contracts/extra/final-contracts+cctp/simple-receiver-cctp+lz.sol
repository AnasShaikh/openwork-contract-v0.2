// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

interface IMessageTransmitterV2 {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool);
}

interface ICCTPHookReceiver {
    function onCCTPReceive(
        bytes32 sender,
        uint256 amount,
        bytes calldata hookData
    ) external returns (bool);
}

contract CCTPLayerZeroReceiver is OAppReceiver, ICCTPHookReceiver {
    
    // ==================== CONTRACTS ====================
    IMessageTransmitterV2 public immutable messageTransmitterV2;
    IERC20 public immutable usdc;
    
    // ==================== TRACKING ====================
    struct ReceivedTransfer {
        uint256 transferId;
        address sender;
        uint256 usdcAmount;
        string message;
        uint256[] numbers;
        uint64 cctpNonce;
        bool usdcReceived;
        bool dataReceived;
        uint256 timestamp;
    }
    
    mapping(uint256 => ReceivedTransfer) public receivedTransfers;
    mapping(uint256 => bool) public completedTransfers;
    uint256 public totalReceived;
    
    // Latest processed data for easy access
    string public latestMessage;
    uint256[] public latestNumbers;
    uint256 public latestSum;
    
    // ==================== EVENTS ====================
    event LayerZeroDataReceived(
        uint256 indexed transferId,
        address indexed sender,
        string message,
        uint256[] numbers
    );
    
    event CCTPUSDCReceived(
        uint256 indexed transferId,
        uint256 amount,
        uint64 cctpNonce
    );
    
    event TransferCompleted(
        uint256 indexed transferId,
        address sender,
        uint256 usdcAmount,
        string message,
        uint256 numbersSum
    );
    
    constructor(
        address _endpoint,
        address _owner,
        address _messageTransmitterV2,
        address _usdc
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        messageTransmitterV2 = IMessageTransmitterV2(_messageTransmitterV2);
        usdc = IERC20(_usdc);
    }
    
    // Override the oAppVersion function
    function oAppVersion() public pure override returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }
    
    // ==================== LAYERZERO RECEIVER ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32,            // _guid (not used)
        bytes calldata _message,
        address,            // _executor (not used)
        bytes calldata      // _extraData (not used)
    ) internal override {
        // Decode LayerZero message
        (string memory functionName, uint256 transferId, address sender, string memory message, uint256[] memory numbers) = 
            abi.decode(_message, (string, uint256, address, string, uint256[]));
        
        if (keccak256(bytes(functionName)) == keccak256("combinedTransfer")) {
            // Store or update transfer data
            ReceivedTransfer storage transfer = receivedTransfers[transferId];
            transfer.transferId = transferId;
            transfer.sender = sender;
            transfer.message = message;
            transfer.numbers = numbers;
            transfer.dataReceived = true;
            transfer.timestamp = block.timestamp;
            
            // Update latest message
            latestMessage = message;
            latestNumbers = numbers;
            
            // Calculate sum
            uint256 sum = 0;
            for (uint i = 0; i < numbers.length; i++) {
                sum += numbers[i];
            }
            latestSum = sum;
            
            emit LayerZeroDataReceived(transferId, sender, message, numbers);
            
            // Check if transfer is now complete
            _checkTransferComplete(transferId);
        }
    }
    
    // ==================== CCTP RECEIVER ====================
    
    /**
     * @dev Receive CCTP V2 message with attestation
     */
    function receiveCCTPMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external {
        // Verify and process the message through CCTP V2
        bool success = messageTransmitterV2.receiveMessage(message, attestation);
        require(success, "CCTP V2 message verification failed");
    }
    
    /**
     * @dev CCTP Hook receiver - called automatically by CCTP V2
     */
    function onCCTPReceive(
        bytes32 sender,
        uint256 amount,
        bytes calldata hookData
    ) external override returns (bool) {
        // Only allow calls from MessageTransmitter
        require(msg.sender == address(messageTransmitterV2), "Unauthorized caller");
        
        // Decode hook data to get transferId
        (uint256 transferId) = abi.decode(hookData, (uint256));
        
        // Store or update transfer data
        ReceivedTransfer storage transfer = receivedTransfers[transferId];
        transfer.transferId = transferId;
        transfer.usdcAmount = amount;
        transfer.usdcReceived = true;
        
        // Generate pseudo-nonce for tracking
        uint64 pseudoNonce = uint64(block.timestamp);
        transfer.cctpNonce = pseudoNonce;
        
        if (transfer.timestamp == 0) {
            transfer.timestamp = block.timestamp;
        }
        
        emit CCTPUSDCReceived(transferId, amount, pseudoNonce);
        
        // Check if transfer is now complete
        _checkTransferComplete(transferId);
        
        return true;
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    function _checkTransferComplete(uint256 transferId) internal {
        ReceivedTransfer storage transfer = receivedTransfers[transferId];
        
        if (transfer.usdcReceived && transfer.dataReceived && !completedTransfers[transferId]) {
            completedTransfers[transferId] = true;
            totalReceived++;
            
            emit TransferCompleted(
                transferId,
                transfer.sender,
                transfer.usdcAmount,
                transfer.message,
                latestSum
            );
        }
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getReceivedTransfer(uint256 transferId) external view returns (ReceivedTransfer memory) {
        return receivedTransfers[transferId];
    }
    
    function isTransferComplete(uint256 transferId) external view returns (bool) {
        return completedTransfers[transferId];
    }
    
    function getLatestNumbers() external view returns (uint256[] memory) {
        return latestNumbers;
    }
    
    function getLatestData() external view returns (
        string memory message,
        uint256[] memory numbers,
        uint256 sum
    ) {
        return (latestMessage, latestNumbers, latestSum);
    }
    
    function getUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    function getStats() external view returns (
        uint256 totalCompleted,
        string memory latest,
        uint256 usdcBalance
    ) {
        return (
            totalReceived,
            latestMessage,
            usdc.balanceOf(address(this))
        );
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function withdraw() external onlyOwner {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }
        
        uint256 usdcBalance = usdc.balanceOf(address(this));
        if (usdcBalance > 0) {
            usdc.transfer(owner(), usdcBalance);
        }
    }
    
    receive() external payable {}
}