// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MinimalCrossChainJobPoster is OAppSender, ReentrancyGuard {
    
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
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
    
    uint32 public immutable chainId;
    uint32 public nativeChainEid;     // Chain where NativeJobContract is deployed
    
    // Events
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    
    constructor(
        address _endpoint,
        address _owner, 
        uint32 _chainId,
        uint32 _nativeChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        chainId = _chainId;
        nativeChainEid = _nativeChainEid;
    }
    
    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }
    
    /**
     * @notice Update native chain endpoint (admin function)
     */
    function updateNativeChainEndpoint(uint32 _nativeChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
    }
    
    /**
     * @notice Post a job with milestones
     */
    function postJob(
        string memory _jobDetailHash, 
        string[] memory _descriptions, 
        uint256[] memory _amounts,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(_descriptions.length > 0, "Must have at least one milestone");
        require(_descriptions.length == _amounts.length, "Descriptions and amounts length mismatch");
        
        uint256 calculatedTotal = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            calculatedTotal += _amounts[i];
        }
        require(calculatedTotal > 0, "Total amount must be greater than 0");
        
        string memory jobId = string(abi.encodePacked(Strings.toString(chainId), "-", Strings.toString(++jobCounter)));
        
        Job storage newJob = jobs[jobId];
        newJob.id = jobId;
        newJob.jobGiver = msg.sender;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        // Send to native chain
        bytes memory payload = abi.encode("postJob", jobId, msg.sender, _jobDetailHash, _descriptions, _amounts);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobPosted(jobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(jobId, JobStatus.Open);
        emit CrossChainMessageSent("postJob", nativeChainEid, payload);
    }
    
    /**
     * @notice Get job details
     */
    function getJob(string memory _jobId) public view returns (Job memory) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    /**
     * @notice Quote the fee for posting a job
     */
    function quotePostJob(
        string memory _jobDetailHash,
        string[] memory _descriptions,
        uint256[] memory _amounts,
        bytes calldata _nativeOptions
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode("postJob", "temp-id", msg.sender, _jobDetailHash, _descriptions, _amounts);
        MessagingFee memory msgFee = _quote(nativeChainEid, payload, _nativeOptions, false);
        return msgFee.nativeFee;
    }
    
    // View functions
    function getJobCount() external view returns (uint256) { 
        return jobCounter; 
    }
    
    function isJobOpen(string memory _jobId) external view returns (bool) { 
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open; 
    }
    
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status;
    }
    
    // Admin functions
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}