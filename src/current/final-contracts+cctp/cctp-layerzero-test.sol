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

contract CCTPLayerZeroTest is Ownable, ReentrancyGuard {
    IERC20 public usdcToken;
    ILayerZeroBridge public bridge;
    ITokenMessenger public tokenMessenger;
    uint32 public nativeChainDomain;
    address public escrowManager;
    
    struct Job {
        address client;
        uint256 payment;
        address selectedFreelancer;
        uint8 status; // 0: posted, 1: started, 2: completed
    }
    
    mapping(uint256 => Job) public jobs;
    uint256 public nextJobId = 1;
    
    event JobStarted(uint256 indexed jobId, address freelancer, uint256 payment, uint64 cctpNonce);
    
    constructor(
        address _usdcToken,
        address _bridge,
        address _tokenMessenger,
        uint32 _nativeChainDomain,
        address _escrowManager
    ) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        bridge = ILayerZeroBridge(_bridge);
        tokenMessenger = ITokenMessenger(_tokenMessenger);
        nativeChainDomain = _nativeChainDomain;
        escrowManager = _escrowManager;
    }
    
    // Simplified function to create a job for testing
    function createJob(uint256 payment) external returns (uint256 jobId) {
        jobId = nextJobId++;
        jobs[jobId] = Job({
            client: msg.sender,
            payment: payment,
            selectedFreelancer: address(0),
            status: 0
        });
    }
    
    // Apply to job (simplified)
    function applyToJob(uint256 jobId) external {
        jobs[jobId].selectedFreelancer = msg.sender;
    }
    
    // Core function to test: CCTP payment + LayerZero data transfer
    function startJob(uint256 jobId) external payable nonReentrant {
        Job storage job = jobs[jobId];
        
        // Minimal validation - just check job exists and has payment
        require(job.payment > 0, "Job not found");
        require(job.selectedFreelancer != address(0), "No freelancer selected");
        
        // Transfer USDC from client to this contract
        usdcToken.transferFrom(job.client, address(this), job.payment);
        
        // Approve TokenMessenger to burn USDC
        usdcToken.approve(address(tokenMessenger), job.payment);
        
        // Send USDC via CCTP to native chain escrow
        bytes32 mintRecipient = bytes32(uint256(uint160(escrowManager)));
        uint64 cctpNonce = tokenMessenger.depositForBurn(
            job.payment,
            nativeChainDomain,
            mintRecipient,
            address(usdcToken)
        );
        
        // Update job status
        job.status = 1;
        
        // Send job start data via LayerZero
        bytes memory payload = abi.encode(jobId, job.selectedFreelancer, job.payment, cctpNonce);
        bridge.sendToNativeChain{value: msg.value}(
            "startJob",
            payload,
            hex"00030100110100000000000000000000000000055730" // Fixed options
        );
        
        emit JobStarted(jobId, job.selectedFreelancer, job.payment, cctpNonce);
    }
    
    // Test helper: send USDC via CCTP directly
    function sendFast(
        uint256 amount,
        uint32 destinationDomain, 
        bytes32 mintRecipient,
        uint256 maxFee
    ) external returns (uint64) {
        require(amount > 0, "Amount must be greater than 0");
        
        usdcToken.transferFrom(msg.sender, address(this), amount);
        usdcToken.approve(address(tokenMessenger), amount);
        
        uint64 nonce = tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdcToken)
        );
        
        return nonce;
    }
}