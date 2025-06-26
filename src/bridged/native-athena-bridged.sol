// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Add this interface at the top of the SkillOracle contract, after the imports
interface INativeDAO {
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive);
}

// Interface to call back to main DAO
interface IMainDAO {
    function incrementEarnerGovernanceActions(address account) external;
}

contract SkillOracle is OApp {
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
    
    // Cross-chain execution tracking
    mapping(bytes32 => bool) public executedMessages;
    
    // Access control for multiple local contracts
    mapping(uint32 => mapping(bytes32 => bool)) public authorizedLocalContracts;
    
    // Events for cross-contract calls
    event CrossContractCallFailed(address indexed account, string reason);
    event CrossContractCallSuccess(address indexed account);
    event CrossChainMessageReceived(bytes32 indexed messageId, string indexed messageType, address indexed executor);
    event LocalContractAuthorized(uint32 indexed eid, bytes32 indexed localContract);
    event LocalContractDeauthorized(uint32 indexed eid, bytes32 indexed localContract);
    event DisputeRaised(address indexed caller, uint256 jobId, uint256 feeAmount);
    event SkillVerificationSubmitted(address indexed caller, string targetOracleName, uint256 feeAmount);
    event AthenaAsked(address indexed caller, string targetOracle, uint256 feeAmount);
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "Only DAO can call this function");
        _;
    }
    
    constructor(address _endpoint, address _owner, address _daoContract) OApp(_endpoint, _owner) Ownable(_owner) {
        daoContract = _daoContract;
    }
    
    // Function to set main DAO contract address
    function setMainDAO(address _mainDAO) external onlyDAO {
        mainDAO = IMainDAO(_mainDAO);
    }
    
    // Access control functions for multiple local contracts
    function addAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
        authorizedLocalContracts[_eid][_localContract] = true;
        emit LocalContractAuthorized(_eid, _localContract);
    }
    
    function removeAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
        authorizedLocalContracts[_eid][_localContract] = false;
        emit LocalContractDeauthorized(_eid, _localContract);
    }
    
    function isAuthorizedLocal(uint32 _eid, bytes32 _localContract) external view returns (bool) {
        return authorizedLocalContracts[_eid][_localContract];
    }
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        // Prevent replay attacks
        require(!executedMessages[_guid], "Message already executed");
        executedMessages[_guid] = true;
        
        // Verify sender is authorized
        require(authorizedLocalContracts[_origin.srcEid][_origin.sender], "Unauthorized local contract");
        
        string memory messageType = abi.decode(payload, (string));
        
        emit CrossChainMessageReceived(_guid, messageType, msg.sender);
        
        if (keccak256(bytes(messageType)) == keccak256(bytes("RAISE_DISPUTE"))) {
            (, address caller, uint256 jobId, string memory disputeHash, string memory oracleName, uint256 feeAmount) = 
                abi.decode(payload, (string, address, uint256, string, string, uint256));
            raiseDispute(caller, jobId, disputeHash, oracleName, feeAmount);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("SUBMIT_SKILL_VERIFICATION"))) {
            (, address caller, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) = 
                abi.decode(payload, (string, address, string, uint256, string));
            submitSkillVerification(caller, applicationHash, feeAmount, targetOracleName);
            
        } else if (keccak256(bytes(messageType)) == keccak256(bytes("ASK_ATHENA"))) {
            (, address caller, string memory description, string memory hash, string memory targetOracle, uint256 feeAmount) = 
                abi.decode(payload, (string, address, string, string, string, uint256));
            askAthena(caller, description, hash, targetOracle, feeAmount);
        }
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
    ) public {
        raiseDispute(msg.sender, _jobId, _disputeHash, _oracleName, _fee);
    }
    
    function raiseDispute(
        address _caller,
        uint256 _jobId,
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _fee
    ) public {
        // Check if oracle is active (has minimum required members)
        require(oracles[_oracleName].members.length >= minOracleMembers, "Oracle not active");
        
        // TODO: Implement getJobDetails() - get job details from another contract
        
        // TODO: Implement check if caller is involved in the job
        
        // Create new dispute
        disputes[disputeCounter] = Dispute({
            jobID: _jobId,
            disputedAmount: _fee,
            hash: _disputeHash,
            disputeRaiserAddress: _caller,
            votesFor: 0,
            votesAgainst: 0,
            result: false,
            isVotingActive: true,
            timeStamp: block.timestamp,
            fees: _fee
        });
        disputeCounter++;
        
        emit DisputeRaised(_caller, _jobId, _fee);
    }
    
    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        string memory _fees
    ) public {
        // Convert fees string to uint for internal function
        uint256 feeAmount = stringToUint(_fees);
        askAthena(msg.sender, _description, _hash, _targetOracle, feeAmount);
    }
    
    function askAthena(
        address _caller,
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        uint256 _feeAmount
    ) public {
        string memory feeString = uint2str(_feeAmount);
        
        askAthenaApplications[askAthenaCounter] = AskAthenaApplication({
            applicant: _caller,
            description: _description,
            hash: _hash,
            targetOracle: _targetOracle,
            fees: feeString,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
        askAthenaCounter++;
        
        emit AthenaAsked(_caller, _targetOracle, _feeAmount);
    }
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName
    ) public {
        submitSkillVerification(msg.sender, _applicationHash, _feeAmount, _targetOracleName);
    }
    
    function submitSkillVerification(
        address _caller,
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName
    ) public {
        skillApplications[applicationCounter] = SkillVerificationApplication({
            applicant: _caller,
            applicationHash: _applicationHash,
            feeAmount: _feeAmount,
            targetOracleName: _targetOracleName,
            votesFor: 0,
            votesAgainst: 0,
            isVotingActive: true,
            timeStamp: block.timestamp
        });
        applicationCounter++;
        
        emit SkillVerificationSubmitted(_caller, _targetOracleName, _feeAmount);
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
    
    // Utility function to convert string to uint
    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
    
    // Utility function to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // Function to get staker info from DAO contract
    function getStakerInfoFromDAO(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) {
        return INativeDAO(daoContract).getStakerInfo(staker);
    }
    
    // Utility functions
    function getDisputeCount() external view returns (uint256) {
        return disputeCounter;
    }
    
    function getApplicationCount() external view returns (uint256) {
        return applicationCounter;
    }
    
    function getAskAthenaCount() external view returns (uint256) {
        return askAthenaCounter;
    }
    
    function getDispute(uint256 _disputeId) external view returns (Dispute memory) {
        require(_disputeId < disputeCounter, "Dispute does not exist");
        return disputes[_disputeId];
    }
    
    function getSkillApplication(uint256 _applicationId) external view returns (SkillVerificationApplication memory) {
        require(_applicationId < applicationCounter, "Application does not exist");
        return skillApplications[_applicationId];
    }
    
    function getAskAthenaApplication(uint256 _applicationId) external view returns (AskAthenaApplication memory) {
        require(_applicationId < askAthenaCounter, "AskAthena application does not exist");
        return askAthenaApplications[_applicationId];
    }
    
    function getOracle(string memory _oracleName) external view returns (Oracle memory) {
        require(bytes(oracles[_oracleName].name).length > 0, "Oracle not found");
        return oracles[_oracleName];
    }
}