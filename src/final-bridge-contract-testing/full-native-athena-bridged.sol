// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Interface to get staker info from Native DAO
interface INativeDAO {
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive);
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

// Interface to communicate with AthenaClient Contract
interface IAthenaClient {
    function recordVote(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external;
    function finalizeDispute(string memory disputeId, bool winningSide, uint256 totalVotingPowerFor, uint256 totalVotingPowerAgainst) external;
}

contract CrossChainNativeAthena is OAppReceiver, OAppSender {
    address public daoContract;
    
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // AthenaClient Contract for fee distribution
    IAthenaClient public athenaClient;
    
    // Cross-chain settings
    uint32 public rewardsChainEid = 40161; // ETH Sepolia by default
    
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
    uint256 public minOracleMembers = 3;
    uint256 public votingPeriodMinutes = 4;
    uint256 public minStakeRequired = 100;
    
    // Events
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event AthenaClientUpdated(address indexed oldContract, address indexed newContract);
    event EarnedTokensUsedForVoting(address indexed user, uint256 earnedTokens, string votingType);
    event CrossContractCallFailed(address indexed account, string reason);
    event DisputeFinalized(string indexed disputeId, bool winningSide, uint256 totalVotesFor, uint256 totalVotesAgainst);
    event DisputeRaised(string indexed jobId, address indexed disputeRaiser, uint256 fees);
    event SkillVerificationSubmitted(address indexed applicant, string targetOracleName, uint256 feeAmount);
    event AskAthenaSubmitted(address indexed applicant, string targetOracle, string fees);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event CrossChainGovernanceNotificationSent(address indexed user, string action, uint32 targetChain, uint256 fee);
    event RewardsChainEidUpdated(uint32 oldEid, uint32 newEid);
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "Only DAO can call this function");
        _;
    }
    
    constructor(address _endpoint, address _owner, address _daoContract) OAppCore(_endpoint, _owner) Ownable(_owner) {
        daoContract = _daoContract;
    }

    // Override the conflicting oAppVersion function
    function oAppVersion() public pure override(OAppReceiver, OAppSender) returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }

    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }

    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used)
        bytes calldata // _extraData (not used)
    ) internal override {
        (string memory functionName) = abi.decode(_message, (string));
        
        if (keccak256(bytes(functionName)) == keccak256(bytes("raiseDispute"))) {
            (, string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) = abi.decode(_message, (string, string, string, string, uint256, address));
            _handleRaiseDispute(jobId, disputeHash, oracleName, fee, disputeRaiser);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitSkillVerification"))) {
            (, address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) = abi.decode(_message, (string, address, string, uint256, string));
            _handleSubmitSkillVerification(applicant, applicationHash, feeAmount, targetOracleName);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("askAthena"))) {
            (, address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) = abi.decode(_message, (string, address, string, string, string, string));
            _handleAskAthena(applicant, description, hash, targetOracle, fees);
        }
        
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }

    // ==================== MESSAGE HANDLERS ====================
    
    function _handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) internal {
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
    
    function _handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) internal {
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
    
    function _handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) internal {
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
    
    // ==================== CONTRACT SETUP FUNCTIONS ====================
    
    function setNOWJContract(address _nowjContract) external onlyOwner {
        address oldContract = address(nowjContract);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        emit NOWJContractUpdated(oldContract, _nowjContract);
    }
    
    function setAthenaClient(address _athenaClient) external onlyOwner {
        address oldContract = address(athenaClient);
        athenaClient = IAthenaClient(_athenaClient);
        emit AthenaClientUpdated(oldContract, _athenaClient);
    }
    
    function updateRewardsChainEid(uint32 _rewardsChainEid) external onlyOwner {
        uint32 oldEid = rewardsChainEid;
        rewardsChainEid = _rewardsChainEid;
        emit RewardsChainEidUpdated(oldEid, _rewardsChainEid);
    }
    
    // ==================== HELPER FUNCTIONS ====================
    
    function _notifyRewardsContract(address account, string memory actionType, bytes memory _options, uint256 nativeFee) private {
        if (rewardsChainEid == 0) {
            emit CrossContractCallFailed(account, "No rewards chain configured");
            return;
        }
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        
        _lzSend(rewardsChainEid, payload, _options, MessagingFee(nativeFee, 0), payable(msg.sender));
        
        emit CrossChainGovernanceNotificationSent(account, actionType, rewardsChainEid, nativeFee);
    }
    
    function _notifyAthenaClient(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) private {
        if (address(athenaClient) != address(0)) {
            try athenaClient.recordVote(disputeId, voter, claimAddress, votingPower, voteFor) {
                // Success
            } catch Error(string memory reason) {
                emit CrossContractCallFailed(voter, string(abi.encodePacked("AthenaClient vote recording failed: ", reason)));
            } catch {
                emit CrossContractCallFailed(voter, "AthenaClient vote recording failed: Unknown error");
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
    
    // ==================== DIRECT SUBMISSION FUNCTIONS (for local use) ====================
    
    function raiseDispute(
        string memory _jobId,
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _fee
    ) external {
        _handleRaiseDispute(_jobId, _disputeHash, _oracleName, _fee, msg.sender);
    }
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName
    ) external {
        _handleSubmitSkillVerification(msg.sender, _applicationHash, _feeAmount, _targetOracleName);
    }

    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        string memory _fees
    ) external {
        _handleAskAthena(msg.sender, _description, _hash, _targetOracle, _fees);
    }
    
    // ==================== VOTING FUNCTIONS ====================
    
    function vote(VotingType _votingType, string memory _disputeId, bool _voteFor, address _claimAddress, bytes calldata _options) external payable {
        // Check if user can vote (has sufficient stake OR earned tokens)
        require(canVote(msg.sender), "Insufficient stake or earned tokens to vote");
        require(_claimAddress != address(0), "Claim address cannot be zero");
        
        // Calculate total vote weight (stake weight + earned tokens)
        uint256 voteWeight = getUserVotingPower(msg.sender);
        require(voteWeight > 0, "No voting power");
        
        // Notify rewards contract about governance action
        string memory votingTypeStr = _votingType == VotingType.Dispute ? "dispute_vote" : 
                                     _votingType == VotingType.SkillVerification ? "skill_verification_vote" : "ask_athena_vote";
        _notifyRewardsContract(msg.sender, votingTypeStr, _options, msg.value);
        
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
            _voteOnDispute(_disputeId, _voteFor, _claimAddress, voteWeight);
        } else if (_votingType == VotingType.SkillVerification) {
            _voteOnSkillVerification(_disputeId, _voteFor, voteWeight);
        } else if (_votingType == VotingType.AskAthena) {
            _voteOnAskAthena(_disputeId, _voteFor, voteWeight);
        }
    }
    
    function _voteOnDispute(string memory _disputeId, bool _voteFor, address _claimAddress, uint256 voteWeight) internal {
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
        
        // Notify AthenaClient about the vote for fee distribution
        _notifyAthenaClient(_disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
    }
    
    function _voteOnSkillVerification(string memory _disputeId, bool _voteFor, uint256 voteWeight) internal {
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
    }
    
    function _voteOnAskAthena(string memory _disputeId, bool _voteFor, uint256 voteWeight) internal {
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
    
    // Send simplified cross-chain message to AthenaClient with only the winning side
    uint32 athenaClientChainEid = 40231; // Arbitrum Sepolia
    bytes memory payload = abi.encode("finalizeDispute", _disputeId, dispute.result);
    
    _lzSend(
        athenaClientChainEid,
        payload,
        _athenaClientOptions,
        MessagingFee(msg.value, 0),
        payable(msg.sender)
    );
    
    emit DisputeFinalized(_disputeId, dispute.result, dispute.votesFor, dispute.votesAgainst);
    emit CrossChainMessageSent("finalizeDispute", athenaClientChainEid, payload);
}
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteGovernanceNotification(
        address account,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (rewardsChainEid == 0) return 0;
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        MessagingFee memory msgFee = _quote(rewardsChainEid, payload, _options, false);
        return msgFee.nativeFee;
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
}