// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface to get staker info from Native DAO
interface INativeDAO {
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive);
}

// Enhanced Interface for Native OpenWork Job Contract with CCTP support
interface INativeOpenWorkJobContract {
    function getUserEarnedTokens(address user) external view returns (uint256);
    function getJob(string memory _jobId) external view returns (
        string memory id,
        address jobGiver,
        address[] memory applicants,
        string memory jobDetailHash,
        uint8 status, // JobStatus enum as uint8
        string[] memory workSubmissions,
        uint256 totalPaid,
        uint256 currentMilestone,
        address selectedApplicant,
        uint256 selectedApplicationId
    );
    function jobExists(string memory _jobId) external view returns (bool);
    function incrementGovernanceAction(address user) external;
    
    // NEW: CCTP dispute resolution support
    function releaseDisputedFunds(address _recipient, uint256 _amount, uint32 _targetChainDomain) external;
}

// Interface for Oracle Manager contract
interface IOracleManager {
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external;
    
    function addSingleOracle(
        string memory _name,
        address[] memory _members,
        string memory _shortDescription,
        string memory _hashOfDetails,
        address[] memory _skillVerifiedAddresses
    ) external;
    
    function addMembers(address[] memory _members, string memory _oracleName) external;
    function removeMemberFromOracle(string memory _oracleName, address _memberToRemove) external;
    function removeOracle(string[] memory _oracleNames) external;
}

// Interface for OpenworkGenesis storage contract with Job struct support
interface IOpenworkGenesis {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
    struct VoterData {
        address voter;
        address claimAddress;
        uint256 votingPower;
        bool voteFor;
    }
    
    struct Oracle {
        string name;
        address[] members;
        string shortDescription;
        string hashOfDetails;
        address[] skillVerifiedAddresses;
    }
    
    struct SkillVerificationApplication {
        uint256 id;
        address applicant;
        string applicationHash;
        uint256 feeAmount;
        string targetOracleName;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
        bool result;
        bool isFinalized;
    }
    
    struct AskAthenaApplication {
        uint256 id;
        address applicant;
        string description;
        string hash;
        string targetOracle;
        string fees;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
        bool result;
        bool isFinalized;
    }
    
    struct Dispute {
        string jobId;
        uint256 disputedAmount;
        string hash;
        address disputeRaiserAddress;
        uint256 votesFor;
        uint256 votesAgainst;
        bool result;
        bool isVotingActive;
        bool isFinalized;
        uint256 timeStamp;
        uint256 fees;
    }

    // NEW: Job struct support (Genesis struct fix)
    struct Job {
        string id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        uint8 status;
        string[] workSubmissions;
        uint256 totalPaid;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
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
        uint32 preferredPaymentChainDomain;
        address preferredPaymentAddress;
    }

    // Oracle setters
    function setOracle(string memory name, address[] memory members, string memory shortDescription, string memory hashOfDetails, address[] memory skillVerifiedAddresses) external;
    function addOracleMember(string memory oracleName, address member) external;
    function removeOracleMember(string memory oracleName, address memberToRemove) external;
    function addSkillVerifiedAddress(string memory oracleName, address user) external;
    function setMemberStakeAmount(string memory oracleName, address member, uint256 amount) external;
    
