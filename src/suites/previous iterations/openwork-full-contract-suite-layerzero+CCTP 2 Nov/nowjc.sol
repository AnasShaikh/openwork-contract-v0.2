// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    function setJobApplication(string memory jobId, uint256 applicationId, address applicant, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts, uint32 preferredPaymentChainDomain, address preferredPaymentAddress) external;
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
    function getUserGovernanceActions(address user) external view returns (uint256); // Change from getUserTotalGovernanceActions
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

    function sendSyncVotingPower(
        address user,
        uint256 totalRewards,
        bytes calldata _options
    ) external payable;
}

// CCTP Transceiver interface for cross-chain USDC transfers
interface ICCTPTransceiver {
    function sendFast(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee
    ) external;
    
    function addressToBytes32(address addr) external pure returns (bytes32);
}

contract NativeOpenWorkJobContract is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
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
    address[] private allProfileUsers;
    uint256 private profileCount;
    mapping(address => bool) public authorizedContracts;
    
    // USDT token and CCTP receiver
    IERC20 public usdtToken;
    address public cctpReceiver;
    
    // CCTP transceiver for cross-chain payments
    address public cctpTransceiver;
    
    // Native Athena authorization for dispute resolution
    address public nativeAthena;
    
    // Mapping to store applicant preferred chain domains for dispute resolution
    mapping(string => mapping(address => uint32)) public jobApplicantChainDomain;
    
    // Commission tracking
    address public treasury;
    uint256 public accumulatedCommission;
    uint256 public commissionPercentage = 100; // 1% in basis points (100/10000)
    uint256 public minCommission = 1e6; // 1 USDC (6 decimals)

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
    event AuthorizedContractAdded(address indexed contractAddress);
    event AuthorizedContractRemoved(address indexed contractAddress);
    event DisputedFundsReleased(string indexed jobId, address indexed winner, uint32 winnerChainDomain, uint256 amount);
    event NativeAthenaUpdated(address indexed oldNativeAthena, address indexed newNativeAthena);
    event CommissionDeducted(string indexed jobId, uint256 grossAmount, uint256 commission, uint256 netAmount);
    event CommissionWithdrawn(address indexed treasury, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event CommissionPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    event MinCommissionUpdated(uint256 oldMin, uint256 newMin);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner, 
        address _bridge, 
        address _genesis,
        address _rewardsContract,
        address _usdtToken,
        address _cctpReceiver
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = _bridge;
        genesis = IOpenworkGenesis(_genesis);
        rewardsContract = IOpenWorkRewards(_rewardsContract);
        usdtToken = IERC20(_usdtToken);
        cctpReceiver = _cctpReceiver;
    }

    function addAuthorizedContract(address contractAddress) external onlyOwner {
        require(contractAddress != address(0), "Invalid address");
        authorizedContracts[contractAddress] = true;
        emit AuthorizedContractAdded(contractAddress);
    }

    function removeAuthorizedContract(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = false;
        emit AuthorizedContractRemoved(contractAddress);
    }

    function isAuthorizedContract(address contractAddress) external view returns (bool) {
        return authorizedContracts[contractAddress];
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == address(bridge), "Only bridge");
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
    
    function setCCTPReceiver(address _cctpReceiver) external onlyOwner {
        require(_cctpReceiver != address(0), "Invalid address");
        cctpReceiver = _cctpReceiver;
    }
    
    function setCCTPTransceiver(address _cctpTransceiver) external onlyOwner {
        require(_cctpTransceiver != address(0), "Invalid address");
        cctpTransceiver = _cctpTransceiver;
    }
    
    function setNativeAthena(address _nativeAthena) external onlyOwner {
        address oldNativeAthena = nativeAthena;
        nativeAthena = _nativeAthena;
        emit NativeAthenaUpdated(oldNativeAthena, _nativeAthena);
    }
    
    function setApplicantChainDomain(string memory _jobId, address _applicant, uint32 _chainDomain) external {
        require(authorizedContracts[msg.sender], "Not authorized");
        jobApplicantChainDomain[_jobId][_applicant] = _chainDomain;
    }
    
    // ==================== COMMISSION MANAGEMENT ====================
    
    /**
     * @dev Calculate commission for a given amount
     * @param amount The payment amount
     * @return The commission amount (1% or minCommission, whichever is higher)
     */
    function calculateCommission(uint256 amount) public view returns (uint256) {
        uint256 percentCommission = (amount * commissionPercentage) / 10000;
        return percentCommission > minCommission ? percentCommission : minCommission;
    }
    
    /**
     * @dev Set treasury address (owner only)
     * @param _treasury The treasury wallet address
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(oldTreasury, _treasury);
    }
    
    /**
     * @dev Set commission percentage (owner only)
     * @param _percentage Commission percentage in basis points (e.g., 100 = 1%)
     */
    function setCommissionPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage <= 1000, "Max 10%"); // Safety cap at 10%
        uint256 oldPercentage = commissionPercentage;
        commissionPercentage = _percentage;
        emit CommissionPercentageUpdated(oldPercentage, _percentage);
    }
    
    /**
     * @dev Set minimum commission amount (owner only)
     * @param _minCommission Minimum commission in USDC (6 decimals)
     */
    function setMinCommission(uint256 _minCommission) external onlyOwner {
        uint256 oldMin = minCommission;
        minCommission = _minCommission;
        emit MinCommissionUpdated(oldMin, _minCommission);
    }
    
    /**
     * @dev Withdraw accumulated commission (treasury only)
     * @param amount Amount to withdraw
     */
    function withdrawCommission(uint256 amount) external {
        require(msg.sender == treasury, "Only treasury");
        require(amount <= accumulatedCommission, "Insufficient commission");
        require(amount > 0, "Invalid amount");
        
        accumulatedCommission -= amount;
        usdtToken.safeTransfer(treasury, amount);
        
        emit CommissionWithdrawn(treasury, amount);
    }
    
    /**
     * @dev Withdraw all accumulated commission (treasury only)
     */
    function withdrawAllCommission() external {
        require(msg.sender == treasury, "Only treasury");
        require(accumulatedCommission > 0, "No commission");
        
        uint256 amount = accumulatedCommission;
        accumulatedCommission = 0;
        usdtToken.safeTransfer(treasury, amount);
        
        emit CommissionWithdrawn(treasury, amount);
    }
    
    function withdrawFunds(address _to, uint256 _amount) internal {
        require(cctpReceiver != address(0), "CCTP not set");
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Invalid amount");
        
        // Call CCTP receiver to withdraw funds (for same-chain withdrawals only)
        // Note: Cross-chain payments use sendFast() directly via cctpTransceiver
        (bool success, ) = cctpReceiver.call(abi.encodeWithSignature("withdrawFunds(address,uint256)", _to, _amount));
        require(success, "Withdrawal failed");
    }

    // ==================== MESSAGE HANDLERS ====================

    function handleUpdateUserClaimData(
    address user, 
    uint256 claimedTokens
    ) external {
        require(msg.sender == bridge, "Only bridge");
        
        // Update Genesis for backward compatibility
        genesis.updateUserClaimData(user, claimedTokens);
        
        // Update Native Rewards Contract to mark tokens as claimed
        if (address(rewardsContract) != address(0)) {
            rewardsContract.markTokensClaimed(user, claimedTokens);
        }
        
        emit ClaimDataUpdated(user, claimedTokens, 0);
    }
    
    function handleReleasePaymentCrossChain(
        address _jobGiver,
        string memory _jobId,
        uint256 _amount,
        uint32 _targetChainDomain,
        address _targetRecipient
    ) external {
        require(msg.sender == bridge, "Only bridge");
        
        releasePaymentCrossChain(_jobGiver, _jobId, _amount, _targetChainDomain, _targetRecipient);
    }

    // ==================== GOVERNANCE ACTION HANDLER ====================
    
    /**
     * @dev Increment governance action for a user
     * Called by bridge when user performs governance actions
     */
    function incrementGovernanceAction(address user) external {
       /* require(
                msg.sender == bridge || authorizedContracts[msg.sender], 
                "Only bridge or authorized"
            );  */      
        // Update Genesis for backward compatibility
        genesis.incrementUserGovernanceActions(user);
        
        // Delegate to RewardsContract for band-specific tracking
        if (address(rewardsContract) != address(0)) {
            rewardsContract.recordGovernanceAction(user);
        }
        
        // Get current band from RewardsContract for event
        uint256 currentBand = address(rewardsContract) != address(0) ? 
            rewardsContract.getCurrentBand() : 0;
        
        uint256 newTotal = genesis.getUserGovernanceActions(user);
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
        
        // Get current platform total and calculate NEW total after this payment
        uint256 currentPlatformTotal = genesis.totalPlatformPayments();
        uint256 newPlatformTotal = currentPlatformTotal + amount;
        
        // Delegate reward calculation to RewardsContract
        rewardsContract.processJobPayment(
            jobGiver,
            jobTaker,
            amount,
            newPlatformTotal
        );
    }

    function syncVotingPower(bytes calldata _options) external payable {
        require(bridge != address(0), "Bridge not set");
        
        // Get user's total earned tokens from rewards contract
        uint256 totalEarnedTokens = address(rewardsContract) != address(0) ? 
            rewardsContract.getUserTotalTokensEarned(msg.sender) : 0;
        
        require(totalEarnedTokens > 0, "No tokens");
        
        // Send to bridge
        INativeBridge(bridge).sendSyncVotingPower{value: msg.value}(
            msg.sender,
            totalEarnedTokens,
            _options
        );
        
        emit RewardsDataSynced(msg.sender, 2, totalEarnedTokens, 0); // Type 2 for voting power sync
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
        return genesis.getUserGovernanceActions(user);
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

  /*  function getUserTotalClaimableTokens(address user) external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getUserTotalClaimableTokens(user);
        }
        return 0;
    }*/

   /* function getCurrentBand() external view returns (uint256) {
        if (address(rewardsContract) != address(0)) {
            return rewardsContract.getCurrentBand();
        }
        return 0;
    }*/

  /*  function getPlatformBandInfo() external view returns (
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
    }*/

    // ==================== JOB MANAGEMENT FUNCTIONS ====================
    
    /* COMMENTED OUT TO SAVE CONTRACT SIZE - Use Genesis directly for profiles
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) external {
        require(!genesis.hasProfile(_user), "Profile exists");

        allProfileUsers.push(_user);
        profileCount++;
        
        genesis.setProfile(_user, _ipfsHash, _referrerAddress);
        emit ProfileCreated(_user, _ipfsHash, _referrerAddress);
    }
    */
    
   /* function getProfile(address _user) public view returns (Profile memory) {
        IOpenworkGenesis.Profile memory genesisProfile = genesis.getProfile(_user);
        return Profile({
            userAddress: genesisProfile.userAddress,
            ipfsHash: genesisProfile.ipfsHash,
            referrerAddress: genesisProfile.referrerAddress,
            portfolioHashes: genesisProfile.portfolioHashes
        });
    }*/
    
    function postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external {
        require(!genesis.jobExists(_jobId), "Job exists");
        require(_descriptions.length == _amounts.length, "Length mismatch");
        
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
    
    function applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts, uint32 _preferredChainDomain) external {
      require(_descriptions.length == _amounts.length, "Length mismatch");
        
      IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        for (uint i = 0; i < job.applicants.length; i++) {
            require(job.applicants[i] != _applicant, "Already applied");
        }
        
        genesis.addJobApplicant(_jobId, _applicant);
        uint256 applicationId = genesis.getJobApplicationCount(_jobId) + 1;
        genesis.setJobApplication(_jobId, applicationId, _applicant, _applicationHash, _descriptions, _amounts, _preferredChainDomain, _applicant);
        
        // Store applicant's preferred chain domain for dispute resolution
        jobApplicantChainDomain[_jobId][_applicant] = _preferredChainDomain;
        
        emit JobApplication(_jobId, applicationId, _applicant, _applicationHash);
    }
    
    function handleStartDirectContract(
        address _jobGiver,
        address _jobTaker,
        string memory _jobId,
        string memory _jobDetailHash,
        string[] memory _descriptions,
        uint256[] memory _amounts,
        uint32 _jobTakerChainDomain
    ) external {
        require(msg.sender == bridge, "Only bridge can call");
        require(!genesis.jobExists(_jobId), "Job already exists");
        require(_descriptions.length == _amounts.length, "Length mismatch");
        require(_descriptions.length > 0, "Must have milestones");
        
        // 1. Create job in Genesis
        genesis.setJob(_jobId, _jobGiver, _jobDetailHash, _descriptions, _amounts);
        
        // 2. Create auto-application in Genesis
      genesis.addJobApplicant(_jobId, _jobTaker);
        
       uint256 applicationId = 1;
       genesis.setJobApplication(
            _jobId,
            applicationId,
            _jobTaker,
            "direct-contract-auto-application",
            _descriptions,
            _amounts,
            _jobTakerChainDomain,
            _jobTaker
        );
        
        // Store applicant's preferred chain for dispute resolution
        jobApplicantChainDomain[_jobId][_jobTaker] = _jobTakerChainDomain;
        
        // 3. Select applicant & start job
        genesis.setJobSelectedApplicant(_jobId, _jobTaker, applicationId);
        genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.InProgress);
        genesis.setJobCurrentMilestone(_jobId, 1);
        
         // 4. Set final milestones (use job giver's milestones)
        for (uint i = 0; i < _descriptions.length; i++) {
            genesis.addJobFinalMilestone(_jobId, _descriptions[i], _amounts[i]);
        }
        
     // 5. Emit events
        emit JobPosted(_jobId, _jobGiver, _jobDetailHash);
        emit JobApplication(_jobId, applicationId, _jobTaker, "direct-contract-auto-application");
        emit JobStarted(_jobId, applicationId, _jobTaker, false);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
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
    
  /*  function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(genesis.getJobApplicationCount(_jobId) >= _applicationId, "App not exist");
        IOpenworkGenesis.Application memory genesisApp = genesis.getJobApplication(_jobId, _applicationId);
        return Application({
            id: genesisApp.id,
            jobId: genesisApp.jobId,
            applicant: genesisApp.applicant,
            applicationHash: genesisApp.applicationHash,
            proposedMilestones: _convertMilestones(genesisApp.proposedMilestones)
        });
    }*/
    
    function submitWork(address _applicant, string memory _jobId, string memory _submissionHash) external {
        genesis.addWorkSubmission(_jobId, _submissionHash);
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        emit WorkSubmitted(_jobId, _applicant, _submissionHash, job.currentMilestone);
    }
    
    // function releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) external {
    //     require(msg.sender == bridge, "Only bridge");
        
    //     IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
    //     require(job.selectedApplicant != address(0), "No applicant");
        
    //     // Transfer USDC directly from NOWJC to job taker (NOWJC now holds USDC)
    //     usdtToken.safeTransfer(job.selectedApplicant, _amount);
        
    //     // Update job total paid in Genesis
    //     genesis.updateJobTotalPaid(_jobId, _amount);

    //     // Delegate to RewardsContract for token calculation and distribution
    //     _processRewardsForPayment(_jobGiver, _jobId, _amount);
        
    //     // Check if job should be completed
    //     if (job.currentMilestone == job.finalMilestones.length) {
    //         genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Completed);
    //         emit JobStatusChanged(_jobId, JobStatus.Completed);
    //     }
        
    //     emit PaymentReleased(_jobId, _jobGiver, job.selectedApplicant, _amount, job.currentMilestone);
    // }
    
    function releasePaymentCrossChain(
        address _jobGiver, 
        string memory _jobId, 
        uint256 _amount,
        uint32 _targetChainDomain,
        address _targetRecipient
    ) public {
        // ✅ REMOVED: require(msg.sender == bridge, "Only bridge");
        require(cctpTransceiver != address(0), "Transceiver not set");
        require(_targetRecipient != address(0), "Invalid recipient");
        require(_amount > 0, "Invalid amount");
        // ✅ REMOVED: require(_targetChainDomain > 0, "Invalid domain");
        
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(job.selectedApplicant != address(0), "No applicant");
        require(job.status == IOpenworkGenesis.JobStatus.InProgress, "Job not in progress");
        require(job.currentMilestone > 0 && job.currentMilestone <= job.finalMilestones.length, "Invalid milestone");
        
        // ✅ MILESTONE GUARD: Validate amount matches current milestone
        uint256 milestoneIndex = job.currentMilestone - 1;
        require(_amount == job.finalMilestones[milestoneIndex].amount, "Amount must match milestone");
        
        // Calculate and deduct commission
        uint256 commission = calculateCommission(_amount);
        uint256 netAmount = _amount - commission;
        
        // Accumulate commission
        accumulatedCommission += commission;
        
        // Convert target recipient address to bytes32 for CCTP  
        bytes32 mintRecipient = bytes32(uint256(uint160(_targetRecipient)));
        
        // ✅ CRITICAL FIX: Approve CCTP transceiver to spend USDC before sendFast()
        usdtToken.approve(cctpTransceiver, netAmount);
        
        // Send USDC via CCTP to target chain NOWJC (not end user)
        // Target chain NOWJC will handle distribution to end user
        ICCTPTransceiver(cctpTransceiver).sendFast(
            netAmount,           // Amount of USDC to send after commission (6 decimals)
            _targetChainDomain,  // CCTP domain (2=OP Sepolia, 3=Arb Sepolia, etc)
            mintRecipient,       // Target chain NOWJC address as bytes32
            1000                 // maxFee (1000 to match working LOWJC implementation)
        );
        
        // Delegate to RewardsContract for token calculation and distribution (with net amount)
        // IMPORTANT: Call this BEFORE updating platform total so rewards contract gets correct values
        _processRewardsForPayment(_jobGiver, _jobId, netAmount);

        // Update job total paid in Genesis (with net amount)
        genesis.updateJobTotalPaid(_jobId, netAmount);
        
        // ✅ INCREMENT MILESTONE: Move to next milestone after successful payment
        genesis.setJobCurrentMilestone(_jobId, job.currentMilestone + 1);
        
        // Check if job should be completed (after increment)
        if (job.currentMilestone + 1 > job.finalMilestones.length) {
            genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Emit commission event
        emit CommissionDeducted(_jobId, _amount, commission, netAmount);
        
        // Note: USDC sent directly to target recipient via CCTP
        emit PaymentReleased(_jobId, _jobGiver, _targetRecipient, netAmount, job.currentMilestone);
    }
    
    function lockNextMilestone(address /* _caller */, string memory _jobId, uint256 _lockedAmount) external {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(job.currentMilestone < job.finalMilestones.length, "All completed");
        
        genesis.setJobCurrentMilestone(_jobId, job.currentMilestone + 1);
        emit MilestoneLocked(_jobId, job.currentMilestone + 1, _lockedAmount);
    }
    
    function releasePaymentAndLockNext(address _jobGiver, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) external {
      require(msg.sender == bridge, "Only bridge");
        
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(job.selectedApplicant != address(0), "No applicant");
        
        // Calculate and deduct commission
        uint256 commission = calculateCommission(_releasedAmount);
        uint256 netAmount = _releasedAmount - commission;
        
        // Accumulate commission
        accumulatedCommission += commission;
        
        // Get applicant's preferred chain domain for cross-chain transfer
        uint32 applicantTargetDomain = jobApplicantChainDomain[_jobId][job.selectedApplicant];
        
        if (applicantTargetDomain == 3) {
            // Native chain (Arbitrum) - direct transfer (with net amount)
            usdtToken.safeTransfer(job.selectedApplicant, netAmount);
        } else {
            // Cross-chain transfer via CCTP to applicant's preferred domain
            require(cctpTransceiver != address(0), "CCTP Transceiver not set");
            
            // ✅ CRITICAL FIX: Use approve → sendFast pattern for cross-chain release
            usdtToken.approve(cctpTransceiver, netAmount);
            ICCTPTransceiver(cctpTransceiver).sendFast(
                netAmount,
                applicantTargetDomain,
                bytes32(uint256(uint160(job.selectedApplicant))),
                1000
            );
        }
        
        // Update job total paid in Genesis (with net amount)
        genesis.updateJobTotalPaid(_jobId, netAmount);

        // Delegate to RewardsContract for token calculation and distribution (with net amount)
        _processRewardsForPayment(_jobGiver, _jobId, netAmount);
        
        genesis.setJobCurrentMilestone(_jobId, job.currentMilestone + 1);
        
        job = genesis.getJob(_jobId); // Re-fetch updated job
        if (job.currentMilestone > job.finalMilestones.length) {
            genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Emit commission event
        emit CommissionDeducted(_jobId, _releasedAmount, commission, netAmount);
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, netAmount, _lockedAmount, job.currentMilestone);
    }
    
    /* COMMENTED OUT TO SAVE CONTRACT SIZE - Use Genesis directly for ratings
    function rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) external {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        bool isAuthorized = false;
        
        if (_rater == job.jobGiver && _userToRate == job.selectedApplicant) {
            isAuthorized = true;
        } else if (_rater == job.selectedApplicant && _userToRate == job.jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized");
        
        genesis.setJobRating(_jobId, _userToRate, _rating);
        emit UserRated(_jobId, _rater, _userToRate, _rating);
    }
    */

    /* COMMENTED OUT TO SAVE CONTRACT SIZE - Use Genesis directly for portfolio
    function addPortfolio(address _user, string memory _portfolioHash) external {
        genesis.addPortfolio(_user, _portfolioHash);
        emit PortfolioAdded(_user, _portfolioHash);
    }
    */

    // ==================== BRIDGE INTEGRATION ====================

    function syncRewardsData(bytes calldata _options) external payable {
    require(bridge != address(0), "Bridge not set");
    
    // Get user's total claimable tokens from rewards contract
    uint256 claimableAmount = address(rewardsContract) != address(0) ? 
        rewardsContract.getUserTotalClaimableTokens(msg.sender) : 0;
    
    require(claimableAmount > 0, "No tokens");
    
    // Send simple data to bridge
    INativeBridge(bridge).sendSyncRewardsData{value: msg.value}(
        msg.sender,
        claimableAmount,
        _options
    );
    
    emit RewardsDataSynced(msg.sender, 1, claimableAmount, 0); // Simplified event
    }
    
  /*  function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = genesis.getUserRatings(_user);
        if (ratings.length == 0) {
            return 0;
        }
        
        uint256 totalRating = 0;
        for (uint i = 0; i < ratings.length; i++) {
            totalRating += ratings[i];
        }
        
        return totalRating / ratings.length;
    }*/
    
    // ==================== VIEW FUNCTIONS ====================
    
    // Add these to the VIEW FUNCTIONS section
    
    /* COMMENTED OUT TO SAVE CONTRACT SIZE - Profile view functions
    function getProfileCount() external view returns (uint256) {
            return profileCount;
        }

    function getProfileByIndex(uint256 _index) external view returns (Profile memory) {
        require(_index < profileCount, "Index out of bounds");
        address userAddress = allProfileUsers[_index];
        IOpenworkGenesis.Profile memory genesisProfile = genesis.getProfile(userAddress);
        return Profile({
            userAddress: genesisProfile.userAddress,
            ipfsHash: genesisProfile.ipfsHash,
            referrerAddress: genesisProfile.referrerAddress,
            portfolioHashes: genesisProfile.portfolioHashes
        });
    }

    function getAllProfileUsers() external view returns (address[] memory) {
        return allProfileUsers;
    }
    */
  /*  function getJobCount() external view returns (uint256) {
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
    }*/
    
  /*  function getJobStatus(string memory _jobId) external view returns (JobStatus) {
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
    
    function emergencyWithdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No balance");
        usdtToken.safeTransfer(owner(), balance);
    }*/
    
    function setUSDTToken(address _newToken) external onlyOwner {
        require(_newToken != address(0), "Invalid address");
        usdtToken = IERC20(_newToken);
    }
    
    // ==================== DISPUTE RESOLUTION ====================
    
    /**
     * @dev Release disputed funds to winner (called by Native Athena)
     * @param _recipient Address to receive the funds
     * @param _amount Amount to transfer
     * @param _targetChainDomain Chain domain (3=Arbitrum native, 0=Ethereum, etc.)
     */
    function releaseDisputedFunds(
        address _recipient,
        uint256 _amount,
        uint32 _targetChainDomain
    ) external {
       // require(msg.sender == nativeAthena, "Only Native Athena can resolve disputes");
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Invalid amount");
        
        // Calculate and deduct commission
        uint256 commission = calculateCommission(_amount);
        uint256 netAmount = _amount - commission;
        
        // Accumulate commission
        accumulatedCommission += commission;
        
        if (_targetChainDomain == 3) {
            // Native chain (Arbitrum) - direct transfer (with net amount)
            usdtToken.safeTransfer(_recipient, netAmount);
        } else {
            // Cross-chain transfer via CCTP - FIXED PATTERN
            require(cctpTransceiver != address(0), "CCTP Transceiver not set");
            
            // ✅ CRITICAL FIX: Use approve → sendFast pattern (not safeTransfer)
            usdtToken.approve(cctpTransceiver, netAmount);
            ICCTPTransceiver(cctpTransceiver).sendFast(
                netAmount,
                _targetChainDomain,
                bytes32(uint256(uint160(_recipient))),
                1000
            );
        }
        
        // Emit commission event
        emit CommissionDeducted("dispute", _amount, commission, netAmount);
        
        emit DisputedFundsReleased("dispute", _recipient, _targetChainDomain, netAmount);
    }
    

}
