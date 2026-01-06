// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface INativeDAO {
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external;
    function upgradeFromDAO(address newImplementation) external;
}

interface INativeAthena {
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, uint256 disputedAmount, address disputeRaiser) external;
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external;
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external;
    function upgradeFromDAO(address newImplementation) external;
}

interface INativeOpenWorkJobContract {
    function postJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external;
    function applyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts, uint32 preferredChainDomain) external;
    function startJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external;
    function submitWork(address applicant, string memory jobId, string memory submissionHash) external;
    function releasePayment(address jobGiver, string memory jobId, uint256 amount) external;
    function releasePaymentCrossChain(address jobGiver, string memory jobId, uint256 amount, uint32 targetChainDomain, address targetRecipient) external;
    function lockNextMilestone(address caller, string memory jobId, uint256 lockedAmount) external;
    function releasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) external;
    function incrementGovernanceAction(address user) external;
    function handleStartDirectContract(address jobGiver, address jobTaker, string memory jobId, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts, uint32 jobTakerChainDomain) external;

    function sendSyncRewardsData(
        uint256 userGovernanceActions,
        uint256[] calldata userBands,
        uint256[] calldata tokensPerBand,
        bytes calldata _options
    ) external payable;

    function handleUpdateUserClaimData(
        address user, 
        uint256 claimedTokens
    ) external;

    function sendSyncVotingPowerToMainChain(
        address user,
        uint256 totalRewards,
        bytes calldata _options
    ) external payable;
    
    function upgradeFromDAO(address newImplementation) external;
}

interface IProfileManager {
    function createProfile(address user, string memory ipfsHash, address referrer) external;
    function addPortfolio(address user, string memory portfolioHash) external;
    function rate(address rater, string memory jobId, address userToRate, uint256 rating) external;
    function updateProfile(address user, string memory newIpfsHash) external;
    function updatePortfolioItem(address user, uint256 index, string memory newPortfolioHash) external;
    function removePortfolioItem(address user, uint256 index) external;
}

