// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

/**
 * @title CCTPv2FastTransferReceiver
 * @dev Receive CCTP V2 Fast Transfer messages with hook data
 * Processes message data automatically during CCTP reception
 */
contract CCTPv2FastTransferReceiver is Ownable, ReentrancyGuard, ICCTPHookReceiver {
    using SafeERC20 for IERC20;
    
    // ==================== CCTP V2 CONTRACTS ====================
    IMessageTransmitterV2 public immutable messageTransmitterV2;
    IERC20 public immutable usdc;
    
    // ==================== MESSAGE TRACKING ====================
    struct FastTransferMessage {
        uint64 nonce;
        address sender;
        string textMessage;
        uint256[] numbers;
        uint256 amount;
        uint256 receivedAt;
        bool isProcessed;
        bool isFastTransfer;
    }
    
    // ==================== STATE VARIABLES ====================
    FastTransferMessage[] public receivedMessages;
    mapping(uint64 => uint256) public nonceToIndex;
    mapping(address => uint256[]) public senderMessages;
    
    uint256 public totalMessagesReceived;
    uint256 public totalUSDCReceived;
    uint256 public fastTransfersReceived;
    uint256 public standardTransfersReceived;
    
    // Latest processed message for quick access
    string public latestMessage;
    uint256[] public latestNumbers;
    uint256 public latestSum;
    
    // ==================== EVENTS ====================
    event FastTransferReceived(
        uint64 indexed nonce,
        address indexed sender,
        uint256 amount,
        string textMessage,
        uint256[] numbers,
        bool isFastTransfer
    );
    
    event MessageAutoProcessed(
        uint64 indexed nonce,
        address indexed sender,
        string textMessage,
        uint256 numbersSum
    );
    
    event HookDataReceived(
        bytes32 indexed sender,
        uint256 amount,
        bytes hookData
    );
    
    constructor(
        address _messageTransmitterV2,
        address _usdc
    ) Ownable(msg.sender) {
        messageTransmitterV2 = IMessageTransmitterV2(_messageTransmitterV2);
        usdc = IERC20(_usdc);
    }
    
    // ==================== CCTP V2 FAST TRANSFER RECEPTION ====================
    
    /**
     * @dev Receive CCTP V2 message with attestation
     */
    function receiveFastTransfer(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant {
        // Verify and process the message through CCTP V2
        bool success = messageTransmitterV2.receiveMessage(message, attestation);
        require(success, "CCTP V2 message verification failed");
        
        // Parse the CCTP message to extract information
        uint64 nonce = _extractNonceFromMessage(message);
        address sender = _extractSenderFromMessage(message);
        uint256 amount = _extractAmountFromMessage(message);
        bytes memory hookData = _extractHookDataFromMessage(message);
        
        // Process hook data to extract our message
        _processHookData(nonce, sender, amount, hookData);
    }
    
    /**
     * @dev CCTP Hook receiver interface - called automatically by CCTP V2
     */
    function onCCTPReceive(
        bytes32 sender,
        uint256 amount,
        bytes calldata hookData
    ) external override returns (bool) {
        // Only allow calls from MessageTransmitter
        require(msg.sender == address(messageTransmitterV2), "Unauthorized caller");
        
        emit HookDataReceived(sender, amount, hookData);
        
        // Process the hook data
        address senderAddress = address(uint160(uint256(sender)));
        _processHookDataDirect(senderAddress, amount, hookData);
        
        return true;
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    /**
     * @dev Process hook data containing message information
     */
    function _processHookData(
        uint64 nonce,
        address sender,
        uint256 amount,
        bytes memory hookData
    ) internal {
        // Decode hook data (message, numbers)
        (string memory textMessage, uint256[] memory numbers) = abi.decode(hookData, (string, uint256[]));
        
        // Determine if this was a fast transfer (simplified heuristic)
        bool isFastTransfer = block.timestamp - _getMessageTimestamp(nonce) < 60; // Less than 1 minute = likely fast
        
        // Store the message
        uint256 messageIndex = receivedMessages.length;
        receivedMessages.push(FastTransferMessage({
            nonce: nonce,
            sender: sender,
            textMessage: textMessage,
            numbers: numbers,
            amount: amount,
            receivedAt: block.timestamp,
            isProcessed: true, // Auto-processed
            isFastTransfer: isFastTransfer
        }));
        
        // Update mappings
        nonceToIndex[nonce] = messageIndex;
        senderMessages[sender].push(messageIndex);
        
        // Update counters
        totalMessagesReceived++;
        totalUSDCReceived += amount;
        if (isFastTransfer) {
            fastTransfersReceived++;
        } else {
            standardTransfersReceived++;
        }
        
        // Process and store latest message
        _updateLatestMessage(textMessage, numbers);
        
        emit FastTransferReceived(nonce, sender, amount, textMessage, numbers, isFastTransfer);
        emit MessageAutoProcessed(nonce, sender, textMessage, latestSum);
    }
    
    /**
     * @dev Process hook data directly (from onCCTPReceive)
     */
    function _processHookDataDirect(
        address sender,
        uint256 amount,
        bytes calldata hookData
    ) internal {
        // Decode hook data
        (string memory textMessage, uint256[] memory numbers) = abi.decode(hookData, (string, uint256[]));
        
        // Store as fast transfer (since it came through hook)
        uint64 pseudoNonce = uint64(block.timestamp); // Use timestamp as pseudo-nonce
        uint256 messageIndex = receivedMessages.length;
        
        receivedMessages.push(FastTransferMessage({
            nonce: pseudoNonce,
            sender: sender,
            textMessage: textMessage,
            numbers: numbers,
            amount: amount,
            receivedAt: block.timestamp,
            isProcessed: true,
            isFastTransfer: true
        }));
        
        // Update mappings and counters
        nonceToIndex[pseudoNonce] = messageIndex;
        senderMessages[sender].push(messageIndex);
        totalMessagesReceived++;
        totalUSDCReceived += amount;
        fastTransfersReceived++;
        
        // Process message
        _updateLatestMessage(textMessage, numbers);
    }
    
    /**
     * @dev Update latest message and calculate sum
     */
    function _updateLatestMessage(string memory textMessage, uint256[] memory numbers) internal {
        latestMessage = textMessage;
        latestNumbers = numbers;
        
        // Calculate sum
        uint256 sum = 0;
        for (uint i = 0; i < numbers.length; i++) {
            sum += numbers[i];
        }
        latestSum = sum;
    }
    
    // ==================== MESSAGE PARSING FUNCTIONS ====================
    
    /**
     * @dev Extract nonce from CCTP message
     */
    function _extractNonceFromMessage(bytes calldata message) internal pure returns (uint64) {
        return uint64(bytes8(message[12:20]));
    }
    
    /**
     * @dev Extract sender from CCTP message  
     */
    function _extractSenderFromMessage(bytes calldata message) internal pure returns (address) {
        return address(bytes20(message[44:64]));
    }
    
    /**
     * @dev Extract amount from CCTP message
     */
    function _extractAmountFromMessage(bytes calldata message) internal pure returns (uint256) {
        // This is simplified - actual parsing depends on CCTP V2 message format
        return 1000000; // Default 1 USDC for now
    }
    
    /**
     * @dev Extract hook data from CCTP V2 message
     */
    function _extractHookDataFromMessage(bytes calldata message) internal pure returns (bytes memory) {
        // This would need to be implemented based on actual CCTP V2 message format
        // For now, return empty bytes
        return new bytes(0);
    }
    
    /**
     * @dev Get message timestamp (simplified)
     */
    function _getMessageTimestamp(uint64 nonce) internal view returns (uint256) {
        // Simplified - would need actual implementation
        return block.timestamp;
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @dev Get message by nonce
     */
    function getMessageByNonce(uint64 nonce) external view returns (FastTransferMessage memory) {
        uint256 index = nonceToIndex[nonce];
        require(index < receivedMessages.length, "Message not found");
        return receivedMessages[index];
    }
    
    /**
     * @dev Get latest message numbers sum (for verification)
     */
    function sumLatestNumbers() external view returns (uint256) {
        return latestSum;
    }
    
    /**
     * @dev Get contract statistics
     */
    function getStats() external view returns (
        uint256 totalMessages,
        uint256 totalUSDC,
        uint256 fastTransfers,
        uint256 standardTransfers,
        string memory latest
    ) {
        return (
            totalMessagesReceived,
            totalUSDCReceived,
            fastTransfersReceived,
            standardTransfersReceived,
            latestMessage
        );
    }
    
    /**
     * @dev Get messages sent by specific address
     */
    function getMessagesBySender(address sender) external view returns (uint256[] memory) {
        return senderMessages[sender];
    }
    
    /**
     * @dev Check USDC balance of contract
     */
    function getUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Get latest numbers array
     */
    function getLatestNumbers() external view returns (uint256[] memory) {
        return latestNumbers;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    /**
     * @dev Withdraw USDC from contract
     */
    function withdrawUSDC() external onlyOwner {
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No USDC to withdraw");
        usdc.safeTransfer(owner(), balance);
    }
    
    /**
     * @dev Emergency withdraw ETH
     */
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}