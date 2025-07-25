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

    // Job and profile management
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
    
    // Legacy reward functions (for backward compatibility)
    function setUserTotalOWTokens(address user, uint256 tokens) external;
    function incrementUserGovernanceActions(address user) external;
    function setUserGovernanceActions(address user, uint256 actions) external;
    function updateUserClaimData(address user, uint256 claimedTokens) external;    
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
    function getUserGovernanceActionsInBand(address user, uint256 band) external view returns (uint256);
    function getUserTotalGovernanceActions(address user) external view returns (uint256);
    function getUserRewardInfo(address user) external view returns (uint256 totalTokens, uint256 governanceActions);
    function totalPlatformPayments() external view returns (uint256);
}

// Interface for the RewardsContract
interface IOpenWorkRewards {
    function processJobPayment(
        address jobGiver,
        address jobTaker, 
        uint256 amount,
        uint256 newPlatformTotal
    ) external returns (uint256[] memory tokensAwarded);
    
    function recordGovernanceAction(address user) external;
    function calculateUserClaimableTokens(address user) external view returns (uint256);
    function claimTokens(address user, uint256 amount) external returns (bool);
    function getUserTotalTokensEarned(address user) external view returns (uint256);
    function getUserGovernanceActionsInBand(address user, uint256 band) external view returns (uint256);
    function getUserTotalGovernanceActions(address user) external view returns (uint256);
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) external view returns (uint256);
    function getCurrentBand() external view returns (uint256);
    function getPlatformBandInfo() external view returns (
        uint256 currentBand,
        uint256 currentTotal,
        uint256 bandMinAmount,
        uint256 bandMaxAmount,
        uint256 governanceRewardRate
    );
    
    function getUserTotalClaimableTokens(address user) external view returns (uint256);
    function markTokensClaimed(address user, uint256 amount) external returns (bool);
}

interface INativeBridge {
    function sendSyncRewardsData(
        address user,
        uint256 claimableAmount,
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

    // ==================== STATE VARIABLES ====================
    
    // Genesis storage contract
    IOpenworkGenesis public genesis;
    
    // RewardsContract reference
    IOpenWorkRewards public rewardsContract;
    
    // Bridge reference
    address public bridge;
    
    // NEW: Track last synced band per user to avoid duplicate syncing
  //  mapping(address => uint256) public userLastSyncedBand;

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
    event RewardsContractUpdated(address indexed oldRewards, address indexed newRewards);
    event GovernanceActionIncremented(address indexed user, uint256 newGovernanceActionCount, uint256 indexed band);
    event TokensEarned(address indexed user, uint256 tokensEarned, uint256 newPlatformTotal, uint256 newUserTotalTokens);
    event ClaimDataUpdated(address indexed user, uint256 claimedJobTokens, uint256 claimedGovernanceTokens);
    event RewardsDataSynced(address indexed user, uint256 syncType, uint256 claimableAmount, uint256 reserved);   

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner, 
        address _bridge, 
        address _genesis,
        address _rewardsContract
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = _bridge;
        genesis = IOpenworkGenesis(_genesis);
        rewardsContract = IOpenWorkRewards(_rewardsContract);
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
    
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        address oldRewards = address(rewardsContract);
        rewardsContract = IOpenWorkRewards(_rewardsContract);
        emit RewardsContractUpdated(oldRewards, _rewardsContract);
    }

    // ==================== MESSAGE HANDLERS ====================


    function handleUpdateUserClaimData(
    address user, 
    uint256 claimedTokens
    ) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        // Update Genesis for backward compatibility
        genesis.updateUserClaimData(user, claimedTokens);
        
        // Update Native Rewards Contract to mark tokens as claimed
        if (address(rewardsContract) != address(0)) {
            rewardsContract.markTokensClaimed(user, claimedTokens);
        }
        
