// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalNativeOpenWorkJobContract is OAppReceiver {
    
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
    }
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    
    // User referrer mapping for rewards calculation
    mapping(address => address) public userReferrers;
    
    // Track which chains can send profile creation messages
    mapping(uint32 => bool) public authorizedChains;
    
    // Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer, uint32 indexed sourceChain);
    event CrossChainProfileReceived(address indexed user, string ipfsHash, address referrer, uint32 sourceChain);
    event AuthorizedChainUpdated(uint32 indexed chainEid, bool authorized);
    
    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) Ownable(_owner) {}
    
    /**
     * @notice Set authorized chains that can send profile creation messages
     * @param _chainEid Chain endpoint ID
     * @param _authorized Whether the chain is authorized
     */
    function setAuthorizedChain(uint32 _chainEid, bool _authorized) external onlyOwner {
        authorizedChains[_chainEid] = _authorized;
        emit AuthorizedChainUpdated(_chainEid, _authorized);
    }
    
    /**
     * @notice Handle incoming LayerZero messages
     * @param _origin Origin information containing source chain and sender
     * @param _message Encoded profile data
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used)
        bytes calldata // _extraData (not used)
    ) internal override {
        // Verify the source chain is authorized
        require(authorizedChains[_origin.srcEid], "Unauthorized source chain");
        
        // Decode profile data
        (address user, string memory ipfsHash, address referrer) = abi.decode(_message, (address, string, address));
        
        // Process profile creation
        _createProfile(user, ipfsHash, referrer, _origin.srcEid);
        
        emit CrossChainProfileReceived(user, ipfsHash, referrer, _origin.srcEid);
    }
    
    /**
     * @notice Internal function to create profile
     * @param user User address
     * @param ipfsHash IPFS hash of profile data
     * @param referrer Referrer address (can be address(0))
     * @param sourceChain Source chain that sent the message
     */
    function _createProfile(address user, string memory ipfsHash, address referrer, uint32 sourceChain) internal {
        require(user != address(0), "Invalid user address");
        require(!hasProfile[user], "Profile already exists");
        
        // Create profile
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer
        });
        
        hasProfile[user] = true;
        
        // Store referrer for rewards calculation
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, ipfsHash, referrer, sourceChain);
    }
    
    /**
     * @notice Local profile creation function (for testing or direct calls)
     * @param user User address
     * @param ipfsHash IPFS hash of profile data
     * @param referrer Referrer address
     */
    function createProfile(address user, string memory ipfsHash, address referrer) external {
        require(user != address(0), "Invalid user address");
        require(!hasProfile[user], "Profile already exists");
        
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer
        });
        
        hasProfile[user] = true;
        
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, ipfsHash, referrer, 0); // 0 indicates local creation
    }
    
    // View functions
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    function isChainAuthorized(uint32 chainEid) external view returns (bool) {
        return authorizedChains[chainEid];
    }
}