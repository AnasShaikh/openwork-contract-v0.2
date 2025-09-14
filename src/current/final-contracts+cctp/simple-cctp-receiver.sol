// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// CCTP V2 Interface for OP Sepolia - SIMPLE VERSION
interface IMessageTransmitterV2 {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external;
}

contract SimpleCCTPReceiver is Ownable {
    using SafeERC20 for IERC20;
    
    // ==================== STATE VARIABLES ====================
    
    IERC20 public immutable usdtToken;
    IMessageTransmitterV2 public immutable messageTransmitter;
    address public immutable nowjcContract;
    
    // Tracking CCTP transfers
    mapping(bytes32 => bool) public processedMessages;
    uint256 public totalReceived;
    uint256 public totalWithdrawn;
    
    // ==================== EVENTS ====================
    
    event FundsReceived(bytes32 indexed messageHash, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    
    constructor(
        address _owner,
        address _usdtToken,
        address _messageTransmitter,
        address _nowjcContract
    ) Ownable(_owner) {
        usdtToken = IERC20(_usdtToken);
        messageTransmitter = IMessageTransmitterV2(_messageTransmitter);
        nowjcContract = _nowjcContract;
    }
    
    // ==================== MAIN FUNCTIONS ====================
    
    /**
     * @dev Receive CCTP message and complete cross-chain USDT transfer
     * Can be called by anyone once CCTP attestation is available
     */
    function receiveFunds(
        bytes calldata _message,
        bytes calldata _attestation
    ) external {
        bytes32 messageHash = keccak256(_message);
        require(!processedMessages[messageHash], "Message already processed");
        
        // Get USDT balance before
        uint256 balanceBefore = usdtToken.balanceOf(address(this));
        
        // Complete CCTP transfer - using proven pattern from working contracts
        messageTransmitter.receiveMessage(_message, _attestation);
        
        // Get USDT balance after
        uint256 balanceAfter = usdtToken.balanceOf(address(this));
        require(balanceAfter > balanceBefore, "No USDT received");
        
        uint256 receivedAmount = balanceAfter - balanceBefore;
        
        // Mark message as processed
        processedMessages[messageHash] = true;
        totalReceived += receivedAmount;
        
        emit FundsReceived(messageHash, receivedAmount);
    }
    
    /**
     * @dev Withdraw funds to recipient
     * Called by nowjc contract when releasing payments to job takers
     */
    function withdrawFunds(address _to, uint256 _amount) external {
        require(msg.sender == nowjcContract, "Only nowjc contract can call");
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than zero");
        
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance >= _amount, "Insufficient USDT balance");
        
        // Transfer USDT to recipient
        usdtToken.safeTransfer(_to, _amount);
        totalWithdrawn += _amount;
        
        emit FundsWithdrawn(_to, _amount);
    }
    
    /**
     * @dev Emergency function to withdraw specific amount to any address
     * Only callable by nowjc contract for dispute resolution or special cases
     */
    function emergencyWithdraw(address _to, uint256 _amount) external {
        require(msg.sender == nowjcContract, "Only nowjc contract can call");
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than zero");
        
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance >= _amount, "Insufficient USDT balance");
        
        usdtToken.safeTransfer(_to, _amount);
        totalWithdrawn += _amount;
        
        emit FundsWithdrawn(_to, _amount);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getUSDTBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
    
    function getAvailableBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
    
    function getTotalStats() external view returns (
        uint256 received,
        uint256 withdrawn,
        uint256 available
    ) {
        return (
            totalReceived,
            totalWithdrawn,
            usdtToken.balanceOf(address(this))
        );
    }
    
    function isMessageProcessed(bytes32 _messageHash) external view returns (bool) {
        return processedMessages[_messageHash];
    }
    
    function isMessageProcessedFromData(bytes calldata _message) external view returns (bool) {
        bytes32 messageHash = keccak256(_message);
        return processedMessages[messageHash];
    }
    
    function getMessageHash(bytes calldata _message) external pure returns (bytes32) {
        return keccak256(_message);
    }
    
    function getCCTPConfig() external view returns (
        address messageTransmitterAddr,
        address usdtTokenAddr,
        address nowjcContractAddr
    ) {
        return (
            address(messageTransmitter),
            address(usdtToken),
            nowjcContract
        );
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function adminWithdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT balance to withdraw");
        usdtToken.safeTransfer(owner(), balance);
        totalWithdrawn += balance;
        emit FundsWithdrawn(owner(), balance);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance to withdraw");
        payable(owner()).transfer(balance);
    }
}