interface IDirectContractManager {
    function handleStartDirectContract(address jobGiver, address jobTaker, string memory jobId, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts, uint32 jobTakerChainDomain) external;
    function upgradeFromDAO(address newImplementation) external;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

contract NativeChainBridge is OAppSender, OAppReceiver {
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;

    // Governance/Admin pattern
    mapping(address => bool) public admins;
    address public nativeDAO;
    
    // Contract addresses for routing incoming messages
    address public nativeDaoContract;
    address public nativeAthenaContract;
    address public nativeOpenWorkJobContract;
    address public directContractManager;
    address public profileManager;
    
    // NEW: Multiple Local Chains Support
    mapping(uint32 => bool) public authorizedLocalChains;
    uint32[] public localChainEids;
    
    // Chain endpoints - simplified to 2 types
    uint32 public mainChainEid;        // Main/Rewards chain (single)
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainEndpointUpdated(string indexed chainType, uint32 newEid);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event DirectContractManagerSet(address indexed directContractManager);
    event UpgradeExecuted(address indexed targetProxy, address indexed newImplementation, uint32 indexed sourceChain);
    event LocalChainAdded(uint32 indexed localChainEid);
    event LocalChainRemoved(uint32 indexed localChainEid);
    event AdminUpdated(address indexed admin, bool status);
    event NativeDAOUpdated(address indexed oldDAO, address indexed newDAO);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    modifier onlyMainChain() {
        require(msg.sender == address(this), "Only main chain can call this function");
        _;
    }
    
    constructor(
        address _endpoint,
        address _owner,
        uint32 _mainChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        mainChainEid = _mainChainEid;
        admins[_owner] = true;  // Owner is default admin
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
    
    // ==================== LOCAL CHAIN MANAGEMENT ====================
    
    function addLocalChain(uint32 _localChainEid) external onlyOwner {
        require(!authorizedLocalChains[_localChainEid], "Local chain already authorized");
        authorizedLocalChains[_localChainEid] = true;
        localChainEids.push(_localChainEid);
        emit LocalChainAdded(_localChainEid);
    }
    
    function removeLocalChain(uint32 _localChainEid) external onlyOwner {
        require(authorizedLocalChains[_localChainEid], "Local chain not authorized");
        authorizedLocalChains[_localChainEid] = false;
        
        // Remove from array
        for (uint256 i = 0; i < localChainEids.length; i++) {
            if (localChainEids[i] == _localChainEid) {
                localChainEids[i] = localChainEids[localChainEids.length - 1];
                localChainEids.pop();
                break;
            }
        }
        emit LocalChainRemoved(_localChainEid);
    }
    
    function getLocalChains() external view returns (uint32[] memory) {
        return localChainEids;
    }
    
    // ==================== JOB ID PARSING UTILITY ====================
    
    function extractEidFromJobId(string memory jobId) internal pure returns (uint32) {
        bytes memory jobIdBytes = bytes(jobId);
        uint256 dashIndex = 0;
        
        // Find the dash position
        for (uint256 i = 0; i < jobIdBytes.length; i++) {
            if (jobIdBytes[i] == '-') {
                dashIndex = i;
                break;
            }
        }
        
        require(dashIndex > 0, "Invalid job ID format");
        
        // Extract EID part (before dash)
        uint32 eid = 0;
        for (uint256 i = 0; i < dashIndex; i++) {
            require(jobIdBytes[i] >= '0' && jobIdBytes[i] <= '9', "Invalid EID in job ID");
            eid = eid * 10 + uint32(uint8(jobIdBytes[i]) - 48);
        }
        
        return eid;
    }
    
    // ==================== UPGRADE FUNCTIONALITY ====================
    
    function handleUpgradeContract(address targetProxy, address newImplementation) external {
        require(admins[msg.sender], "Only admin");
        require(targetProxy != address(0), "Invalid target proxy address");
        require(newImplementation != address(0), "Invalid implementation address");
        
        // Execute the upgrade
        IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
        
        emit UpgradeExecuted(targetProxy, newImplementation, mainChainEid);
    }
    
    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used) 
        bytes calldata // _extraData (not used)
    ) internal override {
        // Decode the function name first
        string memory functionName;
        try this.decodeFunctionName(_message) returns (string memory _functionName) {
            functionName = _functionName;
        } catch {
            revert("Failed to decode message function name");
        }

        // Handle upgrade messages with complete rewrite from scratch
        if (keccak256(bytes(functionName)) == keccak256(bytes("upgradeFromDAO"))) {
            _handleUpgradeMessage(_origin, _message);
        }
        // ==================== NATIVE DAO MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("updateStakeData"))) {
            require(nativeDaoContract != address(0), "Native DAO contract not set");
            (, address staker, uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) = abi.decode(_message, (string, address, uint256, uint256, uint256, bool));
            INativeDAO(nativeDaoContract).updateStakeData(staker, amount, unlockTime, durationMinutes, isActive);
        }

