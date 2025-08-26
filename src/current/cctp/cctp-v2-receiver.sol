// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// CCTP V2 Interfaces
interface IMessageTransmitter {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool);
}

contract CCTPTestReceiver is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ==================== CCTP V2 CONTRACTS ====================
    IMessageTransmitter public messageTransmitter;
    IERC20 public usdc;
    
    // ==================== RECEIVED DATA TRACKING ====================
    struct ReceivedMessage {
        string messageType;
        address sender;
        string textMessage;
        uint256[] numbers;
        uint256 timestamp;
        uint256 usdcAmount;
        uint256 receivedAt;
        uint64 nonce;
    }
    
    // ==================== STATE VARIABLES ====================
    ReceivedMessage[] public receivedMessages;
    mapping(uint64 => uint256) public nonceToMessageIndex; // nonce => array index
    mapping(string => uint256) public messageTypeCount; // message type => count
    
    uint256 public totalUSDCReceived;
    uint256 public totalMessagesReceived;
    
    // ==================== EVENTS ====================
    event MessageOnlyReceived(
        string indexed messageType,
        address indexed sender,
        string textMessage,
        uint256[] numbers,
        uint64 nonce
    );
    
    event TokensWithMessageReceived(
        string indexed messageType,
        address indexed sender,
        uint256 amount,
        string textMessage,
        uint256[] numbers,
        uint64 nonce
    );
    
    event FastTransferReceived(
        address indexed recipient,
        uint256 amount
    );
    
    event CCTPMessageProcessed(
        bytes32 indexed messageHash,
        bool success
    );
    
    constructor(
        address _messageTransmitter,
        address _usdc
    ) Ownable(msg.sender) {
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
        usdc = IERC20(_usdc);
    }
    
    // ==================== CCTP MESSAGE RECEPTION ====================
    
    /**
     * @dev Receive and process CCTP messages with attestation
     * This function is called by relayers with the message and attestation
     */
    function receiveCCTPMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant {
        // Verify and process the message through CCTP
        bool success = messageTransmitter.receiveMessage(message, attestation);
        require(success, "CCTP message verification failed");
        
        bytes32 messageHash = keccak256(message);
        emit CCTPMessageProcessed(messageHash, success);
    }
    
    /**
     * @dev Handle the actual message content (called by MessageTransmitter after verification)
     * This is automatically called by CCTP after successful message verification
     */
    function handle(
        uint32 sourceDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external {
        require(msg.sender == address(messageTransmitter), "Only MessageTransmitter can call");
        
        // Decode the message type first
        (string memory messageType) = abi.decode(messageBody, (string));
        
        if (keccak256(bytes(messageType)) == keccak256("TEST_MESSAGE_ONLY")) {
            _handleMessageOnly(messageBody, sourceDomain);
        } else if (keccak256(bytes(messageType)) == keccak256("TEST_TOKENS_WITH_MESSAGE")) {
            _handleTokensWithMessage(messageBody, sourceDomain);
        } else {
            revert("Unknown message type");
        }
        
        totalMessagesReceived++;
    }
    
    /**
     * @dev Process message-only reception
     */
    function _handleMessageOnly(bytes calldata messageBody, uint32 sourceDomain) internal {
        (
            string memory messageType,
            address sender,
            string memory textMessage,
            uint256[] memory numbers,
            uint256 timestamp
        ) = abi.decode(messageBody, (string, address, string, uint256[], uint256));
        
        // Store the received message
        ReceivedMessage memory newMessage = ReceivedMessage({
            messageType: messageType,
            sender: sender,
            textMessage: textMessage,
            numbers: numbers,
            timestamp: timestamp,
            usdcAmount: 0, // No USDC in message-only
            receivedAt: block.timestamp,
            nonce: uint64(receivedMessages.length) // Use array index as nonce for tracking
        });
        
        receivedMessages.push(newMessage);
        messageTypeCount[messageType]++;
        
        emit MessageOnlyReceived(
            messageType,
            sender,
            textMessage,
            numbers,
            newMessage.nonce
        );
    }
    
    /**
     * @dev Process tokens with message reception
     */
    function _handleTokensWithMessage(bytes calldata messageBody, uint32 sourceDomain) internal {
        (
            string memory messageType,
            address sender,
            string memory textMessage,
            uint256[] memory numbers,
            uint256 timestamp,
            uint256 amount
        ) = abi.decode(messageBody, (string, address, string, uint256[], uint256, uint256));
        
        // Store the received message
        ReceivedMessage memory newMessage = ReceivedMessage({
            messageType: messageType,
            sender: sender,
            textMessage: textMessage,
            numbers: numbers,
            timestamp: timestamp,
            usdcAmount: amount,
            receivedAt: block.timestamp,
            nonce: uint64(receivedMessages.length)
        });
        
        receivedMessages.push(newMessage);
        messageTypeCount[messageType]++;
        totalUSDCReceived += amount;
        
        emit TokensWithMessageReceived(
            messageType,
            sender,
            amount,
            textMessage,
            numbers,
            newMessage.nonce
        );
    }
    
    /**
     * @dev Handle direct USDC reception (fast transfer without message)
     * This is called automatically when USDC is minted to this contract
     */
    function notifyFastTransfer(address recipient, uint256 amount) external {
        require(msg.sender == address(this) || msg.sender == owner(), "Unauthorized");
        
        totalUSDCReceived += amount;
        emit FastTransferReceived(recipient, amount);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @dev Get total number of received messages
     */
    function getReceivedMessageCount() external view returns (uint256) {
        return receivedMessages.length;
    }
    
    /**
     * @dev Get received message by index
     */
    function getReceivedMessage(uint256 index) external view returns (ReceivedMessage memory) {
        require(index < receivedMessages.length, "Message index out of bounds");
        return receivedMessages[index];
    }
    
    /**
     * @dev Get last N received messages
     */
    function getLastMessages(uint256 count) external view returns (ReceivedMessage[] memory) {
        uint256 totalCount = receivedMessages.length;
        uint256 returnCount = count > totalCount ? totalCount : count;
        
        ReceivedMessage[] memory messages = new ReceivedMessage[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            messages[i] = receivedMessages[totalCount - 1 - i];
        }
        
        return messages;
    }
    
    /**
     * @dev Get messages by type
     */
    function getMessagesByType(string memory messageType) external view returns (ReceivedMessage[] memory) {
        uint256 typeCount = messageTypeCount[messageType];
        ReceivedMessage[] memory messages = new ReceivedMessage[](typeCount);
        uint256 foundCount = 0;
        
        for (uint256 i = 0; i < receivedMessages.length && foundCount < typeCount; i++) {
            if (keccak256(bytes(receivedMessages[i].messageType)) == keccak256(bytes(messageType))) {
                messages[foundCount] = receivedMessages[i];
                foundCount++;
            }
        }
        
        return messages;
    }
    
    /**
     * @dev Get contract statistics
     */
    function getStats() external view returns (
        uint256 totalMessages,
        uint256 totalUSDC,
        uint256 messageOnlyCount,
        uint256 tokensWithMessageCount
    ) {
        return (
            totalMessagesReceived,
            totalUSDCReceived,
            messageTypeCount["TEST_MESSAGE_ONLY"],
            messageTypeCount["TEST_TOKENS_WITH_MESSAGE"]
        );
    }
    
    /**
     * @dev Get USDC balance of this contract
     */
    function getUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Get latest received array data for testing
     */
    function getLatestArrayData() external view returns (uint256[] memory) {
        if (receivedMessages.length == 0) {
            return new uint256[](0);
        }
        return receivedMessages[receivedMessages.length - 1].numbers;
    }
    
    /**
     * @dev Test array processing - sum all numbers in latest message
     */
    function sumLatestNumbers() external view returns (uint256) {
        if (receivedMessages.length == 0) {
            return 0;
        }
        
        uint256[] memory numbers = receivedMessages[receivedMessages.length - 1].numbers;
        uint256 sum = 0;
        
        for (uint256 i = 0; i < numbers.length; i++) {
            sum += numbers[i];
        }
        
        return sum;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function updateMessageTransmitter(address _messageTransmitter) external onlyOwner {
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
    }
    
    function updateUSDC(address _usdc) external onlyOwner {
        usdc = IERC20(_usdc);
    }
    
    function clearReceivedMessages() external onlyOwner {
        delete receivedMessages;
        totalMessagesReceived = 0;
        
        // Reset message type counters
        messageTypeCount["TEST_MESSAGE_ONLY"] = 0;
        messageTypeCount["TEST_TOKENS_WITH_MESSAGE"] = 0;
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function emergencyWithdrawUSDC() external onlyOwner {
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No USDC balance to withdraw");
        usdc.safeTransfer(owner(), balance);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}