    // Dispute/Voting setters
    function setDispute(string memory jobId, uint256 disputedAmount, string memory hash, address disputeRaiser, uint256 fees) external;
    function updateDisputeVotes(string memory disputeId, uint256 votesFor, uint256 votesAgainst) external;
    function finalizeDispute(string memory disputeId, bool result) external;
    function finalizeAskAthena(uint256 athenaId, bool result) external;
    function finalizeSkillVerification(uint256 applicationId, bool result) external;
    function setDisputeVote(string memory disputeId, address voter) external;
    function setSkillApplication(uint256 applicationId, address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external;
    function updateSkillApplicationVotes(uint256 applicationId, uint256 votesFor, uint256 votesAgainst) external;
    function setSkillApplicationVote(uint256 applicationId, address voter) external;
    function setAskAthenaApplication(uint256 athenaId, address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external;
    function updateAskAthenaVotes(uint256 athenaId, uint256 votesFor, uint256 votesAgainst) external;
    function setAskAthenaVote(uint256 athenaId, address voter) external;
    
    // Voter data setters
    function addDisputeVoter(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external;
    function addSkillVerificationVoter(uint256 applicationId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external;
    function addAskAthenaVoter(uint256 athenaId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external;
    
    // Getters
    function getJob(string memory jobId) external view returns (Job memory);
    function getJobApplication(string memory jobId, uint256 applicationId) external view returns (Application memory);
    function getOracle(string memory oracleName) external view returns (Oracle memory);
    function getOracleMembers(string memory oracleName) external view returns (address[] memory);
    function getSkillVerificationDate(string memory oracleName, address user) external view returns (uint256);
    function getDispute(string memory disputeId) external view returns (Dispute memory);
    function getSkillApplication(uint256 applicationId) external view returns (SkillVerificationApplication memory);
    function getAskAthenaApplication(uint256 athenaId) external view returns (AskAthenaApplication memory);
    function hasUserVotedOnDispute(string memory disputeId, address user) external view returns (bool);
    function hasUserVotedOnSkillApplication(uint256 applicationId, address user) external view returns (bool);
    function hasUserVotedOnAskAthena(uint256 athenaId, address user) external view returns (bool);
    function applicationCounter() external view returns (uint256);
    function askAthenaCounter() external view returns (uint256);
    
    // Voter data getters
    function getDisputeVoters(string memory disputeId) external view returns (VoterData[] memory);
    function getSkillVerificationVoters(uint256 applicationId) external view returns (VoterData[] memory);
    function getAskAthenaVoters(uint256 athenaId) external view returns (VoterData[] memory);
    function getDisputeVoterClaimAddress(string memory disputeId, address voter) external view returns (address);
    
    // NEW: Activity tracking for oracle members
    function memberLastActivity(address member) external view returns (uint256);
    function oracleActiveStatus(string memory oracleName) external view returns (bool);
    function updateMemberActivity(address member) external;
    function setOracleActiveStatus(string memory oracleName, bool isActive) external;
}

contract NativeAthena is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    
    // DAO Integration (from production contract)
    address public daoContract;
    
    // CCTP Integration (from testable contract)
    IERC20 public usdcToken;
    uint256 public accumulatedFees;
    
    // Genesis storage contract
    IOpenworkGenesis public genesis;
    
    // Oracle Manager contract
    IOracleManager public oracleManager;
    
    // Native OpenWork Job Contract for earned tokens check and CCTP
    INativeOpenWorkJobContract public nowjContract;
    
    // Bridge for cross-chain communication
    address public bridge;
    
    // Add voting type enum
    enum VotingType {
        Dispute,
        SkillVerification,
        AskAthena
    }

    // Configuration parameters
    uint256 public minOracleMembers;
    uint256 public votingPeriodMinutes;
    uint256 public minStakeRequired;
    
    // NEW: Activity tracking parameters
    uint256 public memberActivityThresholdDays = 90; // Members must vote within 90 days to be considered active
    
    // Multi-dispute support
    mapping(string => uint256) public jobDisputeCounters;
    mapping(string => uint256) public disputeStartTimes;

    // Storage gap for upgrade safety
    uint256[50] private __gap;

    // Events
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);
    event DAOContractUpdated(address indexed oldDAO, address indexed newDAO);
    event USDCTokenUpdated(address indexed oldToken, address indexed newToken);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event EarnedTokensUsedForVoting(address indexed user, uint256 earnedTokens, string votingType);
    event CrossContractCallFailed(address indexed account, string reason);
    event DisputeFinalized(string indexed disputeId, bool winningSide, uint256 totalVotesFor, uint256 totalVotesAgainst);
    event DisputeRaised(string indexed jobId, address indexed disputeRaiser, uint256 fees);
    event SkillVerificationSubmitted(address indexed applicant, string targetOracleName, uint256 feeAmount, uint256 indexed applicationId);
    event AskAthenaSubmitted(address indexed applicant, string targetOracle, string fees);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event FeeDistributed(string indexed disputeId, address indexed recipient, uint256 amount);
    event DisputeFeeRefunded(string indexed disputeId, address indexed disputeRaiser, uint256 amount, uint32 targetChain);
    event AskAthenaSettled(uint256 indexed athenaId, bool result, uint256 totalVotesFor, uint256 totalVotesAgainst);
    event SkillVerificationSettled(uint256 indexed applicationId, bool result, uint256 totalVotesFor, uint256 totalVotesAgainst);
    
    // NEW: Oracle activity events
    event OracleStatusUpdated(string indexed oracleName, bool isActive, uint256 activeMemberCount);
    event MemberActivityThresholdUpdated(uint256 newThresholdDays);
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "Only DAO can call this function");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner, 
        address _daoContract, 
        address _genesis,
        address _nowjContract,
        address _usdcToken
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        daoContract = _daoContract;
        genesis = IOpenworkGenesis(_genesis);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        
        // CCTP Integration
        if (_usdcToken != address(0)) {
            usdcToken = IERC20(_usdcToken);
        }
        
        // Initialize default values
        minOracleMembers = 3;
        votingPeriodMinutes = 60; // 1 hour default
        minStakeRequired = 100;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
    }
    
    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == address(bridge), "Only bridge can upgrade");
        upgradeToAndCall(newImplementation, "");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setGenesis(address _genesis) external onlyOwner {
        address oldGenesis = address(genesis);
        genesis = IOpenworkGenesis(_genesis);
        emit GenesisUpdated(oldGenesis, _genesis);
    }
    
