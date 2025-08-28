// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IMinimalNativeOpenWorkJobContract {
    function createProfile(address user, string memory ipfsHash, address referrer) external;
}

/**
 * @title MinimalNativeBridge - Profile Reception Only
 * @dev Receives profile creation messages from local chains via LayerZero
 */
contract MinimalNativeBridge is OAppSender, OAppReceiver {
    
    // Contract address for routing incoming profile messages
    address public nativeOpenWorkJobContract;
    
    // Authorized local chains that can send messages
    mapping(uint32 => bool) public authorizedLocalChains;
    uint32[] public localChainEids;
    
    // Events
    event ProfileReceived(address indexed user, string ipfsHash, address referrer, uint32 sourceChain);
    event LocalChainAuthorized(uint32 indexed chainEid, bool authorized);
    event NativeContractSet(address indexed contractAddress);
    event MessageProcessed(string indexed functionName, uint32 indexed sourceChain, bool success);
    
    modifier onlyAuthorizedChain(uint32 _chainEid) {
        require(authorizedLocalChains[_chainEid], "Chain not authorized");
        _;
    }
    
    constructor(
        address _endpoint,
        address _owner
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
    }
    
    // Override the conflicting oAppVersion function
    function oAppVersion() public pure override(OAppReceiver, OAppSender) returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setNativeOpenWorkJobContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid contract address");
        nativeOpenWorkJobContract = _contract;
        emit NativeContractSet(_contract);
    }
    
    function authorizeLocalChain(uint32 _chainEid, bool _authorized) external onlyOwner {
        if (_authorized && !authorizedLocalChains[_chainEid]) {
            localChainEids.push(_chainEid);
        } else if (!_authorized && authorizedLocalChains[_chainEid]) {
            // Remove from array
            for (uint i = 0; i < localChainEids.length; i++) {
                if (localChainEids[i] == _chainEid) {
                    localChainEids[i] = localChainEids[localChainEids.length - 1];
                    localChainEids.pop();
                    break;
                }
            }
        }
        
        authorizedLocalChains[_chainEid] = _authorized;
        emit LocalChainAuthorized(_chainEid, _authorized);
    }
    
    // ==================== INCOMING MESSAGE HANDLING ====================
    
    /**
     * @dev Handle incoming LayerZero messages for profile creation
     * @param _origin Message origin information
     * @param _payload Message payload containing profile data
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /* _guid */,
        bytes calldata _payload,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) internal override onlyAuthorizedChain(_origin.srcEid) {
        
        // Decode the payload
        (string memory functionName, address user, string memory ipfsHash, address referrer) = 
            abi.decode(_payload, (string, address, string, address));
        
        bool success = false;
        
        // Route message based on function name
        if (keccak256(bytes(functionName)) == keccak256("createProfile")) {
            success = _handleCreateProfile(user, ipfsHash, referrer, _origin.srcEid);
        }
        
        emit MessageProcessed(functionName, _origin.srcEid, success);
    }
    
    /**
     * @dev Handle createProfile message
     * @param user User address creating profile
     * @param ipfsHash IPFS hash of profile data
     * @param referrer Referrer address
     * @param sourceChain Source chain EID
     * @return success Whether the operation succeeded
     */
    function _handleCreateProfile(
        address user,
        string memory ipfsHash,
        address referrer,
        uint32 sourceChain
    ) internal returns (bool success) {
        if (nativeOpenWorkJobContract == address(0)) {
            return false;
        }
        
        try IMinimalNativeOpenWorkJobContract(nativeOpenWorkJobContract)
            .createProfile(user, ipfsHash, referrer) {
            
            emit ProfileReceived(user, ipfsHash, referrer, sourceChain);
            return true;
            
        } catch {
            return false;
        }
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function isAuthorizedLocalChain(uint32 _chainEid) external view returns (bool) {
        return authorizedLocalChains[_chainEid];
    }
    
    function getAuthorizedLocalChains() external view returns (uint32[] memory) {
        return localChainEids;
    }
    
    function getNativeContract() external view returns (address) {
        return nativeOpenWorkJobContract;
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    /**
     * @dev Emergency withdrawal of ETH
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}