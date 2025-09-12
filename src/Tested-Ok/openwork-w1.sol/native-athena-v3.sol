// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

// Interface to notify governance actions in Rewards Contract
interface IRewardsContract {
    function notifyGovernanceAction(address account) external;
}

// Interface to communicate with AthenaClient Contract
interface IAthenaClient {
    function recordVote(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external;
    function finalizeDispute(string memory disputeId, bool winningSide, uint256 totalVotingPowerFor, uint256 totalVotingPowerAgainst) external;
}

contract NativeAthena {
    address public daoContract;
    
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // Rewards Contract for governance action tracking
    IRewardsContract public rewardsContract;
    
    // AthenaClient Contract for fee distribution
    IAthenaClient public athenaClient;
    
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
        string jobId;  // Changed from uint256 jobID to string jobId
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

    mapping(string => mapping(address => bool)) public hasVotedOnDispute;  // Updated key type
    mapping(uint256 => mapping(address => bool)) public hasVotedOnSkillApplication;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnAskAthena;
    mapping(string => Oracle) public oracles;
    mapping(string => mapping(address => uint256)) public memberStakeAmount;
    mapping(string => mapping(address => uint256)) public skillVerificationDates;
    mapping(uint256 => SkillVerificationApplication) public skillApplications;
    mapping(uint256 => AskAthenaApplication) public askAthenaApplications;
    mapping(string => Dispute) public disputes;  // Changed from uint256 to string key
    uint256 public applicationCounter;
    uint256 public askAthenaCounter;
    uint256 public minOracleMembers = 3;
    uint256 public votingPeriodMinutes = 4;
    uint256 public minStakeRequired = 100;
    
    // Events
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event RewardsContractUpdated(address indexed oldContract, address indexed newContract);
    event AthenaClientUpdated(address indexed oldContract, address indexed newContract);
    event EarnedTokensUsedForVoting(address indexed user, uint256 earnedTokens, string votingType);
    event GovernanceActionNotified(address indexed user, string action);
    event CrossContractCallFailed(address indexed account, string reason);
    event DisputeFinalized(string indexed disputeId, bool winningSide, uint256 totalVotesFor, uint256 totalVotesAgainst);
    event DisputeRaised(string indexed jobId, address indexed disputeRaiser, uint256 fees);
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "Only DAO can call this function");
        _;
    }
    
    constructor(address _daoContract) {
        daoContract = _daoContract;
    }
    
    // Function to set Native OpenWork Job Contract address
    function setNOWJContract(address _nowjContract) external {
        address oldContract = address(nowjContract);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        emit NOWJContractUpdated(oldContract, _nowjContract);
    }
    
    // Function to set Rewards Contract address
    function setRewardsContract(address _rewardsContract) external  {
        address oldContract = address(rewardsContract);
        rewardsContract = IRewardsContract(_rewardsContract);
        emit RewardsContractUpdated(oldContract, _rewardsContract);
    }
    
    // Function to set AthenaClient Contract address
    function setAthenaClient(address _athenaClient) external {
        address oldContract = address(athenaClient);
        athenaClient = IAthenaClient(_athenaClient);
        emit AthenaClientUpdated(oldContract, _athenaClient);
    }
    
    // Helper function to notify rewards contract about governance actions
    function _notifyRewardsContract(address account, string memory actionType) private {
        if (address(rewardsContract) != address(0)) {
            try rewardsContract.notifyGovernanceAction(account) {
                emit GovernanceActionNotified(account, actionType);
            } catch Error(string memory reason) {
                emit CrossContractCallFailed(account, string(abi.encodePacked("Rewards notification failed: ", reason)));
            } catch {
                emit CrossContractCallFailed(account, "Rewards notification failed: Unknown error");
            }
        }
    }
    
    // Helper function to notify athena client about votes
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
    
    /**
     * @notice Check if user has sufficient stake OR earned tokens for voting
     * @param account The user address to check
     * @return True if user meets voting requirements
     */
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
    
    /**
     * @notice Get user's total voting power from stake and earned tokens
     * @param account The user address
     * @return Total voting power (stake weight + earned tokens)
     */
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

    /**
     * @notice Get comprehensive voting info for a user
     * @param account The user address
     * @return hasActiveStake Whether user has active stake
     * @return stakeAmount Current stake amount
     * @return earnedTokens Earned tokens from NOWJ
     * @return totalVotingPower Combined voting power
     * @return meetsVotingThreshold Can vote in oracle decisions
     */
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
    
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external {
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
    
    function addMembers(address[] memory _members, string memory _oracleName) external {
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
    
    function approveSkillVerification(uint256 _applicationId) external onlyDAO {
        require(_applicationId < applicationCounter, "Invalid application ID");
        
        SkillVerificationApplication memory application = skillApplications[_applicationId];
        require(bytes(oracles[application.targetOracleName].name).length > 0, "Oracle not found");
        
        oracles[application.targetOracleName].skillVerifiedAddresses.push(application.applicant);
        skillVerificationDates[application.targetOracleName][application.applicant] = block.timestamp;
    }
    
    function raiseDispute(
        string memory _jobId,  // Changed from uint256 to string
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _fee
    ) external {
        // Check if oracle is active (has minimum required members)
        require(oracles[_oracleName].members.length >= minOracleMembers, "Oracle not active");
      
        
        // Check if dispute already exists for this job
        require(!disputes[_jobId].isVotingActive && disputes[_jobId].timeStamp == 0, "Dispute already exists for this job");
        
        // Create new dispute using string jobId as key
        disputes[_jobId] = Dispute({
            jobId: _jobId,  // Store the string jobId
            disputedAmount: _fee,
            hash: _disputeHash,
            disputeRaiserAddress: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            result: false,
            isVotingActive: true,
            isFinalized: false,
            timeStamp: block.timestamp,
            fees: _fee
        });
        
        emit DisputeRaised(_jobId, msg.sender, _fee);
    }
    
    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        string memory _fees
    ) external {
        askAthenaApplications[askAthenaCounter] = AskAthenaApplication({
            applicant: msg.sender,
            description: _description,
            hash: _hash,
            targetOracle: _targetOracle,
            fees: _fees,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
        askAthenaCounter++;
    }
    
    function updateMinOracleMembers(uint256 _newMinMembers) external onlyDAO {
        minOracleMembers = _newMinMembers;
    }

    // Updated voting function with claim address
    function vote(VotingType _votingType, string memory _disputeId, bool _voteFor, address _claimAddress) external {
        // Check if user can vote (has sufficient stake OR earned tokens)
        require(canVote(msg.sender), "Insufficient stake or earned tokens to vote");
        require(_claimAddress != address(0), "Claim address cannot be zero");
        
        // Calculate total vote weight (stake weight + earned tokens)
        uint256 voteWeight = getUserVotingPower(msg.sender);
        require(voteWeight > 0, "No voting power");
        
        // Notify rewards contract about governance action
        string memory votingTypeStr = _votingType == VotingType.Dispute ? "dispute_vote" : 
                                     _votingType == VotingType.SkillVerification ? "skill_verification_vote" : "ask_athena_vote";
        _notifyRewardsContract(msg.sender, votingTypeStr);
        
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
        
        if (_votingType == VotingType.Dispute) {
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
            
        } else if (_votingType == VotingType.SkillVerification) {
            // Convert disputeId to uint for skill verification (assuming it's passed as string number)
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
            
        } else if (_votingType == VotingType.AskAthena) {
            // Convert disputeId to uint for ask athena (assuming it's passed as string number)
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
    }
    
    // Function to finalize dispute - can be called by anyone
    function finalizeDispute(string memory _disputeId) external {
        require(disputes[_disputeId].timeStamp > 0, "Dispute does not exist");
        
        Dispute storage dispute = disputes[_disputeId];
        require(dispute.isVotingActive, "Voting is not active for this dispute");
        require(!dispute.isFinalized, "Dispute already finalized");
        require(block.timestamp > dispute.timeStamp + (votingPeriodMinutes * 60), "Voting period not expired");
        
        // Finalize the dispute
        dispute.isVotingActive = false;
        dispute.isFinalized = true;
        dispute.result = dispute.votesFor > dispute.votesAgainst;
        
        // Notify AthenaClient about finalization using string disputeId
        if (address(athenaClient) != address(0)) {
            try athenaClient.finalizeDispute(_disputeId, dispute.result, dispute.votesFor, dispute.votesAgainst) {
                // Success
            } catch Error(string memory reason) {
                emit CrossContractCallFailed(msg.sender, string(abi.encodePacked("AthenaClient finalization failed: ", reason)));
            } catch {
                emit CrossContractCallFailed(msg.sender, "AthenaClient finalization failed: Unknown error");
            }
        }
        
        emit DisputeFinalized(_disputeId, dispute.result, dispute.votesFor, dispute.votesAgainst);
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
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName
    ) external {
        skillApplications[applicationCounter] = SkillVerificationApplication({
            applicant: msg.sender,
            applicationHash: _applicationHash,
            feeAmount: _feeAmount,
            targetOracleName: _targetOracleName,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
        applicationCounter++;
    }

    // Function to get staker info from DAO contract
    function getStakerInfoFromDAO(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) {
        return INativeDAO(daoContract).getStakerInfo(staker);
    }
    
    // Function to get earned tokens from job contract
    function getEarnedTokensFromJob(address user) external view returns (uint256) {
        if (address(nowjContract) == address(0)) {
            return 0;
        }
        return nowjContract.getUserEarnedTokens(user);
    }
    
    // Helper function to convert string to uint
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
    
    // Function to get job details (for external viewing)
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
}