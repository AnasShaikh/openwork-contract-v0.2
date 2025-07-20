// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Interface to get staker info from Native DAO (now local)
interface INativeDAO {
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive);
    function notifyGovernanceActionFromAthena(address account) external;
}

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
}

// Interface for OpenworkGenesis storage contract
interface IOpenworkGenesis {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
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
}

// UPDATED INTERFACE for the bridge to support new two-chain functionality
interface INativeChainBridge {
    function sendToRewardsChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function sendToAthenaClientChain(
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
    
    function quoteAthenaClientChain(
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

contract NativeAthena is Ownable
{
    address public daoContract;
    
    // Genesis storage contract
    IOpenworkGenesis public genesis;
    
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // Bridge for cross-chain communication
    INativeChainBridge public bridge;
    
    // Cross-chain settings - chain endpoints are now handled by the bridge
    uint32 public rewardsChainEid;
    uint32 public athenaClientChainEid;
    
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

    uint256 public minOracleMembers;
    uint256 public votingPeriodMinutes;
    uint256 public minStakeRequired;
    
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
    event GovernanceActionReceivedFromNativeDAO(address indexed user, string action);
    event GovernanceActionForwardedToRewards(address indexed user, string action, uint256 fee);
    event RewardsChainEidUpdated(uint32 oldEid, uint32 newEid);
    event AthenaClientChainEidUpdated(uint32 oldEid, uint32 newEid);
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "Only DAO can call this function");
        _;
    }
    
    constructor(address _daoContract, address _bridge, address _genesis) Ownable(msg.sender) {
        daoContract = _daoContract;
        bridge = INativeChainBridge(_bridge);
        genesis = IOpenworkGenesis(_genesis);
        
        // Initialize default values
        rewardsChainEid = 40161; // ETH Sepolia by default
        athenaClientChainEid = 40231; // Arbitrum Sepolia by default
        minOracleMembers = 3;
        votingPeriodMinutes = 4;
        minStakeRequired = 100;
    }
    
    // ==================== MESSAGE HANDLERS ====================
    
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) external {
        // Create new dispute in genesis
        genesis.setDispute(jobId, fee, disputeHash, disputeRaiser, fee);
        
        emit DisputeRaised(jobId, disputeRaiser, fee);
    }
    
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external {
        uint256 applicationId = genesis.applicationCounter();
        genesis.setSkillApplication(applicationId, applicant, applicationHash, feeAmount, targetOracleName);
        
        emit SkillVerificationSubmitted(applicant, targetOracleName, feeAmount);
    }
    
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external {
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
    
    // ==================== FIXED LOCAL INTERFACE FOR NATIVE DAO ====================
    
    /**
     * @notice Function for Native DAO to notify governance actions (called locally) - FIXED VERSION
     * @param account Address of the user who performed governance action
     * @param actionType Type of governance action (propose, vote, etc.)
     * @param _rewardsOptions LayerZero options for sending to Rewards Contract
     */
    function notifyGovernanceActionFromNativeDAO(
        address account,
        string memory actionType,
        bytes calldata _rewardsOptions
    ) external payable {
        require(msg.sender == daoContract, "Only Native DAO can call this");
        
        emit GovernanceActionReceivedFromNativeDAO(account, actionType);
        
        // Forward to Rewards Contract via bridge
        _sendGovernanceNotificationToRewards(account, actionType, _rewardsOptions);
    }
    
    /**
     * @notice Send governance notification to Rewards Contract via bridge (FIXED VERSION)
     * @param account Address of the user
     * @param actionType Type of action
     * @param _rewardsOptions LayerZero options
     */
    function _sendGovernanceNotificationToRewards(
        address account,
        string memory actionType,
        bytes calldata _rewardsOptions
    ) internal {
        require(address(bridge) != address(0), "Bridge not set");
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        
        // FIXED: Send directly using user-provided msg.value and options (just like LOWJC)
        bridge.sendToRewardsChain{value: msg.value}("notifyGovernanceAction", payload, _rewardsOptions);
        emit GovernanceActionForwardedToRewards(account, actionType, msg.value);
    }
    
    // ==================== VOTING ELIGIBILITY FUNCTIONS ====================
    
    function canVote(address account) public view returns (bool) {
        // First check if user has sufficient active stake
        (uint256 stakeAmount, , , bool isActive) = INativeDAO(daoContract).getStakerInfo(account);
        if (isActive && stakeAmount >= minStakeRequired) {
            return true;
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
        (uint256 stakeAmount, , uint256 durationMinutes, bool isActive) = INativeDAO(daoContract).getStakerInfo(account);
        if (isActive && stakeAmount > 0) {
            totalVotingPower += stakeAmount * durationMinutes;
        }
        
        // Add earned tokens voting power
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            totalVotingPower += earnedTokens;
        }
        
        return totalVotingPower;
    }

    function getUserVotingInfo(address account) external view returns (
        bool hasActiveStake,
        uint256 stakeAmount,
        uint256 earnedTokens,
        uint256 totalVotingPower,
        bool meetsVotingThreshold
    ) {
        (uint256 stake, , , bool isActive) = INativeDAO(daoContract).getStakerInfo(account);
        hasActiveStake = isActive;
        stakeAmount = hasActiveStake ? stake : 0;
        
        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            earnedTokens = nowjContract.getUserEarnedTokens(account);
        }
        
        totalVotingPower = getUserVotingPower(account);
        meetsVotingThreshold = canVote(account);
    }
    
