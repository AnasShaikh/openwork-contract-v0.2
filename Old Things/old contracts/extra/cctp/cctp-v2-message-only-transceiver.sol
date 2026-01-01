// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;
}

interface IMessageTransmitterV2 {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external;
}

contract CCTPv2MessageOnlyTransceiver {
    ITokenMessengerV2 public immutable tokenMessenger;
    IMessageTransmitterV2 public immutable messageTransmitter;
    IERC20 public immutable usdc;
    
    // Minimum amount for message-only transfers (100 wei USDC)
    uint256 public constant MESSAGE_CARRIER_AMOUNT = 100;
    uint256 public constant MESSAGE_MAX_FEE = 50; // 50% of carrier amount
    
    // Message storage
    mapping(bytes32 => string) public messages;
    mapping(bytes32 => address) public messageSenders;
    mapping(bytes32 => uint256) public messageTimestamps;
    mapping(address => uint256) public userMessageCount;
    
    uint256 public totalMessages;
    
    event MessageSent(
        string message,
        uint32 destinationDomain,
        bytes32 recipient,
        bytes32 nonce,
        address sender
    );
    
    event MessageReceived(
        string message,
        bytes32 nonce,
        address sender,
        uint256 timestamp
    );
    
    event FastTransferReceived(
        bytes message,
        bytes attestation
    );

    constructor(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc
    ) {
        tokenMessenger = ITokenMessengerV2(_tokenMessenger);
        messageTransmitter = IMessageTransmitterV2(_messageTransmitter);
        usdc = IERC20(_usdc);
    }

    // Send a cross-chain message using minimal USDC as carrier
    function sendMessage(
        string calldata message,
        uint32 destinationDomain,
        bytes32 recipient
    ) external returns (bytes32 nonce) {
        require(bytes(message).length > 0, "Message cannot be empty");
        require(bytes(message).length <= 1000, "Message too long");
        
        // Transfer minimal USDC from sender
        usdc.transferFrom(msg.sender, address(this), MESSAGE_CARRIER_AMOUNT);
        
        // Approve TokenMessenger
        usdc.approve(address(tokenMessenger), MESSAGE_CARRIER_AMOUNT);
        
        // Generate pseudo-nonce for tracking (using block data)
        nonce = keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            msg.sender,
            message,
            totalMessages
        ));
        
        // Store message data locally for reference
        messages[nonce] = message;
        messageSenders[nonce] = msg.sender;
        messageTimestamps[nonce] = block.timestamp;
        userMessageCount[msg.sender]++;
        totalMessages++;
        
        // Send via CCTP fast transfer
        tokenMessenger.depositForBurn(
            MESSAGE_CARRIER_AMOUNT,
            destinationDomain,
            recipient,
            address(usdc),
            bytes32(0), // Allow any caller
            MESSAGE_MAX_FEE,
            1000 // Fast transfer
        );
        
        emit MessageSent(message, destinationDomain, recipient, nonce, msg.sender);
        return nonce;
    }

    // Receive and process messages
    function receive(
        bytes calldata message,
        bytes calldata attestation
    ) external {
        messageTransmitter.receiveMessage(message, attestation);
        emit FastTransferReceived(message, attestation);
    }
    
    // Process received message (call after receive)
    function processReceivedMessage(
        bytes32 nonce,
        string calldata messageText,
        address originalSender
    ) external {
        require(bytes(messageText).length > 0, "Invalid message");
        
        // Store received message
        messages[nonce] = messageText;
        messageSenders[nonce] = originalSender;
        messageTimestamps[nonce] = block.timestamp;
        totalMessages++;
        
        emit MessageReceived(messageText, nonce, originalSender, block.timestamp);
    }

    // Helper functions
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    function getMessage(bytes32 nonce) external view returns (
        string memory message,
        address sender,
        uint256 timestamp
    ) {
        return (messages[nonce], messageSenders[nonce], messageTimestamps[nonce]);
    }
    
    function getUserStats(address user) external view returns (uint256 messageCount) {
        return userMessageCount[user];
    }
    
    function getMessageCarrierCost() external pure returns (uint256 amount, uint256 maxFee) {
        return (MESSAGE_CARRIER_AMOUNT, MESSAGE_MAX_FEE);
    }
    
    function getTotalMessages() external view returns (uint256) {
        return totalMessages;
    }
}