// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ProfileGenesis
 * @dev Dedicated storage contract for profile, portfolio, and rating data only
 */
contract ProfileGenesis {
    
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
    
    // Profile data
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(address => address) public userReferrers;
    
    // Rating data
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;

    // ==================== EVENTS ====================
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ProfileUpdated(address indexed user, string newIpfsHash);
    event PortfolioItemUpdated(address indexed user, uint256 index, string newPortfolioHash);
    event PortfolioItemRemoved(address indexed user, uint256 index);

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
    
    constructor() {
        owner = msg.sender;
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

    // ==================== PROFILE SETTERS ====================
    
    function setProfile(
        address user,
        string memory ipfsHash,
        address referrer
    ) external onlyAuthorized {
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
}