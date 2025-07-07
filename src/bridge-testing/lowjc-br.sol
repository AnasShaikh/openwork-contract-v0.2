// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CrossChainOpenWorkJobContract is OAppSender, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
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
        uint256 currentLockedAmount;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
        uint256 totalEscrowed;
        uint256 totalReleased;
    }
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public jobCounter;
    uint256 public totalPlatformPayments;
    
    IERC20 public immutable usdtToken;    
    uint32 public immutable chainId;
    uint32 public nativeContractEid;
    uint32 public rewardsContractEid;
    bytes public defaultOptions;
    
    // Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer);
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobApplication(string indexed jobId, uint256 indexed applicationId, address indexed applicant, string applicationHash);
    event JobStarted(string indexed jobId, uint256 indexed applicationId, address indexed selectedApplicant, bool useApplicantMilestones);
    event WorkSubmitted(string indexed jobId, address indexed applicant, string submissionHash, uint256 milestone);
    event PaymentReleased(string indexed jobId, address indexed jobGiver, address indexed applicant, uint256 amount, uint256 milestone);
    event MilestoneLocked(string indexed jobId, uint256 newMilestone, uint256 lockedAmount);
    event UserRated(string indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event USDTEscrowed(string indexed jobId, address indexed jobGiver, uint256 amount);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(string indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    event PlatformTotalUpdated(uint256 newTotal);
    
    constructor(
        address _endpoint,
        address _owner, 
        address _usdtToken, 
        uint32 _chainId,
        uint32 _nativeContractEid,
        uint32 _rewardsContractEid,
        bytes memory _defaultOptions
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;
        nativeContractEid = _nativeContractEid;
        rewardsContractEid = _rewardsContractEid;
        defaultOptions = _defaultOptions;
    }
    
    // Internal send functions
    function _sendToNative(string memory _message) internal returns (uint256 usedFee) {
        bytes memory payload = abi.encode(_message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        _lzSend(nativeContractEid, payload, defaultOptions, MessagingFee(fee.nativeFee, 0), payable(msg.sender));
        return fee.nativeFee;
    }
    
    function _sendToRewards(string memory _message) internal returns (uint256 usedFee) {
        bytes memory payload = abi.encode(_message);
        MessagingFee memory fee = _quote(rewardsContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        _lzSend(rewardsContractEid, payload, defaultOptions, MessagingFee(fee.nativeFee, 0), payable(msg.sender));
        return fee.nativeFee;
    }
    
    function _sendToBothChains(string memory _nativeMessage, string memory _rewardsMessage) internal {
        bytes memory nativePayload = abi.encode(_nativeMessage);
        bytes memory rewardsPayload = abi.encode(_rewardsMessage);
        
        MessagingFee memory nativeFee = _quote(nativeContractEid, nativePayload, defaultOptions, false);
        MessagingFee memory rewardsFee = _quote(rewardsContractEid, rewardsPayload, defaultOptions, false);
        
        uint256 totalFee = nativeFee.nativeFee + rewardsFee.nativeFee;
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        _lzSend(nativeContractEid, nativePayload, defaultOptions, MessagingFee(nativeFee.nativeFee, 0), payable(msg.sender));
        _lzSend(rewardsContractEid, rewardsPayload, defaultOptions, MessagingFee(rewardsFee.nativeFee, 0), payable(msg.sender));
        
        uint256 excess = msg.value - totalFee;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }
    
    function _refundExcess(uint256 usedFee) internal {
        uint256 excess = msg.value - usedFee;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }
    
    // Configuration functions
    function setNativeContractEid(uint32 _eid) external onlyOwner {
        nativeContractEid = _eid;
    }
    
    function setRewardsContractEid(uint32 _eid) external onlyOwner {
        rewardsContractEid = _eid;
    }
    
    function setDefaultOptions(bytes memory _options) external onlyOwner {
        defaultOptions = _options;
    }
    
    // Quote functions
    function quoteCreateProfile() external view returns (uint256 totalFee, uint256 nativeFee, uint256 rewardsFee) {
        string memory message = "createProfile";
        bytes memory payload = abi.encode(message);
        
        MessagingFee memory nativeMsg = _quote(nativeContractEid, payload, defaultOptions, false);
        MessagingFee memory rewardsMsg = _quote(rewardsContractEid, payload, defaultOptions, false);
        
        nativeFee = nativeMsg.nativeFee;
        rewardsFee = rewardsMsg.nativeFee;
        totalFee = nativeFee + rewardsFee;
    }
    
    function quoteSingleChain(uint32 _dstEid) external view returns (uint256) {
        string memory message = "singleChain";
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(_dstEid, payload, defaultOptions, false);
        return fee.nativeFee;
    }
    
    // Profile Management
    function createProfile(string memory _ipfsHash, address _referrerAddress) external payable nonReentrant {
        // Create profile data
        string memory profileData = string(abi.encodePacked(
            "createProfile:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _ipfsHash, ":",
            Strings.toHexString(uint256(uint160(_referrerAddress)), 20)
        ));
        
        // Create rewards data
        string memory rewardsData = string(abi.encodePacked(
            "createProfile:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            Strings.toHexString(uint256(uint160(_referrerAddress)), 20)
        ));
        
        // Update local state
        profiles[msg.sender] = Profile({
            userAddress: msg.sender,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        hasProfile[msg.sender] = true;
        
        _sendToBothChains(profileData, rewardsData);
        
        emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    // Job Management
    function postJob(string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external payable nonReentrant {
        require(_descriptions.length > 0, "Must have at least one milestone");
        require(_descriptions.length == _amounts.length, "Descriptions and amounts length mismatch");
        
        uint256 calculatedTotal = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            calculatedTotal += _amounts[i];
        }
        require(calculatedTotal > 0, "Total amount must be greater than 0");
        
        string memory jobId = string(abi.encodePacked(Strings.toString(chainId), "-", Strings.toString(++jobCounter)));
        
        // Build message with all data
        string memory message = string(abi.encodePacked(
            "postJob:",
            jobId, ":",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobDetailHash
        ));
        
        // Add descriptions and amounts
        for (uint i = 0; i < _descriptions.length; i++) {
            message = string(abi.encodePacked(
                message, ":",
                _descriptions[i], ":",
                Strings.toString(_amounts[i])
            ));
        }
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        // Update local state
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
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit JobPosted(jobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(jobId, JobStatus.Open);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    // Application Management
    function applyToJob(string memory _jobId, string memory _appHash, string[] memory _descriptions, uint256[] memory _amounts) external payable nonReentrant {
        require(hasProfile[msg.sender], "Must have profile to apply");
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.Open, "Job is not open");
        require(jobs[_jobId].jobGiver != msg.sender, "Cannot apply to own job");
        require(_descriptions.length > 0, "Must propose at least one milestone");
        require(_descriptions.length == _amounts.length, "Descriptions and amounts length mismatch");
        
        address[] memory applicants = jobs[_jobId].applicants;
        for (uint i = 0; i < applicants.length; i++) {
            require(applicants[i] != msg.sender, "Already applied to this job");
        }
        
        jobs[_jobId].applicants.push(msg.sender);
        uint256 appId = ++jobApplicationCounter[_jobId];
        
        // Build message
        string memory message = string(abi.encodePacked(
            "applyToJob:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            _appHash
        ));
        
        for (uint i = 0; i < _descriptions.length; i++) {
            message = string(abi.encodePacked(
                message, ":",
                _descriptions[i], ":",
                Strings.toString(_amounts[i])
            ));
        }
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        // Update local state
        Application storage newApp = jobApplications[_jobId][appId];
        newApp.id = appId;
        newApp.jobId = _jobId;
        newApp.applicant = msg.sender;
        newApp.applicationHash = _appHash;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newApp.proposedMilestones.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit JobApplication(_jobId, appId, msg.sender, _appHash);
    }
    
    function getApplication(string memory _jobId, uint256 _appId) public view returns (Application memory) {
        require(jobApplications[_jobId][_appId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_appId];
    }
    
    // Job startup
    function startJob(string memory _jobId, uint256 _appId, bool _useAppMilestones) external payable nonReentrant {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        
        Application storage app = jobApplications[_jobId][_appId];
        Job storage job = jobs[_jobId];
        
        require(job.jobGiver == msg.sender, "Only job giver can start job");
        require(job.status == JobStatus.Open, "Job is not open");
        require(app.applicant != address(0), "Invalid application");
        
        string memory message = string(abi.encodePacked(
            "startJob:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            Strings.toString(_appId), ":",
            _useAppMilestones ? "true" : "false"
        ));
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        // Update local state
        job.selectedApplicant = app.applicant;
        job.selectedApplicationId = _appId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        MilestonePayment[] memory srcMilestones = _useAppMilestones ? app.proposedMilestones : job.milestonePayments;
        
        for (uint i = 0; i < srcMilestones.length; i++) {
            job.finalMilestones.push(srcMilestones[i]);
        }
        
        uint256 firstAmount = job.finalMilestones[0].amount;
        usdtToken.safeTransferFrom(msg.sender, address(this), firstAmount);
        job.currentLockedAmount = firstAmount;
        job.totalEscrowed += firstAmount;
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit JobStarted(_jobId, _appId, app.applicant, _useAppMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
        emit USDTEscrowed(_jobId, msg.sender, firstAmount);
    }
    
    function submitWork(string memory _jobId, string memory _submissionHash) external payable nonReentrant {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant == msg.sender, "Only selected applicant can submit work");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        string memory message = string(abi.encodePacked(
            "submitWork:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            _submissionHash
        ));
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit WorkSubmitted(_jobId, msg.sender, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    function releasePayment(string memory _jobId) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.jobGiver == msg.sender, "Only job giver can release payment");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.selectedApplicant != address(0), "No applicant selected");
        require(job.currentMilestone <= job.finalMilestones.length, "All milestones completed");
        require(job.currentLockedAmount > 0, "No payment locked");
        
        uint256 amount = job.currentLockedAmount;
        
        // Prepare messages for both chains
        string memory nativeMessage = string(abi.encodePacked(
            "releasePayment:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            Strings.toString(amount)
        ));
        
        string memory rewardsMessage = string(abi.encodePacked(
            "updateRewardsOnPayment:",
            Strings.toHexString(uint256(uint160(job.jobGiver)), 20), ":",
            Strings.toHexString(uint256(uint160(job.selectedApplicant)), 20), ":",
            Strings.toString(amount)
        ));
        
        // Update local state
        usdtToken.safeTransfer(job.selectedApplicant, amount);
        job.totalPaid += amount;
        job.totalReleased += amount;
        job.currentLockedAmount = 0;
        totalPlatformPayments += amount;
        
        if (job.currentMilestone == job.finalMilestones.length) {
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        _sendToBothChains(nativeMessage, rewardsMessage);
        
        emit PaymentReleased(_jobId, msg.sender, job.selectedApplicant, amount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
    }
    
    function lockNextMilestone(string memory _jobId) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.jobGiver == msg.sender, "Only job giver can lock milestone");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.currentLockedAmount == 0, "Previous payment not released");
        require(job.currentMilestone < job.finalMilestones.length, "All milestones already completed");
        
        job.currentMilestone += 1;
        uint256 nextAmount = job.finalMilestones[job.currentMilestone - 1].amount;
        
        string memory message = string(abi.encodePacked(
            "lockNextMilestone:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            Strings.toString(nextAmount)
        ));
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        usdtToken.safeTransferFrom(msg.sender, address(this), nextAmount);
        job.currentLockedAmount = nextAmount;
        job.totalEscrowed += nextAmount;
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit MilestoneLocked(_jobId, job.currentMilestone, nextAmount);
        emit USDTEscrowed(_jobId, msg.sender, nextAmount);
    }
    
    function releaseAndLockNext(string memory _jobId) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.jobGiver == msg.sender, "Only job giver can release and lock");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.selectedApplicant != address(0), "No applicant selected");
        require(job.currentLockedAmount > 0, "No payment locked");
        require(job.currentMilestone < job.finalMilestones.length, "All milestones completed");
        
        uint256 releaseAmount = job.currentLockedAmount;
        job.currentMilestone += 1;
        uint256 nextAmount = 0;
        if (job.currentMilestone <= job.finalMilestones.length) {
            nextAmount = job.finalMilestones[job.currentMilestone - 1].amount;
        }
        
        // Prepare messages for both chains
        string memory nativeMessage = string(abi.encodePacked(
            "releasePaymentAndLockNext:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            Strings.toString(releaseAmount), ":",
            Strings.toString(nextAmount)
        ));
        
        string memory rewardsMessage = string(abi.encodePacked(
            "updateRewardsOnPayment:",
            Strings.toHexString(uint256(uint160(job.jobGiver)), 20), ":",
            Strings.toHexString(uint256(uint160(job.selectedApplicant)), 20), ":",
            Strings.toString(releaseAmount)
        ));
        
        // Update local state
        usdtToken.safeTransfer(job.selectedApplicant, releaseAmount);
        job.totalPaid += releaseAmount;
        job.totalReleased += releaseAmount;
        totalPlatformPayments += releaseAmount;
        
        if (nextAmount > 0) {
            usdtToken.safeTransferFrom(msg.sender, address(this), nextAmount);
            job.currentLockedAmount = nextAmount;
            job.totalEscrowed += nextAmount;
        } else {
            job.currentLockedAmount = 0;
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        _sendToBothChains(nativeMessage, rewardsMessage);
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, releaseAmount, nextAmount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
    }
    
    function rate(string memory _jobId, address _userToRate, uint256 _rating) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.status == JobStatus.InProgress || job.status == JobStatus.Completed, "Job must be started");
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(jobRatings[_jobId][_userToRate] == 0, "User already rated for this job");
        
        bool isAuth = (msg.sender == job.jobGiver && _userToRate == job.selectedApplicant) ||
                      (msg.sender == job.selectedApplicant && _userToRate == job.jobGiver);
        require(isAuth, "Not authorized to rate this user for this job");
        
        string memory message = string(abi.encodePacked(
            "rate:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _jobId, ":",
            Strings.toHexString(uint256(uint160(_userToRate)), 20), ":",
            Strings.toString(_rating)
        ));
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        jobRatings[_jobId][_userToRate] = _rating;
        userRatings[_userToRate].push(_rating);
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit UserRated(_jobId, msg.sender, _userToRate, _rating);
    }
    
    function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = userRatings[_user];
        if (ratings.length == 0) return 0;
        
        uint256 total = 0;
        for (uint i = 0; i < ratings.length; i++) {
            total += ratings[i];
        }
        return total / ratings.length;
    }
    
    function addPortfolio(string memory _portfolioHash) external payable nonReentrant {
        require(hasProfile[msg.sender], "Profile does not exist");
        require(bytes(_portfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        string memory message = string(abi.encodePacked(
            "addPortfolio:",
            Strings.toHexString(uint256(uint160(msg.sender)), 20), ":",
            _portfolioHash
        ));
        
        bytes memory payload = abi.encode(message);
        MessagingFee memory fee = _quote(nativeContractEid, payload, defaultOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee provided");
        
        profiles[msg.sender].portfolioHashes.push(_portfolioHash);
        
        uint256 usedFee = _sendToNative(message);
        _refundExcess(usedFee);
        
        emit PortfolioAdded(msg.sender, _portfolioHash);
    }
    
    // View functions
    function getJobCount() external view returns (uint256) { return jobCounter; }
    function getJobApplicationCount(string memory _jobId) external view returns (uint256) { return jobApplicationCounter[_jobId]; }
    function isJobOpen(string memory _jobId) external view returns (bool) { 
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open; 
    }
    function getEscrowBalance(string memory _jobId) external view returns (uint256 escrowed, uint256 released, uint256 remaining) {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        escrowed = job.totalEscrowed;
        released = job.totalReleased;
        remaining = escrowed - released;
    }
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status;
    }
    function getTotalPlatformPayments() external view returns (uint256) {
        return totalPlatformPayments;
    }
    
    // Admin functions
    function updateLocalPlatformTotal(uint256 newTotal) external onlyOwner {
        require(newTotal >= totalPlatformPayments, "Cannot decrease platform total");
        totalPlatformPayments = newTotal;
        emit PlatformTotalUpdated(newTotal);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}