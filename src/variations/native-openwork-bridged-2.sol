// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

interface IRewardsTrackingContract {
    function updateRewards(string memory jobId, uint256 paidAmountUSDT, uint256 totalPlatformPayments) external;
}

contract NativeOpenWorkJobContract is OApp {
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
    
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public totalPlatformPayments;
    
    // Job tracking variables
    uint256 public jobCounter;
    string[] public allJobIds;
    mapping(address => string[]) public jobsByPoster;
    
    IRewardsTrackingContract public rewardsContract;
    
    event ProfileCreated(address indexed user, string ipfsHash, address referrer);
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobApplication(string indexed jobId, uint256 indexed applicationId, address indexed applicant, string applicationHash);
    event JobStarted(string indexed jobId, uint256 indexed applicationId, address indexed selectedApplicant, bool useApplicantMilestones);
    event WorkSubmitted(string indexed jobId, address indexed applicant, string submissionHash, uint256 milestone);
    event PaymentReleased(string indexed jobId, address indexed jobGiver, address indexed applicant, uint256 amount, uint256 milestone);
    event MilestoneLocked(string indexed jobId, uint256 newMilestone, uint256 lockedAmount);
    event UserRated(string indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(string indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}
    
    // LayerZero message receiver
    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        // Decode the function name first
        string memory functionName = abi.decode(payload, (string));
        
        if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("createProfile"))) {
            (, address user, string memory ipfsHash, address referrerAddress) = abi.decode(payload, (string, address, string, address));
            _createProfile(user, ipfsHash, referrerAddress);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("postJob"))) {
            (, string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(payload, (string, string, address, string, string[], uint256[]));
            _postJob(jobId, jobGiver, jobDetailHash, descriptions, amounts);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("applyToJob"))) {
            (, address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(payload, (string, address, string, string, string[], uint256[]));
            _applyToJob(applicant, jobId, applicationHash, descriptions, amounts);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("startJob"))) {
            (, address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) = abi.decode(payload, (string, address, string, uint256, bool));
            _startJob(jobGiver, jobId, applicationId, useApplicantMilestones);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("submitWork"))) {
            (, address applicant, string memory jobId, string memory submissionHash) = abi.decode(payload, (string, address, string, string));
            _submitWork(applicant, jobId, submissionHash);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("releasePayment"))) {
            (, address jobGiver, string memory jobId, uint256 amount) = abi.decode(payload, (string, address, string, uint256));
            _releasePayment(jobGiver, jobId, amount);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("lockNextMilestone"))) {
            (, address caller, string memory jobId, uint256 lockedAmount) = abi.decode(payload, (string, address, string, uint256));
            _lockNextMilestone(caller, jobId, lockedAmount);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("releasePaymentAndLockNext"))) {
            (, address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) = abi.decode(payload, (string, address, string, uint256, uint256));
            _releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("rate"))) {
            (, address rater, string memory jobId, address userToRate, uint256 rating) = abi.decode(payload, (string, address, string, address, uint256));
            _rate(rater, jobId, userToRate, rating);
        }
        else if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("addPortfolio"))) {
            (, address user, string memory portfolioHash) = abi.decode(payload, (string, address, string));
            _addPortfolio(user, portfolioHash);
        }
        else {
            revert("Unknown function call");
        }
    }
    
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        rewardsContract = IRewardsTrackingContract(_rewardsContract);
    }
    
    function _createProfile(address _user, string memory _ipfsHash, address _referrerAddress) internal {
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
    
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) external {
        _createProfile(_user, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        return profiles[_user];
    }
    
    function _postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) internal {
        require(bytes(jobs[_jobId].id).length == 0, "Job ID already exists");
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        uint256 calculatedTotal = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            calculatedTotal += _amounts[i];
        }
        
        // Increment job counter and track job
        jobCounter++;
        allJobIds.push(_jobId);
        jobsByPoster[_jobGiver].push(_jobId);
        
        Job storage newJob = jobs[_jobId];
        newJob.id = _jobId;
        newJob.jobGiver = _jobGiver;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        newJob.totalPaid = 0;
        newJob.currentMilestone = 0;
        newJob.selectedApplicant = address(0);
        newJob.selectedApplicationId = 0;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        emit JobPosted(_jobId, _jobGiver, _jobDetailHash);
        emit JobStatusChanged(_jobId, JobStatus.Open);
    }
    
    function postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external {
        _postJob(_jobId, _jobGiver, _jobDetailHash, _descriptions, _amounts);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        return jobs[_jobId];
    }
    
    function _applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts) internal {
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        for (uint i = 0; i < jobs[_jobId].applicants.length; i++) {
            require(jobs[_jobId].applicants[i] != _applicant, "Already applied to this job");
        }
        
        jobs[_jobId].applicants.push(_applicant);
        
        jobApplicationCounter[_jobId]++;
        uint256 applicationId = jobApplicationCounter[_jobId];
        
        Application storage newApplication = jobApplications[_jobId][applicationId];
        newApplication.id = applicationId;
        newApplication.jobId = _jobId;
        newApplication.applicant = _applicant;
        newApplication.applicationHash = _applicationHash;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newApplication.proposedMilestones.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        emit JobApplication(_jobId, applicationId, _applicant, _applicationHash);
    }
    
    function applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts) external {
        _applyToJob(_applicant, _jobId, _applicationHash, _descriptions, _amounts);
    }
    
    function _startJob(address /* _jobGiver */, string memory _jobId, uint256 _applicationId, bool _useApplicantMilestones) internal {
        Application storage application = jobApplications[_jobId][_applicationId];
        Job storage job = jobs[_jobId];
        
        job.selectedApplicant = application.applicant;
        job.selectedApplicationId = _applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        if (_useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                job.finalMilestones.push(application.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        emit JobStarted(_jobId, _applicationId, application.applicant, _useApplicantMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
    }
    
    function startJob(address _jobGiver, string memory _jobId, uint256 _applicationId, bool _useApplicantMilestones) external {
        _startJob(_jobGiver, _jobId, _applicationId, _useApplicantMilestones);
    }
    
    function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(jobApplications[_jobId][_applicationId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_applicationId];
    }
    
    function _submitWork(address _applicant, string memory _jobId, string memory _submissionHash) internal {
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        emit WorkSubmitted(_jobId, _applicant, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    function submitWork(address _applicant, string memory _jobId, string memory _submissionHash) external {
        _submitWork(_applicant, _jobId, _submissionHash);
    }
    
    function _releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) internal {
        jobs[_jobId].totalPaid += _amount;
        totalPlatformPayments += _amount;
        
        if (jobs[_jobId].currentMilestone == jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(_jobId, _amount, totalPlatformPayments);
        }
        
        emit PaymentReleased(_jobId, _jobGiver, jobs[_jobId].selectedApplicant, _amount, jobs[_jobId].currentMilestone);
    }
    
    function releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) external {
        _releasePayment(_jobGiver, _jobId, _amount);
    }
    
    function _lockNextMilestone(address /* _caller */, string memory _jobId, uint256 _lockedAmount) internal {
        require(jobs[_jobId].currentMilestone < jobs[_jobId].finalMilestones.length, "All milestones already completed");
        
        jobs[_jobId].currentMilestone += 1;
        
        emit MilestoneLocked(_jobId, jobs[_jobId].currentMilestone, _lockedAmount);
    }
    
    function lockNextMilestone(address _caller, string memory _jobId, uint256 _lockedAmount) external {
        _lockNextMilestone(_caller, _jobId, _lockedAmount);
    }
    
    function _releasePaymentAndLockNext(address /* _jobGiver */, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) internal {
        jobs[_jobId].totalPaid += _releasedAmount;
        totalPlatformPayments += _releasedAmount;
        
        jobs[_jobId].currentMilestone += 1;
        
        if (jobs[_jobId].currentMilestone > jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(_jobId, _releasedAmount, totalPlatformPayments);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, _releasedAmount, _lockedAmount, jobs[_jobId].currentMilestone);
    }
    
    function releasePaymentAndLockNext(address _jobGiver, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) external {
        _releasePaymentAndLockNext(_jobGiver, _jobId, _releasedAmount, _lockedAmount);
    }
    
    function _rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) internal {
        bool isAuthorized = false;
        
        if (_rater == jobs[_jobId].jobGiver && _userToRate == jobs[_jobId].selectedApplicant) {
            isAuthorized = true;
        } else if (_rater == jobs[_jobId].selectedApplicant && _userToRate == jobs[_jobId].jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized to rate this user for this job");
        
        jobRatings[_jobId][_userToRate] = _rating;
        userRatings[_userToRate].push(_rating);
        
        emit UserRated(_jobId, _rater, _userToRate, _rating);
    }
    
    function rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) external {
        _rate(_rater, _jobId, _userToRate, _rating);
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
    
    function _addPortfolio(address _user, string memory _portfolioHash) internal {
        profiles[_user].portfolioHashes.push(_portfolioHash);
        
        emit PortfolioAdded(_user, _portfolioHash);
    }
    
    function addPortfolio(address _user, string memory _portfolioHash) external {
        _addPortfolio(_user, _portfolioHash);
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