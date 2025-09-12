// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ILayerZeroBridge {
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
}

interface ITokenMessenger {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

/**
 * @title CCTP + LayerZero Sender (Arbitrum)
 * @dev Simplified contract to test cross-chain job start with CCTP payment and LayerZero messaging
 */
contract CCTPLayerZeroSender is Ownable, ReentrancyGuard {
    IERC20 public usdcToken;
    ILayerZeroBridge public bridge;
    ITokenMessenger public tokenMessenger;
    uint32 public nativeChainDomain; // Optimism domain = 2
    address public receiverContract; // Receiver contract on Optimism
    
    struct Job {
        address client;
        uint256 payment;
        address selectedFreelancer;
        uint8 status; // 0: posted, 1: started, 2: completed
    }
    
    mapping(uint256 => Job) public jobs;
    uint256 public nextJobId = 1;
    
    event JobCreated(uint256 indexed jobId, address client, uint256 payment);
    event JobStarted(uint256 indexed jobId, address freelancer, uint256 payment, uint64 cctpNonce);
    event CCTPTransferSent(uint64 indexed nonce, uint256 amount, address recipient);
    
    constructor(
        address _usdcToken,
        address _bridge,
        address _tokenMessenger,
        uint32 _nativeChainDomain,
        address _receiverContract
    ) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        bridge = ILayerZeroBridge(_bridge);
        tokenMessenger = ITokenMessenger(_tokenMessenger);
        nativeChainDomain = _nativeChainDomain;
        receiverContract = _receiverContract;
    }
    
    /**
     * @dev Create a job for testing (simplified)
     */
    function createJob(uint256 payment) external returns (uint256 jobId) {
        jobId = nextJobId++;
        jobs[jobId] = Job({
            client: msg.sender,
            payment: payment,
            selectedFreelancer: address(0),
            status: 0
        });
        
        emit JobCreated(jobId, msg.sender, payment);
    }
    
    /**
     * @dev Apply to job (simplified - auto-selects applicant)
     */
    function applyToJob(uint256 jobId) external {
        require(jobs[jobId].payment > 0, "Job not found");
        jobs[jobId].selectedFreelancer = msg.sender;
    }
    
    /**
     * @dev Core test function: Send USDC via CCTP + Job data via LayerZero
     * This is the key functionality we want to test
     */
    function startJob(uint256 jobId) external payable nonReentrant {
        Job storage job = jobs[jobId];
        
        // Minimal validation for testing
        require(job.payment > 0, "Job not found");
        require(job.selectedFreelancer != address(0), "No freelancer selected");
        require(job.status == 0, "Job already started");
        
        // Step 1: Transfer USDC from client to this contract
        usdcToken.transferFrom(job.client, address(this), job.payment);
        
        // Step 2: Approve TokenMessenger to burn USDC
        usdcToken.approve(address(tokenMessenger), job.payment);
        
        // Step 3: Send USDC via CCTP to receiver contract on Optimism
        bytes32 mintRecipient = bytes32(uint256(uint160(receiverContract)));
        uint64 cctpNonce = tokenMessenger.depositForBurn(
            job.payment,
            nativeChainDomain,
            mintRecipient,
            address(usdcToken)
        );
        
        // Step 4: Update job status
        job.status = 1;
        
        // Step 5: Send job start data via LayerZero to receiver
        bytes memory payload = abi.encode(
            jobId,
            job.client,
            job.selectedFreelancer,
            job.payment,
            cctpNonce
        );
        
        bridge.sendToNativeChain{value: msg.value}(
            "receiveJobStart",
            payload,
            hex"00030100110100000000000000000000000000055730" // Fixed LayerZero options
        );
        
        emit JobStarted(jobId, job.selectedFreelancer, job.payment, cctpNonce);
        emit CCTPTransferSent(cctpNonce, job.payment, receiverContract);
    }
    
    /**
     * @dev Direct CCTP test function
     */
    function sendUSDCDirect(
        uint256 amount,
        address recipient
    ) external returns (uint64) {
        require(amount > 0, "Amount must be greater than 0");
        
        usdcToken.transferFrom(msg.sender, address(this), amount);
        usdcToken.approve(address(tokenMessenger), amount);
        
        bytes32 mintRecipient = bytes32(uint256(uint160(recipient)));
        uint64 nonce = tokenMessenger.depositForBurn(
            amount,
            nativeChainDomain,
            mintRecipient,
            address(usdcToken)
        );
        
        emit CCTPTransferSent(nonce, amount, recipient);
        return nonce;
    }
    
    /**
     * @dev Direct LayerZero test function
     */
    function sendMessageDirect(string memory message) external payable {
        bytes memory payload = abi.encode(message, msg.sender, block.timestamp);
        
        bridge.sendToNativeChain{value: msg.value}(
            "receiveTestMessage",
            payload,
            hex"00030100110100000000000000000000000000055730"
        );
    }
    
    // Admin functions
    function updateReceiverContract(address _newReceiver) external onlyOwner {
        receiverContract = _newReceiver;
    }
    
    function getJob(uint256 jobId) external view returns (Job memory) {
        return jobs[jobId];
    }
}