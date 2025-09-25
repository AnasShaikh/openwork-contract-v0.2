// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NativeOpenWorkJobContract is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    enum JobStatus {
        Open,
        InProgress,
        Completed,
        Cancelled
    }
    
    struct MilestonePayment {
        string descriptionHash;
        uint256 amount;
    }
    
    struct Job {
        string id;
        address jobGiver;
        string jobDetailHash;
        JobStatus status;
        MilestonePayment[] milestonePayments;
        uint256 totalPaid;
        uint256 currentMilestone;
    }

    // ==================== STATE VARIABLES ====================
    
    // Self-contained storage
    mapping(string => Job) public jobs;
    string[] public allJobIds;
    uint256 public jobCount;
    
    // Bridge reference
    address public bridge;
    mapping(address => bool) public authorizedContracts;

    // ==================== EVENTS ====================
    
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);

    // ==================== MODIFIERS ====================
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    // ==================== INITIALIZER ====================
    
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    // ==================== UPGRADE AUTHORIZATION ====================
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
    }
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
    }

    // ==================== CORE FUNCTIONS ====================
    
    function postJob(
        string memory _jobId, 
        address _jobGiver, 
        string memory _jobDetailHash, 
        string[] memory _descriptions, 
        uint256[] memory _amounts,
        uint32 _posterChainDomain,
        address _posterAddress
    ) external onlyAuthorized {
        require(bytes(jobs[_jobId].id).length == 0, "Job ID already exists");
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        // Store job data internally
        Job storage newJob = jobs[_jobId];
        newJob.id = _jobId;
        newJob.jobGiver = _jobGiver;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        
        // Store milestone payments
        for (uint i = 0; i < _descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        // Update tracking arrays
        allJobIds.push(_jobId);
        jobCount++;
        
        emit JobPosted(_jobId, _jobGiver, _jobDetailHash);
        emit JobStatusChanged(_jobId, JobStatus.Open);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        return jobs[_jobId];
    }
    
    function jobExists(string memory _jobId) public view returns (bool) {
        return bytes(jobs[_jobId].id).length > 0;
    }
    
    function getJobCount() public view returns (uint256) {
        return jobCount;
    }
    
    function getAllJobIds() public view returns (string[] memory) {
        return allJobIds;
    }
}