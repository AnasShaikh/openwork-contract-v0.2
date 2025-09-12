// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface INativeBridge {
    function lzReceive(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes calldata _payload
    ) external;
}

interface IMessageTransmitter {
    function receiveMessage(bytes calldata message, bytes calldata attestation)
        external
        returns (bool success);
}

/**
 * @title CCTP + LayerZero Receiver (Optimism)
 * @dev Simplified contract to receive cross-chain job data and CCTP payments
 */
contract CCTPLayerZeroReceiver is Ownable, ReentrancyGuard {
    IERC20 public usdcToken;
    INativeBridge public bridge;
    IMessageTransmitter public messageTransmitter;
    address public authorizedSender; // Sender contract address on Arbitrum
    
    struct ReceivedJob {
        uint256 jobId;
        address client;
        address freelancer;
        uint256 payment;
        uint64 cctpNonce;
        bool messageReceived;
        bool paymentReceived;
        uint256 receivedTimestamp;
    }
    
    mapping(uint256 => ReceivedJob) public receivedJobs;
    mapping(uint64 => bool) public processedCCTPNonces;
    
    // Escrow balances
    mapping(address => uint256) public escrowBalances;
    uint256 public totalEscrowBalance;
    
    event JobStartReceived(
        uint256 indexed jobId,
        address client,
        address freelancer,
        uint256 payment,
        uint64 cctpNonce
    );
    event CCTPPaymentReceived(uint64 indexed nonce, uint256 amount, address recipient);
    event TestMessageReceived(string message, address sender, uint256 timestamp);
    event PaymentReleased(uint256 indexed jobId, address freelancer, uint256 amount);
    
    constructor(
        address _usdcToken,
        address _bridge,
        address _messageTransmitter,
        address _authorizedSender
    ) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        bridge = INativeBridge(_bridge);
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
        authorizedSender = _authorizedSender;
    }
    
    /**
     * @dev Receive job start data from LayerZero
     * Called by the bridge when a message arrives from Arbitrum
     */
    function receiveJobStart(bytes calldata payload) external {
        require(msg.sender == address(bridge), "Unauthorized: must be bridge");
        
        (
            uint256 jobId,
            address client,
            address freelancer,
            uint256 payment,
            uint64 cctpNonce
        ) = abi.decode(payload, (uint256, address, address, uint256, uint64));
        
        receivedJobs[jobId] = ReceivedJob({
            jobId: jobId,
            client: client,
            freelancer: freelancer,
            payment: payment,
            cctpNonce: cctpNonce,
            messageReceived: true,
            paymentReceived: false,
            receivedTimestamp: block.timestamp
        });
        
        emit JobStartReceived(jobId, client, freelancer, payment, cctpNonce);
    }
    
    /**
     * @dev Receive test message from LayerZero
     */
    function receiveTestMessage(bytes calldata payload) external {
        require(msg.sender == address(bridge), "Unauthorized: must be bridge");
        
        (string memory message, address sender, uint256 timestamp) = 
            abi.decode(payload, (string, address, uint256));
        
        emit TestMessageReceived(message, sender, timestamp);
    }
    
    /**
     * @dev Receive CCTP payment (called manually after getting attestation)
     * This simulates the CCTP message + attestation flow
     */
    function receiveCCTPPayment(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant {
        // Call the CCTP MessageTransmitter to mint USDC
        bool success = messageTransmitter.receiveMessage(message, attestation);
        require(success, "CCTP message processing failed");
        
        // Extract nonce from message for tracking
        // In a real implementation, you'd properly decode the CCTP message
        // For testing, we'll use a simplified approach
        emit CCTPPaymentReceived(0, 0, address(this));
    }
    
    /**
     * @dev Simplified CCTP receive function for testing
     * In real usage, this would be called by the CCTP MessageTransmitter
     */
    function simulateCCTPReceive(
        uint256 jobId,
        uint256 amount,
        uint64 nonce
    ) external {
        require(!processedCCTPNonces[nonce], "CCTP nonce already processed");
        
        // Mark nonce as processed
        processedCCTPNonces[nonce] = true;
        
        // Update job payment status if job exists
        if (receivedJobs[jobId].messageReceived) {
            receivedJobs[jobId].paymentReceived = true;
            
            // Add to escrow for the freelancer
            escrowBalances[receivedJobs[jobId].freelancer] += amount;
            totalEscrowBalance += amount;
        }
        
        emit CCTPPaymentReceived(nonce, amount, address(this));
    }
    
    /**
     * @dev Release payment to freelancer (simplified)
     */
    function releasePayment(uint256 jobId) external nonReentrant {
        ReceivedJob storage job = receivedJobs[jobId];
        require(job.messageReceived, "Job message not received");
        require(job.paymentReceived, "Payment not received via CCTP");
        require(escrowBalances[job.freelancer] >= job.payment, "Insufficient escrow balance");
        
        // Transfer USDC from escrow to freelancer
        escrowBalances[job.freelancer] -= job.payment;
        totalEscrowBalance -= job.payment;
        
        usdcToken.transfer(job.freelancer, job.payment);
        
        emit PaymentReleased(jobId, job.freelancer, job.payment);
    }
    
    /**
     * @dev Check if job is ready for payment release
     */
    function isJobReadyForRelease(uint256 jobId) external view returns (bool) {
        ReceivedJob memory job = receivedJobs[jobId];
        return job.messageReceived && 
               job.paymentReceived && 
               escrowBalances[job.freelancer] >= job.payment;
    }
    
    /**
     * @dev Get received job details
     */
    function getReceivedJob(uint256 jobId) external view returns (ReceivedJob memory) {
        return receivedJobs[jobId];
    }
    
    /**
     * @dev Check escrow balance for a freelancer
     */
    function getEscrowBalance(address freelancer) external view returns (uint256) {
        return escrowBalances[freelancer];
    }
    
    // Admin functions
    function updateAuthorizedSender(address _newSender) external onlyOwner {
        authorizedSender = _newSender;
    }
    
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        usdcToken.transfer(owner(), amount);
    }
}