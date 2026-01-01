// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IAthenaClient {
    function handleFinalizeDisputeWithVotes(
        string memory disputeId, 
        bool winningSide, 
        uint256 votesFor, 
        uint256 votesAgainst,
        address[] memory voters,
        address[] memory claimAddresses,
        uint256[] memory votingPowers,
        bool[] memory voteDirections
    ) external;
    function handleRecordVote(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

interface IJobContract {
    function handleStartJob(
        address jobGiver,
        string memory jobId,
        uint256 appId,
        bool useAppMilestones,
        uint256 amount
    ) external;
}

contract LayerZeroBridge is OAppSender, OAppReceiver {
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;
    
    // Contract addresses for routing incoming messages
    address public athenaClientContract;
    address public lowjcContract;
    
    // Chain endpoints - simplified to 2 types
    uint32 public nativeChainEid;
    uint32 public mainChainEid;        // Main/Rewards chain (single)
    uint32 public thisLocalChainEid;   // This local chain's EID
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainEndpointUpdated(string indexed chainType, uint32 newEid);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeExecuted(address indexed targetProxy, address indexed newImplementation, uint32 indexed sourceChain);
    event ThisLocalChainEidUpdated(uint32 oldEid, uint32 newEid);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    constructor(
        address _endpoint,
        address _owner,
        uint32 _nativeChainEid,
        uint32 _mainChainEid,
        uint32 _thisLocalChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        nativeChainEid = _nativeChainEid;
        mainChainEid = _mainChainEid;
        thisLocalChainEid = _thisLocalChainEid;
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
    
    // No separate function needed - handled inline in _lzReceive for security
    
    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32,            // _guid (not used)
        bytes calldata _message,
        address,            // _executor (not used)
        bytes calldata      // _extraData (not used)
    ) internal override {
        // --- 1) pull out the function name ---
        (string memory functionName) = abi.decode(_message, (string));

        // --- 2) UPGRADE HANDLING ---
        if (keccak256(bytes(functionName)) == keccak256("upgradeFromDAO")) {
            require(_origin.srcEid == mainChainEid, "Upgrade commands only from main chain");
            // now decode the full payload
            (, address targetProxy, address newImplementation) =
                abi.decode(_message, (string, address, address));
            require(targetProxy != address(0), "Invalid target proxy address");
            require(newImplementation != address(0), "Invalid implementation address");
            IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
            emit UpgradeExecuted(targetProxy, newImplementation, _origin.srcEid);
        }

        // --- 3) ATHENA CLIENT MESSAGES ---
        else if (keccak256(bytes(functionName)) == keccak256("finalizeDisputeWithVotes")) {
            (, string memory disputeId, bool winningSide, uint256 votesFor, uint256 votesAgainst,
             address[] memory voters, address[] memory claimAddresses, 
             uint256[] memory votingPowers, bool[] memory voteDirections) =
                abi.decode(_message, (string, string, bool, uint256, uint256, address[], address[], uint256[], bool[]));
            
            IAthenaClient(athenaClientContract).handleFinalizeDisputeWithVotes(
                disputeId, winningSide, votesFor, votesAgainst,
                voters, claimAddresses, votingPowers, voteDirections
            );
        }

        // --- 4) JOB CONTRACT MESSAGES ---
        else if (keccak256(bytes(functionName)) == keccak256("startJob")) {
            require(lowjcContract != address(0), "LOWJC contract not set");
            // Decode the startJob payload
            (, address jobGiver, string memory jobId, uint256 appId, bool useAppMilestones, uint256 amount) =
                abi.decode(_message, (string, address, string, uint256, bool, uint256));
            
            // Forward to the job contract
            IJobContract(lowjcContract).handleStartJob(jobGiver, jobId, appId, useAppMilestones, amount);
        }

        // --- 5) unknown function → revert ---
        else {
            revert("Unknown function call");
        }

        // --- 5) emit a catch‐all event ---
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }
    
    // ==================== BRIDGE FUNCTIONS ====================
    
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        _lzSend(
            nativeChainEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, nativeChainEid, _payload);
    }
    
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
    
    function sendToTwoChains(
        string memory _functionName,
        bytes memory _mainChainPayload,
        bytes memory _nativePayload,
        bytes calldata _mainChainOptions,
        bytes calldata _nativeOptions
    ) external payable onlyAuthorized {
        // Calculate total fees upfront
        MessagingFee memory fee1 = _quote(mainChainEid, _mainChainPayload, _mainChainOptions, false);
        MessagingFee memory fee2 = _quote(nativeChainEid, _nativePayload, _nativeOptions, false);
        uint256 totalFee = fee1.nativeFee + fee2.nativeFee;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to main chain
        _lzSend(
            mainChainEid,
            _mainChainPayload,
            _mainChainOptions,
            fee1,
            payable(msg.sender)
        );
        
        // Send to native chain
        _lzSend(
            nativeChainEid,
            _nativePayload,
            _nativeOptions,
            fee2,
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, mainChainEid, _mainChainPayload);
        emit CrossChainMessageSent(_functionName, nativeChainEid, _nativePayload);
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
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(nativeChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    function quoteMainChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(mainChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    function quoteTwoChains(
        bytes calldata _mainChainPayload,
        bytes calldata _nativePayload,
        bytes calldata _mainChainOptions,
        bytes calldata _nativeOptions
    ) external view returns (uint256 totalFee, uint256 mainChainFee, uint256 nativeFee) {
        MessagingFee memory msgFee1 = _quote(mainChainEid, _mainChainPayload, _mainChainOptions, false);
        MessagingFee memory msgFee2 = _quote(nativeChainEid, _nativePayload, _nativeOptions, false);
        
        mainChainFee = msgFee1.nativeFee;
        nativeFee = msgFee2.nativeFee;
        totalFee = mainChainFee + nativeFee;
    }
    
    function quoteSpecificChain(
        uint32 _dstEid,
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(_dstEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }
    
    function setAthenaClientContract(address _athenaClient) external onlyOwner {
        athenaClientContract = _athenaClient;
        emit ContractAddressSet("athenaClient", _athenaClient);
    }
    
    function setLowjcContract(address _lowjc) external onlyOwner {
        lowjcContract = _lowjc;
        emit ContractAddressSet("lowjc", _lowjc);
    }
    
    function updateNativeChainEid(uint32 _nativeChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        emit ChainEndpointUpdated("native", _nativeChainEid);
    }
    
    function updateMainChainEid(uint32 _mainChainEid) external onlyOwner {
        mainChainEid = _mainChainEid;
        emit ChainEndpointUpdated("main", _mainChainEid);
    }
    
    function updateThisLocalChainEid(uint32 _thisLocalChainEid) external onlyOwner {
        uint32 oldEid = thisLocalChainEid;
        thisLocalChainEid = _thisLocalChainEid;
        emit ThisLocalChainEidUpdated(oldEid, _thisLocalChainEid);
    }
    
    function updateChainEndpoints(uint32 _nativeChainEid, uint32 _mainChainEid, uint32 _thisLocalChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        mainChainEid = _mainChainEid;
        thisLocalChainEid = _thisLocalChainEid;
        emit ChainEndpointUpdated("native", _nativeChainEid);
        emit ChainEndpointUpdated("main", _mainChainEid);
        emit ThisLocalChainEidUpdated(thisLocalChainEid, _thisLocalChainEid);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}