        emit ClaimDataUpdated(user, claimedTokens, 0);
    }

    // ==================== GOVERNANCE ACTION HANDLER ====================
    
    /**
     * @dev Increment governance action for a user
     * Called by bridge when user performs governance actions
     */
    function incrementGovernanceAction(address user) external {
        require(msg.sender == bridge, "Only bridge can call this function");
        
        // Update Genesis for backward compatibility
        genesis.incrementUserGovernanceActions(user);
        
        // Delegate to RewardsContract for band-specific tracking
        if (address(rewardsContract) != address(0)) {
            rewardsContract.recordGovernanceAction(user);
        }
        
        // Get current band from RewardsContract for event
        uint256 currentBand = address(rewardsContract) != address(0) ? 
            rewardsContract.getCurrentBand() : 0;
        
        uint256 newTotal = genesis.getUserTotalGovernanceActions(user);
        emit GovernanceActionIncremented(user, newTotal, currentBand);
    }

    // ==================== INTERNAL REWARD PROCESSING ====================
    
    /**
     * @dev Process rewards for a payment by delegating to RewardsContract
     */
    function _processRewardsForPayment(address jobGiver, string memory jobId, uint256 amount) internal {
        if (address(rewardsContract) == address(0)) return;
        
        IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
        address jobTaker = job.selectedApplicant;
        
        // Get new platform total after this payment
        uint256 newPlatformTotal = genesis.totalPlatformPayments();
        
        // Delegate reward calculation to RewardsContract
        uint256[] memory tokensAwarded = rewardsContract.processJobPayment(
            jobGiver,
            jobTaker,
            amount,
            newPlatformTotal
        );
        
        // Update Genesis with calculated tokens (for backward compatibility)
        if (tokensAwarded.length > 0 && tokensAwarded[0] > 0) {
            uint256 currentTokens = genesis.getUserEarnedTokens(jobGiver);
            genesis.setUserTotalOWTokens(jobGiver, currentTokens + tokensAwarded[0]);
            emit TokensEarned(jobGiver, tokensAwarded[0], newPlatformTotal, currentTokens + tokensAwarded[0]);
        }
        
        // Handle referrer rewards if any
        if (tokensAwarded.length > 1 && tokensAwarded[1] > 0) {
            address jobGiverReferrer = genesis.getUserReferrer(jobGiver);
            if (jobGiverReferrer != address(0)) {
                uint256 currentTokens = genesis.getUserEarnedTokens(jobGiverReferrer);
                genesis.setUserTotalOWTokens(jobGiverReferrer, currentTokens + tokensAwarded[1]);
                emit TokensEarned(jobGiverReferrer, tokensAwarded[1], newPlatformTotal, currentTokens + tokensAwarded[1]);
            }
        }
        
        if (tokensAwarded.length > 2 && tokensAwarded[2] > 0) {
            address jobTakerReferrer = genesis.getUserReferrer(jobTaker);
            if (jobTakerReferrer != address(0)) {
                uint256 currentTokens = genesis.getUserEarnedTokens(jobTakerReferrer);
                genesis.setUserTotalOWTokens(jobTakerReferrer, currentTokens + tokensAwarded[2]);
                emit TokensEarned(jobTakerReferrer, tokensAwarded[2], newPlatformTotal, currentTokens + tokensAwarded[2]);
            }
        }
    }

    // ==================== REWARDS VIEW FUNCTIONS (DELEGATE TO REWARDS CONTRACT) ====================
    
    function getUserEarnedTokens(address user) external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getUserTotalTokensEarned(user);
        }
        return genesis.getUserEarnedTokens(user);
    }

    function getUserRewardInfo(address user) external view returns (
        uint256 totalTokens,
        uint256 governanceActions
    ) {
        if (address(rewardsContract) != address(0)) {
            totalTokens = rewardsContract.getUserTotalTokensEarned(user);
            governanceActions = rewardsContract.getUserTotalGovernanceActions(user);
        } else {
            return genesis.getUserRewardInfo(user);
        }
    }

    function getUserGovernanceActions(address user) external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getUserTotalGovernanceActions(user);
        }
        return genesis.getUserTotalGovernanceActions(user);
    }

    function getUserGovernanceActionsInBand(address user, uint256 band) external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getUserGovernanceActionsInBand(user, band);
        }
        return genesis.getUserGovernanceActionsInBand(user, band);
    }

    function calculateTokensForAmount(address /* user */, uint256 additionalAmount) external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            uint256 currentPlatformTotal = genesis.totalPlatformPayments();
            uint256 newPlatformTotal = currentPlatformTotal + additionalAmount;
            return rewardsContract.calculateTokensForRange(currentPlatformTotal, newPlatformTotal);
        }
        return 0; // Fallback if rewards contract not set
    }

    function getUserTotalClaimableTokens(address user) external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getUserTotalClaimableTokens(user);
        }
        return 0;
    }

    function getCurrentBand() external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getCurrentBand();
        }
        return 0;
    }

    function getPlatformBandInfo() external view returns (
        uint256 currentBand,
        uint256 currentTotal,
        uint256 bandMinAmount,
        uint256 bandMaxAmount,
        uint256 governanceRewardRate
    ) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getPlatformBandInfo();
        }
        return (0, genesis.totalPlatformPayments(), 0, 0, 0);
    }

    // ==================== JOB MANAGEMENT FUNCTIONS ====================
    
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
        // Update job total paid in Genesis
        genesis.updateJobTotalPaid(_jobId, _amount);

        // Delegate to RewardsContract for token calculation and distribution
        _processRewardsForPayment(_jobGiver, _jobId, _amount);
        
        // Check if job should be completed
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
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
        // Update job total paid in Genesis
        genesis.updateJobTotalPaid(_jobId, _releasedAmount);

        // Delegate to RewardsContract for token calculation and distribution
        _processRewardsForPayment(_jobGiver, _jobId, _releasedAmount);
        
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
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

    function addPortfolio(address _user, string memory _portfolioHash) external {
        genesis.addPortfolio(_user, _portfolioHash);
        emit PortfolioAdded(_user, _portfolioHash);
    }

    // ==================== BRIDGE INTEGRATION ====================

    function syncRewardsData(bytes calldata _options) external payable {
    require(bridge != address(0), "Bridge not set");
    
    // Get user's total claimable tokens from rewards contract
    uint256 claimableAmount = address(rewardsContract) != address(0) ? 
        rewardsContract.getUserTotalClaimableTokens(msg.sender) : 0;
    
    require(claimableAmount > 0, "No tokens to sync");
    
    // Send simple data to bridge
    INativeBridge(bridge).sendSyncRewardsData{value: msg.value}(
        msg.sender,
        claimableAmount,
        _options
    );
    
    emit RewardsDataSynced(msg.sender, 1, claimableAmount, 0); // Simplified event
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

    function getUserReferrer(address user) external view returns (address) {
        return genesis.getUserReferrer(user);
    }
    
    function getTotalPlatformPayments() external view returns (uint256) {
        return genesis.totalPlatformPayments();
    }
}