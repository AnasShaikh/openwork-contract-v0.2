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

    // ==================== STATE VARIABLES ====================
    
    // Access control
    mapping(address => bool) public authorizedContracts;
    address public owner;
    
    // Profile data
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(address => address) public userReferrers;
    
    
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
    
    // Final rewards data
    mapping(address => uint256) public userTotalOWTokens;
    mapping(address => uint256) public userGovernanceActions;

    // ==================== EVENTS ====================
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractAuthorized(address indexed contractAddress, bool authorized);

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
        owner = msg.sender;
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
    }
    
    function addPortfolio(address user, string memory portfolioHash) external onlyAuthorized {
        profiles[user].portfolioHashes.push(portfolioHash);
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
    }
    
    function updateJobStatus(string memory jobId, JobStatus status) external onlyAuthorized {
        jobs[jobId].status = status;
    }
    
    function setJobSelectedApplicant(string memory jobId, address applicant, uint256 applicationId) external onlyAuthorized {
        jobs[jobId].selectedApplicant = applicant;
        jobs[jobId].selectedApplicationId = applicationId;
    }
    
    function setJobCurrentMilestone(string memory jobId, uint256 milestone) external onlyAuthorized {
        jobs[jobId].currentMilestone = milestone;
    }
    
    function addJobFinalMilestone(string memory jobId, string memory description, uint256 amount) external onlyAuthorized {
        jobs[jobId].finalMilestones.push(MilestonePayment({
            descriptionHash: description,
            amount: amount
        }));
    }
    
    function addWorkSubmission(string memory jobId, string memory submissionHash) external onlyAuthorized {
        jobs[jobId].workSubmissions.push(submissionHash);
    }
    
    function updateJobTotalPaid(string memory jobId, uint256 amount) external onlyAuthorized {
        jobs[jobId].totalPaid += amount;
        totalPlatformPayments += amount;
    }
    
    function setJobRating(string memory jobId, address user, uint256 rating) external onlyAuthorized {
        jobRatings[jobId][user] = rating;
        userRatings[user].push(rating);
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
    }
    
    function addOracleMember(string memory oracleName, address member) external onlyAuthorized {
        oracles[oracleName].members.push(member);
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
    }
    
    function addSkillVerifiedAddress(string memory oracleName, address user) external onlyAuthorized {
        oracles[oracleName].skillVerifiedAddresses.push(user);
        skillVerificationDates[oracleName][user] = block.timestamp;
    }
    
    function setMemberStakeAmount(string memory oracleName, address member, uint256 amount) external onlyAuthorized {
        memberStakeAmount[oracleName][member] = amount;
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

    function getUserGovernanceActions(address user) external view returns (uint256) {
        return userGovernanceActions[user];
    }
}