    function setNOWJContract(address _nowjContract) external onlyOwner {
        address oldContract = address(nowjContract);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        emit NOWJContractUpdated(oldContract, _nowjContract);
    }
    
    function setOracleManager(address _oracleManager) external onlyOwner {
        oracleManager = IOracleManager(_oracleManager);
    }
    
    function setDAOContract(address _daoContract) external onlyOwner {
        address oldDAO = daoContract;
        daoContract = _daoContract;
        emit DAOContractUpdated(oldDAO, _daoContract);
    }
    
    function setUSDCToken(address _usdcToken) external onlyOwner {
        address oldToken = address(usdcToken);
        usdcToken = IERC20(_usdcToken);
        emit USDCTokenUpdated(oldToken, _usdcToken);
    }
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = bridge;
        bridge = _bridge;
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    function updateMinOracleMembers(uint256 _newMinMembers) external onlyOwner {
        minOracleMembers = _newMinMembers;
    }
    
    function updateVotingPeriod(uint256 _newPeriodMinutes) external onlyOwner {
        votingPeriodMinutes = _newPeriodMinutes;
    }
    
    function updateMinStakeRequired(uint256 _newMinStake) external onlyOwner {
        minStakeRequired = _newMinStake;
    }
    
    function updateMemberActivityThreshold(uint256 _newThresholdDays) external onlyOwner {
        memberActivityThresholdDays = _newThresholdDays;
        emit MemberActivityThresholdUpdated(_newThresholdDays);
    }
    
    // ==================== ORACLE ACTIVE STATUS FUNCTIONS ====================
    
    /**
     * @notice Update the active status of an oracle by counting active members
     * @dev Anyone can call this function (they pay gas). Expensive operation - only call periodically.
     * @param _oracleName Name of the oracle to update
     */
    function updateOracleActiveStatus(string memory _oracleName) public {
        address[] memory members = genesis.getOracleMembers(_oracleName);
        uint256 activeCount = 0;
        uint256 threshold = memberActivityThresholdDays * 1 days;
        
        for (uint256 i = 0; i < members.length; i++) {
            uint256 lastActivity = genesis.memberLastActivity(members[i]);
            if (lastActivity > 0 && (block.timestamp - lastActivity) <= threshold) {
                activeCount++;
            }
        }
        
        bool isActive = activeCount >= minOracleMembers;
        genesis.setOracleActiveStatus(_oracleName, isActive);
        
        emit OracleStatusUpdated(_oracleName, isActive, activeCount);
    }
    
    /**
     * @notice Check if an oracle is active (cheap read from cache)
     * @param _oracleName Name of the oracle to check
     * @return bool True if oracle is active
     */
    function isOracleActive(string memory _oracleName) public view returns (bool) {
        return genesis.oracleActiveStatus(_oracleName);
    }
    
