// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ProfileGenesis
 * @dev Dedicated storage contract for profile, portfolio, and rating data only
 */
contract NativeProfileGenesis is Initializable, UUPSUpgradeable {
    
    // ==================== STRUCTS ====================
    
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
        string[] portfolioHashes;
    }

    // ==================== STATE VARIABLES ====================

    // Access control
    mapping(address => bool) public authorizedContracts;
    address public owner;

    // Governance/Admin pattern
    mapping(address => bool) public admins;
    address public nativeDAO;
    
    // Profile data
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(address => address) public userReferrers;
    
    // Rating data
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    
    // Profile tracking
    address[] private allProfileAddresses;
    mapping(address => uint256) private profileAddressIndex;
    uint256 private profileCount;

    // Storage gap for upgrade safety
    uint256[50] private __gap;

    // ==================== EVENTS ====================
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ProfileUpdated(address indexed user, string newIpfsHash);
    event PortfolioItemUpdated(address indexed user, uint256 index, string newPortfolioHash);
    event PortfolioItemRemoved(address indexed user, uint256 index);
    event AdminUpdated(address indexed admin, bool status);
    event NativeDAOUpdated(address indexed oldDAO, address indexed newDAO);

    // ==================== MODIFIERS ====================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ==================== INITIALIZER ====================
    
    function initialize(address _owner) public initializer {
        __UUPSUpgradeable_init();
        owner = _owner;
        admins[_owner] = true;
    }

    // ==================== UPGRADE AUTHORIZATION ====================
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(msg.sender == owner, "Not owner");
    }

    // ==================== ACCESS CONTROL ====================
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }

    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner || msg.sender == nativeDAO, "Auth");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    function setNativeDAO(address _nativeDAO) external onlyOwner {
        address oldDAO = nativeDAO;
        nativeDAO = _nativeDAO;
        emit NativeDAOUpdated(oldDAO, _nativeDAO);
    }

    // ==================== PROFILE SETTERS ====================
    
    function setProfile(
        address user,
        string memory ipfsHash,
        address referrer
    ) external onlyAuthorized {
        // Track new profile
        if (!hasProfile[user]) {
            allProfileAddresses.push(user);
            profileAddressIndex[user] = profileCount;
            profileCount++;
        }
        
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer,
            portfolioHashes: new string[](0)
        });
        hasProfile[user] = true;
        if (referrer != address(0)) {
            userReferrers[user] = referrer;
        }
    }
    
    function addPortfolio(address user, string memory portfolioHash) external onlyAuthorized {
        require(hasProfile[user], "Profile does not exist");
        profiles[user].portfolioHashes.push(portfolioHash);
    }
    
    function updateProfileIpfsHash(address user, string memory newIpfsHash) external onlyAuthorized {
        require(hasProfile[user], "Profile does not exist");
        profiles[user].ipfsHash = newIpfsHash;
        emit ProfileUpdated(user, newIpfsHash);
    }
    
    function updatePortfolioItem(address user, uint256 index, string memory newPortfolioHash) external onlyAuthorized {
        require(hasProfile[user], "Profile does not exist");
        require(index < profiles[user].portfolioHashes.length, "Portfolio index out of bounds");
        profiles[user].portfolioHashes[index] = newPortfolioHash;
        emit PortfolioItemUpdated(user, index, newPortfolioHash);
    }
    
    function removePortfolioItem(address user, uint256 index) external onlyAuthorized {
        require(hasProfile[user], "Profile does not exist");
        require(index < profiles[user].portfolioHashes.length, "Portfolio index out of bounds");
        
        // Move last element to the index being removed and pop
        uint256 lastIndex = profiles[user].portfolioHashes.length - 1;
        if (index != lastIndex) {
            profiles[user].portfolioHashes[index] = profiles[user].portfolioHashes[lastIndex];
        }
        profiles[user].portfolioHashes.pop();
        emit PortfolioItemRemoved(user, index);
    }

    // ==================== RATING SETTERS ====================
    
    function setJobRating(string memory jobId, address user, uint256 rating) external onlyAuthorized {
        jobRatings[jobId][user] = rating;
        userRatings[user].push(rating);
    }

    // ==================== GETTERS ====================
    
    function getProfile(address user) external view returns (Profile memory) {
        return profiles[user];
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    function getUserRatings(address user) external view returns (uint256[] memory) {
        return userRatings[user];
    }
    
    function getJobRating(string memory jobId, address user) external view returns (uint256) {
        return jobRatings[jobId][user];
    }
    
    /**
     * @dev Get total number of profiles
     */
    function getProfileCount() external view returns (uint256) {
        return profileCount;
    }
    
    /**
     * @dev Get all profile addresses
     * @notice May fail with too many profiles due to gas limits. Use getProfileAddressesBatch for large datasets.
     */
    function getAllProfileAddresses() external view returns (address[] memory) {
        return allProfileAddresses;
    }
    
    /**
     * @dev Get profile addresses in batches for pagination
     * @param startIndex Starting index in the array
     * @param count Number of addresses to return
     * @return addresses Array of profile addresses for the requested range
     */
    function getProfileAddressesBatch(uint256 startIndex, uint256 count) external view returns (address[] memory addresses) {
        require(startIndex < profileCount, "Start index out of bounds");
        
        // Calculate actual count to return (handle edge case where count exceeds remaining items)
        uint256 remaining = profileCount - startIndex;
        uint256 actualCount = count > remaining ? remaining : count;
        
        addresses = new address[](actualCount);
        for (uint256 i = 0; i < actualCount; i++) {
            addresses[i] = allProfileAddresses[startIndex + i];
        }
        
        return addresses;
    }
}
