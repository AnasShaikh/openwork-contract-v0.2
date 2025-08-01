// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMailbox {
    // Mailbox interface for verification only
}

/**
 * @title HyperlaneReceiver
 * @dev Simple contract to receive messages from Optimism Sepolia via Hyperlane
 * Based on official Hyperlane documentation
 */
contract HyperlaneReceiver {
    IMailbox public immutable mailbox;
    
    // Hyperlane domain IDs (from official docs)
    uint32 public constant OPTIMISM_SEPOLIA_DOMAIN = 11155420;
    uint32 public constant ARBITRUM_SEPOLIA_DOMAIN = 421614;
    
    // Storage for received messages
    string public lastMessage;
    uint256 public lastValue;
    address public lastSender;
    uint32 public lastOriginDomain;
    uint256 public messageCount;
    
    // Events
    event MessageReceived(
        uint32 indexed origin,
        bytes32 indexed sender,
        string message
    );
    
    event ValueReceived(
        uint32 indexed origin,
        bytes32 indexed sender,
        uint256 value
    );
    
    // Errors
    error UnauthorizedMailbox();
    error UnauthorizedOrigin(uint32 origin);
    
    modifier onlyMailbox() {
        if (msg.sender != address(mailbox)) revert UnauthorizedMailbox();
        _;
    }
    
    modifier onlyFromOptimismSepolia(uint32 _origin) {
        if (_origin != OPTIMISM_SEPOLIA_DOMAIN) revert UnauthorizedOrigin(_origin);
        _;
    }
    
    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }
    
    /**
     * @dev Handle incoming messages from Hyperlane
     * This is the function that Hyperlane calls when delivering a message
     * @param _origin Domain ID of the origin chain
     * @param _sender Address of the sender (as bytes32)
     * @param _message The message body
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external onlyMailbox onlyFromOptimismSepolia(_origin) {
        
        // Update message tracking
        messageCount++;
        lastSender = address(uint160(uint256(_sender)));
        lastOriginDomain = _origin;
        
        // Try to decode as string first
        try this.decodeAsString(_message) returns (string memory decodedMessage) {
            lastMessage = decodedMessage;
            lastValue = 0; // Reset value when receiving string
            emit MessageReceived(_origin, _sender, decodedMessage);
        } catch {
            // If string decode fails, try as uint256
            try this.decodeAsUint256(_message) returns (uint256 decodedValue) {
                lastValue = decodedValue;
                lastMessage = ""; // Reset message when receiving value
                emit ValueReceived(_origin, _sender, decodedValue);
            } catch {
                // If both fail, treat as raw string
                lastMessage = "Raw message received";
                emit MessageReceived(_origin, _sender, "Raw message received");
            }
        }
    }
    
    /**
     * @dev External function to decode message as string (for try/catch)
     */
    function decodeAsString(bytes calldata _message) external pure returns (string memory) {
        return abi.decode(_message, (string));
    }
    
    /**
     * @dev External function to decode message as uint256 (for try/catch)  
     */
    function decodeAsUint256(bytes calldata _message) external pure returns (uint256) {
        return abi.decode(_message, (uint256));
    }
    
    /**
     * @dev Get the last received message
     */
    function getLastMessage() external view returns (string memory) {
        return lastMessage;
    }
    
    /**
     * @dev Get the last received value
     */
    function getLastValue() external view returns (uint256) {
        return lastValue;
    }
    
    /**
     * @dev Get comprehensive info about the last message
     */
    function getLastMessageInfo() external view returns (
        string memory message,
        uint256 value,
        address sender,
        uint32 originDomain,
        uint256 totalMessages
    ) {
        return (lastMessage, lastValue, lastSender, lastOriginDomain, messageCount);
    }
    
    /**
     * @dev Get the local domain of this chain (hardcoded)
     */
    function getLocalDomain() external pure returns (uint32) {
        return ARBITRUM_SEPOLIA_DOMAIN;
    }
    
    /**
     * @dev Get mailbox address
     */
    function getMailbox() external view returns (address) {
        return address(mailbox);
    }
}