    /**
     * @notice Check if an address is a member of a specific oracle
     * @param _account Address to check
     * @param _oracleName Name of the oracle
     * @return bool True if address is an oracle member
     */
    function isOracleMember(address _account, string memory _oracleName) public view returns (bool) {
        address[] memory members = genesis.getOracleMembers(_oracleName);
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == _account) return true;
        }
        return false;
    }
    
    /**
     * @notice Get the count of active members in an oracle (expensive - iterates all members)
     * @param _oracleName Name of the oracle
     * @return uint256 Number of active members
     */
    function getOracleActiveMemberCount(string memory _oracleName) public view returns (uint256) {
        address[] memory members = genesis.getOracleMembers(_oracleName);
        uint256 activeCount = 0;
        uint256 threshold = memberActivityThresholdDays * 1 days;
        
        for (uint256 i = 0; i < members.length; i++) {
            uint256 lastActivity = genesis.memberLastActivity(members[i]);
            if (lastActivity > 0 && (block.timestamp - lastActivity) <= threshold) {
                activeCount++;
            }
        }
        return activeCount;
    }
    
    // ==================== MESSAGE HANDLERS ====================
    
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, uint256 disputedAmount, address disputeRaiser) external {
        require(msg.sender == bridge, "Only bridge");        
        
        // NEW: Check if oracle is active before accepting dispute
        require(isOracleActive(oracleName), "Oracle not active - cannot register dispute");
        
        // Check if oracle has minimum required members
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(oracleName);
        require(oracle.members.length >= minOracleMembers, "Oracle not active");
        
        // Increment dispute counter for this job
        jobDisputeCounters[jobId]++;
        
        // Create dispute ID: jobId-disputeNumber
        string memory disputeId = string(abi.encodePacked(jobId, "-", uint2str(jobDisputeCounters[jobId])));
        
        // Set start time in separate mapping
        disputeStartTimes[disputeId] = block.timestamp;
        
        // Create new dispute in genesis
        genesis.setDispute(disputeId, disputedAmount, disputeHash, disputeRaiser, fee);
        
        emit DisputeRaised(disputeId, disputeRaiser, fee);
    }
    
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external {
        require(msg.sender == bridge, "Only bridge");
        
        // NEW: Check oracle must be active before accepting skill verification
        require(isOracleActive(targetOracleName), "Skill verification not available - oracle is not active (needs 20+ active members)");
        
        uint256 applicationId = genesis.applicationCounter();
        genesis.setSkillApplication(applicationId, applicant, applicationHash, feeAmount, targetOracleName);
        
        emit SkillVerificationSubmitted(applicant, targetOracleName, feeAmount, applicationId);
    }
    
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        
        uint256 athenaId = genesis.askAthenaCounter();
        genesis.setAskAthenaApplication(athenaId, applicant, description, hash, targetOracle, fees);
        
        emit AskAthenaSubmitted(applicant, targetOracle, fees);
    }
    
    // ==================== VOTING ELIGIBILITY FUNCTIONS (from production) ====================
    
    function canVote(address account) public view returns (bool) {
        // First check if user has sufficient active stake
        if (daoContract != address(0)) {
            (uint256 stakeAmount, , , bool isActive) = INativeDAO(daoContract).getStakerInfo(account);
            if (isActive && stakeAmount >= minStakeRequired) {
                return true;
            }
        }
        
        // If no sufficient stake, check earned tokens from NOWJ contract
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            return earnedTokens >= minStakeRequired;
        }
        
        return false;
    }
    
    function getUserVotingPower(address account) public view returns (uint256) {
        uint256 totalVotingPower = 0;
        
        // Get stake-based voting power
        if (daoContract != address(0)) {
            (uint256 stakeAmount, , uint256 durationMinutes, bool isActive) = INativeDAO(daoContract).getStakerInfo(account);
            if (isActive && stakeAmount > 0) {
                totalVotingPower += stakeAmount * durationMinutes;
            }
        }
        
        // Add earned tokens voting power
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            totalVotingPower += earnedTokens;
        }
        
        return totalVotingPower;
    }

    // ==================== ORACLE MANAGEMENT (from production) ====================
    
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external onlyOwner {
        require(address(oracleManager) != address(0), "Oracle manager not set");
        oracleManager.addOrUpdateOracle(_names, _members, _shortDescriptions, _hashOfDetails, _skillVerifiedAddresses);
    }
    
    function addSingleOracle(
        string memory _name,
        address[] memory _members,
        string memory _shortDescription,
        string memory _hashOfDetails,
        address[] memory _skillVerifiedAddresses
    ) external onlyDAO {
        require(address(oracleManager) != address(0), "Oracle manager not set");
        oracleManager.addSingleOracle(_name, _members, _shortDescription, _hashOfDetails, _skillVerifiedAddresses);
    }

    function addMembers(address[] memory _members, string memory _oracleName) external onlyDAO {
        require(address(oracleManager) != address(0), "Oracle manager not set");
        oracleManager.addMembers(_members, _oracleName);
    }

    function getOracleMembers(string memory _oracleName) external view returns (address[] memory) {
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        return genesis.getOracleMembers(_oracleName);
    }
    
    function removeMemberFromOracle(string memory _oracleName, address _memberToRemove) external onlyDAO {
        require(address(oracleManager) != address(0), "Oracle manager not set");
        oracleManager.removeMemberFromOracle(_oracleName, _memberToRemove);
    }

    function removeOracle(string[] memory _oracleNames) external onlyDAO {
        require(address(oracleManager) != address(0), "Oracle manager not set");
        oracleManager.removeOracle(_oracleNames);
    }
    
    // ==================== SKILL VERIFICATION (from production) ====================
    
    function finalizeSkillVerification(uint256 _applicationId) external {
        IOpenworkGenesis.SkillVerificationApplication memory application = genesis.getSkillApplication(_applicationId);
        require(application.applicant != address(0), "Application does not exist");
        require(!application.isFinalized, "Already finalized");
        require(application.isVotingActive, "Voting not active");
        require(block.timestamp > application.timeStamp + (votingPeriodMinutes * 60), "Voting period not expired");
        
        bool result = application.votesFor > application.votesAgainst;
        genesis.finalizeSkillVerification(_applicationId, result);
        
        // Only add skill verification if approved
        if (result) {
            genesis.addSkillVerifiedAddress(application.targetOracleName, application.applicant);
        }
        
        // Distribute fees to winning voters
        _distributeFeeToWinningVoters(VotingType.SkillVerification, uint2str(_applicationId), result, application.feeAmount);
        
        emit SkillVerificationSettled(_applicationId, result, application.votesFor, application.votesAgainst);
    }
    
    // ==================== VOTING FUNCTIONS (from production) ====================
    
    function vote(
        VotingType _votingType, 
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress
    ) external {
        require(canVote(msg.sender), "Insufficient stake or earned tokens to vote");
        require(_claimAddress != address(0), "Claim address cannot be zero");
        
        uint256 voteWeight = getUserVotingPower(msg.sender);
        require(voteWeight > 0, "No voting power");
        
        // STORE VOTER DATA IN GENESIS - before routing
        if (_votingType == VotingType.Dispute) {
            genesis.addDisputeVoter(_disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
        } else if (_votingType == VotingType.SkillVerification) {
            uint256 applicationId = stringToUint(_disputeId);
            genesis.addSkillVerificationVoter(applicationId, msg.sender, _claimAddress, voteWeight, _voteFor);
        } else if (_votingType == VotingType.AskAthena) {
            uint256 athenaId = stringToUint(_disputeId);
            genesis.addAskAthenaVoter(athenaId, msg.sender, _claimAddress, voteWeight, _voteFor);
        }
        
        // Route to individual functions (existing logic)
        if (_votingType == VotingType.Dispute) {
            _voteOnDispute(_disputeId, _voteFor, _claimAddress, voteWeight);
        } else if (_votingType == VotingType.SkillVerification) {
            _voteOnSkillVerification(_disputeId, _voteFor, _claimAddress, voteWeight);
        } else if (_votingType == VotingType.AskAthena) {
            _voteOnAskAthena(_disputeId, _voteFor, _claimAddress, voteWeight);
        }
    }
    
    function _voteOnDispute(
        string memory _disputeId, 
        bool _voteFor, 
        address /* _claimAddress */,
        uint256 voteWeight
    ) internal {
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        require(dispute.timeStamp > 0, "Dispute does not exist");
        require(!genesis.hasUserVotedOnDispute(_disputeId, msg.sender), "Already voted on this dispute");
        require(dispute.isVotingActive, "Voting is not active for this dispute");
        require(block.timestamp <= dispute.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
        
        genesis.setDisputeVote(_disputeId, msg.sender);
        
        // NEW: Record member activity
        genesis.updateMemberActivity(msg.sender);
        
        if (_voteFor) {
            genesis.updateDisputeVotes(_disputeId, dispute.votesFor + voteWeight, dispute.votesAgainst);
        } else {
            genesis.updateDisputeVotes(_disputeId, dispute.votesFor, dispute.votesAgainst + voteWeight);
        }
        
        if (address(nowjContract) != address(0)) {
            nowjContract.incrementGovernanceAction(msg.sender);
        }
    }
    
    function _voteOnSkillVerification(
        string memory _disputeId, 
        bool _voteFor, 
        address /* _claimAddress */, 
        uint256 voteWeight
    ) internal {
        uint256 applicationId = stringToUint(_disputeId);
        
        // Get application from genesis
        IOpenworkGenesis.SkillVerificationApplication memory application = genesis.getSkillApplication(applicationId);
        require(application.applicant != address(0), "Application does not exist");
        require(!genesis.hasUserVotedOnSkillApplication(applicationId, msg.sender), "Already voted");
        require(application.isVotingActive, "Voting not active");
        require(block.timestamp <= application.timeStamp + (votingPeriodMinutes * 60), "Voting expired");
        
        // NEW: Check if oracle is active and voter is a member
        if (isOracleActive(application.targetOracleName)) {
            require(
                isOracleMember(msg.sender, application.targetOracleName),
                "Only oracle members can vote on active oracle applications"
            );
        }
        // If oracle is inactive, existing canVote() check allows all DAO members
        
        // Record vote in genesis
        genesis.setSkillApplicationVote(applicationId, msg.sender);
        
        // NEW: Record member activity
        genesis.updateMemberActivity(msg.sender);
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateSkillApplicationVotes(applicationId, application.votesFor + voteWeight, application.votesAgainst);
        } else {
            genesis.updateSkillApplicationVotes(applicationId, application.votesFor, application.votesAgainst + voteWeight);
        }
        
        if (address(nowjContract) != address(0)) {
            nowjContract.incrementGovernanceAction(msg.sender);
        }
    }
    
    function _voteOnAskAthena(
        string memory _disputeId, 
        bool _voteFor, 
        address /* _claimAddress */, 
        uint256 voteWeight
    ) internal {
        uint256 athenaId = stringToUint(_disputeId);
        
        // Get askAthena application from genesis
        IOpenworkGenesis.AskAthenaApplication memory athenaApp = genesis.getAskAthenaApplication(athenaId);
        require(athenaApp.applicant != address(0), "AskAthena application does not exist");
        require(!genesis.hasUserVotedOnAskAthena(athenaId, msg.sender), "Already voted on this AskAthena application");
        require(athenaApp.isVotingActive, "Voting is not active for this AskAthena application");
        require(block.timestamp <= athenaApp.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
        
        // Record vote in genesis
        genesis.setAskAthenaVote(athenaId, msg.sender);
        
        // NEW: Record member activity
        genesis.updateMemberActivity(msg.sender);
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateAskAthenaVotes(athenaId, athenaApp.votesFor + voteWeight, athenaApp.votesAgainst);
        } else {
            genesis.updateAskAthenaVotes(athenaId, athenaApp.votesFor, athenaApp.votesAgainst + voteWeight);
        }
        
        if (address(nowjContract) != address(0)) {
            nowjContract.incrementGovernanceAction(msg.sender);
        }
    }
    
    // ==================== NEW: CCTP DISPUTE SETTLEMENT ====================
    
    function _distributeFeeToWinningVoters(VotingType _votingType, string memory _disputeId, bool _winningSide, uint256 _totalFees) internal {
        if (_totalFees == 0 || address(usdcToken) == address(0)) {
            return;
        }
        
        // Get all voters based on voting type
        IOpenworkGenesis.VoterData[] memory voters;
        if (_votingType == VotingType.Dispute) {
            voters = genesis.getDisputeVoters(_disputeId);
        } else if (_votingType == VotingType.SkillVerification) {
            voters = genesis.getSkillVerificationVoters(stringToUint(_disputeId));
        } else if (_votingType == VotingType.AskAthena) {
            voters = genesis.getAskAthenaVoters(stringToUint(_disputeId));
        }
        
        if (voters.length == 0) {
            return;
        }
        
        // Calculate total voting power of winning side
        uint256 totalWinningVotingPower = 0;
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i].voteFor == _winningSide) {
                totalWinningVotingPower += voters[i].votingPower;
            }
        }
        
        if (totalWinningVotingPower == 0) {
            return;
        }
        
        // Distribute fees proportionally to winning voters
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i].voteFor == _winningSide && voters[i].claimAddress != address(0)) {
                uint256 voterFeeShare = (_totalFees * voters[i].votingPower) / totalWinningVotingPower;
                
                if (voterFeeShare > 0) {
                    usdcToken.safeTransfer(voters[i].claimAddress, voterFeeShare);
                    emit FeeDistributed(_disputeId, voters[i].claimAddress, voterFeeShare);
                }
            }
        }
    }
    
    function settleDispute(string memory _disputeId) external {
        require(disputeStartTimes[_disputeId] > 0, "Dispute does not exist");
        require(block.timestamp >= disputeStartTimes[_disputeId] + (votingPeriodMinutes * 60), "Voting period not ended");
        
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        require(dispute.timeStamp > 0, "Dispute does not exist");
        require(!dispute.isFinalized, "Dispute already finalized");
        
        bool disputeRaiserWins = dispute.votesFor > dispute.votesAgainst;
        genesis.finalizeDispute(_disputeId, disputeRaiserWins);
        
        // NEW LOGIC: Fund release based on dispute outcome and parties
        if (address(nowjContract) != address(0)) {
            // Extract original job ID from dispute ID (remove -1, -2, etc.)
            string memory originalJobId = _extractJobIdFromDisputeId(_disputeId);
            IOpenworkGenesis.Job memory job = genesis.getJob(originalJobId);
            
            bool shouldReleaseFunds = false;
            address fundRecipient = address(0);
            uint32 targetChainDomain = 0;
            
            if (dispute.disputeRaiserAddress == job.jobGiver) {
                // Job giver raised the dispute
                if (disputeRaiserWins) {
                    // Job giver wins - funds go to job giver
                    shouldReleaseFunds = true;
                    fundRecipient = job.jobGiver;
                    targetChainDomain = _parseJobIdForChainDomain(originalJobId);
                }
                // Job giver loses - funds stay in contract (no release)
            } else {
                // Applicant raised the dispute
                if (disputeRaiserWins) {
                    // Applicant wins - funds go to applicant
                    shouldReleaseFunds = true;
                    fundRecipient = dispute.disputeRaiserAddress; // Should be the applicant
                    IOpenworkGenesis.Application memory app = genesis.getJobApplication(originalJobId, job.selectedApplicationId);
                    targetChainDomain = app.preferredPaymentChainDomain;
                }
                // Applicant loses - funds stay in contract (no release)
            }
            
            // Release funds if conditions are met
            if (shouldReleaseFunds && fundRecipient != address(0)) {
                nowjContract.releaseDisputedFunds(
                    fundRecipient,
                    dispute.disputedAmount,
                    targetChainDomain
                );
            }
        }
        
        // Check if any votes were cast - if not, refund fees to dispute raiser
        IOpenworkGenesis.VoterData[] memory voters = genesis.getDisputeVoters(_disputeId);
        if (voters.length == 0 && dispute.fees > 0 && address(usdcToken) != address(0)) {
            // No votes were cast - refund dispute fees to dispute raiser on their preferred chain
            uint32 preferredChain = _getDisputeRaiserPreferredChain(_disputeId, dispute.disputeRaiserAddress);
            
            // If same chain or no cross-chain capability, transfer directly
            if (preferredChain == 3 || address(nowjContract) == address(0)) { // 3 = Arbitrum Sepolia
                usdcToken.safeTransfer(dispute.disputeRaiserAddress, dispute.fees);
            } else {
                // Use cross-chain transfer through job contract
                nowjContract.releaseDisputedFunds(dispute.disputeRaiserAddress, dispute.fees, preferredChain);
            }
            
            emit DisputeFeeRefunded(_disputeId, dispute.disputeRaiserAddress, dispute.fees, preferredChain);
        } else {
            // Normal case: distribute fees to winning voters
            _distributeFeeToWinningVoters(VotingType.Dispute, _disputeId, disputeRaiserWins, dispute.fees);
        }
        
        emit DisputeFinalized(_disputeId, disputeRaiserWins, dispute.votesFor, dispute.votesAgainst);
    }
    
    function settleAskAthena(uint256 _athenaId) external {
        IOpenworkGenesis.AskAthenaApplication memory athenaApp = genesis.getAskAthenaApplication(_athenaId);
        require(athenaApp.applicant != address(0), "AskAthena application does not exist");
        require(!athenaApp.isFinalized, "Already finalized");
        require(athenaApp.isVotingActive, "Voting not active");
        require(block.timestamp > athenaApp.timeStamp + (votingPeriodMinutes * 60), "Voting period not expired");
        
        bool result = athenaApp.votesFor > athenaApp.votesAgainst;
        genesis.finalizeAskAthena(_athenaId, result);
        
        // Distribute fees to winning voters
        uint256 feeAmount = stringToUint(athenaApp.fees);
        _distributeFeeToWinningVoters(VotingType.AskAthena, uint2str(_athenaId), result, feeAmount);
        
        emit AskAthenaSettled(_athenaId, result, athenaApp.votesFor, athenaApp.votesAgainst);
    }
    
    // ==================== CCTP FEE MANAGEMENT ====================
    
    
    // ==================== UTILITY FUNCTIONS ====================
    
    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                result = result * 10 + (uint256(uint8(b[i])) - 48);
            }
        }
        return result;
    }
    
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    function _parseJobIdForChainDomain(string memory _jobId) internal pure returns (uint32) {
        bytes memory jobIdBytes = bytes(_jobId);
        uint256 dashIndex = 0;
        
        // Find the dash position in job ID like "40232-57"
        for (uint256 i = 0; i < jobIdBytes.length; i++) {
            if (jobIdBytes[i] == '-') {
                dashIndex = i;
                break;
            }
        }
        
        if (dashIndex == 0) return 0; // No dash found
        
        // Extract the EID part before the dash
        bytes memory eidBytes = new bytes(dashIndex);
        for (uint256 i = 0; i < dashIndex; i++) {
            eidBytes[i] = jobIdBytes[i];
        }
        
        uint256 eid = stringToUint(string(eidBytes));
        
        // Convert EID to CCTP domain
        if (eid == 40161) return 0;      // Ethereum Sepolia
        else if (eid == 40232) return 2; // OP Sepolia  
        else if (eid == 40231) return 3; // Arbitrum Sepolia
        else return 0; // Default to Ethereum
    }
    
    function _extractJobIdFromDisputeId(string memory _disputeId) internal pure returns (string memory) {
        bytes memory disputeIdBytes = bytes(_disputeId);
        
        // Find the last dash in the dispute ID
        int256 lastDashIndex = -1;
        for (uint256 i = disputeIdBytes.length; i > 0; i--) {
            if (disputeIdBytes[i-1] == '-') {
                // Check if everything after this dash is numeric (dispute counter)
                bool isNumeric = true;
                for (uint256 j = i; j < disputeIdBytes.length; j++) {
                    if (disputeIdBytes[j] < '0' || disputeIdBytes[j] > '9') {
                        isNumeric = false;
                        break;
                    }
                }
                if (isNumeric) {
                    lastDashIndex = int256(i-1);
                    break;
                }
            }
        }
        
        if (lastDashIndex == -1) {
            // No dispute counter found, return original ID
            return _disputeId;
        }
        
        // Extract job ID (everything before the last dash)
        bytes memory jobIdBytes = new bytes(uint256(lastDashIndex));
        for (uint256 i = 0; i < uint256(lastDashIndex); i++) {
            jobIdBytes[i] = disputeIdBytes[i];
        }
        
        return string(jobIdBytes);
    }
    
    function _getDisputeRaiserPreferredChain(string memory _disputeId, address _disputeRaiser) internal view returns (uint32) {
        // Extract original job ID from dispute ID
        string memory originalJobId = _extractJobIdFromDisputeId(_disputeId);
        IOpenworkGenesis.Job memory job = genesis.getJob(originalJobId);
        
        // If dispute raiser is the selected applicant, get their preferred payment chain
        if (_disputeRaiser == job.selectedApplicant && job.selectedApplicationId > 0) {
            IOpenworkGenesis.Application memory app = genesis.getJobApplication(originalJobId, job.selectedApplicationId);
            return app.preferredPaymentChainDomain;
        }
        
        // If dispute raiser is the job giver or we can't determine preference, 
        // use the job's original chain (parsed from job ID)
        return _parseJobIdForChainDomain(originalJobId);
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH for paying fees
    receive() external payable {}
}
