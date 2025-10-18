// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface INativeOpenWorkJobContract {
    function postJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external;
    function applyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts, uint32 preferredChainDomain) external;
    function startJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external;
    function getJobApplicationCount(string memory jobId) external view returns (uint256);
}

contract DirectContractManager is Ownable {
    // ==================== STATE VARIABLES ====================
    
    INativeOpenWorkJobContract public nowjc;
    address public bridge;
    
    // Counter for generating unique application IDs
    uint256 private directContractCounter;
    
    // ==================== EVENTS ====================
    
    event DirectContractStarted(
        string indexed jobId,
        address indexed jobGiver,
        address indexed jobTaker,
        uint256 applicationId,
        string jobDetailHash
    );
    event NOWJCAddressUpdated(address indexed oldNOWJC, address indexed newNOWJC);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);

    constructor(
        address _owner,
        address _nowjc,
        address _bridge
    ) Ownable(_owner) {
        require(_nowjc != address(0), "Invalid NOWJC address");
        require(_bridge != address(0), "Invalid bridge address");
        
        nowjc = INativeOpenWorkJobContract(_nowjc);
        bridge = _bridge;
        directContractCounter = 0;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setNOWJC(address _nowjc) external onlyOwner {
        require(_nowjc != address(0), "Invalid NOWJC address");
        address oldNOWJC = address(nowjc);
        nowjc = INativeOpenWorkJobContract(_nowjc);
        emit NOWJCAddressUpdated(oldNOWJC, _nowjc);
    }
    
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Invalid bridge address");
        address oldBridge = bridge;
        bridge = _bridge;
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    // ==================== DIRECT CONTRACT FUNCTIONALITY ====================
    
    /**
     * @dev Handle direct contract creation from bridge
     * This combines postJob + applyToJob + startJob into one atomic operation
     */
    function handleStartDirectContract(
        address _jobGiver,
        address _jobTaker,
        string memory _jobId,
        string memory _jobDetailHash,
        string[] memory _descriptions,
        uint256[] memory _amounts,
        uint32 _jobTakerChainDomain
    ) external {
        require(msg.sender == bridge, "Only bridge can call");
        require(_jobGiver != address(0), "Invalid job giver");
        require(_jobTaker != address(0), "Invalid job taker");
        require(_descriptions.length > 0, "Must have milestones");
        require(_descriptions.length == _amounts.length, "Length mismatch");
        
        // Step 1: Post the job via NOWJC
        nowjc.postJob(_jobId, _jobGiver, _jobDetailHash, _descriptions, _amounts);
        
        // Step 2: Create auto-application for the job taker
        string memory autoApplicationHash = "direct-contract-auto-application";
        nowjc.applyToJob(_jobTaker, _jobId, autoApplicationHash, _descriptions, _amounts, _jobTakerChainDomain);
        
        // Step 3: Get the application ID (should be 1 for direct contracts)
        uint256 applicationId = nowjc.getJobApplicationCount(_jobId);
        
        // Step 4: Start the job with the auto-application
        nowjc.startJob(_jobGiver, _jobId, applicationId, false); // false = use job giver's milestones
        
        // Increment counter for tracking
        directContractCounter++;
        
        emit DirectContractStarted(_jobId, _jobGiver, _jobTaker, applicationId, _jobDetailHash);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getDirectContractCount() external view returns (uint256) {
        return directContractCounter;
    }
    
    function getNOWJCAddress() external view returns (address) {
        return address(nowjc);
    }
    
    function getBridgeAddress() external view returns (address) {
        return bridge;
    }
}