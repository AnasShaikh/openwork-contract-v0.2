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
    function getUserGovernanceActions(address user) external view returns (uint256);
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

contract NOWJCTestableWithDisputeResolution is 
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
    
    // USDT token and CCTP receiver
    IERC20 public usdtToken;
    address public cctpReceiver;
    
    // CCTP transceiver for cross-chain payments
    address public cctpTransceiver;
    
    // Mapping of CCTP domain to target chain NOWJC address
    mapping(uint32 => address) public targetChainNOWJC;
    
    // ADDED: Native Athena address for dispute resolution authorization
    address public nativeAthena;
    
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
    event PaymentReleasedToTargetChain(string indexed jobId, address indexed applicant, uint256 amount, uint32 targetChainDomain);
    event DisputedFundsReleased(string indexed jobId, address indexed winner, uint256 amount, uint32 winnerChainDomain);
    event NativeAthenaSet(address indexed nativeAthena);

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can call this function");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner,
        address _genesis,
        address _rewardsContract,
        address _bridge,
        address _usdtToken
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        genesis = IOpenworkGenesis(_genesis);
        rewardsContract = IOpenWorkRewards(_rewardsContract);
        bridge = _bridge;
        usdtToken = IERC20(_usdtToken);
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || bridge == _msgSender(), "Unauthorized upgrade");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == bridge, "Only bridge can upgrade");
        upgradeToAndCall(newImplementation, "");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        require(_rewardsContract != address(0), "Invalid address");
        rewardsContract = IOpenWorkRewards(_rewardsContract);
    }
    
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Invalid address");
        bridge = _bridge;
    }
    
    function setGenesis(address _genesis) external onlyOwner {
        require(_genesis != address(0), "Invalid address");
        genesis = IOpenworkGenesis(_genesis);
    }
    
    function setUSDTToken(address _usdtToken) external onlyOwner {
        require(_usdtToken != address(0), "Invalid address");
        usdtToken = IERC20(_usdtToken);
    }
    
    function setCCTPReceiver(address _cctpReceiver) external onlyOwner {
        require(_cctpReceiver != address(0), "Invalid address");
        cctpReceiver = _cctpReceiver;
    }
    
    function setCCTPTransceiver(address _cctpTransceiver) external onlyOwner {
        require(_cctpTransceiver != address(0), "Invalid address");
        cctpTransceiver = _cctpTransceiver;
    }
    
    function setTargetChainNOWJC(uint32 _domain, address _nowjcAddress) external onlyOwner {
        require(_nowjcAddress != address(0), "Invalid address");
        targetChainNOWJC[_domain] = _nowjcAddress;
    }
    
    function setNativeAthena(address _nativeAthena) external onlyOwner {
        require(_nativeAthena != address(0), "Invalid address");
        nativeAthena = _nativeAthena;
        emit NativeAthenaSet(_nativeAthena);
    }
    
    // ==================== DISPUTE RESOLUTION FUNCTIONS ====================
    
    function releaseDisputedFunds(
        string memory _jobId,
        address _winner,
        uint32 _winnerChainDomain
    ) external {
        require(msg.sender == nativeAthena, "Only Native Athena can resolve disputes");
        require(_winner != address(0), "Invalid winner address");
        
        // Verify job exists
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(bytes(job.id).length > 0, "Job does not exist");
        require(job.status == IOpenworkGenesis.JobStatus.InProgress, "Job not in progress");
        
        // Get disputed amount (assume it's the remaining locked funds)
        uint256 disputedAmount = 0;
        for (uint256 i = job.currentMilestone; i < job.finalMilestones.length; i++) {
            disputedAmount += job.finalMilestones[i].amount;
        }
        
        require(disputedAmount > 0, "No disputed funds to release");
        require(disputedAmount <= usdtToken.balanceOf(address(this)), "Insufficient contract balance");
        
        if (_winnerChainDomain == 3) {
            // Winner on native chain (Arbitrum) - direct transfer
            usdtToken.safeTransfer(_winner, disputedAmount);
        } else {
            // Winner on remote chain - use CCTP
            require(cctpTransceiver != address(0), "CCTP transceiver not set");
            
            // Convert winner address to bytes32 for CCTP  
            bytes32 mintRecipient = bytes32(uint256(uint160(_winner)));
            
            // Approve CCTP transceiver to spend USDC
            usdtToken.approve(cctpTransceiver, disputedAmount);
            
            // Send USDC via CCTP to winner on target chain
            ICCTPTransceiver(cctpTransceiver).sendFast(
                disputedAmount,           // Amount of USDC to send
                _winnerChainDomain,       // CCTP domain
                mintRecipient,            // Winner address as bytes32
                1000                      // maxFee
            );
        }
        
        // Update job status to cancelled (dispute resolved)
        genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Cancelled);
        
        emit DisputedFundsReleased(_jobId, _winner, disputedAmount, _winnerChainDomain);
        emit JobStatusChanged(_jobId, JobStatus.Cancelled);
    }
    
    // ==================== EXISTING PAYMENT FUNCTIONS (UNCHANGED) ====================
    
    function withdrawFunds(address _to, uint256 _amount) internal {
        require(cctpReceiver != address(0), "CCTP not set");
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Invalid amount");
        
        // Call CCTP receiver to withdraw funds (for same-chain withdrawals only)
        (bool success, ) = cctpReceiver.call(abi.encodeWithSignature("withdrawFunds(address,uint256)", _to, _amount));
        require(success, "Withdrawal failed");
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
    
    function releasePaymentToTargetChain(
        string memory _jobId,
        uint256 _amount,
        address _targetRecipient,
        uint32 _targetChainDomain
    ) external {
        // Verify we have sufficient balance
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= usdtToken.balanceOf(address(this)), "Insufficient contract balance");
        
        // Get job details for validation and events
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(bytes(job.id).length > 0, "Job does not exist");
        
        // Convert target recipient address to bytes32 for CCTP  
        bytes32 mintRecipient = bytes32(uint256(uint160(_targetRecipient)));
        
        // Approve CCTP transceiver to spend USDC
        usdtToken.approve(cctpTransceiver, _amount);
        
        // Send USDC via CCTP to target chain
        ICCTPTransceiver(cctpTransceiver).sendFast(
            _amount,
            _targetChainDomain,
            mintRecipient,
            1000
        );
        
        // Update job total paid in Genesis
        genesis.updateJobTotalPaid(_jobId, _amount);
        // Delegate to RewardsContract for token calculation and distribution
        _processRewardsForPayment(job.jobGiver, _jobId, _amount);
        
        // Check if job should be completed
        if (job.currentMilestone == job.finalMilestones.length) {
            genesis.updateJobStatus(_jobId, IOpenworkGenesis.JobStatus.Completed);
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        emit PaymentReleasedToTargetChain(_jobId, _targetRecipient, _amount, _targetChainDomain);
    }
    
    // ==================== HELPER FUNCTIONS ====================
    
    function _processRewardsForPayment(address _jobGiver, string memory _jobId, uint256 _amount) internal {
        if (address(rewardsContract) != address(0)) {
            IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
            uint256 newPlatformTotal = genesis.totalPlatformPayments() + _amount;
            
            try rewardsContract.processJobPayment(
                _jobGiver,
                job.selectedApplicant,
                _amount,
                newPlatformTotal
            ) returns (uint256[] memory) {
                // Success - rewards processed
            } catch {
                // Continue even if rewards processing fails
            }
        }
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getUserEarnedTokens(address user) external view returns (uint256) {
        if (address(rewardsContract) == address(0)) {
            return 0;
        }
        return rewardsContract.getUserTotalTokensEarned(user);
    }
    
    function jobExists(string memory _jobId) external view returns (bool) {
        return genesis.jobExists(_jobId);
    }
    
    function getJob(string memory _jobId) external view returns (
        string memory id,
        address jobGiver,
        address[] memory applicants,
        string memory jobDetailHash,
        uint8 status,
        string[] memory workSubmissions,
        uint256 totalPaid,
        uint256 currentMilestone,
        address selectedApplicant,
        uint256 selectedApplicationId
    ) {
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        return (
            job.id,
            job.jobGiver,
            job.applicants,
            job.jobDetailHash,
            uint8(job.status),
            job.workSubmissions,
            job.totalPaid,
            job.currentMilestone,
            job.selectedApplicant,
            job.selectedApplicationId
        );
    }
    
    function incrementGovernanceAction(address user) external {
        if (address(rewardsContract) != address(0)) {
            rewardsContract.recordGovernanceAction(user);
        }
        // Also update Genesis for backward compatibility
        genesis.incrementUserGovernanceActions(user);
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function emergencyWithdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT balance to withdraw");
        usdtToken.safeTransfer(owner(), balance);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}