// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IMessageTransmitter {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool);
}

/**
 * @title CCTPMessageReceiver
 * @dev Receive rich message data via CCTP minimal USDC transfers
 * Correlates received USDC with off-chain message data lookup
 */
contract CCTPMessageReceiver is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ==================== CCTP CONTRACTS ====================
    IMessageTransmitter public immutable messageTransmitter;
    IERC20 public immutable usdc;
    
    // ==================== MESSAGE TRACKING ====================
    struct ReceivedMessage {
        uint64 nonce;
        address sender;
        string textMessage;
        uint256[] numbers;
        bytes customData;
        uint256 receivedAt;
        uint256 usdcAmount;
        bool isProcessed;
    }
    
    // ==================== STATE VARIABLES ====================
    ReceivedMessage[] public receivedMessages;
    mapping(uint64 => uint256) public nonceToIndex; // CCTP nonce => array index
    mapping(address => uint256[]) public senderMessages; // sender => message indices
    
    uint256 public totalMessagesReceived;
    uint256 public totalUSDCReceived;
    uint256 public unprocessedMessages;
    
    // ==================== EVENTS ====================
    event CCTPMessageReceived(
        uint64 indexed nonce,
        address indexed sender,
        uint256 usdcAmount,
        bytes32 indexed messageHash
    );
    
    event MessageProcessed(
        uint64 indexed nonce,
        address indexed sender,
        string textMessage,
        uint256[] numbers
    );
    
    event CustomDataReceived(
        uint64 indexed nonce,
        address indexed sender,
        bytes customData
    );
    
    event MessageCorrelated(
        uint64 indexed nonce,
        uint256 indexed messageIndex
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
     * @dev Receive CCTP message with attestation
     */
    function receiveCCTPMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant {
        // Verify and process the message through CCTP
        bool success = messageTransmitter.receiveMessage(message, attestation);
        require(success, "CCTP message verification failed");
        
        // Parse the CCTP message to extract nonce and sender info
        uint64 nonce = _extractNonceFromMessage(message);
        address sender = _extractSenderFromMessage(message);
        uint256 amount = _extractAmountFromMessage(message);
        
        // Create initial message record (will be populated later)
        uint256[] memory emptyNumbers;
        ReceivedMessage memory newMessage = ReceivedMessage({
            nonce: nonce,
            sender: sender,
            textMessage: "",
            numbers: emptyNumbers,
            customData: "",
            receivedAt: block.timestamp,
            usdcAmount: amount,
            isProcessed: false
        });
        
        // Store the message
        uint256 messageIndex = receivedMessages.length;
        receivedMessages.push(newMessage);
        nonceToIndex[nonce] = messageIndex;
        senderMessages[sender].push(messageIndex);
        
        totalMessagesReceived++;
        totalUSDCReceived += amount;
        unprocessedMessages++;
        
        bytes32 messageHash = keccak256(message);
        emit CCTPMessageReceived(nonce, sender, amount, messageHash);
        emit MessageCorrelated(nonce, messageIndex);
    }
    
    /**
     * @dev Process message data for a received CCTP transfer
     * This allows correlation of off-chain message data with on-chain CCTP transfers
     */
    function processMessage(
        uint64 nonce,
        string calldata textMessage,
        uint256[] calldata numbers
    ) external {
        require(nonceToIndex[nonce] < receivedMessages.length, "Message not found");
        
        uint256 messageIndex = nonceToIndex[nonce];
        ReceivedMessage storage message = receivedMessages[messageIndex];
        
        require(!message.isProcessed, "Message already processed");
        require(
            msg.sender == message.sender || msg.sender == owner(),
            "Only sender or owner can process"
        );
        
        // Update the message with actual data
        message.textMessage = textMessage;
        message.numbers = numbers;
        message.isProcessed = true;
        
        unprocessedMessages--;
        
        emit MessageProcessed(nonce, message.sender, textMessage, numbers);
    }
    
    /**
     * @dev Process custom data for a received CCTP transfer
     */
    function processCustomData(
        uint64 nonce,
        bytes calldata customData
    ) external {
        require(nonceToIndex[nonce] < receivedMessages.length, "Message not found");
        
        uint256 messageIndex = nonceToIndex[nonce];
        ReceivedMessage storage message = receivedMessages[messageIndex];
        
        require(!message.isProcessed, "Message already processed");
        require(
            msg.sender == message.sender || msg.sender == owner(),
            "Only sender or owner can process"
        );
        
        // Update the message with custom data
        message.customData = customData;
        message.isProcessed = true;
        
        unprocessedMessages--;
        
        emit CustomDataReceived(nonce, message.sender, customData);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @dev Get total number of received messages
     */
    function getMessageCount() external view returns (uint256) {
        return receivedMessages.length;
    }
    
    /**
     * @dev Get received message by index
     */
    function getMessage(uint256 index) external view returns (ReceivedMessage memory) {
        require(index < receivedMessages.length, "Index out of bounds");
        return receivedMessages[index];
    }
    
    /**
     * @dev Get received message by CCTP nonce
     */
    function getMessageByNonce(uint64 nonce) external view returns (ReceivedMessage memory) {
        require(nonceToIndex[nonce] < receivedMessages.length, "Message not found");
        return receivedMessages[nonceToIndex[nonce]];
    }
    
    /**
     * @dev Get last N messages
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
     * @dev Get all messages from a specific sender
     */
    function getMessagesBySender(address sender) external view returns (ReceivedMessage[] memory) {
        uint256[] memory indices = senderMessages[sender];
        ReceivedMessage[] memory messages = new ReceivedMessage[](indices.length);
        
        for (uint256 i = 0; i < indices.length; i++) {
            messages[i] = receivedMessages[indices[i]];
        }
        
        return messages;
    }
    
    /**
     * @dev Get unprocessed messages
     */
    function getUnprocessedMessages() external view returns (ReceivedMessage[] memory) {
        // Count unprocessed first
        uint256 unprocessedCount = 0;
        for (uint256 i = 0; i < receivedMessages.length; i++) {
            if (!receivedMessages[i].isProcessed) {
                unprocessedCount++;
            }
        }
        
        // Create array of unprocessed messages
        ReceivedMessage[] memory unprocessed = new ReceivedMessage[](unprocessedCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < receivedMessages.length; i++) {
            if (!receivedMessages[i].isProcessed) {
                unprocessed[currentIndex] = receivedMessages[i];
                currentIndex++;
            }
        }
        
        return unprocessed;
    }
    
    /**
     * @dev Get contract statistics
     */
    function getStats() external view returns (
        uint256 totalMessages,
        uint256 totalUSDC,
        uint256 unprocessedCount,
        uint256 processedCount
    ) {
        return (
            totalMessagesReceived,
            totalUSDCReceived,
            unprocessedMessages,
            totalMessagesReceived - unprocessedMessages
        );
    }
    
    /**
     * @dev Get USDC balance of this contract
     */
    function getUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Sum all numbers in the latest processed message
     */
    function sumLatestNumbers() external view returns (uint256) {
        if (receivedMessages.length == 0) return 0;
        
        // Find the latest processed message
        for (uint256 i = receivedMessages.length; i > 0; i--) {
            ReceivedMessage memory message = receivedMessages[i - 1];
            if (message.isProcessed && message.numbers.length > 0) {
                uint256 sum = 0;
                for (uint256 j = 0; j < message.numbers.length; j++) {
                    sum += message.numbers[j];
                }
                return sum;
            }
        }
        
        return 0;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    /**
     * @dev Batch process messages (admin only)
     */
    function batchProcessMessages(
        uint64[] calldata nonces,
        string[] calldata messages,
        uint256[][] calldata numbersArray
    ) external onlyOwner {
        require(
            nonces.length == messages.length && messages.length == numbersArray.length,
            "Array lengths must match"
        );
        
        for (uint256 i = 0; i < nonces.length; i++) {
            if (nonceToIndex[nonces[i]] < receivedMessages.length) {
                uint256 messageIndex = nonceToIndex[nonces[i]];
                ReceivedMessage storage message = receivedMessages[messageIndex];
                
                if (!message.isProcessed) {
                    message.textMessage = messages[i];
                    message.numbers = numbersArray[i];
                    message.isProcessed = true;
                    unprocessedMessages--;
                    
                    emit MessageProcessed(nonces[i], message.sender, messages[i], numbersArray[i]);
                }
            }
        }
    }
    
    /**
     * @dev Clear all message data (admin only)
     */
    function clearMessages() external onlyOwner {
        delete receivedMessages;
        totalMessagesReceived = 0;
        totalUSDCReceived = 0;
        unprocessedMessages = 0;
    }
    
    /**
     * @dev Withdraw accumulated USDC
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
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    /**
     * @dev Extract nonce from CCTP message
     */
    function _extractNonceFromMessage(bytes calldata message) internal pure returns (uint64) {
        // CCTP message format: domain(4) + recipient(32) + nonce(8) + sender(32) + ...
        // Nonce is at bytes 36-44 (after 4 bytes domain + 32 bytes recipient)
        return uint64(bytes8(message[36:44]));
    }
    
    /**
     * @dev Extract sender address from CCTP message body
     */
    function _extractSenderFromMessage(bytes calldata message) internal pure returns (address) {
        // Extract sender from message body (last 32 bytes typically contain sender info)
        if (message.length >= 32) {
            bytes32 senderBytes32 = bytes32(message[message.length-32:message.length]);
            return address(uint160(uint256(senderBytes32)));
        }
        return address(0);
    }
    
    /**
     * @dev Extract amount from CCTP message body
     */
    function _extractAmountFromMessage(bytes calldata message) internal pure returns (uint256) {
        // Extract amount from message body (typically at a fixed offset)
        if (message.length >= 64) {
            return uint256(bytes32(message[message.length-64:message.length-32]));
        }
        return 1; // Default minimal amount
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}