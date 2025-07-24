// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title OpenworkGenesisBack
 * @dev Back-end contract handling complex voter data operations and additional storage
 */
contract OpenworkGenesisBack {
    
    // ==================== STRUCTS ====================
    
    struct VoterData {
        address voter;
        address claimAddress;
        uint256 votingPower;
        bool voteFor;
    }

    // ==================== STATE VARIABLES ====================
    
    // IMPORTANT: These first state variables MUST match the front contract's layout for delegatecall
    // Back contract reference
    address public backContract;
    
    // Access control - matching front contract layout
    mapping(address => bool) public authorizedContracts;
    address public owner;
    
    // Voter data storage - the main purpose of this back contract
    mapping(string => VoterData[]) public disputeVoters;
    mapping(uint256 => VoterData[]) public skillVerificationVoters;
    mapping(uint256 => VoterData[]) public askAthenaVoters;
    mapping(string => mapping(address => address)) public disputeVoterClaimAddresses;
    
    // Additional complex mappings that were space-consuming
    mapping(string => mapping(address => bool)) private _hasVotedOnDispute;
    mapping(uint256 => mapping(address => bool)) private _hasVotedOnSkillApplication;
    mapping(uint256 => mapping(address => bool)) private _hasVotedOnAskAthena;
    
    // Extended voter tracking data
    mapping(address => mapping(string => bool)) public voterParticipatedInDispute;
    mapping(address => mapping(uint256 => bool)) public voterParticipatedInSkillVerification;
    mapping(address => mapping(uint256 => bool)) public voterParticipatedInAskAthena;
    
    // Historical voting data for analytics
    mapping(address => uint256) public totalDisputeVotes;
    mapping(address => uint256) public totalSkillVerificationVotes;
    mapping(address => uint256) public totalAskAthenaVotes;
    mapping(address => uint256) public totalVotingPowerUsed;
    
    // Dispute outcome tracking
    mapping(string => address[]) public disputeWinningVoters;
    mapping(string => address[]) public disputeLosingVoters;
    mapping(string => uint256) public disputeWinningVotingPower;
    mapping(string => uint256) public disputeLosingVotingPower;
    
    // Skill verification outcome tracking
    mapping(uint256 => address[]) public skillVerificationApprovedVoters;
    mapping(uint256 => address[]) public skillVerificationRejectedVoters;
    mapping(uint256 => uint256) public skillVerificationApprovedPower;
    mapping(uint256 => uint256) public skillVerificationRejectedPower;
    
    // Ask Athena outcome tracking
    mapping(uint256 => address[]) public askAthenaApprovedVoters;
    mapping(uint256 => address[]) public askAthenaRejectedVoters;
    mapping(uint256 => uint256) public askAthenaApprovedPower;
    mapping(uint256 => uint256) public askAthenaRejectedPower;
    
    // Reward distribution tracking
    mapping(string => mapping(address => uint256)) public disputeVoterRewards;
    mapping(uint256 => mapping(address => uint256)) public skillVerificationVoterRewards;
    mapping(uint256 => mapping(address => uint256)) public askAthenaVoterRewards;
    mapping(address => uint256) public totalVoterRewards;
    
    // Voting power delegation history
    mapping(address => address[]) public delegationHistory;
    mapping(address => mapping(address => uint256)) public delegationTimestamps;
    mapping(address => mapping(address => uint256)) public delegatedAmounts;
    
    // Staking history and analytics
    mapping(address => uint256[]) public stakingHistory;
    mapping(address => uint256[]) public stakingTimestamps;
    mapping(address => uint256) public totalStakingTime;
    mapping(address => uint256) public maxStakedAmount;
    
    // Governance participation metrics
    mapping(address => uint256) public governanceProposalsVoted;
    mapping(address => uint256) public governanceProposalsCreated;
    mapping(address => uint256) public lastGovernanceActivity;
    
    // Oracle performance metrics
    mapping(string => uint256) public oracleDisputesHandled;
    mapping(string => uint256) public oracleSkillVerificationsHandled;
    mapping(string => uint256) public oracleAskAthenaHandled;
    mapping(string => uint256) public oracleSuccessfulOutcomes;
    mapping(string => mapping(address => uint256)) public memberContributions;
    
    // Platform analytics
    mapping(uint256 => uint256) public dailyVotingActivity; // timestamp/day => count
    mapping(uint256 => uint256) public dailyStakingActivity;
    mapping(uint256 => uint256) public dailyGovernanceActivity;
    mapping(address => uint256[]) public userActivityTimestamps;
    
    // Emergency and recovery data
    mapping(address => bool) public emergencyVoters;
    mapping(string => bool) public emergencyDisputes;
    mapping(uint256 => bool) public emergencySkillApplications;
    mapping(uint256 => bool) public emergencyAskAthenaApplications;
    
    // ==================== EVENTS ====================
    
    event FrontContractSet(address indexed frontContract);
    event VoterDataAdded(address indexed voter, string indexed disputeId, uint256 votingPower);
    event VoterRewardDistributed(address indexed voter, uint256 amount);
    event EmergencyActionTaken(address indexed actor, string actionType);

    // ==================== MODIFIERS ====================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyFrontContract() {
        require(msg.sender == backContract, "Only front contract"); // Use backContract which stores front address
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner, "Not authorized"); // Use front contract's auth mapping
        _;
    }

    // ==================== CONSTRUCTOR ====================
    
    constructor(address _frontContract) {
        owner = msg.sender;
        backContract = _frontContract; // Store front contract address in backContract slot
    }

    // ==================== FRONT CONTRACT MANAGEMENT ====================
    
    function setFrontContract(address _frontContract) external onlyOwner {
        backContract = _frontContract; // Store in backContract slot for consistency
        emit FrontContractSet(_frontContract);
    }

    // ==================== VOTER DATA SETTERS ====================

    function addDisputeVoter(
        string memory disputeId,
        address voter,
        address claimAddress,
        uint256 votingPower,
        bool voteFor
    ) public onlyAuthorized {
        disputeVoters[disputeId].push(VoterData({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
        
        disputeVoterClaimAddresses[disputeId][voter] = claimAddress;
        _hasVotedOnDispute[disputeId][voter] = true;
        
        // Update analytics
        voterParticipatedInDispute[voter][disputeId] = true;
        totalDisputeVotes[voter]++;
        totalVotingPowerUsed[voter] += votingPower;
        
        // Track daily activity
        uint256 today = block.timestamp / 86400;
        dailyVotingActivity[today]++;
        userActivityTimestamps[voter].push(block.timestamp);
        
        // Update outcome tracking based on vote
        if (voteFor) {
            disputeWinningVoters[disputeId].push(voter);
            disputeWinningVotingPower[disputeId] += votingPower;
        } else {
            disputeLosingVoters[disputeId].push(voter);
            disputeLosingVotingPower[disputeId] += votingPower;
        }
        
        emit VoterDataAdded(voter, disputeId, votingPower);
    }

    function addSkillVerificationVoter(
        uint256 applicationId,
        address voter,
        address claimAddress,
        uint256 votingPower,
        bool voteFor
    ) public onlyAuthorized {
        skillVerificationVoters[applicationId].push(VoterData({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
        
        _hasVotedOnSkillApplication[applicationId][voter] = true;
        
        // Update analytics
        voterParticipatedInSkillVerification[voter][applicationId] = true;
        totalSkillVerificationVotes[voter]++;
        totalVotingPowerUsed[voter] += votingPower;
        
        // Track daily activity
        uint256 today = block.timestamp / 86400;
        dailyVotingActivity[today]++;
        userActivityTimestamps[voter].push(block.timestamp);
        
        // Update outcome tracking based on vote
        if (voteFor) {
            skillVerificationApprovedVoters[applicationId].push(voter);
            skillVerificationApprovedPower[applicationId] += votingPower;
        } else {
            skillVerificationRejectedVoters[applicationId].push(voter);
            skillVerificationRejectedPower[applicationId] += votingPower;
        }
    }

    function addAskAthenaVoter(
        uint256 athenaId,
        address voter,
        address claimAddress,
        uint256 votingPower,
        bool voteFor
    ) public onlyAuthorized {
        askAthenaVoters[athenaId].push(VoterData({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
        
        _hasVotedOnAskAthena[athenaId][voter] = true;
        
        // Update analytics
        voterParticipatedInAskAthena[voter][athenaId] = true;
        totalAskAthenaVotes[voter]++;
        totalVotingPowerUsed[voter] += votingPower;
        
        // Track daily activity
        uint256 today = block.timestamp / 86400;
        dailyVotingActivity[today]++;
        userActivityTimestamps[voter].push(block.timestamp);
        
        // Update outcome tracking based on vote
        if (voteFor) {
            askAthenaApprovedVoters[athenaId].push(voter);
            askAthenaApprovedPower[athenaId] += votingPower;
        } else {
            askAthenaRejectedVoters[athenaId].push(voter);
            askAthenaRejectedPower[athenaId] += votingPower;
        }
    }

    // ==================== REWARD DISTRIBUTION FUNCTIONS ====================

    function distributeDisputeRewards(
        string memory disputeId,
        address[] memory winners,
        uint256[] memory rewards
    ) external onlyAuthorized {
        require(winners.length == rewards.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < winners.length; i++) {
            disputeVoterRewards[disputeId][winners[i]] = rewards[i];
            totalVoterRewards[winners[i]] += rewards[i];
            emit VoterRewardDistributed(winners[i], rewards[i]);
        }
    }

    function distributeSkillVerificationRewards(
        uint256 applicationId,
        address[] memory winners,
        uint256[] memory rewards
    ) external onlyAuthorized {
        require(winners.length == rewards.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < winners.length; i++) {
            skillVerificationVoterRewards[applicationId][winners[i]] = rewards[i];
            totalVoterRewards[winners[i]] += rewards[i];
            emit VoterRewardDistributed(winners[i], rewards[i]);
        }
    }

    function distributeAskAthenaRewards(
        uint256 athenaId,
        address[] memory winners,
        uint256[] memory rewards
    ) external onlyAuthorized {
        require(winners.length == rewards.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < winners.length; i++) {
            askAthenaVoterRewards[athenaId][winners[i]] = rewards[i];
            totalVoterRewards[winners[i]] += rewards[i];
            emit VoterRewardDistributed(winners[i], rewards[i]);
        }
    }

    // ==================== DELEGATION TRACKING FUNCTIONS ====================

    function recordDelegation(
        address delegator,
        address delegatee,
        uint256 amount
    ) external onlyAuthorized {
        delegationHistory[delegator].push(delegatee);
        delegationTimestamps[delegator][delegatee] = block.timestamp;
        delegatedAmounts[delegator][delegatee] = amount;
    }

    function recordStakingActivity(
        address staker,
        uint256 amount,
        bool isStaking
    ) external onlyAuthorized {
        if (isStaking) {
            stakingHistory[staker].push(amount);
            stakingTimestamps[staker].push(block.timestamp);
            
            if (amount > maxStakedAmount[staker]) {
                maxStakedAmount[staker] = amount;
            }
            
            // Track daily activity
            uint256 today = block.timestamp / 86400;
            dailyStakingActivity[today]++;
        }
        
        // Update total staking time (simplified calculation)
        totalStakingTime[staker] = block.timestamp;
    }

    // ==================== GOVERNANCE TRACKING FUNCTIONS ====================

    function recordGovernanceVote(address voter, uint256 /* proposalId */) external onlyAuthorized {
        governanceProposalsVoted[voter]++;
        lastGovernanceActivity[voter] = block.timestamp;
        
        uint256 today = block.timestamp / 86400;
        dailyGovernanceActivity[today]++;
        userActivityTimestamps[voter].push(block.timestamp);
    }

    function recordGovernanceProposal(address creator, uint256 /* proposalId */) external onlyAuthorized {
        governanceProposalsCreated[creator]++;
        lastGovernanceActivity[creator] = block.timestamp;
        
        uint256 today = block.timestamp / 86400;
        dailyGovernanceActivity[today]++;
        userActivityTimestamps[creator].push(block.timestamp);
    }

    // ==================== ORACLE PERFORMANCE TRACKING ====================

    function updateOracleMetrics(
        string memory oracleName,
        string memory metricType,
        address member,
        bool successful
    ) external onlyAuthorized {
        if (keccak256(bytes(metricType)) == keccak256(bytes("dispute"))) {
            oracleDisputesHandled[oracleName]++;
        } else if (keccak256(bytes(metricType)) == keccak256(bytes("skill"))) {
            oracleSkillVerificationsHandled[oracleName]++;
        } else if (keccak256(bytes(metricType)) == keccak256(bytes("athena"))) {
            oracleAskAthenaHandled[oracleName]++;
        }
        
        if (successful) {
            oracleSuccessfulOutcomes[oracleName]++;
        }
        
        memberContributions[oracleName][member]++;
    }

    // ==================== EMERGENCY FUNCTIONS ====================

    function setEmergencyVoter(address voter, bool isEmergency) external onlyOwner {
        emergencyVoters[voter] = isEmergency;
        emit EmergencyActionTaken(voter, "emergency_voter_status");
    }

    function setEmergencyDispute(string memory disputeId, bool isEmergency) external onlyOwner {
        emergencyDisputes[disputeId] = isEmergency;
        emit EmergencyActionTaken(msg.sender, "emergency_dispute");
    }

    function setEmergencySkillApplication(uint256 applicationId, bool isEmergency) external onlyOwner {
        emergencySkillApplications[applicationId] = isEmergency;
        emit EmergencyActionTaken(msg.sender, "emergency_skill_app");
    }

    function setEmergencyAskAthenaApplication(uint256 athenaId, bool isEmergency) external onlyOwner {
        emergencyAskAthenaApplications[athenaId] = isEmergency;
        emit EmergencyActionTaken(msg.sender, "emergency_athena_app");
    }

    // ==================== GETTER FUNCTIONS ====================

    function getDisputeVoters(string memory disputeId) external view returns (VoterData[] memory) {
        return disputeVoters[disputeId];
    }

    function getSkillVerificationVoters(uint256 applicationId) external view returns (VoterData[] memory) {
        return skillVerificationVoters[applicationId];
    }

    function getAskAthenaVoters(uint256 athenaId) external view returns (VoterData[] memory) {
        return askAthenaVoters[athenaId];
    }

    function getDisputeVoterClaimAddress(string memory disputeId, address voter) external view returns (address) {
        return disputeVoterClaimAddresses[disputeId][voter];
    }

    function getDisputeVoterCount(string memory disputeId) external view returns (uint256) {
        return disputeVoters[disputeId].length;
    }

    function getSkillVerificationVoterCount(uint256 applicationId) external view returns (uint256) {
        return skillVerificationVoters[applicationId].length;
    }

    function getAskAthenaVoterCount(uint256 athenaId) external view returns (uint256) {
        return askAthenaVoters[athenaId].length;
    }

    function hasVotedOnDispute(string memory disputeId, address voter) external view returns (bool) {
        return _hasVotedOnDispute[disputeId][voter];
    }

    function hasVotedOnSkillApplication(uint256 applicationId, address voter) external view returns (bool) {
        return _hasVotedOnSkillApplication[applicationId][voter];
    }

    function hasVotedOnAskAthena(uint256 athenaId, address voter) external view returns (bool) {
        return _hasVotedOnAskAthena[athenaId][voter];
    }

    // ==================== ANALYTICS GETTERS ====================

    function getVoterAnalytics(address voter) external view returns (
        uint256 totalDisputes,
        uint256 totalSkillVerifications,
        uint256 totalAskAthenas,
        uint256 totalPowerUsed,
        uint256 totalRewards
    ) {
        return (
            totalDisputeVotes[voter],
            totalSkillVerificationVotes[voter],
            totalAskAthenaVotes[voter],
            totalVotingPowerUsed[voter],
            totalVoterRewards[voter]
        );
    }

    function getDisputeOutcome(string memory disputeId) external view returns (
        address[] memory winningVoters,
        address[] memory losingVoters,
        uint256 winningPower,
        uint256 losingPower
    ) {
        return (
            disputeWinningVoters[disputeId],
            disputeLosingVoters[disputeId],
            disputeWinningVotingPower[disputeId],
            disputeLosingVotingPower[disputeId]
        );
    }

    function getSkillVerificationOutcome(uint256 applicationId) external view returns (
        address[] memory approvedVoters,
        address[] memory rejectedVoters,
        uint256 approvedPower,
        uint256 rejectedPower
    ) {
        return (
            skillVerificationApprovedVoters[applicationId],
            skillVerificationRejectedVoters[applicationId],
            skillVerificationApprovedPower[applicationId],
            skillVerificationRejectedPower[applicationId]
        );
    }

    function getAskAthenaOutcome(uint256 athenaId) external view returns (
        address[] memory approvedVoters,
        address[] memory rejectedVoters,
        uint256 approvedPower,
        uint256 rejectedPower
    ) {
        return (
            askAthenaApprovedVoters[athenaId],
            askAthenaRejectedVoters[athenaId],
            askAthenaApprovedPower[athenaId],
            askAthenaRejectedPower[athenaId]
        );
    }

    function getDailyActivity(uint256 day) external view returns (
        uint256 votingActivity,
        uint256 stakingActivity,
        uint256 governanceActivity
    ) {
        return (
            dailyVotingActivity[day],
            dailyStakingActivity[day],
            dailyGovernanceActivity[day]
        );
    }

    function getOraclePerformance(string memory oracleName) external view returns (
        uint256 disputesHandled,
        uint256 skillVerificationsHandled,
        uint256 askAthenaHandled,
        uint256 successfulOutcomes
    ) {
        return (
            oracleDisputesHandled[oracleName],
            oracleSkillVerificationsHandled[oracleName],
            oracleAskAthenaHandled[oracleName],
            oracleSuccessfulOutcomes[oracleName]
        );
    }

    function getUserActivityTimestamps(address user) external view returns (uint256[] memory) {
        return userActivityTimestamps[user];
    }

    function getDelegationHistory(address delegator) external view returns (address[] memory) {
        return delegationHistory[delegator];
    }

    function getStakingHistory(address staker) external view returns (
        uint256[] memory amounts,
        uint256[] memory timestamps,
        uint256 totalTime,
        uint256 maxAmount
    ) {
        return (
            stakingHistory[staker],
            stakingTimestamps[staker],
            totalStakingTime[staker],
            maxStakedAmount[staker]
        );
    }

    function getGovernanceMetrics(address user) external view returns (
        uint256 proposalsVoted,
        uint256 proposalsCreated,
        uint256 lastActivity
    ) {
        return (
            governanceProposalsVoted[user],
            governanceProposalsCreated[user],
            lastGovernanceActivity[user]
        );
    }

    // ==================== EMERGENCY GETTERS ====================

    function isEmergencyVoter(address voter) external view returns (bool) {
        return emergencyVoters[voter];
    }

    function isEmergencyDispute(string memory disputeId) external view returns (bool) {
        return emergencyDisputes[disputeId];
    }

    function isEmergencySkillApplication(uint256 applicationId) external view returns (bool) {
        return emergencySkillApplications[applicationId];
    }

    function isEmergencyAskAthenaApplication(uint256 athenaId) external view returns (bool) {
        return emergencyAskAthenaApplications[athenaId];
    }

    // ==================== BATCH OPERATIONS ====================

    function batchAddDisputeVoters(
        string memory disputeId,
        address[] memory voters,
        address[] memory claimAddresses,
        uint256[] memory votingPowers,
        bool[] memory votesFor
    ) external onlyAuthorized {
        require(
            voters.length == claimAddresses.length &&
            voters.length == votingPowers.length &&
            voters.length == votesFor.length,
            "Arrays length mismatch"
        );

        for (uint256 i = 0; i < voters.length; i++) {
            addDisputeVoter(disputeId, voters[i], claimAddresses[i], votingPowers[i], votesFor[i]);
        }
    }

    function batchAddSkillVerificationVoters(
        uint256 applicationId,
        address[] memory voters,
        address[] memory claimAddresses,
        uint256[] memory votingPowers,
        bool[] memory votesFor
    ) external onlyAuthorized {
        require(
            voters.length == claimAddresses.length &&
            voters.length == votingPowers.length &&
            voters.length == votesFor.length,
            "Arrays length mismatch"
        );

        for (uint256 i = 0; i < voters.length; i++) {
            addSkillVerificationVoter(applicationId, voters[i], claimAddresses[i], votingPowers[i], votesFor[i]);
        }
    }

    function batchAddAskAthenaVoters(
        uint256 athenaId,
        address[] memory voters,
        address[] memory claimAddresses,
        uint256[] memory votingPowers,
        bool[] memory votesFor
    ) external onlyAuthorized {
        require(
            voters.length == claimAddresses.length &&
            voters.length == votingPowers.length &&
            voters.length == votesFor.length,
            "Arrays length mismatch"
        );

        for (uint256 i = 0; i < voters.length; i++) {
            addAskAthenaVoter(athenaId, voters[i], claimAddresses[i], votingPowers[i], votesFor[i]);
        }
    }
}