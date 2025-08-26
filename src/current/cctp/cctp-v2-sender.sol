// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// CCTP V2 Interfaces
interface ITokenMessenger {
    function depositForBurnWithMessage(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes calldata messageBody
    ) external returns (uint64);
    
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64);
}

interface IMessageTransmitter {
    function sendMessage(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external returns (uint64);
}

contract CCTPTestSender is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ==================== CCTP V2 CONTRACTS ====================
    ITokenMessenger public tokenMessenger;
    IMessageTransmitter public messageTransmitter;
    IERC20 public usdc;
    
    // ==================== DOMAIN MAPPINGS ====================
    uint32 public constant ETHEREUM_SEPOLIA_DOMAIN = 0;
    uint32 public constant OPTIMISM_SEPOLIA_DOMAIN = 2; 
    uint32 public constant ARBITRUM_SEPOLIA_DOMAIN = 3;
    uint32 public constant BASE_SEPOLIA_DOMAIN = 6;
    
    uint32 public localDomain;
    
    // ==================== RECIPIENT MAPPING ====================
    bytes32 public receiverContract; // Receiver contract address as bytes32
    
    // ==================== EVENTS ====================
    event FastTransferSent(
        uint32 indexed destinationDomain,
        uint256 amount,
        address indexed recipient,
        uint64 nonce
    );
    
    event MessageOnlySent(
        uint32 indexed destinationDomain,
        string message,
        uint256[] numbers,
        uint64 nonce
    );
    
    event TokensWithMessageSent(
        uint32 indexed destinationDomain,
        uint256 amount,
        string message,
        uint256[] numbers,
        uint64 nonce
    );
    
    constructor(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc,
        uint32 _localDomain,
        bytes32 _receiverContract
    ) Ownable(msg.sender) {
        tokenMessenger = ITokenMessenger(_tokenMessenger);
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
        usdc = IERC20(_usdc);
        localDomain = _localDomain;
        receiverContract = _receiverContract;
    }
    
    // ==================== TEST FUNCTION 1: FAST TRANSFER ====================
    
    /**
     * @dev Test fast USDC transfer without message
     * @param amount Amount of USDC to transfer (in 6 decimals)
     * @param destinationDomain Target domain (0=Ethereum, 2=Optimism, 3=Arbitrum, 6=Base)
     * @param recipient Recipient address on destination chain
     */
    function testFastTransfer(
        uint256 amount,
        uint32 destinationDomain,
        address recipient
    ) external nonReentrant returns (uint64) {
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient");
        
        // Transfer USDC from sender to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve TokenMessenger to burn USDC
        usdc.approve(address(tokenMessenger), amount);
        
        // Convert recipient address to bytes32
        bytes32 mintRecipient = bytes32(uint256(uint160(recipient)));
        
        // Send fast transfer (USDC only, no message)
        uint64 nonce = tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdc)
        );
        
        emit FastTransferSent(destinationDomain, amount, recipient, nonce);
        return nonce;
    }
    
    // ==================== TEST FUNCTION 2: MESSAGE ONLY ====================
    
    /**
     * @dev Test sending message only (no USDC) with array data
     * @param destinationDomain Target domain
     * @param message Text message to send
     * @param numbers Array of numbers to send
     */
    function testMessageOnly(
        uint32 destinationDomain,
        string memory message,
        uint256[] memory numbers
    ) external returns (uint64) {
        require(bytes(message).length > 0, "Message cannot be empty");
        require(numbers.length > 0, "Numbers array cannot be empty");
        
        // Encode the message data
        bytes memory messageBody = abi.encode(
            "TEST_MESSAGE_ONLY",
            msg.sender,
            message,
            numbers,
            block.timestamp
        );
        
        // Send message without tokens
        uint64 nonce = messageTransmitter.sendMessage(
            destinationDomain,
            receiverContract,
            messageBody
        );
        
        emit MessageOnlySent(destinationDomain, message, numbers, nonce);
        return nonce;
    }
    
    // ==================== TEST FUNCTION 3: TOKENS WITH MESSAGE ====================
    
    /**
     * @dev Test sending USDC with message data
     * @param amount Amount of USDC to transfer
     * @param destinationDomain Target domain
     * @param message Text message to send
     * @param numbers Array of numbers to send
     */
    function testTokensWithMessage(
        uint256 amount,
        uint32 destinationDomain,
        string memory message,
        uint256[] memory numbers
    ) external nonReentrant returns (uint64) {
        require(amount > 0, "Amount must be greater than zero");
        require(bytes(message).length > 0, "Message cannot be empty");
        require(numbers.length > 0, "Numbers array cannot be empty");
        
        // Transfer USDC from sender to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve TokenMessenger to burn USDC
        usdc.approve(address(tokenMessenger), amount);
        
        // Encode the message data
        bytes memory messageBody = abi.encode(
            "TEST_TOKENS_WITH_MESSAGE",
            msg.sender,
            message,
            numbers,
            block.timestamp,
            amount
        );
        
        // Send USDC with message
        uint64 nonce = tokenMessenger.depositForBurnWithMessage(
            amount,
            destinationDomain,
            receiverContract,
            address(usdc),
            messageBody
        );
        
        emit TokensWithMessageSent(destinationDomain, amount, message, numbers, nonce);
        return nonce;
    }
    
    // ==================== DOMAIN HELPER FUNCTIONS ====================
    
    function getEthereumDomain() external pure returns (uint32) {
        return ETHEREUM_SEPOLIA_DOMAIN;
    }
    
    function getOptimismDomain() external pure returns (uint32) {
        return OPTIMISM_SEPOLIA_DOMAIN;
    }
    
    function getArbitrumDomain() external pure returns (uint32) {
        return ARBITRUM_SEPOLIA_DOMAIN;
    }
    
    function getBaseDomain() external pure returns (uint32) {
        return BASE_SEPOLIA_DOMAIN;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function updateCCTPContracts(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc
    ) external onlyOwner {
        tokenMessenger = ITokenMessenger(_tokenMessenger);
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
        usdc = IERC20(_usdc);
    }
    
    function updateReceiverContract(bytes32 _receiverContract) external onlyOwner {
        receiverContract = _receiverContract;
    }
    
    function updateLocalDomain(uint32 _localDomain) external onlyOwner {
        localDomain = _localDomain;
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getCCTPContracts() external view returns (address, address, address) {
        return (address(tokenMessenger), address(messageTransmitter), address(usdc));
    }
    
    function getUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    function getReceiverContract() external view returns (bytes32) {
        return receiverContract;
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    /**
     * @dev Convert address to bytes32 for CCTP
     */
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    /**
     * @dev Convert bytes32 back to address
     */
    function bytes32ToAddress(bytes32 b) external pure returns (address) {
        return address(uint160(uint256(b)));
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