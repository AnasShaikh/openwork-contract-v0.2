// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface to get earned tokens and job details from Native OpenWork Job Contract
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
    function releaseDisputedFunds(address _recipient, uint256 _amount, uint32 _targetChainDomain) external;
    function jobApplicantChainDomain(string memory _jobId, address _applicant) external view returns (uint32);
}

// Interface for OpenworkGenesis storage contract
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
        address applicant;
        string applicationHash;
        uint256 feeAmount;
        string targetOracleName;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
    }
    
    struct AskAthenaApplication {
        address applicant;
        string description;
        string hash;
        string targetOracle;
        string fees;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
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
}

// UPDATED INTERFACE for the bridge to support new two-chain functionality
interface INativeChainBridge {
    function sendToRewardsChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function sendToLocalChain(
        string memory _disputeId,
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function sendToTwoChains(
        string memory _functionName,
        bytes memory _rewardsPayload,
        bytes memory _athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external payable;
    
    function quoteRewardsChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
    
    function quoteLocalChain(
        string memory _disputeId,
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
    
    function quoteTwoChains(
        bytes calldata _rewardsPayload,
        bytes calldata _athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 athenaClientFee);
}

contract NativeAthenaTestable is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    
    // CCTP Integration for receiving fees
    IERC20 public usdcToken;
    uint256 public accumulatedFees;
    
    // Genesis storage contract
    IOpenworkGenesis public genesis;
    
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // Bridge for cross-chain communication
    INativeChainBridge public bridge;
    
    // Cross-chain settings - chain endpoints are now handled by the bridge
    uint32 public rewardsChainEid;
    uint32 public athenaClientChainEid;
    
    // REMOVED: DAO dependency - replaced with simpler voting eligibility
    uint256 public minTokensRequired; // Minimum earned tokens required to vote
    
    // Add this enum to define voting types
    enum VotingType {
        Dispute,
        SkillVerification,
        AskAthena
    }
    
    struct Oracle {
        string name;
        address[] members;
        string shortDescription;
        string hashOfDetails;
        address[] skillVerifiedAddresses;
    }
    
    struct SkillVerificationApplication {
        address applicant;
        string applicationHash;
        uint256 feeAmount;
        string targetOracleName;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
    }
    
    struct AskAthenaApplication {
        address applicant;
        string description;
        string hash;
        string targetOracle;
        string fees;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
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

    struct VoterData {
        address voter;
        address claimAddress;
        uint256 votingPower;
        bool voteFor;
    }

    uint256 public minOracleMembers;
    uint256 public votingPeriodMinutes;
        
    // Events
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);
    event EarnedTokensUsedForVoting(address indexed user, uint256 earnedTokens, string votingType);
    event CrossContractCallFailed(address indexed account, string reason);
    event DisputeFinalized(string indexed disputeId, bool winningSide, uint256 totalVotesFor, uint256 totalVotesAgainst);
    event DisputeRaised(string indexed jobId, address indexed disputeRaiser, uint256 fees);
    event SkillVerificationSubmitted(address indexed applicant, string targetOracleName, uint256 feeAmount);
    event AskAthenaSubmitted(address indexed applicant, string targetOracle, string fees);
    event RewardsChainEidUpdated(uint32 oldEid, uint32 newEid);
    event AthenaClientChainEidUpdated(uint32 oldEid, uint32 newEid);
    event USDCTokenSet(address indexed token);
    event FeesAccumulated(uint256 amount, uint256 totalAccumulated);
    event FeePaymentProcessed(string indexed disputeId, address indexed recipient, uint256 amount);
    event MinTokensRequiredUpdated(uint256 oldAmount, uint256 newAmount);
    event DisputedFundsResolved(string indexed disputeId, address indexed winner, bool winningSide);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner, 
        address _bridge, 
        address _genesis,
        address _usdcToken
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = INativeChainBridge(_bridge);
        genesis = IOpenworkGenesis(_genesis);
        usdcToken = IERC20(_usdcToken);
        
        // Initialize default values
        rewardsChainEid = 40161; // ETH Sepolia by default
        athenaClientChainEid = 40231; // Arbitrum Sepolia by default
        minOracleMembers = 3;
        votingPeriodMinutes = 2;
        minTokensRequired = 100; // CHANGED: Use earned tokens instead of stake
        accumulatedFees = 0;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == address(bridge), "Only bridge can upgrade");
        upgradeToAndCall(newImplementation, "");
    }
    
