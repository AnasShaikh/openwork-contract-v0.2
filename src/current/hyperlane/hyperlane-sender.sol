// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMailbox {
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId);
}

/**
 * @title HyperlaneSender
 * @dev Simple contract to send messages from Optimism Sepolia to Arbitrum Sepolia via Hyperlane
 * Based on official Hyperlane documentation
 */
contract HyperlaneSender {
    IMailbox public immutable mailbox;
    
    // Hyperlane domain IDs (from official docs)
    uint32 public constant ARBITRUM_SEPOLIA_DOMAIN = 421614;
    uint32 public constant OPTIMISM_SEPOLIA_DOMAIN = 11155420;
    
    // Events
    event MessageSent(
        bytes32 indexed messageId, 
        uint32 indexed destinationDomain,
        bytes32 indexed recipient,
        string message
    );
    
    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }
    
    /**
     * @dev Send a simple string message to Arbitrum Sepolia
     * @param _recipient Address of receiver contract on Arbitrum Sepolia
     * @param _message String message to send
     */
    function sendMessage(address _recipient, string calldata _message) external payable {
        // Convert recipient address to bytes32
        bytes32 recipientAddress = bytes32(uint256(uint160(_recipient)));
        
        // Encode the message as bytes
        bytes memory messageBody = abi.encode(_message);
        
        // Send the message via Hyperlane Mailbox
        bytes32 messageId = mailbox.dispatch{value: msg.value}(
            ARBITRUM_SEPOLIA_DOMAIN,
            recipientAddress,
            messageBody
        );
        
        emit MessageSent(messageId, ARBITRUM_SEPOLIA_DOMAIN, recipientAddress, _message);
    }
    
    /**
     * @dev Send a numeric value to Arbitrum Sepolia
     * @param _recipient Address of receiver contract on Arbitrum Sepolia  
     * @param _value Numeric value to send
     */
    function sendValue(address _recipient, uint256 _value) external payable {
        bytes32 recipientAddress = bytes32(uint256(uint160(_recipient)));
        bytes memory messageBody = abi.encode(_value);
        
        bytes32 messageId = mailbox.dispatch{value: msg.value}(
            ARBITRUM_SEPOLIA_DOMAIN,
            recipientAddress,
            messageBody
        );
        
        emit MessageSent(messageId, ARBITRUM_SEPOLIA_DOMAIN, recipientAddress, "");
    }
    
    /**
     * @dev Get the local domain of this chain (hardcoded)
     */
    function getLocalDomain() external pure returns (uint32) {
        return OPTIMISM_SEPOLIA_DOMAIN;
    }
    
    /**
     * @dev Get mailbox address
     */
    function getMailbox() external view returns (address) {
        return address(mailbox);
    }
}