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
    function releaseDisputedFunds(string memory _jobId, address _winner, uint32 _winnerChainDomain, uint256 _amount) external;
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

contract NativeAthenaWithWorkingDisputeSettlement is 
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
    
    // Chain domain mappings for cross-chain dispute resolution (LayerZero EID → CCTP Domain)
    mapping(uint32 => uint32) public eidToCctpDomain;
    
    // Fixed disputed amount for current test (can be enhanced later)
    uint256 public constant DISPUTED_AMOUNT = 500000; // 0.5 USDC
    
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
    event DisputedFundsResolved(string indexed disputeId, address indexed winner, bool winningSide, uint32 targetDomain, uint256 amount);
    event ChainDomainMappingAdded(uint32 indexed eid, uint32 indexed cctpDomain);
    
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
        
        // Initialize chain domain mappings
        _initializeChainMappings();
    }
    
    function _initializeChainMappings() internal {
        // Based on your job ID format and CCTP domains:
        eidToCctpDomain[40232] = 2;  // OP Sepolia: EID 40232 → CCTP Domain 2
        eidToCctpDomain[40161] = 3;  // Arbitrum Sepolia: EID 40161 → CCTP Domain 3
        // Add more chains as needed
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
    
    /**
     * @notice ENHANCED: Handles BOTH fee distribution AND disputed funds cross-chain transfer
     * @dev This is the complete dispute settlement function
     */
    function processFeePayment(
        string memory _disputeId,
        address[] memory _recipients,
        address[] memory _claimAddresses,
        uint256[] memory _votingPowers,
        bool[] memory _voteDirections,
        bool _winningSide,
        uint256 _totalFees
    ) external {
        require(_recipients.length == _claimAddresses.length, "Array length mismatch");
        require(_totalFees <= accumulatedFees, "Insufficient accumulated fees");
        
        // STEP 1: Distribute fees to winning voters (existing working logic)
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
                        emit FeePaymentProcessed(_disputeId, _claimAddresses[i], voterShare);
                    }
                }
            }
        }
        
        // Update accumulated fees after distribution
        accumulatedFees -= _totalFees;
        
        // STEP 2: NEW - Handle disputed funds cross-chain settlement
        _handleDisputedFundsSettlement(_disputeId, _winningSide);
    }
    
    /**
     * @notice NEW: Handle disputed funds settlement cross-chain
     * @dev Determines winner and sends funds via NOWJC to target chain
     */
    function _handleDisputedFundsSettlement(string memory _disputeId, bool _winningSide) internal {
        // Get job details from NOWJC to determine winner and chain
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
        
        // Determine dispute winner based on voting result
        if (_winningSide) {
            // Job giver wins - typically means job giver was right
            winner = jobGiver;
        } else {
            // Selected applicant wins - typically means applicant was right
            winner = selectedApplicant;
        }
        
        if (winner != address(0)) {
            // Parse job ID to get winner's chain domain
            uint32 winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
            
            // Transfer USDC from this contract to NOWJC for disputed amount
            usdcToken.safeTransfer(address(nowjContract), DISPUTED_AMOUNT);
            
            // Call NOWJC to release disputed funds cross-chain
            nowjContract.releaseDisputedFunds(_disputeId, winner, winnerChainDomain, DISPUTED_AMOUNT);
            
            emit DisputedFundsResolved(_disputeId, winner, _winningSide, winnerChainDomain, DISPUTED_AMOUNT);
        }
    }
    
    /**
     * @notice Parse job ID to extract LayerZero EID and convert to CCTP domain
     * @dev Job ID format: "EID-SEQUENCE" (e.g., "40232-57")
     */
    function _parseJobIdForChainDomain(string memory _jobId) internal view returns (uint32) {
        bytes memory jobIdBytes = bytes(_jobId);
        uint256 dashPosition = 0;
        
        // Find the dash position
        for (uint256 i = 0; i < jobIdBytes.length; i++) {
            if (jobIdBytes[i] == "-") {
                dashPosition = i;
                break;
            }
        }
        
        if (dashPosition == 0) {
            // No dash found, return default domain (Arbitrum = 3)
            return 3;
        }
        
        // Extract EID part (before dash)
        bytes memory eidBytes = new bytes(dashPosition);
        for (uint256 i = 0; i < dashPosition; i++) {
            eidBytes[i] = jobIdBytes[i];
        }
        
        // Convert bytes to uint32 EID
        uint32 eid = _bytesToUint32(eidBytes);
        
        // Map EID to CCTP domain
        uint32 cctpDomain = eidToCctpDomain[eid];
        if (cctpDomain == 0) {
            // Unknown EID, default to native chain (Arbitrum = 3)
            return 3;
        }
        
        return cctpDomain;
    }
    
    /**
     * @notice Convert bytes to uint32
     */
    function _bytesToUint32(bytes memory _bytes) internal pure returns (uint32) {
        uint32 result = 0;
        for (uint256 i = 0; i < _bytes.length; i++) {
            if (_bytes[i] >= "0" && _bytes[i] <= "9") {
                result = result * 10 + uint32(uint8(_bytes[i]) - 48);
            }
        }
        return result;
    }
    
    // ==================== CHAIN DOMAIN MANAGEMENT ====================
    
    function addChainMapping(uint32 _eid, uint32 _cctpDomain) external onlyOwner {
        eidToCctpDomain[_eid] = _cctpDomain;
        emit ChainDomainMappingAdded(_eid, _cctpDomain);
    }
    
    function getChainDomainMapping(uint32 _eid) external view returns (uint32) {
        return eidToCctpDomain[_eid];
    }
    
    function parseJobIdForChainDomain(string memory _jobId) external view returns (uint32) {
        return _parseJobIdForChainDomain(_jobId);
    }
    
    // ==================== MESSAGE HANDLERS (EXISTING CODE UNCHANGED) ====================
    
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory /* oracleName */, uint256 fee, address disputeRaiser) external {
        genesis.setDispute(jobId, fee, disputeHash, disputeRaiser, fee);
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
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            return earnedTokens >= minTokensRequired;
        }
        return false;
    }
    
    function getUserVotingPower(address account) public view returns (uint256) {
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
        hasActiveStake = false;
        stakeAmount = 0;
        
        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            earnedTokens = nowjContract.getUserEarnedTokens(account);
        }
        
        totalVotingPower = earnedTokens;
        meetsVotingThreshold = canVote(account);
    }
    
    // ==================== VOTING FUNCTIONS (EXISTING CODE PRESERVED) ====================
    
    function vote(
        VotingType _votingType, 
        string memory _disputeId, 
        bool _voteFor, 
        address _claimAddress
    ) external {
        require(_claimAddress != address(0), "Claim address cannot be zero");
        
        uint256 voteWeight = getUserVotingPower(msg.sender);
        require(voteWeight > 0, "No voting power");
        
        if (_votingType == VotingType.Dispute) {
            genesis.addDisputeVoter(_disputeId, msg.sender, _claimAddress, voteWeight, _voteFor);
            _voteOnDispute(_disputeId, _voteFor, _claimAddress, voteWeight);
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
    
    function finalizeDispute(string memory _disputeId, bytes calldata _athenaClientOptions) external payable {
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        require(dispute.timeStamp > 0, "Dispute does not exist");
        require(!dispute.isFinalized, "Dispute already finalized");
        
        bool winningSide = dispute.votesFor > dispute.votesAgainst;
        genesis.finalizeDispute(_disputeId, winningSide);
        
        IOpenworkGenesis.VoterData[] memory allVoterData = genesis.getDisputeVoters(_disputeId);
        require(allVoterData.length > 0, "No voters found for this dispute");
        
        uint256 winningVoterCount = 0;
        for (uint256 i = 0; i < allVoterData.length; i++) {
            if (allVoterData[i].voteFor == winningSide) {
                winningVoterCount++;
            }
        }
        
        address[] memory winningVoters = new address[](winningVoterCount);
        address[] memory winningClaimAddresses = new address[](winningVoterCount);
        uint256[] memory winningVotingPowers = new uint256[](winningVoterCount);
        bool[] memory winningVoteDirections = new bool[](winningVoterCount);
        
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

    // ==================== UTILITY AND VIEW FUNCTIONS ====================
    
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
    
    function updateMinOracleMembers(uint256 _newMinMembers) external onlyOwner {
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
    
    function getEarnedTokensFromJob(address user) external view returns (uint256) {
        if (address(nowjContract) == address(0)) {
            return 0;
        }
        return nowjContract.getUserEarnedTokens(user);
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
    
    function hasVotedOnDispute(string memory _disputeId, address _user) external view returns (bool) {
        return genesis.hasUserVotedOnDispute(_disputeId, _user);
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
    
    receive() external payable {}
}