    // ==================== CCTP FEE RECEIVING ====================
    
    function setUSDCToken(address _usdcToken) external onlyOwner {
        require(_usdcToken != address(0), "USDC token cannot be zero address");
        usdcToken = IERC20(_usdcToken);
        emit USDCTokenSet(_usdcToken);
    }
    
    function receiveFees(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        
        // Transfer USDC from caller (CCTP receiver) to this contract
        usdcToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        accumulatedFees += _amount;
        emit FeesAccumulated(_amount, accumulatedFees);
    }
    
    function processFeePayment(
        string memory _disputeId,
        address[] memory _recipients,
        address[] memory _claimAddresses,
        uint256[] memory _votingPowers,
        bool[] memory _voteDirections,
        bool _winningSide,
        uint256 _totalFees
    ) external {
        // require(msg.sender == address(bridge), "Only bridge can call this function");
        require(_recipients.length == _claimAddresses.length, "Array length mismatch");
        require(_totalFees <= accumulatedFees, "Insufficient accumulated fees");
        
        uint256 totalWinningVotingPower = 0;
        
        // Calculate total winning voting power
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_voteDirections[i] == _winningSide) {
                totalWinningVotingPower += _votingPowers[i];
            }
        }
        
        // Distribute fees to winning voters
        if (totalWinningVotingPower > 0) {
            for (uint256 i = 0; i < _recipients.length; i++) {
                if (_voteDirections[i] == _winningSide) {
                    uint256 voterShare = (_votingPowers[i] * _totalFees) / totalWinningVotingPower;
                    
                    if (voterShare > 0) {
                        usdcToken.safeTransfer(_claimAddresses[i], voterShare);
                        accumulatedFees -= voterShare;
                        emit FeePaymentProcessed(_disputeId, _claimAddresses[i], voterShare);
                    }
                }
            }
        }
        
        // ADDED: Resolve disputed job funds after fee distribution
       _resolveDisputedFunds(_disputeId, _winningSide);
    }
    
    // ==================== DISPUTED FUNDS RESOLUTION ====================
    
    function _resolveDisputedFunds(string memory _disputeId, bool _winningSide) internal {
        // Get job details from Genesis
        if (address(nowjContract) == address(0)) return; // No NOWJC connected
        
        // Check if dispute ID corresponds to a job ID
        if (!nowjContract.jobExists(_disputeId)) return; // Not a job dispute
        
        // Get job details to determine winner
        (
            string memory jobId,
            address jobGiver,
            ,
            ,
            ,
            ,
            ,
            ,
            address selectedApplicant,
            
        ) = nowjContract.getJob(_disputeId);
        if (bytes(jobId).length == 0) return; // Job not found
        
        address winner;
        uint32 winnerChainDomain;
        
        // Determine dispute winner based on voting result
        if (_winningSide) {
            // Job giver wins - typically means job giver was right
            winner = jobGiver;
            winnerChainDomain = _getChainDomainForUser(jobGiver);
        } else {
            // Selected applicant wins - typically means applicant was right
            winner = selectedApplicant;
            winnerChainDomain = _getChainDomainForUser(selectedApplicant);
        }
        
        if (winner != address(0)) {
            // Get job details to calculate disputed amount (current milestone)
            (
                string memory jobId,
                address jobGiver,
                address[] memory applicants,
                string memory jobDetailHash,
                uint8 status,
                string[] memory workSubmissions,
                uint256 totalPaid,
                uint256 currentMilestone,
                address selectedApplicant,
                uint256 selectedApplicationId
            ) = nowjContract.getJob(_disputeId);
            
            // Get current milestone amount from dispute data (binary logic: current milestone amount)
            IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
            uint256 disputedAmount = dispute.disputedAmount;
            
            // Determine winner's chain domain
            if (winner == selectedApplicant) {
                // Applicant wins - get their stored preferred chain domain from NOWJC
                winnerChainDomain = nowjContract.jobApplicantChainDomain(_disputeId, winner);
                if (winnerChainDomain == 0) {
                    winnerChainDomain = 3; // Default to Arbitrum if not set
                }
            } else {
                // Job giver wins - default to native chain (Arbitrum = 3)
                winnerChainDomain = 3;
            }
            
            // Call simplified NOWJC interface with all parameters
            nowjContract.releaseDisputedFunds(winner, disputedAmount, winnerChainDomain);
            emit DisputedFundsResolved(_disputeId, winner, _winningSide);
        }
    }
    
    function _getChainDomainForUser(address /* _user */) internal pure returns (uint32) {
        // TODO: Implement chain detection logic
        // For now, default to native chain (Arbitrum = domain 3)
        // In production, this could:
        // 1. Check user's original registration chain
        // 2. Use bridge mapping of user preferences
        // 3. Query cross-chain user registry
        return 3; // Default to native chain
    }
    
    // ==================== MESSAGE HANDLERS ====================
    
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory /* oracleName */, uint256 fee, address disputeRaiser) external {
       // require(msg.sender == address(bridge), "Only bridge can call this function");
        
        // REMOVED: Oracle validation for testing purposes
        // TODO: Re-enable oracle validation when oracle system is fully configured
        // IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(oracleName);
        // require(oracle.members.length >= minOracleMembers, "Oracle not active");
        
        // Check if dispute already exists for this job - get from genesis
        // IOpenworkGenesis.Dispute memory existingDispute = genesis.getDispute(jobId);
       // require(!existingDispute.isVotingActive && existingDispute.timeStamp == 0, "Dispute already exists for this job");
        
        // Create new dispute in genesis
        genesis.setDispute(jobId, fee, disputeHash, disputeRaiser, fee);
        
        // Register expected CCTP fees for distribution
        accumulatedFees += fee;
        emit FeesAccumulated(fee, accumulatedFees);
        
        emit DisputeRaised(jobId, disputeRaiser, fee);
    }
    
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        
        uint256 applicationId = genesis.applicationCounter();
        genesis.setSkillApplication(applicationId, applicant, applicationHash, feeAmount, targetOracleName);
        
        emit SkillVerificationSubmitted(applicant, targetOracleName, feeAmount);
    }
    
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        
        uint256 athenaId = genesis.askAthenaCounter();
        genesis.setAskAthenaApplication(athenaId, applicant, description, hash, targetOracle, fees);
        
        emit AskAthenaSubmitted(applicant, targetOracle, fees);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = address(bridge);
        bridge = INativeChainBridge(_bridge);
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
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
    
    function updateRewardsChainEid(uint32 _rewardsChainEid) external onlyOwner {
        uint32 oldEid = rewardsChainEid;
        rewardsChainEid = _rewardsChainEid;
        emit RewardsChainEidUpdated(oldEid, _rewardsChainEid);
    }
    
    function updateAthenaClientChainEid(uint32 _chainEid) external onlyOwner {
        uint32 oldEid = athenaClientChainEid;
        athenaClientChainEid = _chainEid;
        emit AthenaClientChainEidUpdated(oldEid, _chainEid);
    }
    
    function setMinTokensRequired(uint256 _minTokens) external onlyOwner {
        uint256 oldAmount = minTokensRequired;
        minTokensRequired = _minTokens;
        emit MinTokensRequiredUpdated(oldAmount, _minTokens);
    }
    
    // ==================== SIMPLIFIED VOTING ELIGIBILITY ====================
    
    function canVote(address account) public view returns (bool) {
        // CHANGED: Simplified to only check earned tokens from NOWJ contract
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            return earnedTokens >= minTokensRequired;
        }
        
        return false;
    }
    
    function getUserVotingPower(address account) public view returns (uint256) {
        // CHANGED: Simplified to only use earned tokens
        if (address(nowjContract) != address(0)) {
            return nowjContract.getUserEarnedTokens(account);
        }
        
        return 0;
    }

    function getUserVotingInfo(address account) external view returns (
        bool hasActiveStake,
        uint256 stakeAmount,
        uint256 earnedTokens,
        uint256 totalVotingPower,
        bool meetsVotingThreshold
    ) {
        // CHANGED: Simplified response
        hasActiveStake = false; // No stake checking
        stakeAmount = 0; // No stake checking
        
        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            earnedTokens = nowjContract.getUserEarnedTokens(account);
        }
        
        totalVotingPower = earnedTokens;
        meetsVotingThreshold = canVote(account);
    }
    
    // ==================== ORACLE MANAGEMENT ====================
    
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        require(_names.length == _members.length && 
                _names.length == _shortDescriptions.length &&
                _names.length == _hashOfDetails.length &&
                _names.length == _skillVerifiedAddresses.length, 
                "Array lengths must match");
        
        for (uint256 i = 0; i < _names.length; i++) {
            genesis.setOracle(_names[i], _members[i], _shortDescriptions[i], _hashOfDetails[i], _skillVerifiedAddresses[i]);
        }
    }
    
    function addSingleOracle(
    string memory _name,
    address[] memory _members,
    string memory _shortDescription,
    string memory _hashOfDetails,
    address[] memory _skillVerifiedAddresses
    ) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        require(bytes(_name).length > 0, "Oracle name cannot be empty");
        require(_members.length >= minOracleMembers, "Not enough members for oracle");
        
        // Verify all members meet voting requirements
        for (uint256 i = 0; i < _members.length; i++) {
            require(canVote(_members[i]), "Member does not meet minimum earned tokens requirement");
        }
        
        genesis.setOracle(_name, _members, _shortDescription, _hashOfDetails, _skillVerifiedAddresses);
    }

    function addMembers(address[] memory _members, string memory _oracleName) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        // Check oracle exists in genesis
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        
        for (uint256 i = 0; i < _members.length; i++) {
            require(canVote(_members[i]), "Member does not meet minimum earned tokens requirement");
            genesis.addOracleMember(_oracleName, _members[i]);
        }
    }

    function getOracleMembers(string memory _oracleName) external view returns (address[] memory) {
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        return genesis.getOracleMembers(_oracleName);
    }
    
    function removeMemberFromOracle(string memory _oracleName, address _memberToRemove) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        
        genesis.removeOracleMember(_oracleName, _memberToRemove);
    }

    function removeOracle(string[] memory _oracleNames) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        for (uint256 i = 0; i < _oracleNames.length; i++) {
            // Note: Genesis contract doesn't have removeOracle function, 
            // but we can set empty oracle to effectively remove it
            address[] memory emptyMembers = new address[](0);
            address[] memory emptySkillVerified = new address[](0);
            genesis.setOracle(_oracleNames[i], emptyMembers, "", "", emptySkillVerified);
        }
    }
    
    // ==================== SKILL VERIFICATION ====================
    
    function approveSkillVerification(uint256 _applicationId) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        // Get application from genesis
        IOpenworkGenesis.SkillVerificationApplication memory application = genesis.getSkillApplication(_applicationId);
        require(application.applicant != address(0), "Invalid application ID");
        
        // Check oracle exists in genesis
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(application.targetOracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        
        genesis.addSkillVerifiedAddress(application.targetOracleName, application.applicant);
    }
    
    // ==================== REVISED VOTING FUNCTIONS - NOW USING GENESIS FOR STORAGE ====================
    
    function vote(
    VotingType _votingType, 
    string memory _disputeId, 
    bool _voteFor, 
    address _claimAddress
    ) external {
        // require(canVote(msg.sender), "Insufficient earned tokens to vote");
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
        require(!genesis.hasUserVotedOnSkillApplication(applicationId, msg.sender), "Already voted on this application");
        require(application.isVotingActive, "Voting is not active for this application");
        require(block.timestamp <= application.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
        
        // Record vote in genesis
        genesis.setSkillApplicationVote(applicationId, msg.sender);
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateSkillApplicationVotes(applicationId, application.votesFor + voteWeight, application.votesAgainst);
        } else {
            genesis.updateSkillApplicationVotes(applicationId, application.votesFor, application.votesAgainst + voteWeight);
        }
        
        // REVISED: Call local NOWJC contract instead of bridge to rewards
        if (address(nowjContract) != address(0)) {
            nowjContract.incrementGovernanceAction(msg.sender);
        }
        
        // REVISED: No cross-chain call needed during voting - voter info stored locally in genesis
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
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateAskAthenaVotes(athenaId, athenaApp.votesFor + voteWeight, athenaApp.votesAgainst);
        } else {
            genesis.updateAskAthenaVotes(athenaId, athenaApp.votesFor, athenaApp.votesAgainst + voteWeight);
        }
        
        // REVISED: Call local NOWJC contract instead of bridge to rewards
        if (address(nowjContract) != address(0)) {
            nowjContract.incrementGovernanceAction(msg.sender);
        }
        
        // REVISED: No cross-chain call needed during voting - voter info stored locally in genesis
    }
    
    // ==================== REVISED FINALIZE DISPUTE FUNCTION - NOW USING GENESIS FOR VOTER DATA ====================
    
