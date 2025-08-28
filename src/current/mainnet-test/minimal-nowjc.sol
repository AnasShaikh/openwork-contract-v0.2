// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title MinimalNOWJC - Native Profile Storage Only
 * @dev Minimal native chain contract for receiving and storing profiles
 */
contract MinimalNativeOpenWorkJobContract is 
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
        uint256 createdAt;
        uint32 sourceChain; // Which chain the profile was created from
    }
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(uint32 => uint256) public profilesFromChain; // Count profiles from each chain
    uint256 public totalProfilesReceived;
    
    // Authorized bridge contract
    address public authorizedBridge;
    uint32 public nativeChainId;
    
    // Events
    event ProfileReceived(address indexed user, string ipfsHash, address referrer, uint32 sourceChain, uint256 timestamp);
    event BridgeAuthorized(address indexed bridge);
    event ProfileUpdated(address indexed user, string newIpfsHash);
    
    modifier onlyBridge() {
        require(msg.sender == authorizedBridge, "Only authorized bridge can call");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner,
        uint32 _nativeChainId,
        address _authorizedBridge
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        nativeChainId = _nativeChainId;
        authorizedBridge = _authorizedBridge;
        totalProfilesReceived = 0;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender(), "Unauthorized upgrade");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setAuthorizedBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Invalid bridge address");
        authorizedBridge = _bridge;
        emit BridgeAuthorized(_bridge);
    }
    
    // ==================== PROFILE MANAGEMENT ====================
    
    /**
     * @dev Create/receive profile from cross-chain message
     * @param user User address creating profile
     * @param ipfsHash IPFS hash of profile data
     * @param referrer Referrer address (can be address(0))
     */
    function createProfile(
        address user, 
        string memory ipfsHash, 
        address referrer
    ) external onlyBridge nonReentrant {
        require(user != address(0), "Invalid user address");
        require(bytes(ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        // For testing purposes, allow profile updates
        // In production, you might want to prevent overwriting
        if (hasProfile[user]) {
            // Update existing profile
            profiles[user].ipfsHash = ipfsHash;
            profiles[user].referrerAddress = referrer;
            emit ProfileUpdated(user, ipfsHash);
            return;
        }
        
        // Create new profile
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer,
            createdAt: block.timestamp,
            sourceChain: 0 // Will be set by bridge if available
        });
        
        hasProfile[user] = true;
        totalProfilesReceived++;
        
        emit ProfileReceived(user, ipfsHash, referrer, 0, block.timestamp);
    }
    
    /**
     * @dev Create profile with source chain information
     * @param user User address creating profile
     * @param ipfsHash IPFS hash of profile data
     * @param referrer Referrer address
     * @param sourceChain Chain ID where profile was originally created
     */
    function createProfileWithSource(
        address user,
        string memory ipfsHash,
        address referrer,
        uint32 sourceChain
    ) external onlyBridge nonReentrant {
        require(user != address(0), "Invalid user address");
        require(bytes(ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        if (hasProfile[user]) {
            // Update existing profile
            profiles[user].ipfsHash = ipfsHash;
            profiles[user].referrerAddress = referrer;
            profiles[user].sourceChain = sourceChain;
            emit ProfileUpdated(user, ipfsHash);
            return;
        }
        
        // Create new profile
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer,
            createdAt: block.timestamp,
            sourceChain: sourceChain
        });
        
        hasProfile[user] = true;
        totalProfilesReceived++;
        profilesFromChain[sourceChain]++;
        
        emit ProfileReceived(user, ipfsHash, referrer, sourceChain, block.timestamp);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    function getTotalProfilesReceived() external view returns (uint256) {
        return totalProfilesReceived;
    }
    
    function getProfilesFromChain(uint32 _chainId) external view returns (uint256) {
        return profilesFromChain[_chainId];
    }
    
    function getNativeChainId() external view returns (uint32) {
        return nativeChainId;
    }
    
    function getAuthorizedBridge() external view returns (address) {
        return authorizedBridge;
    }
    
    function checkProfileExists(address _user) external view returns (bool) {
        return hasProfile[_user];
    }
    
    /**
     * @dev Get profile basic info without full struct
     * @param _user User address
     * @return exists Whether profile exists
     * @return ipfsHash IPFS hash of profile
     * @return createdAt Creation timestamp
     * @return sourceChain Source chain ID
     */
    function getProfileInfo(address _user) external view returns (
        bool exists,
        string memory ipfsHash,
        uint256 createdAt,
        uint32 sourceChain
    ) {
        exists = hasProfile[_user];
        if (exists) {
            Profile memory profile = profiles[_user];
            ipfsHash = profile.ipfsHash;
            createdAt = profile.createdAt;
            sourceChain = profile.sourceChain;
        }
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