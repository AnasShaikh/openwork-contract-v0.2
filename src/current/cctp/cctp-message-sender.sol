// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITokenMessenger {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

/**
 * @title CCTPMessageSender  
 * @dev Send rich message data using CCTP with minimal USDC as carrier
 * Uses 1 wei USDC to enable message transmission via existing CCTP infrastructure
 */
contract CCTPMessageSender is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ==================== CCTP CONTRACTS ====================
    ITokenMessenger public immutable tokenMessenger;
    IERC20 public immutable usdc;
    
    // ==================== DOMAIN MAPPINGS ====================
    uint32 public constant ETHEREUM_SEPOLIA_DOMAIN = 0;
    uint32 public constant OPTIMISM_SEPOLIA_DOMAIN = 2; 
    uint32 public constant ARBITRUM_SEPOLIA_DOMAIN = 3;
    uint32 public constant BASE_SEPOLIA_DOMAIN = 6;
    
    // ==================== MESSAGE TRACKING ====================
    struct MessageData {
        address sender;
        address recipient;
        string textMessage;
        uint256[] numbers;
        bytes customData;
        uint256 timestamp;
        uint32 destinationDomain;
    }
    
    // Message storage and tracking
    mapping(uint64 => MessageData) public sentMessages; // nonce => message data
    uint256 public totalMessagesSent;
    
    // Message recipient for all messages (can be updated)
    bytes32 public defaultRecipient;
    
    // ==================== EVENTS ====================
    event MessageSent(
        uint64 indexed nonce,
        uint32 indexed destinationDomain,
        address indexed sender,
        address recipient,
        string textMessage,
        uint256[] numbers
    );
    
    event CustomDataSent(
        uint64 indexed nonce,
        uint32 indexed destinationDomain,
        address indexed sender,
        bytes customData
    );
    
    event RecipientUpdated(bytes32 newRecipient);
    
    constructor(
        address _tokenMessenger,
        address _usdc,
        bytes32 _defaultRecipient
    ) Ownable(msg.sender) {
        tokenMessenger = ITokenMessenger(_tokenMessenger);
        usdc = IERC20(_usdc);
        defaultRecipient = _defaultRecipient;
    }
    
    // ==================== MESSAGE SENDING FUNCTIONS ====================
    
    /**
     * @dev Send a text message with array data using minimal USDC
     * @param destinationDomain Target chain domain ID
     * @param recipient Recipient address on destination chain
     * @param message Text message to send
     * @param numbers Array of numbers to include
     */
    function sendMessage(
        uint32 destinationDomain,
        address recipient,
        string calldata message,
        uint256[] calldata numbers
    ) external nonReentrant returns (uint64) {
        require(bytes(message).length > 0, "Message cannot be empty");
        require(recipient != address(0), "Invalid recipient");
        
        // Transfer minimal USDC (1 wei) from sender
        usdc.safeTransferFrom(msg.sender, address(this), 1);
        usdc.approve(address(tokenMessenger), 1);
        
        // Convert recipient to bytes32
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));
        
        // Send via CCTP with minimal amount
        uint64 nonce = tokenMessenger.depositForBurn(
            1,
            destinationDomain,
            recipientBytes32,
            address(usdc)
        );
        
        // Store message data
        sentMessages[nonce] = MessageData({
            sender: msg.sender,
            recipient: recipient,
            textMessage: message,
            numbers: numbers,
            customData: "",
            timestamp: block.timestamp,
            destinationDomain: destinationDomain
        });
        
        totalMessagesSent++;
        
        emit MessageSent(nonce, destinationDomain, msg.sender, recipient, message, numbers);
        return nonce;
    }
    
    /**
     * @dev Send custom byte data with minimal USDC
     * @param destinationDomain Target chain domain ID  
     * @param recipient Recipient address on destination chain
     * @param customData Custom bytes to send
     */
    function sendCustomData(
        uint32 destinationDomain,
        address recipient,
        bytes calldata customData
    ) external nonReentrant returns (uint64) {
        require(customData.length > 0, "Custom data cannot be empty");
        require(recipient != address(0), "Invalid recipient");
        
        // Transfer minimal USDC (1 wei) from sender
        usdc.safeTransferFrom(msg.sender, address(this), 1);
        usdc.approve(address(tokenMessenger), 1);
        
        // Convert recipient to bytes32
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));
        
        // Send via CCTP with minimal amount
        uint64 nonce = tokenMessenger.depositForBurn(
            1,
            destinationDomain,
            recipientBytes32,
            address(usdc)
        );
        
        // Store message data
        uint256[] memory emptyNumbers;
        sentMessages[nonce] = MessageData({
            sender: msg.sender,
            recipient: recipient,
            textMessage: "",
            numbers: emptyNumbers,
            customData: customData,
            timestamp: block.timestamp,
            destinationDomain: destinationDomain
        });
        
        totalMessagesSent++;
        
        emit CustomDataSent(nonce, destinationDomain, msg.sender, customData);
        return nonce;
    }
    
    /**
     * @dev Send message to default recipient (saves gas)
     * @param destinationDomain Target chain domain ID
     * @param message Text message to send
     * @param numbers Array of numbers to include
     */
    function sendToDefault(
        uint32 destinationDomain,
        string calldata message,
        uint256[] calldata numbers
    ) external nonReentrant returns (uint64) {
        require(defaultRecipient != bytes32(0), "Default recipient not set");
        require(bytes(message).length > 0, "Message cannot be empty");
        
        // Transfer minimal USDC (1 wei) from sender
        usdc.safeTransferFrom(msg.sender, address(this), 1);
        usdc.approve(address(tokenMessenger), 1);
        
        // Send via CCTP with minimal amount
        uint64 nonce = tokenMessenger.depositForBurn(
            1,
            destinationDomain,
            defaultRecipient,
            address(usdc)
        );
        
        // Store message data
        address recipientAddress = address(uint160(uint256(defaultRecipient)));
        sentMessages[nonce] = MessageData({
            sender: msg.sender,
            recipient: recipientAddress,
            textMessage: message,
            numbers: numbers,
            customData: "",
            timestamp: block.timestamp,
            destinationDomain: destinationDomain
        });
        
        totalMessagesSent++;
        
        emit MessageSent(nonce, destinationDomain, msg.sender, recipientAddress, message, numbers);
        return nonce;
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @dev Get sent message data by nonce
     */
    function getSentMessage(uint64 nonce) external view returns (MessageData memory) {
        return sentMessages[nonce];
    }
    
    /**
     * @dev Get total messages sent count
     */
    function getTotalMessagesSent() external view returns (uint256) {
        return totalMessagesSent;
    }
    
    /**
     * @dev Check if user has enough USDC for message sending
     */
    function canSendMessage(address user) external view returns (bool) {
        return usdc.balanceOf(user) >= 1 && usdc.allowance(user, address(this)) >= 1;
    }
    
    /**
     * @dev Get contract's USDC balance (accumulated minimal amounts)
     */
    function getAccumulatedUSDC() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Get domain constants
     */
    function getDomains() external pure returns (uint32, uint32, uint32, uint32) {
        return (ETHEREUM_SEPOLIA_DOMAIN, OPTIMISM_SEPOLIA_DOMAIN, ARBITRUM_SEPOLIA_DOMAIN, BASE_SEPOLIA_DOMAIN);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    /**
     * @dev Update default recipient for messages
     */
    function updateDefaultRecipient(bytes32 newRecipient) external onlyOwner {
        defaultRecipient = newRecipient;
        emit RecipientUpdated(newRecipient);
    }
    
    /**
     * @dev Withdraw accumulated minimal USDC amounts
     */
    function withdrawAccumulatedUSDC() external onlyOwner {
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No USDC to withdraw");
        usdc.safeTransfer(owner(), balance);
    }
    
    /**
     * @dev Emergency withdraw any ETH
     */
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    /**
     * @dev Convert address to bytes32 for CCTP
     */
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    /**
     * @dev Convert bytes32 to address
     */
    function bytes32ToAddress(bytes32 b) external pure returns (address) {
        return address(uint160(uint256(b)));
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}