// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Interface for OpenworkGenesis storage contract
interface IOpenworkGenesis {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
        string[] portfolioHashes;
    }
    
    struct Job {
        string id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        JobStatus status;
        string[] workSubmissions;
        uint256 totalPaid;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
    }

    // Profile management
    function setProfile(address user, string memory ipfsHash, address referrer) external;
    function addPortfolio(address user, string memory portfolioHash) external;
    function setJobRating(string memory jobId, address user, uint256 rating) external;
    
    // Getters
    function getProfile(address user) external view returns (Profile memory);
    function getJob(string memory jobId) external view returns (Job memory);
    function getUserRatings(address user) external view returns (uint256[] memory);
    function hasProfile(address user) external view returns (bool);
}

contract ProfileManager is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ==================== STATE VARIABLES ====================
    
    IOpenworkGenesis public genesis;
    address public bridge;
    
    // Track all profile users
    address[] private allProfileUsers;
    uint256 private profileCount;
    
    // ==================== EVENTS ====================
    
    event ProfileCreated(address indexed user, string ipfsHash, address indexed referrer);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event UserRated(string indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _bridge,
        address _genesis
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = _bridge;
        genesis = IOpenworkGenesis(_genesis);
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == address(bridge), "Only bridge");
        upgradeToAndCall(newImplementation, "");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = bridge;
        bridge = _bridge;
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    function setGenesis(address _genesis) external onlyOwner {
        address oldGenesis = address(genesis);
        genesis = IOpenworkGenesis(_genesis);
        emit GenesisUpdated(oldGenesis, _genesis);
    }
    
    // ==================== PROFILE MANAGEMENT ====================
    
    /**
     * @dev Create a user profile (called by bridge for cross-chain profile creation)
     * @param _user User address
     * @param _ipfsHash IPFS hash of profile data
     * @param _referrerAddress Referrer address (can be zero address)
     */
    function createProfile(
        address _user, 
        string memory _ipfsHash, 
        address _referrerAddress
    ) external {
        require(msg.sender == bridge, "Only bridge");
        require(_user != address(0), "Invalid user address");
        require(!genesis.hasProfile(_user), "Profile already exists");
        
        // Track profile
        allProfileUsers.push(_user);
        profileCount++;
        
        // Store in Genesis
        genesis.setProfile(_user, _ipfsHash, _referrerAddress);
        
        emit ProfileCreated(_user, _ipfsHash, _referrerAddress);
    }
    
    /**
     * @dev Add portfolio item to user profile (called by bridge)
     * @param _user User address
     * @param _portfolioHash IPFS hash of portfolio item
     */
    function addPortfolio(address _user, string memory _portfolioHash) external {
        require(msg.sender == bridge, "Only bridge");
        require(_user != address(0), "Invalid user address");
        require(genesis.hasProfile(_user), "Profile does not exist");
        
        genesis.addPortfolio(_user, _portfolioHash);
        
        emit PortfolioAdded(_user, _portfolioHash);
    }
    
    // ==================== RATING SYSTEM ====================
    
    /**
     * @dev Rate a user after job completion (called by bridge)
     * @param _rater Address of the person giving the rating
     * @param _jobId Job ID
     * @param _userToRate Address of user being rated
     * @param _rating Rating value (e.g., 1-5)
     */
    function rate(
        address _rater,
        string memory _jobId,
        address _userToRate,
        uint256 _rating
    ) external {
        require(msg.sender == bridge, "Only bridge");
        require(_rating > 0 && _rating <= 5, "Rating must be 1-5");
        
        // Get job from Genesis
        IOpenworkGenesis.Job memory job = genesis.getJob(_jobId);
        require(bytes(job.id).length != 0, "Job does not exist");
        
        // Verify authorization
        bool isAuthorized = false;
        if (_rater == job.jobGiver && _userToRate == job.selectedApplicant) {
            isAuthorized = true; // Job giver rating job taker
        } else if (_rater == job.selectedApplicant && _userToRate == job.jobGiver) {
            isAuthorized = true; // Job taker rating job giver
        }
        
        require(isAuthorized, "Not authorized to rate");
        
        // Store rating in Genesis
        genesis.setJobRating(_jobId, _userToRate, _rating);
        
        emit UserRated(_jobId, _rater, _userToRate, _rating);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    /**
     * @dev Get user profile
     */
    function getProfile(address _user) external view returns (
        address userAddress,
        string memory ipfsHash,
        address referrerAddress,
        string[] memory portfolioHashes
    ) {
        IOpenworkGenesis.Profile memory profile = genesis.getProfile(_user);
        return (
            profile.userAddress,
            profile.ipfsHash,
            profile.referrerAddress,
            profile.portfolioHashes
        );
    }
    
    /**
     * @dev Get total number of profiles
     */
    function getProfileCount() external view returns (uint256) {
        return profileCount;
    }
    
    /**
     * @dev Get profile by index
     */
    function getProfileByIndex(uint256 _index) external view returns (
        address userAddress,
        string memory ipfsHash,
        address referrerAddress,
        string[] memory portfolioHashes
    ) {
        require(_index < profileCount, "Index out of bounds");
        address userAddr = allProfileUsers[_index];
        IOpenworkGenesis.Profile memory profile = genesis.getProfile(userAddr);
        return (
            profile.userAddress,
            profile.ipfsHash,
            profile.referrerAddress,
            profile.portfolioHashes
        );
    }
    
    /**
     * @dev Get all profile user addresses
     */
    function getAllProfileUsers() external view returns (address[] memory) {
        return allProfileUsers;
    }
    
    /**
     * @dev Check if user has profile
     */
    function hasProfile(address _user) external view returns (bool) {
        return genesis.hasProfile(_user);
    }
    
    /**
     * @dev Get user's average rating
     */
    function getUserRating(address _user) external view returns (uint256) {
        uint256[] memory ratings = genesis.getUserRatings(_user);
        if (ratings.length == 0) {
            return 0;
        }
        
        uint256 totalRating = 0;
        for (uint i = 0; i < ratings.length; i++) {
            totalRating += ratings[i];
        }
        
        return totalRating / ratings.length;
    }
    
    /**
     * @dev Get all ratings for a user
     */
    function getUserRatings(address _user) external view returns (uint256[] memory) {
        return genesis.getUserRatings(_user);
    }
}