    // ==================== ORACLE MANAGEMENT ====================
    
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external  {
        require(_names.length == _members.length && 
                _names.length == _shortDescriptions.length &&
                _names.length == _hashOfDetails.length &&
                _names.length == _skillVerifiedAddresses.length, 
                "Array lengths must match");
        
        for (uint256 i = 0; i < _names.length; i++) {
            genesis.setOracle(_names[i], _members[i], _shortDescriptions[i], _hashOfDetails[i], _skillVerifiedAddresses[i]);
        }
    }
    
    function addMembers(address[] memory _members, string memory _oracleName) external {
        for (uint256 i = 0; i < _members.length; i++) {
            genesis.addOracleMember(_oracleName, _members[i]);
        }
    }

    function getOracleMembers(string memory _oracleName) external view returns (address[] memory) {
        return genesis.getOracleMembers(_oracleName);
    }
    
    function removeMemberFromOracle(string memory _oracleName, address _memberToRemove) external {
        genesis.removeOracleMember(_oracleName, _memberToRemove);
    }

    function removeOracle(string[] memory _oracleNames) external {
        for (uint256 i = 0; i < _oracleNames.length; i++) {
            // Note: Genesis contract doesn't have removeOracle function, 
            // but we can set empty oracle to effectively remove it
            address[] memory emptyMembers = new address[](0);
            address[] memory emptySkillVerified = new address[](0);
            genesis.setOracle(_oracleNames[i], emptyMembers, "", "", emptySkillVerified);
        }
    }
    
    // ==================== SKILL VERIFICATION ====================
    
    function approveSkillVerification(uint256 _applicationId) external {
        // Get application from genesis
        IOpenworkGenesis.SkillVerificationApplication memory application = genesis.getSkillApplication(_applicationId);
        
        genesis.addSkillVerifiedAddress(application.targetOracleName, application.applicant);
    }
    
    // ==================== FIXED VOTING FUNCTIONS - USING sendToTwoChains ====================
    
