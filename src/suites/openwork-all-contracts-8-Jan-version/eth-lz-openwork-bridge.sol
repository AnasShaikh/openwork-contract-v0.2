// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IETHRewardsContract {
    function handleSyncClaimableRewards(address user, uint256 claimableAmount, uint32 sourceChain) external;
}

interface IETHOpenworkDAO {
    function handleSyncVotingPower(address user, uint256 totalRewards, uint32 sourceChain) external;
}

/// @title ETHLZOpenworkBridge
/// @notice LayerZero bridge on ETH Sepolia for cross-chain communication with Native chain
/// @dev Handles outgoing messages to Native chain and incoming reward/voting sync messages
///      Uses LayerZero V2 OApp pattern for omnichain messaging
contract ETHLZOpenworkBridge is OAppSender, OAppReceiver {
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;

    // Admin pattern
    mapping(address => bool) public admins;

    // Allowed source chains for incoming messages
    mapping(uint32 => bool) public allowedSourceChains;

    // Contract addresses for routing incoming messages
    address public mainDaoContract;
    address public rewardsContract;
    
    // Chain endpoint - Native chain where core contracts are deployed
    uint32 public nativeChainEid;
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainEndpointUpdated(string indexed chainType, uint32 newEid);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeCommandSent(uint32 indexed targetChain, address indexed targetProxy, address indexed newImplementation);
    event SourceChainAllowed(uint32 indexed eid, bool allowed);
    event AdminUpdated(address indexed admin, bool status);

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
        uint32 _nativeChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        nativeChainEid = _nativeChainEid;
        admins[_owner] = true;
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

    /// @notice Sends upgrade command to a contract on another chain via LayerZero
    /// @param _dstChainId LayerZero endpoint ID of the destination chain
    /// @param targetProxy Address of the proxy contract to upgrade on destination
    /// @param newImplementation Address of the new implementation contract
    /// @param _options LayerZero messaging options (gas limits, etc)
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

    
    /// @notice Get fee quote for sending an upgrade command
    /// @param targetChainId LayerZero endpoint ID of target chain
    /// @param targetProxy Proxy contract to upgrade
    /// @param newImplementation New implementation address
    /// @return fee Native token fee required for the message
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
        IETHRewardsContract(rewardsContract).handleSyncClaimableRewards(user, claimableAmount, _origin.srcEid);
        }

        else if (keccak256(bytes(functionName)) == keccak256(bytes("syncVotingPower"))) {
        require(mainDaoContract != address(0), "Main DAO contract not set");
        (, address user, uint256 totalRewards) = abi.decode(_message, (string, address, uint256));
        IETHOpenworkDAO(mainDaoContract).handleSyncVotingPower(user, totalRewards, _origin.srcEid);
        }
            
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }
    
    // ==================== BRIDGE FUNCTIONS ====================

    /// @notice Send a message to the Native chain (Arbitrum)
    /// @param _functionName Name of the function to call on destination
    /// @param _payload ABI-encoded message data
    /// @param _options LayerZero messaging options
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
    
    /// @notice Send a message to a specific chain by endpoint ID
    /// @param _functionName Name of the function to call on destination
    /// @param _dstEid LayerZero endpoint ID of destination chain
    /// @param _payload ABI-encoded message data
    /// @param _options LayerZero messaging options
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
    
    /// @notice Send messages to two chains in a single transaction
    /// @param _functionName Name of the function to call on destinations
    /// @param _dstEid1 LayerZero endpoint ID of first destination chain
    /// @param _dstEid2 LayerZero endpoint ID of second destination chain
    /// @param _payload1 ABI-encoded message data for first chain
    /// @param _payload2 ABI-encoded message data for second chain
    /// @param _options1 LayerZero messaging options for first chain
    /// @param _options2 LayerZero messaging options for second chain
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
    
    /// @notice Send messages to three chains in a single transaction
    /// @param _functionName Name of the function to call on destinations
    /// @param _dstEid1 LayerZero endpoint ID of first destination chain
    /// @param _dstEid2 LayerZero endpoint ID of second destination chain
    /// @param _dstEid3 LayerZero endpoint ID of third destination chain
    /// @param _payload1 ABI-encoded message data for first chain
    /// @param _payload2 ABI-encoded message data for second chain
    /// @param _payload3 ABI-encoded message data for third chain
    /// @param _options1 LayerZero messaging options for first chain
    /// @param _options2 LayerZero messaging options for second chain
    /// @param _options3 LayerZero messaging options for third chain
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

    /// @notice Get fee quote for sending a message to Native chain
    /// @param _payload ABI-encoded message data
    /// @param _options LayerZero messaging options
    /// @return fee Native token fee required
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(nativeChainEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    /// @notice Get fee quote for sending a message to a specific chain
    /// @param _dstEid LayerZero endpoint ID of destination chain
    /// @param _payload ABI-encoded message data
    /// @param _options LayerZero messaging options
    /// @return fee Native token fee required
    function quoteSpecificChain(
        uint32 _dstEid,
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(_dstEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    /// @notice Get fee quote for sending messages to two chains
    /// @param _dstEid1 LayerZero endpoint ID of first destination chain
    /// @param _dstEid2 LayerZero endpoint ID of second destination chain
    /// @param _payload1 ABI-encoded message data for first chain
    /// @param _payload2 ABI-encoded message data for second chain
    /// @param _options1 LayerZero messaging options for first chain
    /// @param _options2 LayerZero messaging options for second chain
    /// @return totalFee Combined fee for both messages
    /// @return fee1 Fee for first chain message
    /// @return fee2 Fee for second chain message
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
    
    /// @notice Get fee quote for sending messages to three chains
    /// @param _dstEid1 LayerZero endpoint ID of first destination chain
    /// @param _dstEid2 LayerZero endpoint ID of second destination chain
    /// @param _dstEid3 LayerZero endpoint ID of third destination chain
    /// @param _payload1 ABI-encoded message data for first chain
    /// @param _payload2 ABI-encoded message data for second chain
    /// @param _payload3 ABI-encoded message data for third chain
    /// @param _options1 LayerZero messaging options for first chain
    /// @param _options2 LayerZero messaging options for second chain
    /// @param _options3 LayerZero messaging options for third chain
    /// @return totalFee Combined fee for all messages
    /// @return fee1 Fee for first chain message
    /// @return fee2 Fee for second chain message
    /// @return fee3 Fee for third chain message
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

    /// @notice Set admin status for an address
    /// @param _admin Address to modify
    /// @param _status True to grant admin, false to revoke
    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || msg.sender == mainDaoContract, "Auth");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    /// @notice Authorize a contract to use this bridge for sending messages
    /// @param _contract Contract address to authorize
    /// @param _authorized True to authorize, false to revoke
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }

    /// @notice Allow or disallow a source chain for incoming messages
    /// @param _eid LayerZero endpoint ID of the source chain
    /// @param _allowed True to allow, false to block
    function setAllowedSourceChain(uint32 _eid, bool _allowed) external onlyOwner {
        allowedSourceChains[_eid] = _allowed;
        emit SourceChainAllowed(_eid, _allowed);
    }
    
    /// @notice Set the Main DAO contract address for routing messages
    /// @param _mainDao Address of the ETHOpenworkDAO contract
    function setMainDaoContract(address _mainDao) external onlyOwner {
        require(_mainDao != address(0), "Invalid main DAO address");
        mainDaoContract = _mainDao;
        emit ContractAddressSet("mainDao", _mainDao);
    }
    
    /// @notice Set the Rewards contract address for routing messages
    /// @param _rewards Address of the ETHRewardsContract
    function setRewardsContract(address _rewards) external onlyOwner {
        rewardsContract = _rewards;
        emit ContractAddressSet("rewards", _rewards);
    }
    
    /// @notice Update the Native chain endpoint ID
    /// @param _nativeChainEid New LayerZero endpoint ID for Native chain
    function updateNativeChainEid(uint32 _nativeChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        emit ChainEndpointUpdated("native", _nativeChainEid);
    }

    /// @notice Withdraw accumulated ETH from the contract
    /// @dev Used to recover ETH sent for LayerZero fees
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }
}