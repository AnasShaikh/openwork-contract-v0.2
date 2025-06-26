// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IRewardsTrackingContract {
    function updateRewards(uint256 jobId, uint256 paidAmountUSDT, uint256 totalPlatformPayments) external;
}

contract NativeOpenWorkJobContract is OApp {
    enum JobStatus {
        Open,           // Job posted, accepting applications
        InProgress,     // Job started, work in progress
        Completed,      // All milestones completed
        Cancelled       // Job cancelled
    }
    
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
        string[] portfolioHashes;
    }
    
    struct MilestonePayment {
        string descriptionHash;
        uint256 amount;
    }
    
    struct Application {
        uint256 id;
        uint256 jobId;
        address applicant;
        string applicationHash;
        MilestonePayment[] proposedMilestones;
    }
    
    struct Job {
        uint256 id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        JobStatus status;
        string[] workSubmissions;
        MilestonePayment[] milestonePayments;
        MilestonePayment[] finalMilestones;
        uint256 totalPaid;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
    }
    
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => mapping(uint256 => Application)) public jobApplications;
    mapping(uint256 => uint256) public jobApplicationCounter;
    mapping(uint256 => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public jobCounter;
    uint256 public totalPlatformPayments;
    
    // Cross-chain execution tracking
    mapping(bytes32 => bool) public executedMessages;
    
    // Access control for multiple local contracts
    mapping(uint32 => mapping(bytes32 => bool)) public authorizedLocalContracts;
    
    IRewardsTrackingContract public rewardsContract;
    
    event ProfileCreated(address indexed user, string ipfsHash, address referrer);
    event JobPosted(uint256 indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobApplication(uint256 indexed jobId, uint256 indexed applicationId, address indexed applicant, string applicationHash);
    event JobStarted(uint256 indexed jobId, uint256 indexed applicationId, address indexed selectedApplicant, bool useApplicantMilestones);
    event WorkSubmitted(uint256 indexed jobId, address indexed applicant, string submissionHash, uint256 milestone);
    event PaymentReleased(uint256 indexed jobId, address indexed jobGiver, address indexed applicant, uint256 amount, uint256 milestone);
    event MilestoneLocked(uint256 indexed jobId, uint256 newMilestone, uint256 lockedAmount);
    event UserRated(uint256 indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event CrossChainMessageReceived(bytes32 indexed messageId, string indexed messageType, address indexed executor);
    event LocalContractAuthorized(uint32 indexed eid, bytes32 indexed localContract);
    event LocalContractDeauthorized(uint32 indexed eid, bytes32 indexed localContract);
    event JobStatusChanged(uint256 indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(uint256 indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}
    
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        rewardsContract = IRewardsTrackingContract(_rewardsContract);
    }
    
    // Access control functions for multiple local contracts
    function addAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
        authorizedLocalContracts[_eid][_localContract] = true;
        emit LocalContractAuthorized(_eid, _localContract);
    }
    
    function removeAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
        authorizedLocalContracts[_eid][_localContract] = false;
        emit LocalContractDeauthorized(_eid, _localContract);
    }
    
    function isAuthorizedLocal(uint32 _eid, bytes32 _localContract) external view returns (bool) {
        return authorizedLocalContracts[_eid][_localContract];
    }
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        // Prevent replay attacks
        require(!executedMessages[_guid], "Message already executed");
        executedMessages[_guid] = true;
        
        // Verify sender is authorized
        require(authorizedLocalContracts[_origin.srcEid][_origin.sender], "Unauthorized local contract");
        
        string memory messageType = abi.decode(payload, (string));
        
        emit CrossChainMessageReceived(_guid, messageType, msg.sender);
        
        if (keccak256(bytes(messageType)) == keccak256(bytes("CREATE_PROFILE"))) {
            (, address user, string memory ipfsHash, address referrerAddress) = 
                abi.decode(payload, (string, address, string, address));
            createProfile(user, ipfsHash, referrerAddress);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("POST_JOB"))) {
            (, address jobGiver, string memory jobDetailHash, MilestonePayment[] memory milestonePayments, uint256 totalValue) = 
                abi.decode(payload, (string, address, string, MilestonePayment[], uint256));
            postJob(jobGiver, jobDetailHash, milestonePayments, totalValue);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("APPLY_TO_JOB"))) {
            (, address applicant, uint256 jobId, string memory applicationHash, MilestonePayment[] memory proposedMilestones) = 
                abi.decode(payload, (string, address, uint256, string, MilestonePayment[]));
            applyToJob(applicant, jobId, applicationHash, proposedMilestones);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("START_JOB"))) {
            (, address jobGiver, uint256 applicationId, bool useApplicantMilestones) = 
                abi.decode(payload, (string, address, uint256, bool));
            startJob(jobGiver, applicationId, useApplicantMilestones);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("SUBMIT_WORK"))) {
            (, address applicant, uint256 jobId, string memory submissionHash) = 
                abi.decode(payload, (string, address, uint256, string));
            submitWork(applicant, jobId, submissionHash);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("RELEASE_PAYMENT"))) {
            (, address jobGiver, uint256 jobId, uint256 amount) = 
                abi.decode(payload, (string, address, uint256, uint256));
            releasePayment(jobGiver, jobId, amount);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("LOCK_NEXT_MILESTONE"))) {
            (, address caller, uint256 jobId, uint256 lockedAmount) = 
                abi.decode(payload, (string, address, uint256, uint256));
            lockNextMilestone(caller, jobId, lockedAmount);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("RATE_USER"))) {
            (, address rater, uint256 jobId, address userToRate, uint256 rating) = 
                abi.decode(payload, (string, address, uint256, address, uint256));
            rate(rater, jobId, userToRate, rating);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("ADD_PORTFOLIO"))) {
            (, address user, string memory portfolioHash) = 
                abi.decode(payload, (string, address, string));
            addPortfolio(user, portfolioHash);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("RELEASE_AND_LOCK"))) {
            (, address jobGiver, uint256 jobId, uint256 releasedAmount, uint256 lockedAmount) = 
                abi.decode(payload, (string, address, uint256, uint256, uint256));
            releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount);
        }
    }
    
    function createProfile(string memory _ipfsHash, address _referrerAddress) public {
        createProfile(msg.sender, _ipfsHash, _referrerAddress);
    }
    
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) public {
        require(!hasProfile[_user], "Profile already exists");
        
        profiles[_user] = Profile({
            userAddress: _user,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        
        hasProfile[_user] = true;
        
        emit ProfileCreated(_user, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    function postJob(string memory _jobDetailHash, MilestonePayment[] memory _milestonePayments) public {
        postJob(msg.sender, _jobDetailHash, _milestonePayments, 0);
    }
    
    function postJob(address _jobGiver, string memory _jobDetailHash, MilestonePayment[] memory _milestonePayments, uint256 _totalValue) public {
        require(hasProfile[_jobGiver], "Must have profile to post job");
        require(_milestonePayments.length > 0, "Must have at least one milestone");
        
        jobCounter++;
        Job storage newJob = jobs[jobCounter];
        newJob.id = jobCounter;
        newJob.jobGiver = _jobGiver;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        newJob.totalPaid = 0;
        newJob.currentMilestone = 0;
        newJob.selectedApplicant = address(0);
        newJob.selectedApplicationId = 0;
        
        for (uint i = 0; i < _milestonePayments.length; i++) {
            newJob.milestonePayments.push(_milestonePayments[i]);
        }
        
        emit JobPosted(jobCounter, _jobGiver, _jobDetailHash);
        emit JobStatusChanged(jobCounter, JobStatus.Open);
    }
    
    function getJob(uint256 _jobId) public view returns (Job memory) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    function applyToJob(uint256 _jobId, string memory _applicationHash, MilestonePayment[] memory _proposedMilestones) public {
        applyToJob(msg.sender, _jobId, _applicationHash, _proposedMilestones);
    }
    
    function applyToJob(address _applicant, uint256 _jobId, string memory _applicationHash, MilestonePayment[] memory _proposedMilestones) public {
        require(hasProfile[_applicant], "Must have profile to apply");
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.Open, "Job is not open");
        require(jobs[_jobId].jobGiver != _applicant, "Cannot apply to own job");
        require(_proposedMilestones.length > 0, "Must propose at least one milestone");
        
        // Check if already applied
        for (uint i = 0; i < jobs[_jobId].applicants.length; i++) {
            require(jobs[_jobId].applicants[i] != _applicant, "Already applied to this job");
        }
        
        jobs[_jobId].applicants.push(_applicant);
        
        // Create application
        jobApplicationCounter[_jobId]++;
        uint256 applicationId = jobApplicationCounter[_jobId];
        
        Application storage newApplication = jobApplications[_jobId][applicationId];
        newApplication.id = applicationId;
        newApplication.jobId = _jobId;
        newApplication.applicant = _applicant;
        newApplication.applicationHash = _applicationHash;
        
        for (uint i = 0; i < _proposedMilestones.length; i++) {
            newApplication.proposedMilestones.push(_proposedMilestones[i]);
        }
        
        emit JobApplication(_jobId, applicationId, _applicant, _applicationHash);
    }
    
    function getJobDetails(uint256 _jobId) public view returns (Job memory) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    function isOpen(uint256 _jobId) public view returns (bool) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open;
    }
    
    function startJob(uint256 _applicationId, bool _useApplicantMilestones) public {
        startJob(msg.sender, _applicationId, _useApplicantMilestones);
    }
    
    function startJob(address _jobGiver, uint256 _applicationId, bool _useApplicantMilestones) public {
        // Get the application to find the job
        uint256 jobId = 0;
        for (uint256 i = 1; i <= jobCounter; i++) {
            if (jobApplications[i][_applicationId].id == _applicationId) {
                jobId = i;
                break;
            }
        }
        require(jobId != 0, "Application does not exist");
        
        Application storage application = jobApplications[jobId][_applicationId];
        Job storage job = jobs[jobId];
        
        require(job.jobGiver == _jobGiver, "Only job giver can start job");
        require(job.status == JobStatus.Open, "Job is not open");
        require(application.applicant != address(0), "Invalid application");
        
        // Set selected applicant and application
        job.selectedApplicant = application.applicant;
        job.selectedApplicationId = _applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        // Choose and store final milestones
        if (_useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                job.finalMilestones.push(application.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        emit JobStarted(jobId, _applicationId, application.applicant, _useApplicantMilestones);
        emit JobStatusChanged(jobId, JobStatus.InProgress);
    }
    
    function getApplication(uint256 _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(jobApplications[_jobId][_applicationId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_applicationId];
    }
    
    function submitWork(uint256 _jobId, string memory _submissionHash) public {
        submitWork(msg.sender, _jobId, _submissionHash);
    }
    
    function submitWork(address _applicant, uint256 _jobId, string memory _submissionHash) public {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant == _applicant, "Only selected applicant can submit work");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        emit WorkSubmitted(_jobId, _applicant, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    function releasePayment(uint256 _jobId, uint256 _amount) public {
        releasePayment(msg.sender, _jobId, _amount);
    }
    
    function releasePayment(address _jobGiver, uint256 _jobId, uint256 _amount) public {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].jobGiver == _jobGiver, "Only job giver can release payment");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant != address(0), "No applicant selected");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        // Update total paid amount
        jobs[_jobId].totalPaid += _amount;
        totalPlatformPayments += _amount;
        
        // Check if all milestones completed
        if (jobs[_jobId].currentMilestone == jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Update rewards
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(_jobId, _amount, totalPlatformPayments);
        }
        
        emit PaymentReleased(_jobId, _jobGiver, jobs[_jobId].selectedApplicant, _amount, jobs[_jobId].currentMilestone);
    }
    
    function lockNextMilestone(uint256 _jobId, uint256 _lockedAmount) public {
        lockNextMilestone(msg.sender, _jobId, _lockedAmount);
    }
    
    function lockNextMilestone(address /* _caller */, uint256 _jobId, uint256 _lockedAmount) public {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].currentMilestone < jobs[_jobId].finalMilestones.length, "All milestones already completed");
        
        // Increment to next milestone
        jobs[_jobId].currentMilestone += 1;
        
        emit MilestoneLocked(_jobId, jobs[_jobId].currentMilestone, _lockedAmount);
    }
    
    function releasePaymentAndLockNext(address _jobGiver, uint256 _jobId, uint256 _releasedAmount, uint256 _lockedAmount) public {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].jobGiver == _jobGiver, "Only job giver can release and lock");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant != address(0), "No applicant selected");
        
        // Update total paid amount
        jobs[_jobId].totalPaid += _releasedAmount;
        totalPlatformPayments += _releasedAmount;
        
        // Increment milestone
        jobs[_jobId].currentMilestone += 1;
        
        // Check if all milestones completed
        if (jobs[_jobId].currentMilestone > jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Update rewards
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(_jobId, _releasedAmount, totalPlatformPayments);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, _releasedAmount, _lockedAmount, jobs[_jobId].currentMilestone);
    }
    
    function rate(uint256 _jobId, address _userToRate, uint256 _rating) public {
        rate(msg.sender, _jobId, _userToRate, _rating);
    }
    
    function rate(address _rater, uint256 _jobId, address _userToRate, uint256 _rating) public {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress || jobs[_jobId].status == JobStatus.Completed, "Job must be started");
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(jobRatings[_jobId][_userToRate] == 0, "User already rated for this job");
        
        bool isAuthorized = false;
        
        // Check if caller is job giver rating the selected applicant
        if (_rater == jobs[_jobId].jobGiver && _userToRate == jobs[_jobId].selectedApplicant) {
            isAuthorized = true;
        }
        // Check if caller is selected applicant rating the job giver
        else if (_rater == jobs[_jobId].selectedApplicant && _userToRate == jobs[_jobId].jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized to rate this user for this job");
        
        jobRatings[_jobId][_userToRate] = _rating;
        userRatings[_userToRate].push(_rating);
        
        emit UserRated(_jobId, _rater, _userToRate, _rating);
    }
    
    function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = userRatings[_user];
        if (ratings.length == 0) {
            return 0;
        }
        
        uint256 totalRating = 0;
        for (uint i = 0; i < ratings.length; i++) {
            totalRating += ratings[i];
        }
        
        return totalRating / ratings.length;
    }
    
    function addPortfolio(string memory _portfolioHash) public {
        addPortfolio(msg.sender, _portfolioHash);
    }
    
    function addPortfolio(address _user, string memory _portfolioHash) public {
        require(hasProfile[_user], "Profile does not exist");
        require(bytes(_portfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        profiles[_user].portfolioHashes.push(_portfolioHash);
        
        emit PortfolioAdded(_user, _portfolioHash);
    }
    
    // Utility functions
    function getJobCount() external view returns (uint256) {
        return jobCounter;
    }
    
    function getJobApplicationCount(uint256 _jobId) external view returns (uint256) {
        return jobApplicationCounter[_jobId];
    }
    
    function isJobOpen(uint256 _jobId) external view returns (bool) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open;
    }
    
    function getJobStatus(uint256 _jobId) external view returns (JobStatus) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId].status;
    }
}