function finalizeDispute(string memory _disputeId, bytes calldata _athenaClientOptions) external payable {
    IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
    require(dispute.timeStamp > 0, "Dispute does not exist");
    require(!dispute.isFinalized, "Dispute already finalized");
    
    bool winningSide = dispute.votesFor > dispute.votesAgainst;
    genesis.finalizeDispute(_disputeId, winningSide);
    
    // Get all voter data from Genesis and filter for winners only
    IOpenworkGenesis.VoterData[] memory allVoterData = genesis.getDisputeVoters(_disputeId);
    require(allVoterData.length > 0, "No voters found for this dispute");
    
    // Count winning voters
    uint256 winningVoterCount = 0;
    for (uint256 i = 0; i < allVoterData.length; i++) {
        if (allVoterData[i].voteFor == winningSide) {
            winningVoterCount++;
        }
    }
    
    // Create arrays for winning voters only
    address[] memory winningVoters = new address[](winningVoterCount);
    address[] memory winningClaimAddresses = new address[](winningVoterCount);
    uint256[] memory winningVotingPowers = new uint256[](winningVoterCount);
    bool[] memory winningVoteDirections = new bool[](winningVoterCount);
    
    // Populate arrays with winning voters
    uint256 winnerIndex = 0;
    for (uint256 i = 0; i < allVoterData.length; i++) {
        if (allVoterData[i].voteFor == winningSide) {
            winningVoters[winnerIndex] = allVoterData[i].voter;
            winningClaimAddresses[winnerIndex] = allVoterData[i].claimAddress;
            winningVotingPowers[winnerIndex] = allVoterData[i].votingPower;
            winningVoteDirections[winnerIndex] = allVoterData[i].voteFor;
            winnerIndex++;
        }
    }
    
    // Send to AthenaClient via LocalChain
    require(address(bridge) != address(0), "Bridge not set");
    require(msg.value > 0, "Fee required for cross-chain call");
    
    bytes memory payload = abi.encode(
        "finalizeDisputeWithVotes", 
        _disputeId, 
        winningSide,
        dispute.votesFor,
        dispute.votesAgainst,
        winningVoters,
        winningClaimAddresses,
        winningVotingPowers,
        winningVoteDirections
    );
    
    bridge.sendToLocalChain{value: msg.value}(_disputeId, "finalizeDisputeWithVotes", payload, _athenaClientOptions);
    
    emit DisputeFinalized(_disputeId, winningSide, dispute.votesFor, dispute.votesAgainst);
}

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
    
    function updateMinOracleMembers(uint256 _newMinMembers) external onlyOwner { // CHANGED: onlyOwner instead of onlyDAO
        minOracleMembers = _newMinMembers;
    }
    
    function getRewardsChainEid() external view returns (uint32) {
        return rewardsChainEid;
    }
    
    function getAthenaClientChainEid() external view returns (uint32) {
        return athenaClientChainEid;
    }
    
    function getAccumulatedFees() external view returns (uint256) {
        return accumulatedFees;
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getEarnedTokensFromJob(address user) external view returns (uint256) {
        if (address(nowjContract) == address(0)) {
            return 0;
        }
        return nowjContract.getUserEarnedTokens(user);
    }
    
    function getJobDetails(string memory _jobId) external view returns (
        bool exists,
        address jobGiver,
        address selectedApplicant,
        uint8 status,
        string memory jobDetailHash
    ) {
        if (address(nowjContract) == address(0)) {
            return (false, address(0), address(0), 0, "");
        }
        
        exists = nowjContract.jobExists(_jobId);
        
        if (!exists) {
            return (false, address(0), address(0), 0, "");
        }
        
        (
            ,
            jobGiver,
            ,
            jobDetailHash,
            status,
            ,
            ,
            ,
            selectedApplicant,
        ) = nowjContract.getJob(_jobId);
    }
    
    function getDispute(string memory _disputeId) external view returns (Dispute memory) {
        IOpenworkGenesis.Dispute memory genesisDispute = genesis.getDispute(_disputeId);
        return Dispute({
            jobId: genesisDispute.jobId,
            disputedAmount: genesisDispute.disputedAmount,
            hash: genesisDispute.hash,
            disputeRaiserAddress: genesisDispute.disputeRaiserAddress,
            votesFor: genesisDispute.votesFor,
            votesAgainst: genesisDispute.votesAgainst,
            result: genesisDispute.result,
            isVotingActive: genesisDispute.isVotingActive,
            isFinalized: genesisDispute.isFinalized,
            timeStamp: genesisDispute.timeStamp,
            fees: genesisDispute.fees
        });
    }
    
    function getSkillApplication(uint256 _applicationId) external view returns (SkillVerificationApplication memory) {
        IOpenworkGenesis.SkillVerificationApplication memory genesisApp = genesis.getSkillApplication(_applicationId);
        return SkillVerificationApplication({
            applicant: genesisApp.applicant,
            applicationHash: genesisApp.applicationHash,
            feeAmount: genesisApp.feeAmount,
            targetOracleName: genesisApp.targetOracleName,
            votesFor: genesisApp.votesFor,
            votesAgainst: genesisApp.votesAgainst,
            isVotingActive: genesisApp.isVotingActive,
            timeStamp: genesisApp.timeStamp
        });
    }
    
    function getAskAthenaApplication(uint256 _applicationId) external view returns (AskAthenaApplication memory) {
        IOpenworkGenesis.AskAthenaApplication memory genesisApp = genesis.getAskAthenaApplication(_applicationId);
        return AskAthenaApplication({
            applicant: genesisApp.applicant,
            description: genesisApp.description,
            hash: genesisApp.hash,
            targetOracle: genesisApp.targetOracle,
            fees: genesisApp.fees,
            votesFor: genesisApp.votesFor,
            votesAgainst: genesisApp.votesAgainst,
            isVotingActive: genesisApp.isVotingActive,
            timeStamp: genesisApp.timeStamp
        });
    }
    
    function getOracle(string memory _oracleName) external view returns (Oracle memory) {
        IOpenworkGenesis.Oracle memory genesisOracle = genesis.getOracle(_oracleName);
        return Oracle({
            name: genesisOracle.name,
            members: genesisOracle.members,
            shortDescription: genesisOracle.shortDescription,
            hashOfDetails: genesisOracle.hashOfDetails,
            skillVerifiedAddresses: genesisOracle.skillVerifiedAddresses
        });
    }
    
    function getApplicationCounter() external view returns (uint256) {
        return genesis.applicationCounter();
    }
    
    function getAskAthenaCounter() external view returns (uint256) {
        return genesis.askAthenaCounter();
    }
    
    function hasVotedOnDispute(string memory _disputeId, address _user) external view returns (bool) {
        return genesis.hasUserVotedOnDispute(_disputeId, _user);
    }
    
    function hasVotedOnSkillApplication(uint256 _applicationId, address _user) external view returns (bool) {
        return genesis.hasUserVotedOnSkillApplication(_applicationId, _user);
    }
    
    function hasVotedOnAskAthena(uint256 _athenaId, address _user) external view returns (bool) {
        return genesis.hasUserVotedOnAskAthena(_athenaId, _user);
    }
    
    // ==================== NEW VIEW FUNCTIONS FOR VOTER DATA FROM GENESIS ====================
    
    function getDisputeVoters(string memory _disputeId) external view returns (VoterData[] memory) {
        IOpenworkGenesis.VoterData[] memory genesisVoters = genesis.getDisputeVoters(_disputeId);
        VoterData[] memory voters = new VoterData[](genesisVoters.length);
        
        for (uint256 i = 0; i < genesisVoters.length; i++) {
            voters[i] = VoterData({
                voter: genesisVoters[i].voter,
                claimAddress: genesisVoters[i].claimAddress,
                votingPower: genesisVoters[i].votingPower,
                voteFor: genesisVoters[i].voteFor
            });
        }
        
        return voters;
    }
    
    function getSkillVerificationVoters(uint256 _applicationId) external view returns (VoterData[] memory) {
        IOpenworkGenesis.VoterData[] memory genesisVoters = genesis.getSkillVerificationVoters(_applicationId);
        VoterData[] memory voters = new VoterData[](genesisVoters.length);
        
        for (uint256 i = 0; i < genesisVoters.length; i++) {
            voters[i] = VoterData({
                voter: genesisVoters[i].voter,
                claimAddress: genesisVoters[i].claimAddress,
                votingPower: genesisVoters[i].votingPower,
                voteFor: genesisVoters[i].voteFor
            });
        }
        
        return voters;
    }
    
    function getAskAthenaVoters(uint256 _athenaId) external view returns (VoterData[] memory) {
        IOpenworkGenesis.VoterData[] memory genesisVoters = genesis.getAskAthenaVoters(_athenaId);
        VoterData[] memory voters = new VoterData[](genesisVoters.length);
        
        for (uint256 i = 0; i < genesisVoters.length; i++) {
            voters[i] = VoterData({
                voter: genesisVoters[i].voter,
                claimAddress: genesisVoters[i].claimAddress,
                votingPower: genesisVoters[i].votingPower,
                voteFor: genesisVoters[i].voteFor
            });
        }
        
        return voters;
    }
    
    function getDisputeVoterClaimAddress(string memory _disputeId, address _voter) external view returns (address) {
        return genesis.getDisputeVoterClaimAddress(_disputeId, _voter);
    }
    
    // ==================== FEE MANAGEMENT FUNCTIONS ====================
    
    function withdrawAccumulatedFees(uint256 _amount) external onlyOwner {
        require(_amount <= accumulatedFees, "Amount exceeds accumulated fees");
        require(_amount <= usdcToken.balanceOf(address(this)), "Insufficient contract balance");
        
        usdcToken.safeTransfer(owner(), _amount);
        accumulatedFees -= _amount;
    }
    
    function emergencyWithdrawUSDC() external onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "No USDC balance to withdraw");
        usdcToken.safeTransfer(owner(), balance);
        accumulatedFees = 0;
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH for paying LayerZero fees
    receive() external payable {}

}