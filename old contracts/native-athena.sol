// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Add this interface at the top of the SkillOracle contract, after the imports
interface INativeDAO {
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive);
}

// Interface to call back to main DAO
interface IMainDAO {
    function incrementEarnerGovernanceActions(address account) external;
}

contract SkillOracle {
    address public daoContract;
    
    // Main DAO contract for cross-contract calls
    IMainDAO public mainDAO;
    
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
        uint256 jobID;
        uint256 disputedAmount;
        string hash;
        address disputeRaiserAddress;
        uint256 votesFor;
        uint256 votesAgainst;
        bool result;
        bool isVotingActive;
        uint256 timeStamp;
        uint256 fees;
    }

    mapping(uint256 => mapping(address => bool)) public hasVotedOnDispute;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnSkillApplication;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnAskAthena;
    mapping(string => Oracle) public oracles;
    mapping(string => mapping(address => uint256)) public memberStakeAmount;
    mapping(string => mapping(address => uint256)) public skillVerificationDates;
    mapping(uint256 => SkillVerificationApplication) public skillApplications;
    mapping(uint256 => AskAthenaApplication) public askAthenaApplications;
    mapping(uint256 => Dispute) public disputes;
    uint256 public applicationCounter;
    uint256 public askAthenaCounter;
    uint256 public disputeCounter;
    uint256 public minOracleMembers = 3;
    uint256 public votingPeriodMinutes = 4;
    uint256 public minStakeRequired = 100;
    
    // Events for cross-contract calls
    event CrossContractCallFailed(address indexed account, string reason);
    event CrossContractCallSuccess(address indexed account);
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "Only DAO can call this function");
        _;
    }
    
    constructor(address _daoContract) {
        daoContract = _daoContract;
    }
    
    // Function to set main DAO contract address
    function setMainDAO(address _mainDAO) external onlyDAO {
        mainDAO = IMainDAO(_mainDAO);
    }
    
    // Helper function to call main DAO
    function _callMainDAOIncrement(address account) private {
        if (address(mainDAO) == address(0)) return;
        
        try mainDAO.incrementEarnerGovernanceActions(account) {
            emit CrossContractCallSuccess(account);
        } catch Error(string memory reason) {
            emit CrossContractCallFailed(account, reason);
        } catch {
            emit CrossContractCallFailed(account, "Unknown error");
        }
    }
    
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external onlyDAO {
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
    
    function approveSkillVerification(uint256 _applicationId) external onlyDAO {
        require(_applicationId < applicationCounter, "Invalid application ID");
        
        SkillVerificationApplication memory application = skillApplications[_applicationId];
        require(bytes(oracles[application.targetOracleName].name).length > 0, "Oracle not found");
        
        oracles[application.targetOracleName].skillVerifiedAddresses.push(application.applicant);
        skillVerificationDates[application.targetOracleName][application.applicant] = block.timestamp;
    }
    
    function raiseDispute(
        uint256 _jobId,
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _fee
    ) external {
        // Check if oracle is active (has minimum required members)
        require(oracles[_oracleName].members.length >= minOracleMembers, "Oracle not active");
        
        // TODO: Implement getJobDetails() - get job details from another contract
        
        // TODO: Implement check if caller is involved in the job
        
        // Create new dispute
        disputes[disputeCounter] = Dispute({
            jobID: _jobId,
            disputedAmount: _fee,
            hash: _disputeHash,
            disputeRaiserAddress: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            result: false,
            isVotingActive: true,
            timeStamp: block.timestamp,
            fees: _fee
        });
        disputeCounter++;
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

    // Unified voting function that handles all three types of voting
    function vote(VotingType _votingType, uint256 _id, bool _voteFor) external {
        // Common stake validation
        (uint256 stakeAmount, , uint256 durationMinutes, bool isActive) = INativeDAO(daoContract).getStakerInfo(msg.sender);
        require(isActive && stakeAmount >= minStakeRequired, "Insufficient stake or inactive stake");
        
        // Call main DAO to increment governance actions if caller is an earner
        _callMainDAOIncrement(msg.sender);
        
        // Calculate vote weight
        uint256 voteWeight = stakeAmount * durationMinutes;
        
        if (_votingType == VotingType.Dispute) {
            require(_id < disputeCounter, "Dispute does not exist");
            require(!hasVotedOnDispute[_id][msg.sender], "Already voted on this dispute");
            
            Dispute storage dispute = disputes[_id];
            require(dispute.isVotingActive, "Voting is not active for this dispute");
            require(block.timestamp <= dispute.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
            
            hasVotedOnDispute[_id][msg.sender] = true;
            
            if (_voteFor) {
                dispute.votesFor += voteWeight;
            } else {
                dispute.votesAgainst += voteWeight;
            }
            
        } else if (_votingType == VotingType.SkillVerification) {
            require(_id < applicationCounter, "Application does not exist");
            require(!hasVotedOnSkillApplication[_id][msg.sender], "Already voted on this application");
            
            SkillVerificationApplication storage application = skillApplications[_id];
            require(application.isVotingActive, "Voting is not active for this application");
            require(block.timestamp <= application.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
            
            hasVotedOnSkillApplication[_id][msg.sender] = true;
            
            if (_voteFor) {
                application.votesFor += voteWeight;
            } else {
                application.votesAgainst += voteWeight;
            }
            
        } else if (_votingType == VotingType.AskAthena) {
            require(_id < askAthenaCounter, "AskAthena application does not exist");
            require(!hasVotedOnAskAthena[_id][msg.sender], "Already voted on this AskAthena application");
            
            AskAthenaApplication storage athenaApp = askAthenaApplications[_id];
            require(athenaApp.isVotingActive, "Voting is not active for this AskAthena application");
            require(block.timestamp <= athenaApp.timeStamp + (votingPeriodMinutes * 60), "Voting period has expired");
            
            hasVotedOnAskAthena[_id][msg.sender] = true;
            
            if (_voteFor) {
                athenaApp.votesFor += voteWeight;
            } else {
                athenaApp.votesAgainst += voteWeight;
            }
        }
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
}