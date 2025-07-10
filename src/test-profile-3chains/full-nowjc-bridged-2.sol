// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalNativeOpenWorkJobContract is OAppReceiver {
    
    enum JobStatus {
        Open,
        InProgress,
        Completed,
        Cancelled
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
        string jobId;
        address applicant;
        string applicationHash;
        MilestonePayment[] proposedMilestones;
    }
    
    struct Job {
        string id;
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
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    
    // Job tracking variables
    uint256 public jobCounter;
    string[] public allJobIds;
    mapping(address => string[]) public jobsByPoster;
    
    // User referrer mapping for rewards calculation
    mapping(address => address) public userReferrers;
    
    // Track which chains can send messages
    mapping(uint32 => bool) public authorizedChains;
    
    // Events
// Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer, uint32 sourceChain);
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash, uint32 sourceChain);
    event JobApplication(string indexed jobId, uint256 indexed applicationId, address indexed applicant, string applicationHash, uint32 sourceChain);
    event JobStarted(string indexed jobId, uint256 indexed applicationId, address indexed selectedApplicant, bool useApplicantMilestones, uint32 sourceChain);
    event WorkSubmitted(string indexed jobId, address indexed applicant, string submissionHash, uint256 milestone, uint32 sourceChain);
    event PaymentReleased(string indexed jobId, address indexed jobGiver, address indexed applicant, uint256 amount, uint256 milestone, uint32 sourceChain);
    event MilestoneLocked(string indexed jobId, uint256 newMilestone, uint256 lockedAmount, uint32 sourceChain);
    event UserRated(string indexed jobId, address indexed rater, address indexed rated, uint256 rating, uint32 sourceChain);
    event PortfolioAdded(address indexed user, string portfolioHash, uint32 sourceChain);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(string indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone, uint32 sourceChain);

    event CrossChainMessageReceived(string indexed functionName, uint32 sourceChain, bytes data);
    event AuthorizedChainUpdated(uint32 indexed chainEid, bool authorized);    

    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) Ownable(_owner) {}
    
    /**
     * @notice Set authorized chains that can send messages
     * @param _chainEid Chain endpoint ID
     * @param _authorized Whether the chain is authorized
     */
    function setAuthorizedChain(uint32 _chainEid, bool _authorized) external onlyOwner {
        authorizedChains[_chainEid] = _authorized;
        emit AuthorizedChainUpdated(_chainEid, _authorized);
    }
    
    /**
     * @notice Handle incoming LayerZero messages
     * @param _origin Origin information containing source chain and sender
     * @param _message Encoded function call data
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used)
        bytes calldata // _extraData (not used)
    ) internal override {
        // Verify the source chain is authorized
        require(authorizedChains[_origin.srcEid], "Unauthorized source chain");
        
        // Decode the function name and parameters
        (string memory functionName) = abi.decode(_message, (string));
        
        // Route to appropriate handler based on function name
        if (keccak256(bytes(functionName)) == keccak256(bytes("createProfile"))) {
            _handleCreateProfile(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("postJob"))) {
            _handlePostJob(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("applyToJob"))) {
            _handleApplyToJob(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("startJob"))) {
            _handleStartJob(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitWork"))) {
            _handleSubmitWork(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePayment"))) {
            _handleReleasePayment(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("lockNextMilestone"))) {
            _handleLockNextMilestone(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePaymentAndLockNext"))) {
            _handleReleasePaymentAndLockNext(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("rate"))) {
            _handleRate(_message, _origin.srcEid);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("addPortfolio"))) {
            _handleAddPortfolio(_message, _origin.srcEid);
        } else {
            revert("Unknown function");
        }
        
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }
    
    /**
     * @notice Handle profile creation messages
     */
    function _handleCreateProfile(bytes calldata _message, uint32 _sourceChain) internal {
        (, address user, string memory ipfsHash, address referrer) = abi.decode(_message, (string, address, string, address));
        _createProfile(user, ipfsHash, referrer, _sourceChain);
    }
    
    /**
     * @notice Handle job posting messages
     */
    function _handlePostJob(bytes calldata _message, uint32 _sourceChain) internal {
        (, string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) = 
            abi.decode(_message, (string, string, address, string, string[], uint256[]));
        _postJob(jobId, jobGiver, jobDetailHash, descriptions, amounts, _sourceChain);
    }
    
    /**
     * @notice Handle job application messages
     */
    function _handleApplyToJob(bytes calldata _message, uint32 _sourceChain) internal {
        (, address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) = 
            abi.decode(_message, (string, address, string, string, string[], uint256[]));
        _applyToJob(applicant, jobId, applicationHash, descriptions, amounts, _sourceChain);
    }
    
    /**
     * @notice Handle start job messages
     */
    function _handleStartJob(bytes calldata _message, uint32 _sourceChain) internal {
        (, address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) = 
            abi.decode(_message, (string, address, string, uint256, bool));
        _startJob(jobGiver, jobId, applicationId, useApplicantMilestones, _sourceChain);
    }
    
    /**
     * @notice Handle work submission messages
     */
    function _handleSubmitWork(bytes calldata _message, uint32 _sourceChain) internal {
        (, address applicant, string memory jobId, string memory submissionHash) = 
            abi.decode(_message, (string, address, string, string));
        _submitWork(applicant, jobId, submissionHash, _sourceChain);
    }
    
    /**
     * @notice Handle payment release messages
     */
    function _handleReleasePayment(bytes calldata _message, uint32 _sourceChain) internal {
        (, address jobGiver, string memory jobId, uint256 amount) = 
            abi.decode(_message, (string, address, string, uint256));
        _releasePayment(jobGiver, jobId, amount, _sourceChain);
    }
    
    /**
     * @notice Handle milestone locking messages
     */
    function _handleLockNextMilestone(bytes calldata _message, uint32 _sourceChain) internal {
        (, address caller, string memory jobId, uint256 lockedAmount) = 
            abi.decode(_message, (string, address, string, uint256));
        _lockNextMilestone(caller, jobId, lockedAmount, _sourceChain);
    }
    
    /**
     * @notice Handle release payment and lock next messages
     */
    function _handleReleasePaymentAndLockNext(bytes calldata _message, uint32 _sourceChain) internal {
        (, address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) = 
            abi.decode(_message, (string, address, string, uint256, uint256));
        _releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount, _sourceChain);
    }
    
    /**
     * @notice Handle rating messages
     */
    function _handleRate(bytes calldata _message, uint32 _sourceChain) internal {
        (, address rater, string memory jobId, address userToRate, uint256 rating) = 
            abi.decode(_message, (string, address, string, address, uint256));
        _rate(rater, jobId, userToRate, rating, _sourceChain);
    }
    
    /**
     * @notice Handle portfolio addition messages
     */
    function _handleAddPortfolio(bytes calldata _message, uint32 _sourceChain) internal {
        (, address user, string memory portfolioHash) = 
            abi.decode(_message, (string, address, string));
        _addPortfolio(user, portfolioHash, _sourceChain);
    }
    
    // Internal implementation functions
    function _createProfile(address user, string memory ipfsHash, address referrer, uint32 sourceChain) internal {
        require(user != address(0), "Invalid user address");
        require(!hasProfile[user], "Profile already exists");
        
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer,
            portfolioHashes: new string[](0)
        });
        
        hasProfile[user] = true;
        
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, ipfsHash, referrer, sourceChain);
    }
    
    function _postJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts, uint32 sourceChain) internal {
        require(bytes(jobs[jobId].id).length == 0, "Job ID already exists");
        require(descriptions.length == amounts.length, "Array length mismatch");
        
        // Increment job counter and track job
        jobCounter++;
        allJobIds.push(jobId);
        jobsByPoster[jobGiver].push(jobId);
        
        Job storage newJob = jobs[jobId];
        newJob.id = jobId;
        newJob.jobGiver = jobGiver;
        newJob.jobDetailHash = jobDetailHash;
        newJob.status = JobStatus.Open;
        newJob.totalPaid = 0;
        newJob.currentMilestone = 0;
        newJob.selectedApplicant = address(0);
        newJob.selectedApplicationId = 0;
        
        for (uint i = 0; i < descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: descriptions[i],
                amount: amounts[i]
            }));
        }
        
        emit JobPosted(jobId, jobGiver, jobDetailHash, sourceChain);
        emit JobStatusChanged(jobId, JobStatus.Open);
    }
    
    function _applyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts, uint32 sourceChain) internal {
        require(descriptions.length == amounts.length, "Array length mismatch");
        
        for (uint i = 0; i < jobs[jobId].applicants.length; i++) {
            require(jobs[jobId].applicants[i] != applicant, "Already applied to this job");
        }
        
        jobs[jobId].applicants.push(applicant);
        
        jobApplicationCounter[jobId]++;
        uint256 applicationId = jobApplicationCounter[jobId];
        
        Application storage newApplication = jobApplications[jobId][applicationId];
        newApplication.id = applicationId;
        newApplication.jobId = jobId;
        newApplication.applicant = applicant;
        newApplication.applicationHash = applicationHash;
        
        for (uint i = 0; i < descriptions.length; i++) {
            newApplication.proposedMilestones.push(MilestonePayment({
                descriptionHash: descriptions[i],
                amount: amounts[i]
            }));
        }
        
        emit JobApplication(jobId, applicationId, applicant, applicationHash, sourceChain);
    }
    
    function _startJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones, uint32 sourceChain) internal {
        Application storage application = jobApplications[jobId][applicationId];
        Job storage job = jobs[jobId];
        
        job.selectedApplicant = application.applicant;
        job.selectedApplicationId = applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        if (useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                job.finalMilestones.push(application.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        emit JobStarted(jobId, applicationId, application.applicant, useApplicantMilestones, sourceChain);
        emit JobStatusChanged(jobId, JobStatus.InProgress);
    }
    
    function _submitWork(address applicant, string memory jobId, string memory submissionHash, uint32 sourceChain) internal {
        jobs[jobId].workSubmissions.push(submissionHash);
        emit WorkSubmitted(jobId, applicant, submissionHash, jobs[jobId].currentMilestone, sourceChain);
    }
    
    function _releasePayment(address jobGiver, string memory jobId, uint256 amount, uint32 sourceChain) internal {
        jobs[jobId].totalPaid += amount;
        
        if (jobs[jobId].currentMilestone == jobs[jobId].finalMilestones.length) {
            jobs[jobId].status = JobStatus.Completed;
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        emit PaymentReleased(jobId, jobGiver, jobs[jobId].selectedApplicant, amount, jobs[jobId].currentMilestone, sourceChain);
    }
    
    function _lockNextMilestone(address caller, string memory jobId, uint256 lockedAmount, uint32 sourceChain) internal {
        require(jobs[jobId].currentMilestone < jobs[jobId].finalMilestones.length, "All milestones already completed");
        
        jobs[jobId].currentMilestone += 1;
        
        emit MilestoneLocked(jobId, jobs[jobId].currentMilestone, lockedAmount, sourceChain);
    }
    
    function _releasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount, uint32 sourceChain) internal {
        jobs[jobId].totalPaid += releasedAmount;
        jobs[jobId].currentMilestone += 1;
        
        if (jobs[jobId].currentMilestone > jobs[jobId].finalMilestones.length) {
            jobs[jobId].status = JobStatus.Completed;
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(jobId, releasedAmount, lockedAmount, jobs[jobId].currentMilestone, sourceChain);
    }
    
    function _rate(address rater, string memory jobId, address userToRate, uint256 rating, uint32 sourceChain) internal {
        bool isAuthorized = false;
        
        if (rater == jobs[jobId].jobGiver && userToRate == jobs[jobId].selectedApplicant) {
            isAuthorized = true;
        } else if (rater == jobs[jobId].selectedApplicant && userToRate == jobs[jobId].jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized to rate this user for this job");
        
        jobRatings[jobId][userToRate] = rating;
        userRatings[userToRate].push(rating);
        
        emit UserRated(jobId, rater, userToRate, rating, sourceChain);
    }
    
    function _addPortfolio(address user, string memory portfolioHash, uint32 sourceChain) internal {
        profiles[user].portfolioHashes.push(portfolioHash);
        emit PortfolioAdded(user, portfolioHash, sourceChain);
    }
    
    // Local function versions (for testing or direct calls)
    function createProfile(address user, string memory ipfsHash, address referrer) external {
        _createProfile(user, ipfsHash, referrer, 0); // 0 indicates local creation
    }
    
    function postJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external {
        _postJob(jobId, jobGiver, jobDetailHash, descriptions, amounts, 0);
    }
    
    function applyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) external {
        _applyToJob(applicant, jobId, applicationHash, descriptions, amounts, 0);
    }
    
    function startJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external {
        _startJob(jobGiver, jobId, applicationId, useApplicantMilestones, 0);
    }
    
    function submitWork(address applicant, string memory jobId, string memory submissionHash) external {
        _submitWork(applicant, jobId, submissionHash, 0);
    }
    
    function releasePayment(address jobGiver, string memory jobId, uint256 amount) external {
        _releasePayment(jobGiver, jobId, amount, 0);
    }
    
    function lockNextMilestone(address caller, string memory jobId, uint256 lockedAmount) external {
        _lockNextMilestone(caller, jobId, lockedAmount, 0);
    }
    
    function releasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) external {
        _releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount, 0);
    }
    
    function rate(address rater, string memory jobId, address userToRate, uint256 rating) external {
        _rate(rater, jobId, userToRate, rating, 0);
    }
    
    function addPortfolio(address user, string memory portfolioHash) external {
        _addPortfolio(user, portfolioHash, 0);
    }
    
    // View functions
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        return jobs[_jobId];
    }
    
    function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(jobApplications[_jobId][_applicationId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_applicationId];
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
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    function isChainAuthorized(uint32 chainEid) external view returns (bool) {
        return authorizedChains[chainEid];
    }
    
    function getJobCount() external view returns (uint256) {
        return jobCounter;
    }
    
    function getAllJobIds() external view returns (string[] memory) {
        return allJobIds;
    }
    
    function getJobsByPoster(address _poster) external view returns (string[] memory) {
        return jobsByPoster[_poster];
    }
    
    function getJobApplicationCount(string memory _jobId) external view returns (uint256) {
        return jobApplicationCounter[_jobId];
    }
    
    function isJobOpen(string memory _jobId) external view returns (bool) {
        return jobs[_jobId].status == JobStatus.Open;
    }
    
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        return jobs[_jobId].status;
    }
    
    function jobExists(string memory _jobId) external view returns (bool) {
        return bytes(jobs[_jobId].id).length != 0;
    }
}