    function vote(
        VotingType _votingType, 
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress, 
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external payable {
        // Calculate total vote weight (stake weight + earned tokens)
        uint256 voteWeight = getUserVotingPower(msg.sender);
        
        // Route to appropriate voting function
        if (_votingType == VotingType.Dispute) {
            _voteOnDispute(_disputeId, _voteFor, _claimAddress, voteWeight, _rewardsOptions, _athenaClientOptions);
        } else if (_votingType == VotingType.SkillVerification) {
            _voteOnSkillVerification(_disputeId, _voteFor, _claimAddress, voteWeight, _rewardsOptions, _athenaClientOptions);
        } else if (_votingType == VotingType.AskAthena) {
            _voteOnAskAthena(_disputeId, _voteFor, _claimAddress, voteWeight, _rewardsOptions, _athenaClientOptions);
        }
    }
    
    function _voteOnDispute(
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress, 
        uint256 voteWeight,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) internal {
        // Get dispute from genesis
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        
        // Record vote in genesis
        genesis.setDisputeVote(_disputeId, msg.sender);
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateDisputeVotes(_disputeId, dispute.votesFor + voteWeight, dispute.votesAgainst);
        } else {
            genesis.updateDisputeVotes(_disputeId, dispute.votesFor, dispute.votesAgainst + voteWeight);
        }
        
        // Use bridge's sendToTwoChains
        if (address(bridge) != address(0)) {
            bytes memory rewardsPayload = abi.encode("notifyGovernanceAction", msg.sender);
            bytes memory athenaClientPayload = abi.encode("recordVote", _disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
            
            bridge.sendToTwoChains{value: msg.value}(
                "voteOnDispute",
                rewardsPayload,
                athenaClientPayload,
                _rewardsOptions,
                _athenaClientOptions
            );
        }
    }
    
    function _voteOnSkillVerification(
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress, 
        uint256 voteWeight,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) internal {
        uint256 applicationId = stringToUint(_disputeId);
        
        // Get application from genesis
        IOpenworkGenesis.SkillVerificationApplication memory application = genesis.getSkillApplication(applicationId);
        
        // Record vote in genesis
        genesis.setSkillApplicationVote(applicationId, msg.sender);
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateSkillApplicationVotes(applicationId, application.votesFor + voteWeight, application.votesAgainst);
        } else {
            genesis.updateSkillApplicationVotes(applicationId, application.votesFor, application.votesAgainst + voteWeight);
        }
        
        // Use bridge's sendToTwoChains
        if (address(bridge) != address(0)) {
            bytes memory rewardsPayload = abi.encode("notifyGovernanceAction", msg.sender);
            bytes memory athenaClientPayload = abi.encode("recordVote", _disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
            
            bridge.sendToTwoChains{value: msg.value}(
                "voteOnSkillVerification",
                rewardsPayload,
                athenaClientPayload,
                _rewardsOptions,
                _athenaClientOptions
            );
        }
    }
    
    function _voteOnAskAthena(
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress, 
        uint256 voteWeight,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) internal {
        uint256 athenaId = stringToUint(_disputeId);
        
        // Get askAthena application from genesis
        IOpenworkGenesis.AskAthenaApplication memory athenaApp = genesis.getAskAthenaApplication(athenaId);
        
        // Record vote in genesis
        genesis.setAskAthenaVote(athenaId, msg.sender);
        
        // Update vote counts in genesis
        if (_voteFor) {
            genesis.updateAskAthenaVotes(athenaId, athenaApp.votesFor + voteWeight, athenaApp.votesAgainst);
        } else {
            genesis.updateAskAthenaVotes(athenaId, athenaApp.votesFor, athenaApp.votesAgainst + voteWeight);
        }
        
        // Use bridge's sendToTwoChains
        if (address(bridge) != address(0)) {
            bytes memory rewardsPayload = abi.encode("notifyGovernanceAction", msg.sender);
            bytes memory athenaClientPayload = abi.encode("recordVote", _disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
            
            bridge.sendToTwoChains{value: msg.value}(
                "voteOnAskAthena",
                rewardsPayload,
                athenaClientPayload,
                _rewardsOptions,
                _athenaClientOptions
            );
        }
    }
    
    // FIXED: Function to finalize dispute - also uses sendToAthenaClientChain
    function finalizeDispute(string memory _disputeId, bytes calldata _athenaClientOptions) external payable {
        // Get dispute from genesis
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        
        // Finalize the dispute in genesis
        bool result = dispute.votesFor > dispute.votesAgainst;
        genesis.finalizeDispute(_disputeId, result);
        
        // Send message to AthenaClient
        if (address(bridge) != address(0) && msg.value > 0) {
            bytes memory payload = abi.encode("finalizeDispute", _disputeId, result);
            bridge.sendToAthenaClientChain{value: msg.value}("finalizeDispute", payload, _athenaClientOptions);
        }
        
        emit DisputeFinalized(_disputeId, result, dispute.votesFor, dispute.votesAgainst);
    }
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteGovernanceNotification(
        address account,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        return bridge.quoteRewardsChain(payload, _options);
    }
    
    function quoteVoteFees(
        VotingType /* _votingType */,
        string memory _disputeId,
        address _claimAddress,
        bool _voteFor,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 athenaClientFee) {
        // Calculate vote weight for the caller
        uint256 voteWeight = getUserVotingPower(msg.sender);
        
        // Prepare payloads
        bytes memory rewardsPayload = abi.encode("notifyGovernanceAction", msg.sender);
        bytes memory athenaPayload = abi.encode("recordVote", _disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
        
        // Get quote from bridge
        return bridge.quoteTwoChains(rewardsPayload, athenaPayload, _rewardsOptions, _athenaClientOptions);
    }
    
    function quoteNativeDAOGovernanceForwarding(
        address account,
        bytes calldata _rewardsOptions
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        return bridge.quoteRewardsChain(payload, _rewardsOptions);
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
    
    function updateMinOracleMembers(uint256 _newMinMembers) external onlyDAO {
        minOracleMembers = _newMinMembers;
    }
    
    function getRewardsChainEid() external view returns (uint32) {
        return rewardsChainEid;
    }
    
    function getAthenaClientChainEid() external view returns (uint32) {
        return athenaClientChainEid;
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getStakerInfoFromDAO(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) {
        return INativeDAO(daoContract).getStakerInfo(staker);
    }
    
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
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH for paying LayerZero fees
    receive() external payable {}
}