        // ==================== NATIVE ATHENA MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("raiseDispute"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, uint256 disputedAmount, address disputeRaiser) = abi.decode(_message, (string, string, string, string, uint256, uint256, address));
            INativeAthena(nativeAthenaContract).handleRaiseDispute(jobId, disputeHash, oracleName, fee, disputedAmount, disputeRaiser);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitSkillVerification"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) = abi.decode(_message, (string, address, string, uint256, string));
            INativeAthena(nativeAthenaContract).handleSubmitSkillVerification(applicant, applicationHash, feeAmount, targetOracleName);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("askAthena"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) = abi.decode(_message, (string, address, string, string, string, string));
            INativeAthena(nativeAthenaContract).handleAskAthena(applicant, description, hash, targetOracle, fees);
        }
        
        // ==================== PROFILE MANAGER MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("createProfile"))) {
            require(profileManager != address(0), "Profile Manager not set");
            (, address user, string memory ipfsHash, address referrer) = abi.decode(_message, (string, address, string, address));
            IProfileManager(profileManager).createProfile(user, ipfsHash, referrer);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("addPortfolio"))) {
            require(profileManager != address(0), "Profile Manager not set");
            (, address user, string memory portfolioHash) = abi.decode(_message, (string, address, string));
            IProfileManager(profileManager).addPortfolio(user, portfolioHash);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("rate"))) {
            require(profileManager != address(0), "Profile Manager not set");
            (, address rater, string memory jobId, address userToRate, uint256 rating) = abi.decode(_message, (string, address, string, address, uint256));
            IProfileManager(profileManager).rate(rater, jobId, userToRate, rating);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("updateProfile"))) {
            require(profileManager != address(0), "Profile Manager not set");
            (, address user, string memory newIpfsHash) = abi.decode(_message, (string, address, string));
            IProfileManager(profileManager).updateProfile(user, newIpfsHash);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("updatePortfolioItem"))) {
            require(profileManager != address(0), "Profile Manager not set");
            (, address user, uint256 index, string memory newPortfolioHash) = abi.decode(_message, (string, address, uint256, string));
            IProfileManager(profileManager).updatePortfolioItem(user, index, newPortfolioHash);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("removePortfolioItem"))) {
            require(profileManager != address(0), "Profile Manager not set");
            (, address user, uint256 index) = abi.decode(_message, (string, address, uint256));
            IProfileManager(profileManager).removePortfolioItem(user, index);
        }
        
        // ==================== NATIVE OPENWORK JOB CONTRACT MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("postJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(_message, (string, string, address, string, string[], uint256[]));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).postJob(jobId, jobGiver, jobDetailHash, descriptions, amounts);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("applyToJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts, uint32 preferredChainDomain) = abi.decode(_message, (string, address, string, string, string[], uint256[], uint32));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).applyToJob(applicant, jobId, applicationHash, descriptions, amounts, preferredChainDomain);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("startJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) = abi.decode(_message, (string, address, string, uint256, bool));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).startJob(jobGiver, jobId, applicationId, useApplicantMilestones);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitWork"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address applicant, string memory jobId, string memory submissionHash) = abi.decode(_message, (string, address, string, string));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).submitWork(applicant, jobId, submissionHash);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePayment"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 amount) = abi.decode(_message, (string, address, string, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).releasePayment(jobGiver, jobId, amount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("lockNextMilestone"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address caller, string memory jobId, uint256 lockedAmount) = abi.decode(_message, (string, address, string, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).lockNextMilestone(caller, jobId, lockedAmount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePaymentAndLockNext"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) = abi.decode(_message, (string, address, string, uint256, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePaymentCrossChain"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 amount, uint32 targetChainDomain, address targetRecipient) = abi.decode(_message, (string, address, string, uint256, uint32, address));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).releasePaymentCrossChain(jobGiver, jobId, amount, targetChainDomain, targetRecipient);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("startDirectContract"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, address jobTaker, string memory jobId, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts, uint32 jobTakerChainDomain) = abi.decode(_message, (string, address, address, string, string, string[], uint256[], uint32));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleStartDirectContract(jobGiver, jobTaker, jobId, jobDetailHash, descriptions, amounts, jobTakerChainDomain);
        }
        // ==================== GOVERNANCE ACTION HANDLING ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("incrementGovernanceAction"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user) = abi.decode(_message, (string, address));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).incrementGovernanceAction(user);
        }
        else if (keccak256(bytes(functionName)) == keccak256(bytes("updateUserClaimData"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user, uint256 claimedAmount) = abi.decode(_message, (string, address, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleUpdateUserClaimData(user, claimedAmount);
        }
        // Reject unknown messages
        else {
            revert(string(abi.encodePacked("Unknown function: ", functionName)));
        }

        // Emit comprehensive event
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }

    // External function for safe decoding (allows try/catch)
    function decodeFunctionName(bytes calldata _message) external pure returns (string memory) {
        (string memory functionName) = abi.decode(_message, (string));
        return functionName;
    }

    // Simplified upgrade message handler - routes to specific known contracts
    function _handleUpgradeMessage(Origin calldata _origin, bytes calldata _message) internal {
        // Direct decode - no try/catch
        (, address targetProxy, address newImplementation) = abi.decode(_message, (string, address, address));
        
        // Route to specific known contracts like other functions
        if (targetProxy == nativeAthenaContract) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            INativeAthena(nativeAthenaContract).upgradeFromDAO(newImplementation);
        } else if (targetProxy == nativeDaoContract) {
            require(nativeDaoContract != address(0), "Native DAO contract not set");
            INativeDAO(nativeDaoContract).upgradeFromDAO(newImplementation);
        } else if (targetProxy == nativeOpenWorkJobContract) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).upgradeFromDAO(newImplementation);
        } else {
            revert("Unknown target contract for upgrade");
        }
        
        emit UpgradeExecuted(targetProxy, newImplementation, _origin.srcEid);
    }
    
    // ==================== BRIDGE FUNCTIONS ====================
    
    function sendToMainChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        _lzSend(
            mainChainEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, mainChainEid, _payload);
    }
    
    function sendToLocalChain(
        string memory _disputeId,
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        uint32 targetEid = extractEidFromJobId(_disputeId);
        require(authorizedLocalChains[targetEid], "Local chain not authorized");
        
        _lzSend(
            targetEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, targetEid, _payload);
    }

    function sendSyncRewardsData(
        address user,
        uint256 claimableAmount,
        bytes calldata _options
    ) external payable onlyAuthorized {
        bytes memory payload = abi.encode(
            "syncClaimableRewards",
            user,
            claimableAmount
        );
        
        _lzSend(
            mainChainEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent("syncClaimableRewards", mainChainEid, payload);
    }

    function sendSyncVotingPower(
        address user,
        uint256 totalRewards,
        bytes calldata _options
    ) external payable onlyAuthorized {
        bytes memory payload = abi.encode(
            "syncVotingPower",
            user,
            totalRewards
        );
        
        _lzSend(
            mainChainEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent("syncVotingPower", mainChainEid, payload);
    }
    
    // ==================== QUOTE FUNCTIONS ====================

    function quoteSyncVotingPower(
        address user,
        uint256 totalRewards,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode(
            "syncVotingPower",
            user,
            totalRewards
        );
        MessagingFee memory msgFee = _quote(mainChainEid, payload, _options, false);
        return msgFee.nativeFee;
    }

    function quoteSyncRewardsData(
        address user,
        uint256 claimableAmount,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode(
            "syncClaimableRewards",
            user,
            claimableAmount
        );
        MessagingFee memory msgFee = _quote(mainChainEid, payload, _options, false);
        return msgFee.nativeFee;
    }

    function quoteLocalChain(
        string memory _disputeId,
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        uint32 targetEid = extractEidFromJobId(_disputeId);
        require(authorizedLocalChains[targetEid], "Local chain not authorized");
        
        MessagingFee memory msgFee = _quote(targetEid, _payload, _options, false);
        return msgFee.nativeFee;
    }

    function quoteMainChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(mainChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
        
    function quoteThreeChains(
        uint32 _dstEid1,
        uint32 _dstEid2,
        uint32 _dstEid3,
        bytes calldata _payload1,
        bytes calldata _payload2,
        bytes calldata _payload3,
        bytes calldata _options1,
        bytes calldata _options2,
        bytes calldata _options3
    ) external view returns (uint256 totalFee, uint256 fee1, uint256 fee2, uint256 fee3) {
        MessagingFee memory msgFee1 = _quote(_dstEid1, _payload1, _options1, false);
        MessagingFee memory msgFee2 = _quote(_dstEid2, _payload2, _options2, false);
        MessagingFee memory msgFee3 = _quote(_dstEid3, _payload3, _options3, false);
        
        fee1 = msgFee1.nativeFee;
        fee2 = msgFee2.nativeFee;
        fee3 = msgFee3.nativeFee;
        totalFee = fee1 + fee2 + fee3;
    }
    
    // ==================== ADMIN FUNCTIONS ====================

    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || msg.sender == nativeDAO, "Only owner or DAO");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    function setNativeDAO(address _nativeDAO) external onlyOwner {
        address oldDAO = nativeDAO;
        nativeDAO = _nativeDAO;
        emit NativeDAOUpdated(oldDAO, _nativeDAO);
    }

    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }
    
    function setNativeDaoContract(address _nativeDao) external onlyOwner {
        nativeDaoContract = _nativeDao;
        emit ContractAddressSet("nativeDao", _nativeDao);
    }
    
    function setNativeAthenaContract(address _nativeAthena) external onlyOwner {
        nativeAthenaContract = _nativeAthena;
        emit ContractAddressSet("nativeAthena", _nativeAthena);
    }
    
    function setNativeOpenWorkJobContract(address _nativeOpenWorkJob) external onlyOwner {
        nativeOpenWorkJobContract = _nativeOpenWorkJob;
        emit ContractAddressSet("nativeOpenWorkJob", _nativeOpenWorkJob);
    }
    
    function setDirectContractManager(address _directContractManager) external onlyOwner {
        require(_directContractManager != address(0), "Invalid Direct Contract Manager address");
        directContractManager = _directContractManager;
        emit DirectContractManagerSet(_directContractManager);
    }
    
    function setProfileManager(address _profileManager) external onlyOwner {
        require(_profileManager != address(0), "Invalid Profile Manager address");
        profileManager = _profileManager;
        emit ContractAddressSet("profileManager", _profileManager);
    }
    
    function updateMainChainEid(uint32 _mainChainEid) external onlyOwner {
        mainChainEid = _mainChainEid;
        emit ChainEndpointUpdated("main", _mainChainEid);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}
