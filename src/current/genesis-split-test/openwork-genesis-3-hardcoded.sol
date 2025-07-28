// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title OpenworkGenesis
 * @dev Simple storage contract for all platform data - no complex logic, just store and retrieve
 */
contract OpenworkGenesis {
    
    // ==================== ENUMS ====================
    
    enum JobStatus {
        Open,
        InProgress,
        Completed,
        Cancelled
    }

    // ==================== STRUCTS ====================
    
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

    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 durationMinutes;
        bool isActive;
    }

    struct Earner {
        address earnerAddress;
        uint256 balance;
        uint256 total_governance_actions;
    }

    struct ContractInfo {
        address contractAddress;
        uint256 chainId;
        string name;
    }

    // ==================== STATE VARIABLES ====================
    
    // Access control
    mapping(address => bool) public authorizedContracts;
    address public owner;
    
    // Profile data
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(address => address) public userReferrers;
    mapping(address => uint256) public userTotalClaimedTokens;
    
    // Job data
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public totalPlatformPayments;
    uint256 public jobCounter;
    string[] public allJobIds;
    mapping(address => string[]) public jobsByPoster;
    
    // Oracle data
    mapping(string => Oracle) public oracles;
    mapping(string => mapping(address => uint256)) public memberStakeAmount;
    mapping(string => mapping(address => uint256)) public skillVerificationDates;
    
    // Dispute/Voting data
    mapping(uint256 => SkillVerificationApplication) public skillApplications;
    mapping(uint256 => AskAthenaApplication) public askAthenaApplications;
    mapping(string => Dispute) public disputes;
    mapping(string => mapping(address => bool)) public hasVotedOnDispute;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnSkillApplication;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnAskAthena;
    uint256 public applicationCounter;
    uint256 public askAthenaCounter;
    
    // Voter data storage
    mapping(string => VoterData[]) public disputeVoters;
    mapping(uint256 => VoterData[]) public skillVerificationVoters;
    mapping(uint256 => VoterData[]) public askAthenaVoters;
    mapping(string => mapping(address => address)) public disputeVoterClaimAddresses;
    
    // DAO data storage
    mapping(address => Stake) public stakes;
    mapping(address => Earner) public earners;
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotingPower;
    mapping(address => bool) public isStaker;
    address[] public allStakers;
    uint256[] public proposalIds;
    
    // Contract registry data
    mapping(string => ContractInfo) public contracts;
    string[] public contractNames;
    
    // Final rewards data
    mapping(address => uint256) public userTotalOWTokens;
    mapping(address => uint256) public userGovernanceActions;

    // ==================== EVENTS ====================
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ContractUpdated(string indexed name, address indexed contractAddress, uint256 indexed chainId);
    
    // Data update events
    event ProfileSet(address indexed user, string ipfsHash, address indexed referrer);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event JobSet(string indexed jobId, address indexed jobGiver);
    event JobAppSet(string indexed jobId, uint256 indexed appId, address indexed applicant);
    event JobStatusUpdated(string indexed jobId, uint8 status);
    event JobSelectedUpdated(string indexed jobId, address indexed selectedApplicant, uint256 appId);
    event JobMilestoneUpdated(string indexed jobId, uint256 milestone);
    event JobMilestoneAdded(string indexed jobId, string description, uint256 amount);
    event WorkSubmitted(string indexed jobId, string submissionHash);
    event PaymentUpdated(string indexed jobId, uint256 amount, uint256 totalPaid);
    event RatingSet(string indexed jobId, address indexed user, uint256 rating);
    event OracleSet(string indexed name, uint256 memberCount);
    event OracleMemberAdded(string indexed oracleName, address indexed member);
    event OracleMemberRemoved(string indexed oracleName, address indexed member);
    event SkillAdded(string indexed oracleName, address indexed user);
    event StakeAmountSet(string indexed oracleName, address indexed member, uint256 amount);
    event DisputeSet(string indexed jobId, address indexed raiser, uint256 fees);
    event DisputeVotesUpdated(string indexed disputeId, uint256 votesFor, uint256 votesAgainst);
    event DisputeFinalized(string indexed disputeId, bool result);
    event DisputeVoteSet(string indexed disputeId, address indexed voter);
    event SkillAppSet(uint256 indexed appId, address indexed applicant, string targetOracle);
    event SkillVotesUpdated(uint256 indexed appId, uint256 votesFor, uint256 votesAgainst);
    event SkillVoteSet(uint256 indexed appId, address indexed voter);
    event AthenaAppSet(uint256 indexed athenaId, address indexed applicant, string targetOracle);
    event AthenaVotesUpdated(uint256 indexed athenaId, uint256 votesFor, uint256 votesAgainst);
    event AthenaVoteSet(uint256 indexed athenaId, address indexed voter);
    event DisputeVoterAdded(string indexed disputeId, address indexed voter, address claimAddr);
    event SkillVoterAdded(uint256 indexed appId, address indexed voter, address claimAddr);
    event AthenaVoterAdded(uint256 indexed athenaId, address indexed voter, address claimAddr);
    event StakeUpdated(address indexed staker, uint256 amount, bool isActive);
    event EarnerUpdated(address indexed earner, uint256 balance, uint256 govActions);
    event DelegateSet(address indexed delegator, address indexed delegatee);
    event DelegatePowerUpdated(address indexed delegatee, uint256 power);
    event ProposalAdded(uint256 indexed proposalId);
    event StakerRemoved(address indexed staker);
    event TokensSet(address indexed user, uint256 tokens);
    event GovernanceActionsSet(address indexed user, uint256 actions);
    event GovernanceActionsIncremented(address indexed user, uint256 newTotal);
    event ClaimDataUpdated(address indexed user, uint256 claimedAmount);

    // ==================== MODIFIERS ====================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    
    constructor() {
        owner = address(0xfD08836eeE6242092a9c869237a8d122275b024A);
    }

    // ==================== ACCESS CONTROL ====================
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }

    // ==================== PROFILE SETTERS ====================
    
    function setProfile(
        address user,
        string memory ipfsHash,
        address referrer
    ) external onlyAuthorized {
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer,
            portfolioHashes: new string[](0)
        });
        hasProfile[user] = true;
        if (referrer != address(0)) {
            userReferrers[user] = referrer;
        }
        emit ProfileSet(user, ipfsHash, referrer);
    }
    
    function addPortfolio(address user, string memory portfolioHash) external onlyAuthorized {
        profiles[user].portfolioHashes.push(portfolioHash);
        emit PortfolioAdded(user, portfolioHash);
    }

    // ==================== JOB SETTERS ====================
    
    function setJob(
        string memory jobId,
        address jobGiver,
        string memory jobDetailHash,
        string[] memory descriptions,
        uint256[] memory amounts
    ) external onlyAuthorized {
        jobCounter++;
        allJobIds.push(jobId);
        jobsByPoster[jobGiver].push(jobId);
        
        Job storage newJob = jobs[jobId];
        newJob.id = jobId;
        newJob.jobGiver = jobGiver;
        newJob.jobDetailHash = jobDetailHash;
        newJob.status = JobStatus.Open;
        newJob.totalPaid = 0;
        newJob.currentMilestone = 0;
        newJob.selectedApplicant = address(0);
        newJob.selectedApplicationId = 0;
        
        for (uint i = 0; i < descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: descriptions[i],
                amount: amounts[i]
            }));
        }
        emit JobSet(jobId, jobGiver);
    }
    
    function addJobApplicant(string memory jobId, address applicant) external onlyAuthorized {
        jobs[jobId].applicants.push(applicant);
    }
    
    function setJobApplication(
        string memory jobId,
        uint256 applicationId,
        address applicant,
        string memory applicationHash,
        string[] memory descriptions,
        uint256[] memory amounts
    ) external onlyAuthorized {
        if (applicationId > jobApplicationCounter[jobId]) {
            jobApplicationCounter[jobId] = applicationId;
        }
        
        Application storage newApplication = jobApplications[jobId][applicationId];
        newApplication.id = applicationId;
        newApplication.jobId = jobId;
        newApplication.applicant = applicant;
        newApplication.applicationHash = applicationHash;
        
        // Clear existing milestones
        delete newApplication.proposedMilestones;
        for (uint i = 0; i < descriptions.length; i++) {
            newApplication.proposedMilestones.push(MilestonePayment({
                descriptionHash: descriptions[i],
                amount: amounts[i]
            }));
        }
        emit JobAppSet(jobId, applicationId, applicant);
    }
    
    function updateJobStatus(string memory jobId, JobStatus status) external onlyAuthorized {
        jobs[jobId].status = status;
        emit JobStatusUpdated(jobId, uint8(status));
    }
    
    function setJobSelectedApplicant(string memory jobId, address applicant, uint256 applicationId) external onlyAuthorized {
        jobs[jobId].selectedApplicant = applicant;
        jobs[jobId].selectedApplicationId = applicationId;
        emit JobSelectedUpdated(jobId, applicant, applicationId);
    }
    
    function setJobCurrentMilestone(string memory jobId, uint256 milestone) external onlyAuthorized {
        jobs[jobId].currentMilestone = milestone;
        emit JobMilestoneUpdated(jobId, milestone);
    }
    
    function addJobFinalMilestone(string memory jobId, string memory description, uint256 amount) external onlyAuthorized {
        jobs[jobId].finalMilestones.push(MilestonePayment({
            descriptionHash: description,
            amount: amount
        }));
        emit JobMilestoneAdded(jobId, description, amount);
    }
    
    function addWorkSubmission(string memory jobId, string memory submissionHash) external onlyAuthorized {
        jobs[jobId].workSubmissions.push(submissionHash);
        emit WorkSubmitted(jobId, submissionHash);
    }
    
    function updateJobTotalPaid(string memory jobId, uint256 amount) external onlyAuthorized {
        jobs[jobId].totalPaid += amount;
        totalPlatformPayments += amount;
        emit PaymentUpdated(jobId, amount, jobs[jobId].totalPaid);
    }
    
    function setJobRating(string memory jobId, address user, uint256 rating) external onlyAuthorized {
        jobRatings[jobId][user] = rating;
        userRatings[user].push(rating);
        emit RatingSet(jobId, user, rating);
    }

    // ==================== ORACLE SETTERS ====================
    
    function setOracle(
        string memory name,
        address[] memory members,
        string memory shortDescription,
        string memory hashOfDetails,
        address[] memory skillVerifiedAddresses
    ) external onlyAuthorized {
        oracles[name] = Oracle({
            name: name,
            members: members,
            shortDescription: shortDescription,
            hashOfDetails: hashOfDetails,
            skillVerifiedAddresses: skillVerifiedAddresses
        });
        emit OracleSet(name, members.length);
    }
    
    function addOracleMember(string memory oracleName, address member) external onlyAuthorized {
        oracles[oracleName].members.push(member);
        emit OracleMemberAdded(oracleName, member);
    }
    
    function removeOracleMember(string memory oracleName, address memberToRemove) external onlyAuthorized {
        address[] storage members = oracles[oracleName].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == memberToRemove) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
        emit OracleMemberRemoved(oracleName, memberToRemove);
    }
    
    function addSkillVerifiedAddress(string memory oracleName, address user) external onlyAuthorized {
        oracles[oracleName].skillVerifiedAddresses.push(user);
        skillVerificationDates[oracleName][user] = block.timestamp;
        emit SkillAdded(oracleName, user);
    }
    
    function setMemberStakeAmount(string memory oracleName, address member, uint256 amount) external onlyAuthorized {
        memberStakeAmount[oracleName][member] = amount;
        emit StakeAmountSet(oracleName, member, amount);
    }

    // ==================== DISPUTE/VOTING SETTERS ====================
    
    function setDispute(
        string memory jobId,
        uint256 disputedAmount,
        string memory hash,
        address disputeRaiser,
        uint256 fees
    ) external onlyAuthorized {
        disputes[jobId] = Dispute({
            jobId: jobId,
            disputedAmount: disputedAmount,
            hash: hash,
            disputeRaiserAddress: disputeRaiser,
            votesFor: 0,
            votesAgainst: 0,
            result: false,
            isVotingActive: true,
            isFinalized: false,
            timeStamp: block.timestamp,
            fees: fees
        });
    }
    
    function updateDisputeVotes(string memory disputeId, uint256 votesFor, uint256 votesAgainst) external onlyAuthorized {
        disputes[disputeId].votesFor = votesFor;
        disputes[disputeId].votesAgainst = votesAgainst;
    }
    
    function finalizeDispute(string memory disputeId, bool result) external onlyAuthorized {
        disputes[disputeId].isVotingActive = false;
        disputes[disputeId].isFinalized = true;
        disputes[disputeId].result = result;
    }
    
    function setDisputeVote(string memory disputeId, address voter) external onlyAuthorized {
        hasVotedOnDispute[disputeId][voter] = true;
    }
    
    function setSkillApplication(
        uint256 applicationId,
        address applicant,
        string memory applicationHash,
        uint256 feeAmount,
        string memory targetOracleName
    ) external onlyAuthorized {
        if (applicationId >= applicationCounter) {
            applicationCounter = applicationId + 1;
        }
        skillApplications[applicationId] = SkillVerificationApplication({
            applicant: applicant,
            applicationHash: applicationHash,
            feeAmount: feeAmount,
            targetOracleName: targetOracleName,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
    }
    
    function updateSkillApplicationVotes(uint256 applicationId, uint256 votesFor, uint256 votesAgainst) external onlyAuthorized {
        skillApplications[applicationId].votesFor = votesFor;
        skillApplications[applicationId].votesAgainst = votesAgainst;
    }
    
    function setSkillApplicationVote(uint256 applicationId, address voter) external onlyAuthorized {
        hasVotedOnSkillApplication[applicationId][voter] = true;
    }
    
    function setAskAthenaApplication(
        uint256 athenaId,
        address applicant,
        string memory description,
        string memory hash,
        string memory targetOracle,
        string memory fees
    ) external onlyAuthorized {
        if (athenaId >= askAthenaCounter) {
            askAthenaCounter = athenaId + 1;
        }
        askAthenaApplications[athenaId] = AskAthenaApplication({
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
    }
    
    function updateAskAthenaVotes(uint256 athenaId, uint256 votesFor, uint256 votesAgainst) external onlyAuthorized {
        askAthenaApplications[athenaId].votesFor = votesFor;
        askAthenaApplications[athenaId].votesAgainst = votesAgainst;
    }
    
    function setAskAthenaVote(uint256 athenaId, address voter) external onlyAuthorized {
        hasVotedOnAskAthena[athenaId][voter] = true;
    }

    // ==================== VOTER DATA SETTERS ====================

    function addDisputeVoter(
        string memory disputeId,
        address voter,
        address claimAddress,
        uint256 votingPower,
        bool voteFor
    ) external onlyAuthorized {
        disputeVoters[disputeId].push(VoterData({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
        disputeVoterClaimAddresses[disputeId][voter] = claimAddress;
    }

    function addSkillVerificationVoter(
        uint256 applicationId,
        address voter,
        address claimAddress,
        uint256 votingPower,
        bool voteFor
    ) external onlyAuthorized {
        skillVerificationVoters[applicationId].push(VoterData({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
    }

    function addAskAthenaVoter(
        uint256 athenaId,
        address voter,
        address claimAddress,
        uint256 votingPower,
        bool voteFor
    ) external onlyAuthorized {
        askAthenaVoters[athenaId].push(VoterData({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
    }

    // ==================== DAO DATA SETTERS ====================

    function setStake(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external onlyAuthorized {
        stakes[staker] = Stake({
            amount: amount,
            unlockTime: unlockTime,
            durationMinutes: durationMinutes,
            isActive: isActive
        });
        
        // Update staker tracking
        if (isActive && !isStaker[staker]) {
            allStakers.push(staker);
            isStaker[staker] = true;
        } else if (!isActive && isStaker[staker]) {
            isStaker[staker] = false;
        }
    }

    function setEarner(
        address earnerAddress,
        uint256 balance,
        uint256 governanceActions
    ) external onlyAuthorized {
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            total_governance_actions: governanceActions
        });
    }

    function setDelegate(address delegator, address delegatee) external onlyAuthorized {
        delegates[delegator] = delegatee;
    }

    function setDelegatedVotingPower(address delegatee, uint256 power) external onlyAuthorized {
        delegatedVotingPower[delegatee] = power;
    }

    function updateDelegatedVotingPower(address delegatee, uint256 powerChange, bool increase) external onlyAuthorized {
        if (increase) {
            delegatedVotingPower[delegatee] += powerChange;
        } else {
            if (delegatedVotingPower[delegatee] >= powerChange) {
                delegatedVotingPower[delegatee] -= powerChange;
            } else {
                delegatedVotingPower[delegatee] = 0;
            }
        }
    }

    function addProposalId(uint256 proposalId) external onlyAuthorized {
        proposalIds.push(proposalId);
    }

    function removeStaker(address staker) external onlyAuthorized {
        if (isStaker[staker]) {
            isStaker[staker] = false;
            // Note: We don't remove from allStakers array to preserve history
            // Just mark as inactive in the stakes mapping
            stakes[staker].isActive = false;
        }
    }

    // ==================== CONTRACT REGISTRY SETTERS ====================

    function setContract(
        string memory name,
        address contractAddress,
        uint256 chainId
    ) external onlyAuthorized {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(contractAddress != address(0), "Invalid address");
        
        // If new contract, add to names array
        if (bytes(contracts[name].name).length == 0) {
            contractNames.push(name);
        }
        
        contracts[name] = ContractInfo({
            contractAddress: contractAddress,
            chainId: chainId,
            name: name
        });
        
        emit ContractUpdated(name, contractAddress, chainId);
    }

    function removeContract(string memory name) external onlyAuthorized {
        require(bytes(contracts[name].name).length > 0, "Contract does not exist");
        
        // Remove from names array
        for (uint256 i = 0; i < contractNames.length; i++) {
            if (keccak256(bytes(contractNames[i])) == keccak256(bytes(name))) {
                contractNames[i] = contractNames[contractNames.length - 1];
                contractNames.pop();
                break;
            }
        }
        
        delete contracts[name];
    }

    // ==================== REWARDS SETTERS ====================
    
    function setUserTotalOWTokens(address user, uint256 tokens) external onlyAuthorized {
        userTotalOWTokens[user] = tokens;
    }

    function setUserGovernanceActions(address user, uint256 actions) external onlyAuthorized {
        userGovernanceActions[user] = actions;
    }

    function incrementUserGovernanceActions(address user) external onlyAuthorized {
        userGovernanceActions[user]++;
    }

    function updateUserClaimData(address user, uint256 claimedAmount) external onlyAuthorized {
        userTotalClaimedTokens[user] += claimedAmount;
    }

    // ==================== GETTERS ====================
    
    // Profile getters
    function getProfile(address user) external view returns (Profile memory) {
        return profiles[user];
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    // Job getters
    function getJob(string memory jobId) external view returns (Job memory) {
        return jobs[jobId];
    }
    
    function getJobApplication(string memory jobId, uint256 applicationId) external view returns (Application memory) {
        return jobApplications[jobId][applicationId];
    }
    
    function getJobCount() external view returns (uint256) {
        return jobCounter;
    }
    
    function getAllJobIds() external view returns (string[] memory) {
        return allJobIds;
    }
    
    function getJobsByPoster(address poster) external view returns (string[] memory) {
        return jobsByPoster[poster];
    }
    
    function getJobApplicationCount(string memory jobId) external view returns (uint256) {
        return jobApplicationCounter[jobId];
    }
    
    function getUserRatings(address user) external view returns (uint256[] memory) {
        return userRatings[user];
    }
    
    function jobExists(string memory jobId) external view returns (bool) {
        return bytes(jobs[jobId].id).length != 0;
    }
    
    // Oracle getters
    function getOracle(string memory oracleName) external view returns (Oracle memory) {
        return oracles[oracleName];
    }
    
    function getOracleMembers(string memory oracleName) external view returns (address[] memory) {
        return oracles[oracleName].members;
    }
    
    function getSkillVerificationDate(string memory oracleName, address user) external view returns (uint256) {
        return skillVerificationDates[oracleName][user];
    }
    
    // Dispute/Voting getters
    function getDispute(string memory disputeId) external view returns (Dispute memory) {
        return disputes[disputeId];
    }
    
    function getSkillApplication(uint256 applicationId) external view returns (SkillVerificationApplication memory) {
        return skillApplications[applicationId];
    }
    
    function getAskAthenaApplication(uint256 athenaId) external view returns (AskAthenaApplication memory) {
        return askAthenaApplications[athenaId];
    }
    
    function hasUserVotedOnDispute(string memory disputeId, address user) external view returns (bool) {
        return hasVotedOnDispute[disputeId][user];
    }
    
    function hasUserVotedOnSkillApplication(uint256 applicationId, address user) external view returns (bool) {
        return hasVotedOnSkillApplication[applicationId][user];
    }
    
    function hasUserVotedOnAskAthena(uint256 athenaId, address user) external view returns (bool) {
        return hasVotedOnAskAthena[athenaId][user];
    }

    // ==================== VOTER DATA GETTERS ====================

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

    // ==================== DAO DATA GETTERS ====================

    function getStake(address staker) external view returns (Stake memory) {
        return stakes[staker];
    }

    function getStakerInfo(address staker) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) {
        Stake memory stake = stakes[staker];
        return (stake.amount, stake.unlockTime, stake.durationMinutes, stake.isActive);
    }

    function getEarner(address earnerAddress) external view returns (Earner memory) {
        return earners[earnerAddress];
    }

    function getEarnerInfo(address earnerAddress) external view returns (
        address earner,
        uint256 balance,
        uint256 governanceActions
    ) {
        Earner memory earnerData = earners[earnerAddress];
        return (earnerData.earnerAddress, earnerData.balance, earnerData.total_governance_actions);
    }

    function getDelegate(address delegator) external view returns (address) {
        return delegates[delegator];
    }

    function getDelegatedVotingPower(address delegatee) external view returns (uint256) {
        return delegatedVotingPower[delegatee];
    }

    function getAllStakers() external view returns (address[] memory) {
        return allStakers;
    }

    function getAllProposalIds() external view returns (uint256[] memory) {
        return proposalIds;
    }

    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function getIsStaker(address staker) external view returns (bool) {
        return isStaker[staker];
    }

    function getActiveStakersCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < allStakers.length; i++) {
            if (stakes[allStakers[i]].isActive) {
                count++;
            }
        }
        return count;
    }

    // ==================== CONTRACT REGISTRY GETTERS ====================

    function getContract(string memory name) external view returns (address contractAddress, uint256 chainId) {
        ContractInfo memory info = contracts[name];
        return (info.contractAddress, info.chainId);
    }

    function getAllContracts() external view returns (string[] memory names, address[] memory addresses, uint256[] memory chainIds) {
        uint256 length = contractNames.length;
        names = new string[](length);
        addresses = new address[](length);
        chainIds = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            ContractInfo memory info = contracts[contractNames[i]];
            names[i] = info.name;
            addresses[i] = info.contractAddress;
            chainIds[i] = info.chainId;
        }
    }

    function getContractCount() external view returns (uint256) {
        return contractNames.length;
    }
    
    // Rewards getters
    function getUserEarnedTokens(address user) external view returns (uint256) {
        return userTotalOWTokens[user];
    }
    
    function getUserRewardInfo(address user) external view returns (
        uint256 totalTokens,
        uint256 governanceActions
    ) {
        return (userTotalOWTokens[user], userGovernanceActions[user]);
    }

    function getUserTotalClaimedTokens(address user) external view returns (uint256) {
        return userTotalClaimedTokens[user];
    }

    function getUserGovernanceActions(address user) external view returns (uint256) {
        return userGovernanceActions[user];
    }
}