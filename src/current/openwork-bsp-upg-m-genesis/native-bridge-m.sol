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
}

interface INativeAthena {
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) external;
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external;
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external;
}

interface INativeOpenWorkJobContract {
    function handleCreateProfile(address user, string memory ipfsHash, address referrer) external;
    function handlePostJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external;
    function handleApplyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) external;
    function handleStartJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external;
    function handleSubmitWork(address applicant, string memory jobId, string memory submissionHash) external;
    function handleReleasePayment(address jobGiver, string memory jobId, uint256 amount) external;
    function handleLockNextMilestone(address caller, string memory jobId, uint256 lockedAmount) external;
    function handleReleasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) external;
    function handleRate(address rater, string memory jobId, address userToRate, uint256 rating) external;
    function handleAddPortfolio(address user, string memory portfolioHash) external;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

contract NativeChainBridge is OAppSender, OAppReceiver {
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;
    
    // Contract addresses for routing incoming messages
    address public nativeDaoContract;
    address public nativeAthenaContract;
    address public nativeOpenWorkJobContract;
    
    // Chain endpoints - this bridge handles multiple destination chains
    uint32 public rewardsChainEid;     // Chain where RewardsContract is deployed
    uint32 public athenaClientChainEid; // Chain where AthenaClient is deployed
    uint32 public lowjcChainEid;       // Chain where LOWJC is deployed
    uint32 public mainChainEid;        // Chain where Main DAO is deployed
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainEndpointUpdated(string indexed chainType, uint32 newEid);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeExecuted(address indexed targetProxy, address indexed newImplementation, uint32 indexed sourceChain);
    
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
        uint32 _rewardsChainEid,
        uint32 _athenaClientChainEid,
        uint32 _lowjcChainEid,
        uint32 _mainChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        rewardsChainEid = _rewardsChainEid;
        athenaClientChainEid = _athenaClientChainEid;
        lowjcChainEid = _lowjcChainEid;
        mainChainEid = _mainChainEid;
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
    
    // ==================== UPGRADE FUNCTIONALITY ====================
    
    function handleUpgradeContract(address targetProxy, address newImplementation) external onlyMainChain {
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
        (string memory functionName) = abi.decode(_message, (string));
        
        // ==================== UPGRADE HANDLING ====================
  if (keccak256(bytes(functionName)) == keccak256("upgradeFromDAO")) {
    require(_origin.srcEid == mainChainEid, "Upgrade commands only from main chain");
    (, address targetProxy, address newImplementation) = 
        abi.decode(_message, (string, address, address));
    require(targetProxy != address(0), "Invalid target proxy address");
    require(newImplementation != address(0), "Invalid implementation address");
    IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
    emit UpgradeExecuted(targetProxy, newImplementation, _origin.srcEid);
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
            (, string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) = abi.decode(_message, (string, string, string, string, uint256, address));
            INativeAthena(nativeAthenaContract).handleRaiseDispute(jobId, disputeHash, oracleName, fee, disputeRaiser);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitSkillVerification"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) = abi.decode(_message, (string, address, string, uint256, string));
            INativeAthena(nativeAthenaContract).handleSubmitSkillVerification(applicant, applicationHash, feeAmount, targetOracleName);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("askAthena"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) = abi.decode(_message, (string, address, string, string, string, string));
            INativeAthena(nativeAthenaContract).handleAskAthena(applicant, description, hash, targetOracle, fees);
        }
        
        // ==================== NATIVE OPENWORK JOB CONTRACT MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("createProfile"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user, string memory ipfsHash, address referrer) = abi.decode(_message, (string, address, string, address));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleCreateProfile(user, ipfsHash, referrer);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("postJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(_message, (string, string, address, string, string[], uint256[]));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handlePostJob(jobId, jobGiver, jobDetailHash, descriptions, amounts);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("applyToJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(_message, (string, address, string, string, string[], uint256[]));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleApplyToJob(applicant, jobId, applicationHash, descriptions, amounts);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("startJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) = abi.decode(_message, (string, address, string, uint256, bool));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleStartJob(jobGiver, jobId, applicationId, useApplicantMilestones);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitWork"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address applicant, string memory jobId, string memory submissionHash) = abi.decode(_message, (string, address, string, string));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleSubmitWork(applicant, jobId, submissionHash);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePayment"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 amount) = abi.decode(_message, (string, address, string, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleReleasePayment(jobGiver, jobId, amount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("lockNextMilestone"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address caller, string memory jobId, uint256 lockedAmount) = abi.decode(_message, (string, address, string, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleLockNextMilestone(caller, jobId, lockedAmount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePaymentAndLockNext"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) = abi.decode(_message, (string, address, string, uint256, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleReleasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("rate"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address rater, string memory jobId, address userToRate, uint256 rating) = abi.decode(_message, (string, address, string, address, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleRate(rater, jobId, userToRate, rating);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("addPortfolio"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user, string memory portfolioHash) = abi.decode(_message, (string, address, string));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleAddPortfolio(user, portfolioHash);
        }
        
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }
    
    // ==================== BRIDGE FUNCTIONS ====================
    
    function sendToRewardsChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        _lzSend(
            rewardsChainEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, rewardsChainEid, _payload);
    }
    
    function sendToAthenaClientChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        _lzSend(
            athenaClientChainEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
             payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, athenaClientChainEid, _payload);
    }
    
    function sendToLowjcChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        _lzSend(
            lowjcChainEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, lowjcChainEid, _payload);
    }
    
    function sendToSpecificChain(
        string memory _functionName,
        uint32 _dstEid,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        _lzSend(
            _dstEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, _dstEid, _payload);
    }
    
    // NEW: Send to two chains simultaneously
    function sendToTwoChains(
        string memory _functionName,
        bytes memory _rewardsPayload,
        bytes memory _athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external payable onlyAuthorized {
        // Calculate total fees upfront
        MessagingFee memory fee1 = _quote(rewardsChainEid, _rewardsPayload, _rewardsOptions, false);
        MessagingFee memory fee2 = _quote(athenaClientChainEid, _athenaClientPayload, _athenaClientOptions, false);
        uint256 totalFee = fee1.nativeFee + fee2.nativeFee;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to rewards chain
        _lzSend(
            rewardsChainEid,
            _rewardsPayload,
            _rewardsOptions,
            fee1,
            payable(msg.sender)
        );
        
        // Send to athena client chain
        _lzSend(
            athenaClientChainEid,
            _athenaClientPayload,
            _athenaClientOptions,
            fee2,
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, rewardsChainEid, _rewardsPayload);
        emit CrossChainMessageSent(_functionName, athenaClientChainEid, _athenaClientPayload);
    }
    
    function sendToThreeChains(
        string memory _functionName,
        uint32 _dstEid1,
        uint32 _dstEid2,
        uint32 _dstEid3,
        bytes memory _payload1,
        bytes memory _payload2,
        bytes memory _payload3,
        bytes calldata _options1,
        bytes calldata _options2,
        bytes calldata _options3
    ) external payable onlyAuthorized {
        // Calculate total fees upfront
        MessagingFee memory fee1 = _quote(_dstEid1, _payload1, _options1, false);
        MessagingFee memory fee2 = _quote(_dstEid2, _payload2, _options2, false);
        MessagingFee memory fee3 = _quote(_dstEid3, _payload3, _options3, false);
        uint256 totalFee = fee1.nativeFee + fee2.nativeFee + fee3.nativeFee;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to all three chains
        _lzSend(_dstEid1, _payload1, _options1, fee1, payable(msg.sender));
        _lzSend(_dstEid2, _payload2, _options2, fee2, payable(msg.sender));
        _lzSend(_dstEid3, _payload3, _options3, fee3, payable(msg.sender));
        
        emit CrossChainMessageSent(_functionName, _dstEid1, _payload1);
        emit CrossChainMessageSent(_functionName, _dstEid2, _payload2);
        emit CrossChainMessageSent(_functionName, _dstEid3, _payload3);
    }
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteRewardsChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(rewardsChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    function quoteAthenaClientChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(athenaClientChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    function quoteLowjcChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(lowjcChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    function quoteSpecificChain(
        uint32 _dstEid,
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(_dstEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    // NEW: Quote for two chains
    function quoteTwoChains(
        bytes calldata _rewardsPayload,
        bytes calldata _athenaClientPayload,
        bytes calldata _rewardsOptions,
        bytes calldata _athenaClientOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 athenaClientFee) {
        MessagingFee memory msgFee1 = _quote(rewardsChainEid, _rewardsPayload, _rewardsOptions, false);
        MessagingFee memory msgFee2 = _quote(athenaClientChainEid, _athenaClientPayload, _athenaClientOptions, false);
        
        rewardsFee = msgFee1.nativeFee;
        athenaClientFee = msgFee2.nativeFee;
        totalFee = rewardsFee + athenaClientFee;
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
    
    function updateRewardsChainEid(uint32 _rewardsChainEid) external onlyOwner {
        rewardsChainEid = _rewardsChainEid;
        emit ChainEndpointUpdated("rewards", _rewardsChainEid);
    }
    
    function updateAthenaClientChainEid(uint32 _athenaClientChainEid) external onlyOwner {
        athenaClientChainEid = _athenaClientChainEid;
        emit ChainEndpointUpdated("athenaClient", _athenaClientChainEid);
    }
    
    function updateLowjcChainEid(uint32 _lowjcChainEid) external onlyOwner {
        lowjcChainEid = _lowjcChainEid;
        emit ChainEndpointUpdated("lowjc", _lowjcChainEid);
    }
    
    function updateMainChainEid(uint32 _mainChainEid) external onlyOwner {
        mainChainEid = _mainChainEid;
        emit ChainEndpointUpdated("main", _mainChainEid);
    }
    
    function updateChainEndpoints(uint32 _rewardsChainEid, uint32 _athenaClientChainEid, uint32 _lowjcChainEid, uint32 _mainChainEid) external onlyOwner {
        rewardsChainEid = _rewardsChainEid;
        athenaClientChainEid = _athenaClientChainEid;
        lowjcChainEid = _lowjcChainEid;
        mainChainEid = _mainChainEid;
        emit ChainEndpointUpdated("rewards", _rewardsChainEid);
        emit ChainEndpointUpdated("athenaClient", _athenaClientChainEid);
        emit ChainEndpointUpdated("lowjc", _lowjcChainEid);
        emit ChainEndpointUpdated("main", _mainChainEid);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}