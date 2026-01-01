// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalNativeJobReceiver is OAppReceiver {
    
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
    }
    
    // State variables
    mapping(string => Job) public jobs;
    uint256 public jobCounter;
    string[] public allJobIds;
    mapping(address => string[]) public jobsByPoster;
    
    // Events
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event MessageReceived(string functionName, address sender);
    
    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) Ownable(_owner) {
    }

    /**
     * @notice Handle incoming LayerZero messages
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used)
        bytes calldata // _extraData (not used)
    ) internal override {
        (string memory functionName) = abi.decode(_message, (string));
        
        emit MessageReceived(functionName, msg.sender);
        
        if (keccak256(bytes(functionName)) == keccak256(bytes("postJob"))) {
            (, string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(_message, (string, string, address, string, string[], uint256[]));
            _handlePostJob(jobId, jobGiver, jobDetailHash, descriptions, amounts);
        }
    }

    /**
     * @notice Internal function to handle job posting
     */
    function _handlePostJob(
        string memory jobId, 
        address jobGiver, 
        string memory jobDetailHash, 
        string[] memory descriptions, 
        uint256[] memory amounts
    ) internal {
        // Only create job if it doesn't already exist
        if (bytes(jobs[jobId].id).length == 0) {
            jobCounter++;
            allJobIds.push(jobId);
            jobsByPoster[jobGiver].push(jobId);
            
            Job storage newJob = jobs[jobId];
            newJob.id = jobId;
            newJob.jobGiver = jobGiver;
            newJob.jobDetailHash = jobDetailHash;
            newJob.status = JobStatus.Open;
            
            for (uint i = 0; i < descriptions.length; i++) {
                newJob.milestonePayments.push(MilestonePayment({
                    descriptionHash: descriptions[i],
                    amount: amounts[i]
                }));
            }
            
            emit JobPosted(jobId, jobGiver, jobDetailHash);
            emit JobStatusChanged(jobId, JobStatus.Open);
        }
    }
    
    /**
     * @notice Public function to post job directly (for testing)
     */
    function postJob(
        string memory _jobId, 
        address _jobGiver, 
        string memory _jobDetailHash, 
        string[] memory _descriptions, 
        uint256[] memory _amounts
    ) external {
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        require(_descriptions.length > 0, "Must have at least one milestone");
        
        _handlePostJob(_jobId, _jobGiver, _jobDetailHash, _descriptions, _amounts);
    }
    
    /**
     * @notice Get job details
     */
    function getJob(string memory _jobId) public view returns (Job memory) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    // View functions
    function getJobCount() external view returns (uint256) {
        return jobCounter;
    }
    
    function getAllJobIds() external view returns (string[] memory) {
        return allJobIds;
    }
    
    function getJobsByPoster(address _poster) external view returns (string[] memory) {
        return jobsByPoster[_poster];
    }
    
    function isJobOpen(string memory _jobId) external view returns (bool) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open;
    }
    
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status;
    }
    
    function jobExists(string memory _jobId) external view returns (bool) {
        return bytes(jobs[_jobId].id).length != 0;
    }
}