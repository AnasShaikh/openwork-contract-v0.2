// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CCTPv2Transceiver with Dynamic Gas-Based Rewards
 * @notice CCTP transceiver that pays confirmers based on actual gas costs (2x) with safety cap
 * @dev Production version with automatic dynamic reward calculation
 */

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

contract CCTPv2TransceiverWithRewardsDynamic {
    ITokenMessengerV2 public immutable tokenMessenger;
    IMessageTransmitterV2 public immutable messageTransmitter;
    IERC20 public immutable usdc;
    address public owner;
    
    // Reward config
    uint256 public maxRewardAmount;           // Safety cap (default 0.001 ETH)
    uint256 public estimatedGasUsage;         // Estimated gas for receive() (default 200k)
    uint256 public rewardMultiplier;          // Multiplier for gas cost (default 2 = 2x)
    
    // Tracking
    mapping(bytes32 => uint256) public pendingRewards;
    mapping(bytes32 => address) public confirmedBy;
    mapping(bytes32 => uint256) public confirmationTime;
    mapping(bytes32 => address) public rewardDepositor;
    mapping(bytes32 => uint256) public depositTime;
    
    uint256 public constant REFUND_TIMEOUT = 24 hours;
    uint256 public constant REWARD_TRANSFER_GAS_LIMIT = 10000;
    uint256 private locked = 1;
    
    // Events
    event FastTransferSent(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, uint256 maxFee);
    event FastTransferReceived(bytes message, bytes attestation);
    event RewardPaid(bytes32 indexed messageHash, address indexed recipient, uint256 amount);
    event RewardPaymentFailed(bytes32 indexed messageHash, address indexed recipient, uint256 amount, string reason);
    event RewardClaimed(bytes32 indexed messageHash, address indexed claimer, uint256 amount);
    event RewardRefunded(bytes32 indexed messageHash, address indexed depositor, uint256 amount);
    event RewardDeposited(bytes32 indexed messageHash, address indexed depositor, uint256 amount);
    event MaxRewardAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event EstimatedGasUpdated(uint256 oldGas, uint256 newGas);
    event RewardMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier nonReentrant() {
        require(locked == 1, "Reentrancy");
        locked = 2;
        _;
        locked = 1;
    }
    
    constructor(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc
    ) {
        tokenMessenger = ITokenMessengerV2(_tokenMessenger);
        messageTransmitter = IMessageTransmitterV2(_messageTransmitter);
        usdc = IERC20(_usdc);
        owner = msg.sender;
        maxRewardAmount = 0.001 ether;    // Safety cap
        estimatedGasUsage = 200000;       // Typical receive() gas
        rewardMultiplier = 2;             // 2x gas cost
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    function sendFast(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee
    ) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        usdc.approve(address(tokenMessenger), amount);
        
        tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdc),
            bytes32(0),
            maxFee,
            1000
        );
        
        emit FastTransferSent(amount, destinationDomain, mintRecipient, maxFee);
    }
    
    /**
     * @notice Receive CCTP transfer and pay dynamic gas-based reward
     * @dev Calculates reward as: gasUsed * tx.gasprice * 2, capped at maxRewardAmount
     */
    function receive(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant {
        bytes32 messageHash = keccak256(message);
        
        // CRITICAL: CCTP always succeeds first
        messageTransmitter.receiveMessage(message, attestation);
        emit FastTransferReceived(message, attestation);
        
        // Try to pay dynamic reward
        _tryPayReward(messageHash, msg.sender);
    }
    
    /**
     * @notice Calculate and pay dynamic reward based on actual gas cost
     * @dev Reward = min(estimatedGas * tx.gasprice * multiplier, maxRewardAmount)
     */
    function _tryPayReward(bytes32 messageHash, address recipient) private {
        // Check for specific deposited reward first
        uint256 reward = pendingRewards[messageHash];
        
        // If no specific reward, calculate dynamic reward from gas price
        if (reward == 0) {
            reward = estimatedGasUsage * tx.gasprice * rewardMultiplier;
            
            // Apply safety cap
            if (reward > maxRewardAmount) {
                reward = maxRewardAmount;
            }
        }
        
        // Skip if no balance
        if (address(this).balance < reward || reward == 0) {
            return;
        }
        
        // Mark confirmer
        confirmedBy[messageHash] = recipient;
        confirmationTime[messageHash] = block.timestamp;
        
        // Clear specific reward if exists
        if (pendingRewards[messageHash] > 0) {
            pendingRewards[messageHash] = 0;
        }
        
        // Pay reward (gas-limited)
        (bool success, ) = recipient.call{value: reward, gas: REWARD_TRANSFER_GAS_LIMIT}("");
        
        if (success) {
            emit RewardPaid(messageHash, recipient, reward);
        } else {
            pendingRewards[messageHash] = reward;
            emit RewardPaymentFailed(messageHash, recipient, reward, "Transfer failed");
        }
    }
    
    // ==================== OWNER FUNCTIONS ====================
    
    function setMaxRewardAmount(uint256 newAmount) external onlyOwner {
        uint256 oldAmount = maxRewardAmount;
        maxRewardAmount = newAmount;
        emit MaxRewardAmountUpdated(oldAmount, newAmount);
    }
    
    function setEstimatedGasUsage(uint256 newGas) external onlyOwner {
        uint256 oldGas = estimatedGasUsage;
        estimatedGasUsage = newGas;
        emit EstimatedGasUpdated(oldGas, newGas);
    }
    
    function setRewardMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier > 0 && newMultiplier <= 10, "Invalid multiplier");
        uint256 oldMultiplier = rewardMultiplier;
        rewardMultiplier = newMultiplier;
        emit RewardMultiplierUpdated(oldMultiplier, newMultiplier);
    }
    
    function fundRewardPool() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
    }
    
    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Withdraw failed");
    }
    
    function recoverUSDC(uint256 amount) external onlyOwner {
        usdc.transferFrom(address(this), owner, amount);
    }
    
    // ==================== REWARD MANAGEMENT ====================
    
    function depositReward(bytes32 messageHash) external payable {
        require(msg.value > 0, "Must deposit reward");
        pendingRewards[messageHash] += msg.value;
        rewardDepositor[messageHash] = msg.sender;
        depositTime[messageHash] = block.timestamp;
        emit RewardDeposited(messageHash, msg.sender, msg.value);
    }
    
    function claimReward(bytes32 messageHash) external nonReentrant {
        require(confirmedBy[messageHash] == msg.sender, "Not the confirmer");
        uint256 reward = pendingRewards[messageHash];
        require(reward > 0, "No reward available");
        
        pendingRewards[messageHash] = 0;
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Claim transfer failed");
        
        emit RewardClaimed(messageHash, msg.sender, reward);
    }
    
    function refundReward(bytes32 messageHash) external nonReentrant {
        require(msg.sender == rewardDepositor[messageHash], "Not the depositor");
        require(block.timestamp >= depositTime[messageHash] + REFUND_TIMEOUT, "Timeout not reached");
        
        uint256 reward = pendingRewards[messageHash];
        require(reward > 0, "No reward to refund");
        
        pendingRewards[messageHash] = 0;
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Refund transfer failed");
        
        emit RewardRefunded(messageHash, msg.sender, reward);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getPoolBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function calculateCurrentReward() external view returns (uint256) {
        uint256 reward = estimatedGasUsage * tx.gasprice * rewardMultiplier;
        return reward > maxRewardAmount ? maxRewardAmount : reward;
    }
    
    function hasPendingReward(bytes32 messageHash) external view returns (bool) {
        return pendingRewards[messageHash] > 0;
    }
    
    function getRewardInfo(bytes32 messageHash) external view returns (
        uint256 reward,
        address depositor,
        uint256 depositedAt,
        address confirmer,
        uint256 confirmedAt
    ) {
        return (
            pendingRewards[messageHash],
            rewardDepositor[messageHash],
            depositTime[messageHash],
            confirmedBy[messageHash],
            confirmationTime[messageHash]
        );
    }
    
    function canRefund(bytes32 messageHash) external view returns (bool) {
        return block.timestamp >= depositTime[messageHash] + REFUND_TIMEOUT 
            && pendingRewards[messageHash] > 0;
    }
    
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    function getMessageHash(bytes calldata message) external pure returns (bytes32) {
        return keccak256(message);
    }
    
    receive() external payable {}
}
