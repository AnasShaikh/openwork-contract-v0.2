// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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

contract NativeAthena is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    address public daoContract;
    
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

    mapping(string => mapping(address => bool)) public hasVotedOnDispute;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnSkillApplication;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnAskAthena;
    mapping(string => Oracle) public oracles;
    mapping(string => mapping(address => uint256)) public memberStakeAmount;
    mapping(string => mapping(address => uint256)) public skillVerificationDates;
    mapping(uint256 => SkillVerificationApplication) public skillApplications;
    mapping(uint256 => AskAthenaApplication) public askAthenaApplications;
    mapping(string => Dispute) public disputes;
    uint256 public applicationCounter;
    uint256 public askAthenaCounter;
    uint256 public minOracleMembers;
    uint256 public votingPeriodMinutes;
    uint256 public minStakeRequired;
    
    // Events
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
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
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _owner, address _daoContract, address _bridge) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        daoContract = _daoContract;
        bridge = INativeChainBridge(_bridge);
        
        // Initialize default values
        rewardsChainEid = 40161; // ETH Sepolia by default
        athenaClientChainEid = 40231; // Arbitrum Sepolia by default
        minOracleMembers = 3;
        votingPeriodMinutes = 4;
        minStakeRequired = 100;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== MESSAGE HANDLERS ====================
    
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        
        // Check if oracle is active (has minimum required members)
        require(oracles[oracleName].members.length >= minOracleMembers, "Oracle not active");
        
        // Check if dispute already exists for this job
        require(!disputes[jobId].isVotingActive && disputes[jobId].timeStamp == 0, "Dispute already exists for this job");
        
        // Create new dispute using string jobId as key
        disputes[jobId] = Dispute({
            jobId: jobId,
            disputedAmount: fee,
            hash: disputeHash,
            disputeRaiserAddress: disputeRaiser,
            votesFor: 0,
            votesAgainst: 0,
            result: false,
            isVotingActive: true,
            isFinalized: false,
            timeStamp: block.timestamp,
            fees: fee
        });
        
        emit DisputeRaised(jobId, disputeRaiser, fee);
    }
    
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        
        skillApplications[applicationCounter] = SkillVerificationApplication({
            applicant: applicant,
            applicationHash: applicationHash,
            feeAmount: feeAmount,
            targetOracleName: targetOracleName,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
        applicationCounter++;
        
        emit SkillVerificationSubmitted(applicant, targetOracleName, feeAmount);
    }
    
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        
        askAthenaApplications[askAthenaCounter] = AskAthenaApplication({
            applicant: applicant,
            description: description,
            hash: hash,
            targetOracle: targetOracle,
            fees: fees,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
        askAthenaCounter++;
        
        emit AskAthenaSubmitted(applicant, targetOracle, fees);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = address(bridge);
        bridge = INativeChainBridge(_bridge);
        emit BridgeUpdated(oldBridge, _bridge);
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
    
    // ==================== LOCAL INTERFACE FOR NATIVE DAO ====================
    
    /**
     * @notice Function for Native DAO to notify governance actions (called locally)
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
     * @notice Send governance notification to Rewards Contract via bridge
     * @param account Address of the user
     * @param actionType Type of action
     * @param _rewardsOptions LayerZero options
     */
    function _sendGovernanceNotificationToRewards(
        address account,
        string memory actionType,
        bytes calldata _rewardsOptions
    ) internal {
        if (address(bridge) == address(0)) return;
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        
        uint256 fee = 0;
        try bridge.quoteRewardsChain(payload, _rewardsOptions) returns (uint256 quotedFee) {
            fee = quotedFee;
        } catch {
            return;
        }
        
        if (fee > 0 && msg.value >= fee) {
            try bridge.sendToRewardsChain{value: fee}("notifyGovernanceAction", payload, _rewardsOptions) {
                emit GovernanceActionForwardedToRewards(account, actionType, fee);
            } catch {
                // Silent fail
            }
        }
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
            oracles[_names[i]] = Oracle({
                name: _names[i],
                members: _members[i],
                shortDescription: _shortDescriptions[i],
                hashOfDetails: _hashOfDetails[i],
                skillVerifiedAddresses: _skillVerifiedAddresses[i]
            });
        }
    }
    
    function addMembers(address[] memory _members, string memory _oracleName) external onlyDAO {
        require(bytes(oracles[_oracleName].name).length > 0, "Oracle not found");
        
        for (uint256 i = 0; i < _members.length; i++) {
            require(canVote(_members[i]), "Member does not meet minimum stake/earned tokens requirement");
            oracles[_oracleName].members.push(_members[i]);
        }
    }

    function getOracleMembers(string memory _oracleName) external view returns (address[] memory) {
        require(bytes(oracles[_oracleName].name).length > 0, "Oracle not found");
        return oracles[_oracleName].members;
    }
    
    function removeMemberFromOracle(string memory _oracleName, address _memberToRemove) external onlyDAO {
        require(bytes(oracles[_oracleName].name).length > 0, "Oracle not found");
        
        address[] storage members = oracles[_oracleName].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == _memberToRemove) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
    }

    function removeOracle(string[] memory _oracleNames) external onlyDAO {
        for (uint256 i = 0; i < _oracleNames.length; i++) {
            delete oracles[_oracleNames[i]];
        }
    }
    
    // ==================== SKILL VERIFICATION ====================
    
    function approveSkillVerification(uint256 _applicationId) external onlyDAO {
        require(_applicationId < applicationCounter, "Invalid application ID");
        
        SkillVerificationApplication memory application = skillApplications[_applicationId];
        require(bytes(oracles[application.targetOracleName].name).length > 0, "Oracle not found");
        
        oracles[application.targetOracleName].skillVerifiedAddresses.push(application.applicant);
        skillVerificationDates[application.targetOracleName][application.applicant] = block.timestamp;
    }
    
    // ==================== NOTE: DIRECT SUBMISSION REMOVED ====================
    // Direct submission functions removed to maintain proper cross-chain architecture.
    // All dispute raising, skill verification, and ask athena submissions should come 
    // through the bridge from other chains (AthenaClient, LOWJC, etc.).
    // Local submissions would bypass the fee collection and cross-chain flow.
    
    // ==================== UPDATED VOTING FUNCTIONS ====================
    
    function vote(
        VotingType _votingType, 
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress, 
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external payable {
        // Check if user can vote (has sufficient stake OR earned tokens)
        require(canVote(msg.sender), "Insufficient stake or earned tokens to vote");
        require(_claimAddress != address(0), "Claim address cannot be zero");
        
        // Calculate total vote weight (stake weight + earned tokens)
        uint256 voteWeight = getUserVotingPower(msg.sender);
        require(voteWeight > 0, "No voting power");
        
        // Prepare payloads for both chains
        bytes memory rewardsPayload = abi.encode("notifyGovernanceAction", msg.sender);
        bytes memory athenaClientPayload = abi.encode("recordVote", _disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
        
        // Get fee quote for both chains
        (uint256 totalFeeCost, , ) = bridge.quoteTwoChains(
            rewardsPayload,
            athenaClientPayload,
            _rewardsOptions,
            _athenaClientOptions
        );
        
        require(msg.value >= totalFeeCost, "Insufficient fee provided");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        (uint256 stakeAmount, , , bool isActive) = INativeDAO(daoContract).getStakerInfo(msg.sender);
        if (!isActive || stakeAmount < minStakeRequired) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(msg.sender);
                if (earnedTokens >= minStakeRequired) {
                    string memory votingTypeStrShort = _votingType == VotingType.Dispute ? "dispute" : 
                                                      _votingType == VotingType.SkillVerification ? "skill_verification" : "ask_athena";
                    emit EarnedTokensUsedForVoting(msg.sender, earnedTokens, votingTypeStrShort);
                }
            }
        }
        
        // Route to appropriate voting function
        if (_votingType == VotingType.Dispute) {
            _voteOnDispute(_disputeId, _voteFor, _claimAddress, voteWeight, rewardsPayload, athenaClientPayload, _rewardsOptions, _athenaClientOptions);
        } else if (_votingType == VotingType.SkillVerification) {
            _voteOnSkillVerification(_disputeId, _voteFor, _claimAddress, voteWeight, rewardsPayload, athenaClientPayload, _rewardsOptions, _athenaClientOptions);
        } else if (_votingType == VotingType.AskAthena) {
            _voteOnAskAthena(_disputeId, _voteFor, _claimAddress, voteWeight, rewardsPayload, athenaClientPayload, _rewardsOptions, _athenaClientOptions);
        }
    }
    
    function _voteOnDispute(
        string memory _disputeId, 
        bool _voteFor, 
        address /* _claimAddress */, 
        uint256 voteWeight,
        bytes memory rewardsPayload,
        bytes memory athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) internal {
        require(disputes[_disputeId].timeStamp > 0, "Dispute does not exist");
        require(!hasVotedOnDispute[_disputeId][msg.sender], "Already voted on this dispute");
        
        Dispute storage dispute = disputes[_disputeId];
        require(dispute.isVotingActive, "Voting is not active for this dispute");
        require(block.timestamp <= dispute.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
        
        hasVotedOnDispute[_disputeId][msg.sender] = true;
        
        if (_voteFor) {
            dispute.votesFor += voteWeight;
        } else {
            dispute.votesAgainst += voteWeight;
        }
        
        // Send to both chains using the bridge's sendToTwoChains function
        try bridge.sendToTwoChains{value: msg.value}(
            "voteOnDispute",
            rewardsPayload,
            athenaClientPayload,
            _rewardsOptions,
            _athenaClientOptions
        ) {
            // Success
        } catch {
            // Silent fail
        }
    }
    
    function _voteOnSkillVerification(
        string memory _disputeId, 
        bool _voteFor, 
        address /* _claimAddress */, 
        uint256 voteWeight,
        bytes memory rewardsPayload,
        bytes memory athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) internal {
        uint256 applicationId = stringToUint(_disputeId);
        require(applicationId < applicationCounter, "Application does not exist");
        require(!hasVotedOnSkillApplication[applicationId][msg.sender], "Already voted on this application");
        
        SkillVerificationApplication storage application = skillApplications[applicationId];
        require(application.isVotingActive, "Voting is not active for this application");
        require(block.timestamp <= application.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
        
        hasVotedOnSkillApplication[applicationId][msg.sender] = true;
        
        if (_voteFor) {
            application.votesFor += voteWeight;
        } else {
            application.votesAgainst += voteWeight;
        }
        
        // Send to both chains using the bridge's sendToTwoChains function
        try bridge.sendToTwoChains{value: msg.value}(
            "voteOnSkillVerification",
            rewardsPayload,
            athenaClientPayload,
            _rewardsOptions,
            _athenaClientOptions
        ) {
            // Success
        } catch {
            // Silent fail
        }
    }
    
    function _voteOnAskAthena(
        string memory _disputeId, 
        bool _voteFor, 
        address /* _claimAddress */, 
        uint256 voteWeight,
        bytes memory rewardsPayload,
        bytes memory athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) internal {
        uint256 athenaId = stringToUint(_disputeId);
        require(athenaId < askAthenaCounter, "AskAthena application does not exist");
        require(!hasVotedOnAskAthena[athenaId][msg.sender], "Already voted on this AskAthena application");
        
        AskAthenaApplication storage athenaApp = askAthenaApplications[athenaId];
        require(athenaApp.isVotingActive, "Voting is not active for this AskAthena application");
        require(block.timestamp <= athenaApp.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
        
        hasVotedOnAskAthena[athenaId][msg.sender] = true;
        
        if (_voteFor) {
            athenaApp.votesFor += voteWeight;
        } else {
            athenaApp.votesAgainst += voteWeight;
        }
        
        // Send to both chains using the bridge's sendToTwoChains function
        try bridge.sendToTwoChains{value: msg.value}(
            "voteOnAskAthena",
            rewardsPayload,
            athenaClientPayload,
            _rewardsOptions,
            _athenaClientOptions
        ) {
            // Success
        } catch {
            // Silent fail
        }
    }
    
    // Function to finalize dispute - can be called by anyone
    function finalizeDispute(string memory _disputeId, bytes calldata _athenaClientOptions) external payable {
        require(disputes[_disputeId].timeStamp > 0, "Dispute does not exist");
        
        Dispute storage dispute = disputes[_disputeId];
        require(dispute.isVotingActive, "Voting is not active for this dispute");
        require(!dispute.isFinalized, "Dispute already finalized");
        require(block.timestamp > dispute.timeStamp + (votingPeriodMinutes * 60), "Voting period not expired");
        
        // Finalize the dispute
        dispute.isVotingActive = false;
        dispute.isFinalized = true;
        dispute.result = dispute.votesFor > dispute.votesAgainst;
        
        // Send message to AthenaClient with the winning side
        bytes memory payload = abi.encode("finalizeDispute", _disputeId, dispute.result);
        
        try bridge.sendToAthenaClientChain{value: msg.value}("finalizeDispute", payload, _athenaClientOptions) {
            // Success
        } catch {
            // Silent fail
        }
        
        emit DisputeFinalized(_disputeId, dispute.result, dispute.votesFor, dispute.votesAgainst);
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
        return disputes[_disputeId];
    }
    
    function getSkillApplication(uint256 _applicationId) external view returns (SkillVerificationApplication memory) {
        return skillApplications[_applicationId];
    }
    
    function getAskAthenaApplication(uint256 _applicationId) external view returns (AskAthenaApplication memory) {
        return askAthenaApplications[_applicationId];
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