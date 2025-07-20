// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Interface for OpenworkGenesis storage contract
interface IOpenworkGenesis {
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
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
    }

    // Setters
    function setProfile(address user, string memory ipfsHash, address referrer) external;
    function addPortfolio(address user, string memory portfolioHash) external;
    function setJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external;
    function addJobApplicant(string memory jobId, address applicant) external;
    function setJobApplication(string memory jobId, uint256 applicationId, address applicant, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) external;
    function updateJobStatus(string memory jobId, JobStatus status) external;
    function setJobSelectedApplicant(string memory jobId, address applicant, uint256 applicationId) external;
    function setJobCurrentMilestone(string memory jobId, uint256 milestone) external;
    function addJobFinalMilestone(string memory jobId, string memory description, uint256 amount) external;
    function addWorkSubmission(string memory jobId, string memory submissionHash) external;
    function updateJobTotalPaid(string memory jobId, uint256 amount) external;
    function setJobRating(string memory jobId, address user, uint256 rating) external;
    function setUserTotalOWTokens(address user, uint256 tokens) external;
    
    // Getters
    function getProfile(address user) external view returns (Profile memory);
    function getJob(string memory jobId) external view returns (Job memory);
    function getJobApplication(string memory jobId, uint256 applicationId) external view returns (Application memory);
    function getJobCount() external view returns (uint256);
    function getAllJobIds() external view returns (string[] memory);
    function getJobsByPoster(address poster) external view returns (string[] memory);
    function getJobApplicationCount(string memory jobId) external view returns (uint256);
    function getUserRatings(address user) external view returns (uint256[] memory);
    function jobExists(string memory jobId) external view returns (bool);
    function hasProfile(address user) external view returns (bool);
    function getUserReferrer(address user) external view returns (address);
    function getUserEarnedTokens(address user) external view returns (uint256);
    function getUserGovernanceActions(address user) external view returns (uint256);
    function setUserGovernanceActions(address user, uint256 actions) external;
    function incrementUserGovernanceActions(address user) external;
    function getUserRewardInfo(address user) external view returns (uint256 totalTokens, uint256 governanceActions);
    function totalPlatformPayments() external view returns (uint256);

}

    interface INativeBridge {
        function sendSyncRewardsData(
            uint256 totalPlatformPayments, 
            uint256 userTotalOWTokens, 
            uint256 userGovernanceActions,
            bytes calldata _options
        ) external payable;
    }

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
    
    // Reward bands structure for job-based rewards
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }

    // ==================== STATE VARIABLES ====================
    
    // Genesis storage contract
    IOpenworkGenesis public genesis;
    
    // Reward bands array (kept in this contract for calculations)
    RewardBand[] public rewardBands;
    
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
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);
    event GovernanceActionIncremented(address indexed user, uint256 newGovernanceActionCount);
    event TokensEarned(address indexed user, uint256 tokensEarned, uint256 newPlatformTotal, uint256 newUserTotalTokens);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _bridge, address _genesis) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = _bridge;
        genesis = IOpenworkGenesis(_genesis);
        _initializeRewardBands();
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == address(bridge), "Only bridge can upgrade");
        upgradeToAndCall(newImplementation, "");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = bridge;
        bridge = _bridge;
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    function setGenesis(address _genesis) external onlyOwner {
        address oldGenesis = address(genesis);
        genesis = IOpenworkGenesis(_genesis);
        emit GenesisUpdated(oldGenesis, _genesis);
    }

    // ==================== MESSAGE HANDLERS ====================

    function handleCreateProfile(address user, string memory ipfsHash, address referrer) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        if (!genesis.hasProfile(user)) {
            genesis.setProfile(user, ipfsHash, referrer);
            emit ProfileCreated(user, ipfsHash, referrer);
        }
    }

    function handlePostJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        if (!genesis.jobExists(jobId)) {
            genesis.setJob(jobId, jobGiver, jobDetailHash, descriptions, amounts);
            emit JobPosted(jobId, jobGiver, jobDetailHash);
            emit JobStatusChanged(jobId, JobStatus.Open);
        }
    }

    function handleApplyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        bool alreadyApplied = false;
        for (uint i = 0; i < job.applicants.length; i++) {
            if (job.applicants[i] == applicant) {
                alreadyApplied = true;
                break;
            }
        }
        
        if (!alreadyApplied) {
            genesis.addJobApplicant(jobId, applicant);
            uint256 applicationId = genesis.getJobApplicationCount(jobId) + 1;
            genesis.setJobApplication(jobId, applicationId, applicant, applicationHash, descriptions, amounts);
            emit JobApplication(jobId, applicationId, applicant, applicationHash);
        }
    }

    function handleStartJob(address /* jobGiver */, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        IOpenworkGenesis.Application memory application = genesis.getJobApplication(jobId, applicationId);
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        
        genesis.setJobSelectedApplicant(jobId, application.applicant, applicationId);
        genesis.updateJobStatus(jobId, IOpenworkGenesis.JobStatus.InProgress);
        genesis.setJobCurrentMilestone(jobId, 1);
        
        if (useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                genesis.addJobFinalMilestone(jobId, application.proposedMilestones[i].descriptionHash, application.proposedMilestones[i].amount);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                genesis.addJobFinalMilestone(jobId, job.milestonePayments[i].descriptionHash, job.milestonePayments[i].amount);
            }
        }
        
        emit JobStarted(jobId, applicationId, application.applicant, useApplicantMilestones);
        emit JobStatusChanged(jobId, JobStatus.InProgress);
    }

    function handleSubmitWork(address applicant, string memory jobId, string memory submissionHash) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        genesis.addWorkSubmission(jobId, submissionHash);
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        emit WorkSubmitted(jobId, applicant, submissionHash, job.currentMilestone);
    }

    function handleReleasePayment(address jobGiver, string memory jobId, uint256 amount) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        genesis.updateJobTotalPaid(jobId, amount);

        // ==================== REWARDS CALCULATION ====================
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        address jobTaker = job.selectedApplicant;
        
        // Get referrers from genesis
        address jobGiverReferrer = genesis.getUserReferrer(jobGiver);
        address jobTakerReferrer = genesis.getUserReferrer(jobTaker);
        
        // Calculate reward distribution (same logic as before)
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
        
        // Check if job should be completed
        job = genesis.getJob(jobId); // Re-fetch updated job
        if (job.currentMilestone == job.finalMilestones.length) {
            genesis.updateJobStatus(jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        emit PaymentReleased(jobId, jobGiver, job.selectedApplicant, amount, job.currentMilestone);
    }

    function handleLockNextMilestone(address /* caller */, string memory jobId, uint256 lockedAmount) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        if (job.currentMilestone < job.finalMilestones.length) {
            genesis.setJobCurrentMilestone(jobId, job.currentMilestone + 1);
            emit MilestoneLocked(jobId, job.currentMilestone + 1, lockedAmount);
        }
    }

    function handleReleasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        genesis.updateJobTotalPaid(jobId, releasedAmount);

        // ==================== REWARDS CALCULATION ====================
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        address jobTaker = job.selectedApplicant;
        
        // Get referrers from genesis
        address jobGiverReferrer = genesis.getUserReferrer(jobGiver);
        address jobTakerReferrer = genesis.getUserReferrer(jobTaker);
        
        // Calculate reward distribution (same logic as before)
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
        
        job = genesis.getJob(jobId); // Re-fetch for current milestone
        genesis.setJobCurrentMilestone(jobId, job.currentMilestone + 1);
        
        job = genesis.getJob(jobId); // Re-fetch updated job
        if (job.currentMilestone > job.finalMilestones.length) {
            genesis.updateJobStatus(jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(jobId, releasedAmount, lockedAmount, job.currentMilestone);
    }

    function handleRate(address rater, string memory jobId, address userToRate, uint256 rating) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        bool isAuthorized = false;
        
        if (rater == job.jobGiver && userToRate == job.selectedApplicant) {
            isAuthorized = true;
        } else if (rater == job.selectedApplicant && userToRate == job.jobGiver) {
            isAuthorized = true;
        }
        
        if (isAuthorized) {
            genesis.setJobRating(jobId, userToRate, rating);
            emit UserRated(jobId, rater, userToRate, rating);
        }
    }

    function handleAddPortfolio(address user, string memory portfolioHash) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        genesis.addPortfolio(user, portfolioHash);
        emit PortfolioAdded(user, portfolioHash);
    }

    // ==================== REWARDS INITIALIZATION ====================
    
    function _initializeRewardBands() private {
        // Job-based reward bands (same as before)
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
        // Use platform total instead of user cumulative
        uint256 currentPlatformTotal = genesis.totalPlatformPayments();
        uint256 newPlatformTotal = currentPlatformTotal + amountUSDT;
        
        // Calculate tokens based on platform-wide progression
        uint256 tokensToAward = calculateTokensForRange(currentPlatformTotal, newPlatformTotal);
        
        // Update user's total tokens in genesis
        (uint256 currentTotalTokens, ) = genesis.getUserRewardInfo(user);
        genesis.setUserTotalOWTokens(user, currentTotalTokens + tokensToAward);
        
        // Emit event with new values
        emit TokensEarned(user, tokensToAward, newPlatformTotal, currentTotalTokens + tokensToAward);
    }

    // ==================== PUBLIC REWARDS VIEW FUNCTIONS ====================
    
    function getUserEarnedTokens(address user) external view returns (uint256) {
        return genesis.getUserEarnedTokens(user);
    }

    function getUserRewardInfo(address user) external view returns (
    uint256 totalTokens,
    uint256 governanceActions
    ) {
    return genesis.getUserRewardInfo(user);
    }

    function getUserGovernanceActions(address user) external view returns (uint256) {
    return genesis.getUserGovernanceActions(user);
    }

    function calculateTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        // Use platform total instead of user cumulative
        uint256 currentPlatformTotal = genesis.totalPlatformPayments();
        uint256 newPlatformTotal = currentPlatformTotal + additionalAmount;
        return calculateTokensForRange(currentPlatformTotal, newPlatformTotal);
    }

    // ==================== LOCAL FUNCTIONS (for direct use if needed) ====================
    
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) external {
        require(!genesis.hasProfile(_user), "Profile already exists");
        
        genesis.setProfile(_user, _ipfsHash, _referrerAddress);
        emit ProfileCreated(_user, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        IOpenworkGenesis.Profile memory genesisProfile = genesis.getProfile(_user);
        return Profile({
            userAddress: genesisProfile.userAddress,
            ipfsHash: genesisProfile.ipfsHash,
            referrerAddress: genesisProfile.referrerAddress,
            portfolioHashes: genesisProfile.portfolioHashes
        });
    }
    
    function postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external {
        require(!genesis.jobExists(_jobId), "Job ID already exists");
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        genesis.setJob(_jobId, _jobGiver, _jobDetailHash, _descriptions, _amounts);
        emit JobPosted(_jobId, _jobGiver, _jobDetailHash);
        emit JobStatusChanged(_jobId, JobStatus.Open);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        IOpenworkGenesis.Job memory genesisJob = genesis.getJob(_jobId);
        return Job({
            id: genesisJob.id,
            jobGiver: genesisJob.jobGiver,
            applicants: genesisJob.applicants,
            jobDetailHash: genesisJob.jobDetailHash,
            status: JobStatus(uint8(genesisJob.status)),
            workSubmissions: genesisJob.workSubmissions,
            milestonePayments: _convertMilestones(genesisJob.milestonePayments),
            finalMilestones: _convertMilestones(genesisJob.finalMilestones),
            totalPaid: genesisJob.totalPaid,
            currentMilestone: genesisJob.currentMilestone,
            selectedApplicant: genesisJob.selectedApplicant,
            selectedApplicationId: genesisJob.selectedApplicationId
        });
    }
    
    function _convertMilestones(IOpenworkGenesis.MilestonePayment[] memory genesisMilestones) private pure returns (MilestonePayment[] memory) {
        MilestonePayment[] memory milestones = new MilestonePayment[](genesisMilestones.length);
        for (uint i = 0; i < genesisMilestones.length; i++) {
            milestones[i] = MilestonePayment({
                descriptionHash: genesisMilestones[i].descriptionHash,
                amount: genesisMilestones[i].amount
            });
        }
        return milestones;
    }
    
    function applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts) external {
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        for (uint i = 0; i < job.applicants.length; i++) {
            require(job.applicants[i] != _applicant, "Already applied to this job");
        }
        
        genesis.addJobApplicant(_jobId, _applicant);
        uint256 applicationId = genesis.getJobApplicationCount(_jobId) + 1;
        genesis.setJobApplication(_jobId, applicationId, _applicant, _applicationHash, _descriptions, _amounts);
        emit JobApplication(_jobId, applicationId, _applicant, _applicationHash);
    }
    
    function startJob(address /* _jobGiver */, string memory _jobId, uint256 _applicationId, bool _useApplicantMilestones) external {
        IOpenworkGenesis.Application memory application = genesis.getJobApplication(_jobId, _applicationId);
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        
        genesis.setJobSelectedApplicant(_jobId, application.applicant, _applicationId);
        genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.InProgress);
        genesis.setJobCurrentMilestone(_jobId, 1);
        
        if (_useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                genesis.addJobFinalMilestone(_jobId, application.proposedMilestones[i].descriptionHash, application.proposedMilestones[i].amount);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                genesis.addJobFinalMilestone(_jobId, job.milestonePayments[i].descriptionHash, job.milestonePayments[i].amount);
            }
        }
        
        emit JobStarted(_jobId, _applicationId, application.applicant, _useApplicantMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
    }
    
    function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(genesis.getJobApplicationCount(_jobId) >= _applicationId, "Application does not exist");
        IOpenworkGenesis.Application memory genesisApp = genesis.getJobApplication(_jobId, _applicationId);
        return Application({
            id: genesisApp.id,
            jobId: genesisApp.jobId,
            applicant: genesisApp.applicant,
            applicationHash: genesisApp.applicationHash,
            proposedMilestones: _convertMilestones(genesisApp.proposedMilestones)
        });
    }
    
    function submitWork(address _applicant, string memory _jobId, string memory _submissionHash) external {
        genesis.addWorkSubmission(_jobId, _submissionHash);
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        emit WorkSubmitted(_jobId, _applicant, _submissionHash, job.currentMilestone);
    }
    
    function releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) external {
        genesis.updateJobTotalPaid(_jobId, _amount);

        // ==================== REWARDS CALCULATION ====================
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        address jobTaker = job.selectedApplicant;
        
        // Get referrers from genesis
        address jobGiverReferrer = genesis.getUserReferrer(_jobGiver);
        address jobTakerReferrer = genesis.getUserReferrer(jobTaker);
        
        // Calculate reward distribution (same logic as before)
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
        
        // Check if job should be completed
        job = genesis.getJob(_jobId); // Re-fetch updated job
        if (job.currentMilestone == job.finalMilestones.length) {
            genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        emit PaymentReleased(_jobId, _jobGiver, job.selectedApplicant, _amount, job.currentMilestone);
    }
    
    function lockNextMilestone(address /* _caller */, string memory _jobId, uint256 _lockedAmount) external {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(job.currentMilestone < job.finalMilestones.length, "All milestones already completed");
        
        genesis.setJobCurrentMilestone(_jobId, job.currentMilestone + 1);
        emit MilestoneLocked(_jobId, job.currentMilestone + 1, _lockedAmount);
    }
    
    function releasePaymentAndLockNext(address _jobGiver, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) external {
        genesis.updateJobTotalPaid(_jobId, _releasedAmount);

        // ==================== REWARDS CALCULATION ====================
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        address jobTaker = job.selectedApplicant;
        
        // Get referrers from genesis
        address jobGiverReferrer = genesis.getUserReferrer(_jobGiver);
        address jobTakerReferrer = genesis.getUserReferrer(jobTaker);
        
        // Calculate reward distribution (same logic as before)
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
        
        job = genesis.getJob(_jobId); // Re-fetch for current milestone
        genesis.setJobCurrentMilestone(_jobId, job.currentMilestone + 1);
        
        job = genesis.getJob(_jobId); // Re-fetch updated job
        if (job.currentMilestone > job.finalMilestones.length) {
            genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, _releasedAmount, _lockedAmount, job.currentMilestone);
    }
    
    function rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) external {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        bool isAuthorized = false;
        
        if (_rater == job.jobGiver && _userToRate == job.selectedApplicant) {
            isAuthorized = true;
        } else if (_rater == job.selectedApplicant && _userToRate == job.jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized to rate this user for this job");
        
        genesis.setJobRating(_jobId, _userToRate, _rating);
        emit UserRated(_jobId, _rater, _userToRate, _rating);
    }

    function incrementGovernanceAction(address user) external {
    require(msg.sender == bridge, "Only bridge can call this function");
    genesis.incrementUserGovernanceActions(user);
    emit GovernanceActionIncremented(user, genesis.getUserGovernanceActions(user));
    }   

    function syncRewardsData(bytes calldata _options) external payable {
        require(bridge != address(0), "Bridge not set");
        
        uint256 totalPlatformPayments = genesis.totalPlatformPayments();
        uint256 userTotalOWTokens = genesis.getUserEarnedTokens(msg.sender);
        uint256 userGovernanceActions = genesis.getUserGovernanceActions(msg.sender);
        
        // Send to native bridge
        INativeBridge(bridge).sendSyncRewardsData{value: msg.value}(
            totalPlatformPayments, 
            userTotalOWTokens, 
            userGovernanceActions,
            _options
        );
    }
    
    function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = genesis.getUserRatings(_user);
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
        genesis.addPortfolio(_user, _portfolioHash);
        emit PortfolioAdded(_user, _portfolioHash);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getJobCount() external view returns (uint256) {
        return genesis.getJobCount();
    }
    
    function getAllJobIds() external view returns (string[] memory) {
        return genesis.getAllJobIds();
    }
    
    function getJobsByPoster(address _poster) external view returns (string[] memory) {
        return genesis.getJobsByPoster(_poster);
    }
    
    function getJobApplicationCount(string memory _jobId) external view returns (uint256) {
        return genesis.getJobApplicationCount(_jobId);
    }
    
    function isJobOpen(string memory _jobId) external view returns (bool) {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        return job.status == IOpenworkGenesis.JobStatus.Open;
    }
    
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        return JobStatus(uint8(job.status));
    }
    
    function jobExists(string memory _jobId) external view returns (bool) {
        return genesis.jobExists(_jobId);
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
        return genesis.getUserReferrer(user);
    }
    
    function getTotalPlatformPayments() external view returns (uint256) {
        return genesis.totalPlatformPayments();
    }
}