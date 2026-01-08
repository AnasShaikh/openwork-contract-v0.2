// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CCTPv2Transceiver with Dynamic Gas-Based Rewards
 * @notice CCTP transceiver that pays confirmers based on actual gas costs (2x) with safety cap
 * @dev Production version with automatic dynamic reward calculation
 */

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
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

contract CCTPTransceiver {
    ITokenMessengerV2 public immutable tokenMessenger;
    IMessageTransmitterV2 public immutable messageTransmitter;
    IERC20 public immutable usdc;
    address public owner;

    // Governance/Admin pattern
    mapping(address => bool) public admins;

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

    // Replay protection (defense-in-depth)
    mapping(bytes32 => bool) public processedMessages;
    
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
    event AdminUpdated(address indexed admin, bool status);
    
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
        admins[msg.sender] = true;        // Owner is default admin
    }
    
    /// @notice Transfer ownership of the contract to a new address
    /// @param newOwner Address of the new owner
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Send USDC cross-chain via CCTP fast transfer
    /// @param amount Amount of USDC to send
    /// @param destinationDomain CCTP domain ID of the destination chain
    /// @param mintRecipient Recipient address on destination chain (as bytes32)
    /// @param maxFee Maximum fee to pay for the transfer
    function sendFast(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee
    ) external {
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");
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

        // Defense-in-depth replay protection
        require(!processedMessages[messageHash], "Already processed");
        processedMessages[messageHash] = true;

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
    
    // ==================== ADMIN MANAGEMENT ====================

    /// @notice Set admin status for an address
    /// @param _admin Address to modify
    /// @param _status True to grant admin, false to revoke
    function setAdmin(address _admin, bool _status) external onlyOwner {
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    // ==================== REWARD CONFIG (ADMIN ONLY) ====================

    /// @notice Set the maximum reward amount for confirmers
    /// @param newAmount New maximum reward in wei
    function setMaxRewardAmount(uint256 newAmount) external {
        require(admins[msg.sender], "Only admin");
        uint256 oldAmount = maxRewardAmount;
        maxRewardAmount = newAmount;
        emit MaxRewardAmountUpdated(oldAmount, newAmount);
    }

    /// @notice Set the estimated gas usage for reward calculations
    /// @param newGas New gas estimate for receive function
    function setEstimatedGasUsage(uint256 newGas) external {
        require(admins[msg.sender], "Only admin");
        uint256 oldGas = estimatedGasUsage;
        estimatedGasUsage = newGas;
        emit EstimatedGasUpdated(oldGas, newGas);
    }

    /// @notice Set the reward multiplier for gas-based reward calculations
    /// @param newMultiplier New multiplier (1-10x gas cost)
    function setRewardMultiplier(uint256 newMultiplier) external {
        require(admins[msg.sender], "Only admin");
        require(newMultiplier > 0 && newMultiplier <= 10, "Invalid");
        uint256 oldMultiplier = rewardMultiplier;
        rewardMultiplier = newMultiplier;
        emit RewardMultiplierUpdated(oldMultiplier, newMultiplier);
    }

    /// @notice Add ETH to the reward pool for paying confirmers
    function fundRewardPool() external payable {
        require(admins[msg.sender], "Only admin");
        require(msg.value > 0, "Must send ETH");
    }

    /// @notice Withdraw ETH from the contract
    /// @param amount Amount of ETH to withdraw
    function withdrawETH(uint256 amount) external {
        require(admins[msg.sender], "Only admin");
        require(address(this).balance >= amount, "Insufficient");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Failed");
    }

    /// @notice Recover stuck USDC from the contract
    /// @param amount Amount of USDC to recover
    function recoverUSDC(uint256 amount) external {
        require(admins[msg.sender], "Only admin");
        require(usdc.transfer(msg.sender, amount), "Transfer failed");
    }

    // ==================== REWARD MANAGEMENT ====================

    /// @notice Deposit a reward for a specific message hash
    /// @param messageHash The keccak256 hash of the CCTP message
    function depositReward(bytes32 messageHash) external payable {
        require(msg.value > 0, "Must deposit reward");
        pendingRewards[messageHash] += msg.value;
        rewardDepositor[messageHash] = msg.sender;
        depositTime[messageHash] = block.timestamp;
        emit RewardDeposited(messageHash, msg.sender, msg.value);
    }
    
    /// @notice Claim a pending reward as the confirmed message relayer
    /// @param messageHash The keccak256 hash of the CCTP message
    function claimReward(bytes32 messageHash) external nonReentrant {
        require(confirmedBy[messageHash] == msg.sender, "Not the confirmer");
        uint256 reward = pendingRewards[messageHash];
        require(reward > 0, "No reward available");

        pendingRewards[messageHash] = 0;
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Claim transfer failed");

        emit RewardClaimed(messageHash, msg.sender, reward);
    }

    /// @notice Refund a deposited reward if message not confirmed within timeout
    /// @param messageHash The keccak256 hash of the CCTP message
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

    /// @notice Get the current ETH balance of the reward pool
    /// @return Current balance in wei
    function getPoolBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Calculate the current dynamic reward based on gas price
    /// @return Calculated reward amount in wei (capped at maxRewardAmount)
    function calculateCurrentReward() external view returns (uint256) {
        uint256 reward = estimatedGasUsage * tx.gasprice * rewardMultiplier;
        return reward > maxRewardAmount ? maxRewardAmount : reward;
    }
    
    /// @notice Check if a message has a pending reward
    /// @param messageHash The keccak256 hash of the CCTP message
    /// @return True if reward is pending
    function hasPendingReward(bytes32 messageHash) external view returns (bool) {
        return pendingRewards[messageHash] > 0;
    }

    /// @notice Get detailed reward information for a message
    /// @param messageHash The keccak256 hash of the CCTP message
    /// @return reward Pending reward amount
    /// @return depositor Address that deposited the reward
    /// @return depositedAt Timestamp when reward was deposited
    /// @return confirmer Address that confirmed the message
    /// @return confirmedAt Timestamp when message was confirmed
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
    
    /// @notice Check if a reward can be refunded (timeout passed)
    /// @param messageHash The keccak256 hash of the CCTP message
    /// @return True if refund is available
    function canRefund(bytes32 messageHash) external view returns (bool) {
        return block.timestamp >= depositTime[messageHash] + REFUND_TIMEOUT
            && pendingRewards[messageHash] > 0;
    }

    /// @notice Convert an address to bytes32 format for CCTP
    /// @param addr Address to convert
    /// @return Address as bytes32
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    /// @notice Get the keccak256 hash of a CCTP message
    /// @param message The CCTP message bytes
    /// @return The keccak256 hash
    function getMessageHash(bytes calldata message) external pure returns (bytes32) {
        return keccak256(message);
    }

    /// @notice Receive ETH for the reward pool
    receive() external payable {}
}
