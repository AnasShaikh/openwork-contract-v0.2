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

    // ==================== REWARDS CALCULATION STRUCTURES ====================
    
    // Reward bands structure for job-based rewards (copied from main-rewards.sol)
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }

    // User referrer mapping
    mapping(address => address) public userReferrers;
    
    // User tracking for job-based rewards
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    
    // Reward bands array
    RewardBand[] public rewardBands;

    // ==================== EXISTING CONTRACT STATE ====================
    
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
    
    // Bridge reference
    address public bridge;
    
    // ==================== EVENTS ====================
    
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
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    
    // New rewards events
    event TokensEarned(address indexed user, uint256 tokensEarned, uint256 newCumulativeEarnings, uint256 newTotalTokens);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _bridge) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = _bridge;
        _initializeRewardBands();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== MESSAGE HANDLERS ====================

    function handleCreateProfile(address user, string memory ipfsHash, address referrer) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        if (!hasProfile[user]) {
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
            emit ProfileCreated(user, ipfsHash, referrer);
        }
    }

    function handlePostJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        if (bytes(jobs[jobId].id).length == 0) {
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
            
            emit JobPosted(jobId, jobGiver, jobDetailHash);
            emit JobStatusChanged(jobId, JobStatus.Open);
        }
    }

    function handleApplyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        bool alreadyApplied = false;
        for (uint i = 0; i < jobs[jobId].applicants.length; i++) {
            if (jobs[jobId].applicants[i] == applicant) {
                alreadyApplied = true;
                break;
            }
        }
        
        if (!alreadyApplied) {
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
            
            emit JobApplication(jobId, applicationId, applicant, applicationHash);
        }
    }

    function handleStartJob(address /* jobGiver */, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
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
        
        emit JobStarted(jobId, applicationId, application.applicant, useApplicantMilestones);
        emit JobStatusChanged(jobId, JobStatus.InProgress);
    }

    function handleSubmitWork(address applicant, string memory jobId, string memory submissionHash) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        jobs[jobId].workSubmissions.push(submissionHash);
        emit WorkSubmitted(jobId, applicant, submissionHash, jobs[jobId].currentMilestone);
    }

    function handleReleasePayment(address jobGiver, string memory jobId, uint256 amount) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        jobs[jobId].totalPaid += amount;
        totalPlatformPayments += amount;

        // ==================== REWARDS CALCULATION ====================
        address jobTaker = jobs[jobId].selectedApplicant;
        
        // Get referrers
        address jobGiverReferrer = userReferrers[jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution (same logic as main-rewards.sol)
        uint256 jobGiverAmount = amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        // ==================== END REWARDS CALCULATION ====================
        
        if (jobs[jobId].currentMilestone == jobs[jobId].finalMilestones.length) {
            jobs[jobId].status = JobStatus.Completed;
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        emit PaymentReleased(jobId, jobGiver, jobs[jobId].selectedApplicant, amount, jobs[jobId].currentMilestone);
    }

    function handleLockNextMilestone(address /* caller */, string memory jobId, uint256 lockedAmount) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        if (jobs[jobId].currentMilestone < jobs[jobId].finalMilestones.length) {
            jobs[jobId].currentMilestone += 1;
            emit MilestoneLocked(jobId, jobs[jobId].currentMilestone, lockedAmount);
        }
    }

    function handleReleasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        jobs[jobId].totalPaid += releasedAmount;
        totalPlatformPayments += releasedAmount;

        // ==================== REWARDS CALCULATION ====================
        address jobTaker = jobs[jobId].selectedApplicant;
        
        // Get referrers
        address jobGiverReferrer = userReferrers[jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution (same logic as main-rewards.sol)
        uint256 jobGiverAmount = releasedAmount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = releasedAmount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = releasedAmount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        // ==================== END REWARDS CALCULATION ====================
        
        jobs[jobId].currentMilestone += 1;
        
        if (jobs[jobId].currentMilestone > jobs[jobId].finalMilestones.length) {
            jobs[jobId].status = JobStatus.Completed;
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(jobId, releasedAmount, lockedAmount, jobs[jobId].currentMilestone);
    }

    function handleRate(address rater, string memory jobId, address userToRate, uint256 rating) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        bool isAuthorized = false;
        
        if (rater == jobs[jobId].jobGiver && userToRate == jobs[jobId].selectedApplicant) {
            isAuthorized = true;
        } else if (rater == jobs[jobId].selectedApplicant && userToRate == jobs[jobId].jobGiver) {
            isAuthorized = true;
        }
        
        if (isAuthorized) {
            jobRatings[jobId][userToRate] = rating;
            userRatings[userToRate].push(rating);
            emit UserRated(jobId, rater, userToRate, rating);
        }
    }

    function handleAddPortfolio(address user, string memory portfolioHash) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        profiles[user].portfolioHashes.push(portfolioHash);
        emit PortfolioAdded(user, portfolioHash);
    }

    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = bridge;
        bridge = _bridge;
        emit BridgeUpdated(oldBridge, _bridge);
    }

    // ==================== REWARDS INITIALIZATION ====================
    
    function _initializeRewardBands() private {
        // Job-based reward bands (same as main-rewards.sol)
        rewardBands.push(RewardBand(0, 500 * 1e6, 100000 * 1e18));
        rewardBands.push(RewardBand(500 * 1e6, 1000 * 1e6, 50000 * 1e18));
        rewardBands.push(RewardBand(1000 * 1e6, 2000 * 1e6, 25000 * 1e18));
        rewardBands.push(RewardBand(2000 * 1e6, 4000 * 1e6, 12500 * 1e18));
        rewardBands.push(RewardBand(4000 * 1e6, 8000 * 1e6, 6250 * 1e18));
        rewardBands.push(RewardBand(8000 * 1e6, 16000 * 1e6, 3125 * 1e18));
        rewardBands.push(RewardBand(16000 * 1e6, 32000 * 1e6, 1562 * 1e18));
        rewardBands.push(RewardBand(32000 * 1e6, 64000 * 1e6, 781 * 1e18));
        rewardBands.push(RewardBand(64000 * 1e6, 128000 * 1e6, 391 * 1e18));
        rewardBands.push(RewardBand(128000 * 1e6, 256000 * 1e6, 195 * 1e18));
        rewardBands.push(RewardBand(256000 * 1e6, 512000 * 1e6, 98 * 1e18));
        rewardBands.push(RewardBand(512000 * 1e6, 1024000 * 1e6, 49 * 1e18));
        rewardBands.push(RewardBand(1024000 * 1e6, 2048000 * 1e6, 24 * 1e18));
        rewardBands.push(RewardBand(2048000 * 1e6, 4096000 * 1e6, 12 * 1e18));
        rewardBands.push(RewardBand(4096000 * 1e6, 8192000 * 1e6, 6 * 1e18));
        rewardBands.push(RewardBand(8192000 * 1e6, 16384000 * 1e6, 3 * 1e18));
        rewardBands.push(RewardBand(16384000 * 1e6, 32768000 * 1e6, 15 * 1e17));
        rewardBands.push(RewardBand(32768000 * 1e6, 65536000 * 1e6, 75 * 1e16));
        rewardBands.push(RewardBand(65536000 * 1e6, 131072000 * 1e6, 38 * 1e16));
        rewardBands.push(RewardBand(131072000 * 1e6, type(uint256).max, 19 * 1e16));
    }

    // ==================== REWARDS CALCULATION FUNCTIONS ====================
    
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) public view returns (uint256) {
        if (fromAmount >= toAmount) {
            return 0;
        }
        
        uint256 totalTokens = 0;
        uint256 currentAmount = fromAmount;
        
        for (uint256 i = 0; i < rewardBands.length && currentAmount < toAmount; i++) {
            RewardBand memory band = rewardBands[i];
            
            // Skip bands that are entirely below our starting point
            if (band.maxAmount <= currentAmount) {
                continue;
            }
            
            // Calculate the overlap with this band
            uint256 bandStart = currentAmount > band.minAmount ? currentAmount : band.minAmount;
            uint256 bandEnd = toAmount < band.maxAmount ? toAmount : band.maxAmount;
            
            if (bandStart < bandEnd) {
                uint256 amountInBand = bandEnd - bandStart;
                uint256 tokensInBand = (amountInBand * band.owPerDollar) / 1e6; // Convert USDT (6 decimals) to tokens
                totalTokens += tokensInBand;
                currentAmount = bandEnd;
            }
        }
        
        return totalTokens;
    }

    function _accumulateJobTokens(address user, uint256 amountUSDT) private {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        
        // Calculate tokens based on progressive bands
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        // Update user's cumulative earnings and total tokens
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
    }

    // ==================== PUBLIC REWARDS VIEW FUNCTIONS ====================
    
    function getUserEarnedTokens(address user) external view returns (uint256) {
        return userTotalOWTokens[user];
    }

    function getUserRewardInfo(address user) external view returns (
        uint256 cumulativeEarnings,
        uint256 totalTokens
    ) {
        return (userCumulativeEarnings[user], userTotalOWTokens[user]);
    }

    function calculateTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + additionalAmount;
        return calculateTokensForRange(currentCumulative, newCumulative);
    }

    // ==================== LOCAL FUNCTIONS (for direct use if needed) ====================
    
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) external {
        require(!hasProfile[_user], "Profile already exists");
        
        profiles[_user] = Profile({
            userAddress: _user,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        
        hasProfile[_user] = true;

        // Store referrer for rewards calculation
        if (_referrerAddress != address(0) && _referrerAddress != _user) {
            userReferrers[_user] = _referrerAddress;
        }
        
        emit ProfileCreated(_user, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        return profiles[_user];
    }
    
    function postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external {
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
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        return jobs[_jobId];
    }
    
    function applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts) external {
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
    
    function startJob(address /* _jobGiver */, string memory _jobId, uint256 _applicationId, bool _useApplicantMilestones) external {
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
    
    function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(jobApplications[_jobId][_applicationId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_applicationId];
    }
    
    function submitWork(address _applicant, string memory _jobId, string memory _submissionHash) external {
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        emit WorkSubmitted(_jobId, _applicant, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    function releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) external {
        jobs[_jobId].totalPaid += _amount;
        totalPlatformPayments += _amount;

        // ==================== REWARDS CALCULATION ====================
        address jobTaker = jobs[_jobId].selectedApplicant;
        
        // Get referrers
        address jobGiverReferrer = userReferrers[_jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution (same logic as main-rewards.sol)
        uint256 jobGiverAmount = _amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != _jobGiver) {
            jobGiverReferrerAmount = _amount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = _amount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(_jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        // ==================== END REWARDS CALCULATION ====================
        
        if (jobs[_jobId].currentMilestone == jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        emit PaymentReleased(_jobId, _jobGiver, jobs[_jobId].selectedApplicant, _amount, jobs[_jobId].currentMilestone);
    }
    
    function lockNextMilestone(address /* _caller */, string memory _jobId, uint256 _lockedAmount) external {
        require(jobs[_jobId].currentMilestone < jobs[_jobId].finalMilestones.length, "All milestones already completed");
        
        jobs[_jobId].currentMilestone += 1;
        
        emit MilestoneLocked(_jobId, jobs[_jobId].currentMilestone, _lockedAmount);
    }
    
    function releasePaymentAndLockNext(address _jobGiver, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) external {
        jobs[_jobId].totalPaid += _releasedAmount;
        totalPlatformPayments += _releasedAmount;

        // ==================== REWARDS CALCULATION ====================
        address jobTaker = jobs[_jobId].selectedApplicant;
        
        // Get referrers
        address jobGiverReferrer = userReferrers[_jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution (same logic as main-rewards.sol)
        uint256 jobGiverAmount = _releasedAmount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != _jobGiver) {
            jobGiverReferrerAmount = _releasedAmount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = _releasedAmount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(_jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        // ==================== END REWARDS CALCULATION ====================
        
        jobs[_jobId].currentMilestone += 1;
        
        if (jobs[_jobId].currentMilestone > jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, _releasedAmount, _lockedAmount, jobs[_jobId].currentMilestone);
    }
    
    function rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) external {
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
    
    function addPortfolio(address _user, string memory _portfolioHash) external {
        profiles[_user].portfolioHashes.push(_portfolioHash);
        
        emit PortfolioAdded(_user, _portfolioHash);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
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

    // ==================== ADDITIONAL REWARDS VIEW FUNCTIONS ====================
    
    function getRewardBandsCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) {
        require(index < rewardBands.length, "Invalid band index");
        RewardBand memory band = rewardBands[index];
        return (band.minAmount, band.maxAmount, band.owPerDollar);
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
}