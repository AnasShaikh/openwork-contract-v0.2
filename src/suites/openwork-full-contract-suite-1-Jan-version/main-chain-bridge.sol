// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IRewardsContract {
    function handleSyncClaimableRewards(address user, uint256 claimableAmount, uint32 sourceChain) external;
}

interface IMainDAO {
    function handleSyncVotingPower(address user, uint256 totalRewards, uint32 sourceChain) external;
}

contract ThirdChainBridge is OAppSender, OAppReceiver {
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;

    // Allowed source chains for incoming messages
    mapping(uint32 => bool) public allowedSourceChains;

    // Contract addresses for routing incoming messages
    address public mainDaoContract;
    address public rewardsContract;
    
    // Chain endpoints - this bridge handles multiple destination chains
    uint32 public nativeChainEid;      // Chain where Native contracts are deployed
    uint32 public athenaClientChainEid; // Chain where AthenaClient is deployed
    uint32 public lowjcChainEid;       // Chain where LOWJC is deployed
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainEndpointUpdated(string indexed chainType, uint32 newEid);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeCommandSent(uint32 indexed targetChain, address indexed targetProxy, address indexed newImplementation);
    event SourceChainAllowed(uint32 indexed eid, bool allowed);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    modifier onlyMainDAO() {
        require(msg.sender == mainDaoContract, "Only Main DAO can call this function");
        _;
    }
    
    constructor(
        address _endpoint,
        address _owner,
        uint32 _nativeChainEid,
        uint32 _athenaClientChainEid,
        uint32 _lowjcChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        nativeChainEid = _nativeChainEid;
        athenaClientChainEid = _athenaClientChainEid;
        lowjcChainEid = _lowjcChainEid;
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
    
function sendUpgradeCommand(
    uint32 _dstChainId,
    address targetProxy,
    address newImplementation,
    bytes calldata _options
) external payable onlyMainDAO {
    // encode the call for the receiving side
    bytes memory payload = abi.encode("upgradeFromDAO", targetProxy, newImplementation);

    // note: include the refund address as the 5th arg
    _lzSend(
        uint16(_dstChainId),        // destination chain ID
        payload,                    // payload
        _options,                   // adapterParams/options
        MessagingFee(msg.value, 0), // fee struct (amount, unused)
        payable(msg.sender)         // refund excess gas/eth back to caller
    );

    emit UpgradeCommandSent(_dstChainId, targetProxy, newImplementation);
}

    
    function quoteUpgradeCommand(
        uint32 targetChainId,
        address targetProxy,
        address newImplementation
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode("upgradeContract", targetProxy, newImplementation);
        MessagingFee memory msgFee = _quote(targetChainId, payload, bytes(""), false);
        return msgFee.nativeFee;
    }
    
    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used)
        bytes calldata // _extraData (not used)
    ) internal override {
        require(allowedSourceChains[_origin.srcEid], "Unauthorized source");
        (string memory functionName) = abi.decode(_message, (string));
        
        // ==================== UPGRADE HANDLING ====================
        if (keccak256(bytes(functionName)) == keccak256(bytes("upgradeContract"))) {
            // This should never be called on main chain bridge
            // Upgrade commands are sent FROM here, not TO here
            revert("Upgrade commands should originate from Main DAO, not be received");
        }
        
        // ==================== REWARDS CONTRACT MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("syncClaimableRewards"))) {
        require(rewardsContract != address(0), "Rewards contract not set");
        (, address user, uint256 claimableAmount) = abi.decode(_message, (string, address, uint256));
        IRewardsContract(rewardsContract).handleSyncClaimableRewards(user, claimableAmount, _origin.srcEid);
        }

        else if (keccak256(bytes(functionName)) == keccak256(bytes("syncVotingPower"))) {
        require(mainDaoContract != address(0), "Main DAO contract not set");
        (, address user, uint256 totalRewards) = abi.decode(_message, (string, address, uint256));
        IMainDAO(mainDaoContract).handleSyncVotingPower(user, totalRewards, _origin.srcEid);
        }
            
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
    
    function sendToTwoChains(
        string memory _functionName,
        uint32 _dstEid1,
        uint32 _dstEid2,
        bytes memory _payload1,
        bytes memory _payload2,
        bytes calldata _options1,
        bytes calldata _options2
    ) external payable onlyAuthorized {
        // Calculate total fees upfront
        MessagingFee memory fee1 = _quote(_dstEid1, _payload1, _options1, false);
        MessagingFee memory fee2 = _quote(_dstEid2, _payload2, _options2, false);
        uint256 totalFee = fee1.nativeFee + fee2.nativeFee;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to first chain
        _lzSend(
            _dstEid1,
            _payload1,
            _options1,
            fee1,
            payable(msg.sender)
        );
        
        // Send to second chain
        _lzSend(
            _dstEid2,
            _payload2,
            _options2,
            fee2,
            payable(msg.sender)
        );
        
        emit CrossChainMessageSent(_functionName, _dstEid1, _payload1);
        emit CrossChainMessageSent(_functionName, _dstEid2, _payload2);
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
    
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(nativeChainEid, _payload, _options, false);
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
    
    function quoteTwoChains(
        uint32 _dstEid1,
        uint32 _dstEid2,
        bytes calldata _payload1,
        bytes calldata _payload2,
        bytes calldata _options1,
        bytes calldata _options2
    ) external view returns (uint256 totalFee, uint256 fee1, uint256 fee2) {
        MessagingFee memory msgFee1 = _quote(_dstEid1, _payload1, _options1, false);
        MessagingFee memory msgFee2 = _quote(_dstEid2, _payload2, _options2, false);
        
        fee1 = msgFee1.nativeFee;
        fee2 = msgFee2.nativeFee;
        totalFee = fee1 + fee2;
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

    function setAllowedSourceChain(uint32 _eid, bool _allowed) external onlyOwner {
        allowedSourceChains[_eid] = _allowed;
        emit SourceChainAllowed(_eid, _allowed);
    }
    
    function setMainDaoContract(address _mainDao) external onlyOwner {
        require(_mainDao != address(0), "Invalid main DAO address");
        mainDaoContract = _mainDao;
        emit ContractAddressSet("mainDao", _mainDao);
    }
    
    function setRewardsContract(address _rewards) external onlyOwner {
        rewardsContract = _rewards;
        emit ContractAddressSet("rewards", _rewards);
    }
    
    function updateNativeChainEid(uint32 _nativeChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        emit ChainEndpointUpdated("native", _nativeChainEid);
    }
    
    function updateAthenaClientChainEid(uint32 _athenaClientChainEid) external onlyOwner {
        athenaClientChainEid = _athenaClientChainEid;
        emit ChainEndpointUpdated("athenaClient", _athenaClientChainEid);
    }
    
    function updateLowjcChainEid(uint32 _lowjcChainEid) external onlyOwner {
        lowjcChainEid = _lowjcChainEid;
        emit ChainEndpointUpdated("lowjc", _lowjcChainEid);
    }
    
    function updateChainEndpoints(uint32 _nativeChainEid, uint32 _athenaClientChainEid, uint32 _lowjcChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        athenaClientChainEid = _athenaClientChainEid;
        lowjcChainEid = _lowjcChainEid;
        emit ChainEndpointUpdated("native", _nativeChainEid);
        emit ChainEndpointUpdated("athenaClient", _athenaClientChainEid);
        emit ChainEndpointUpdated("lowjc", _lowjcChainEid);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}