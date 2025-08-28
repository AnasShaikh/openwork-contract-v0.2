// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITokenMessengerV2 {
    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external returns (uint64 nonce);
    
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        uint32 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external returns (uint64 nonce);
}

/**
 * @title CCTPv2FastTransferSender
 * @dev Send USDC with custom data using CCTP V2 Fast Transfer
 * Supports both depositForBurnWithCaller and depositForBurnWithHook
 */
contract CCTPv2FastTransferSender is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ==================== CCTP V2 CONTRACTS ====================
    ITokenMessengerV2 public immutable tokenMessengerV2;
    IERC20 public immutable usdc;
    
    // ==================== DOMAIN MAPPINGS ====================
    uint32 public constant ETHEREUM_DOMAIN = 0;
    uint32 public constant OPTIMISM_DOMAIN = 2; 
    uint32 public constant ARBITRUM_DOMAIN = 3;
    uint32 public constant BASE_DOMAIN = 6;
    
    // ==================== FAST TRANSFER CONFIG ====================
    uint32 public constant DEFAULT_MAX_FEE = 1000000; // 1 USDC max fee
    uint32 public constant SOFT_FINALITY = 1000;      // Fast Transfer
    uint32 public constant HARD_FINALITY = 2000;      // Standard Transfer
    
    // ==================== MESSAGE TRACKING ====================
    struct FastTransferData {
        address sender;
        address recipient;
        string textMessage;
        uint256[] numbers;
        uint256 amount;
        uint256 timestamp;
        uint32 destinationDomain;
        bool isFastTransfer;
        uint32 finalityThreshold;
    }
    
    // Transfer storage and tracking
    mapping(uint64 => FastTransferData) public sentTransfers; 
    uint256 public totalTransfersSent;
    
    // Default recipient for fast transfers
    bytes32 public defaultRecipient;
    
    // ==================== EVENTS ====================
    event FastTransferSent(
        uint64 indexed nonce,
        uint32 indexed destinationDomain,
        address indexed sender,
        address recipient,
        uint256 amount,
        string textMessage,
        uint256[] numbers,
        uint32 finalityThreshold
    );
    
    event FastTransferWithHookSent(
        uint64 indexed nonce,
        uint32 indexed destinationDomain,
        address indexed sender,
        uint256 amount,
        bytes hookData
    );
    
    event RecipientUpdated(bytes32 newRecipient);
    
    constructor(
        address _tokenMessengerV2,
        address _usdc,
        bytes32 _defaultRecipient
    ) Ownable(msg.sender) {
        tokenMessengerV2 = ITokenMessengerV2(_tokenMessengerV2);
        usdc = IERC20(_usdc);
        defaultRecipient = _defaultRecipient;
    }
    
    // ==================== FAST TRANSFER FUNCTIONS ====================
    
    /**
     * @dev Send Fast Transfer with custom message data to default recipient
     * @param destinationDomain Target chain domain ID
     * @param amount USDC amount to send (in wei, 6 decimals)
     * @param message Text message to include
     * @param numbers Array of numbers to include
     * @param useFastTransfer True for Fast Transfer (soft finality), False for Standard
     */
    function sendFastTransferToDefault(
        uint32 destinationDomain,
        uint256 amount,
        string calldata message,
        uint256[] calldata numbers,
        bool useFastTransfer
    ) external nonReentrant returns (uint64) {
        require(defaultRecipient != bytes32(0), "Default recipient not set");
        require(bytes(message).length > 0, "Message cannot be empty");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer USDC from sender
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.approve(address(tokenMessengerV2), amount);
        
        // Choose finality threshold
        uint32 finalityThreshold = useFastTransfer ? SOFT_FINALITY : HARD_FINALITY;
        
        // Create hook data with message information
        bytes memory hookData = abi.encode(message, numbers);
        
        // Send via CCTP V2 with hook
        uint64 nonce = tokenMessengerV2.depositForBurnWithHook(
            amount,
            destinationDomain,
            defaultRecipient,
            address(usdc),
            DEFAULT_MAX_FEE,
            finalityThreshold,
            hookData
        );
        
        // Store transfer data
        address recipientAddress = address(uint160(uint256(defaultRecipient)));
        sentTransfers[nonce] = FastTransferData({
            sender: msg.sender,
            recipient: recipientAddress,
            textMessage: message,
            numbers: numbers,
            amount: amount,
            timestamp: block.timestamp,
            destinationDomain: destinationDomain,
            isFastTransfer: useFastTransfer,
            finalityThreshold: finalityThreshold
        });
        
        totalTransfersSent++;
        
        emit FastTransferSent(
            nonce, 
            destinationDomain, 
            msg.sender, 
            recipientAddress, 
            amount, 
            message, 
            numbers, 
            finalityThreshold
        );
        
        return nonce;
    }
    
    /**
     * @dev Send Fast Transfer to specific recipient
     * @param destinationDomain Target chain domain ID
     * @param recipient Recipient address on destination chain
     * @param amount USDC amount to send
     * @param message Text message to include
     * @param numbers Array of numbers to include
     * @param useFastTransfer True for Fast Transfer, False for Standard
     */
    function sendFastTransfer(
        uint32 destinationDomain,
        address recipient,
        uint256 amount,
        string calldata message,
        uint256[] calldata numbers,
        bool useFastTransfer
    ) external nonReentrant returns (uint64) {
        require(recipient != address(0), "Invalid recipient");
        require(bytes(message).length > 0, "Message cannot be empty");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer USDC from sender
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.approve(address(tokenMessengerV2), amount);
        
        // Convert recipient to bytes32
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));
        
        // Choose finality threshold
        uint32 finalityThreshold = useFastTransfer ? SOFT_FINALITY : HARD_FINALITY;
        
        // Create hook data with message information
        bytes memory hookData = abi.encode(message, numbers);
        
        // Send via CCTP V2 with hook
        uint64 nonce = tokenMessengerV2.depositForBurnWithHook(
            amount,
            destinationDomain,
            recipientBytes32,
            address(usdc),
            DEFAULT_MAX_FEE,
            finalityThreshold,
            hookData
        );
        
        // Store transfer data
        sentTransfers[nonce] = FastTransferData({
            sender: msg.sender,
            recipient: recipient,
            textMessage: message,
            numbers: numbers,
            amount: amount,
            timestamp: block.timestamp,
            destinationDomain: destinationDomain,
            isFastTransfer: useFastTransfer,
            finalityThreshold: finalityThreshold
        });
        
        totalTransfersSent++;
        
        emit FastTransferSent(
            nonce, 
            destinationDomain, 
            msg.sender, 
            recipient, 
            amount, 
            message, 
            numbers, 
            finalityThreshold
        );
        
        return nonce;
    }
    
    /**
     * @dev Send raw hook data with Fast Transfer
     * @param destinationDomain Target chain domain ID
     * @param recipient Recipient address on destination chain
     * @param amount USDC amount to send
     * @param hookData Custom hook data
     * @param useFastTransfer True for Fast Transfer, False for Standard
     */
    function sendWithCustomHook(
        uint32 destinationDomain,
        address recipient,
        uint256 amount,
        bytes calldata hookData,
        bool useFastTransfer
    ) external nonReentrant returns (uint64) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer USDC from sender
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.approve(address(tokenMessengerV2), amount);
        
        // Convert recipient to bytes32
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));
        
        // Choose finality threshold
        uint32 finalityThreshold = useFastTransfer ? SOFT_FINALITY : HARD_FINALITY;
        
        // Send via CCTP V2 with custom hook
        uint64 nonce = tokenMessengerV2.depositForBurnWithHook(
            amount,
            destinationDomain,
            recipientBytes32,
            address(usdc),
            DEFAULT_MAX_FEE,
            finalityThreshold,
            hookData
        );
        
        emit FastTransferWithHookSent(nonce, destinationDomain, msg.sender, amount, hookData);
        
        return nonce;
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @dev Get sent transfer data by nonce
     */
    function getSentTransfer(uint64 nonce) external view returns (FastTransferData memory) {
        return sentTransfers[nonce];
    }
    
    /**
     * @dev Get total transfers sent count
     */
    function getTotalTransfersSent() external view returns (uint256) {
        return totalTransfersSent;
    }
    
    /**
     * @dev Check if user has enough USDC and allowance for transfer
     */
    function canSendTransfer(address user, uint256 amount) external view returns (bool) {
        return usdc.balanceOf(user) >= amount && usdc.allowance(user, address(this)) >= amount;
    }
    
    /**
     * @dev Get contract's USDC balance
     */
    function getContractUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Get finality thresholds
     */
    function getFinalityThresholds() external pure returns (uint32 soft, uint32 hard) {
        return (SOFT_FINALITY, HARD_FINALITY);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    /**
     * @dev Update default recipient for transfers
     */
    function updateDefaultRecipient(bytes32 newRecipient) external onlyOwner {
        defaultRecipient = newRecipient;
        emit RecipientUpdated(newRecipient);
    }
    
    /**
     * @dev Withdraw USDC from contract
     */
    function withdrawUSDC() external onlyOwner {
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