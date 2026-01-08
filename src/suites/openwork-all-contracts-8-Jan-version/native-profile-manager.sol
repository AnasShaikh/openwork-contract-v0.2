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
    function updateProfileIpfsHash(address user, string memory newIpfsHash) external;
    function updatePortfolioItem(address user, uint256 index, string memory newPortfolioHash) external;
    function removePortfolioItem(address user, uint256 index) external;
    
    // Getters
    function getProfile(address user) external view returns (Profile memory);
    function getJob(string memory jobId) external view returns (Job memory);
    function getUserRatings(address user) external view returns (uint256[] memory);
    function hasProfile(address user) external view returns (bool);
}

contract NativeProfileManager is 
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

    // Admin pattern
    mapping(address => bool) public admins;
    address public nativeDAO;

    // Storage gap for upgrade safety
    uint256[50] private __gap;

    // ==================== EVENTS ====================
    
    event ProfileCreated(address indexed user, string ipfsHash, address indexed referrer);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event UserRated(string indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);
    event ProfileUpdated(address indexed user, string newIpfsHash);
    event PortfolioItemUpdated(address indexed user, uint256 index, string newPortfolioHash);
    event PortfolioItemRemoved(address indexed user, uint256 index);
    event AdminUpdated(address indexed admin, bool status);
    event NativeDAOUpdated(address indexed oldDAO, address indexed newDAO);

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
        admins[_owner] = true;
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

    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || msg.sender == nativeDAO, "Auth");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    function setNativeDAO(address _nativeDAO) external onlyOwner {
        address oldDAO = nativeDAO;
        nativeDAO = _nativeDAO;
        emit NativeDAOUpdated(oldDAO, _nativeDAO);
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
    
    /**
     * @dev Update user profile IPFS hash (called by bridge)
     * @param _user User address
     * @param _newIpfsHash New IPFS hash of profile data
     */
    function updateProfile(address _user, string memory _newIpfsHash) external {
        require(msg.sender == bridge, "Only bridge");
        require(_user != address(0), "Invalid user address");
        require(genesis.hasProfile(_user), "Profile does not exist");
        require(bytes(_newIpfsHash).length > 0, "IPFS hash cannot be empty");
        
        genesis.updateProfileIpfsHash(_user, _newIpfsHash);
        
        emit ProfileUpdated(_user, _newIpfsHash);
    }
    
    /**
     * @dev Update specific portfolio item (called by bridge)
     * @param _user User address
     * @param _index Index of portfolio item to update
     * @param _newPortfolioHash New IPFS hash of portfolio item
     */
    function updatePortfolioItem(address _user, uint256 _index, string memory _newPortfolioHash) external {
        require(msg.sender == bridge, "Only bridge");
        require(_user != address(0), "Invalid user address");
        require(genesis.hasProfile(_user), "Profile does not exist");
        require(bytes(_newPortfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        genesis.updatePortfolioItem(_user, _index, _newPortfolioHash);
        
        emit PortfolioItemUpdated(_user, _index, _newPortfolioHash);
    }
    
    /**
     * @dev Remove portfolio item (called by bridge)
     * @param _user User address
     * @param _index Index of portfolio item to remove
     */
    function removePortfolioItem(address _user, uint256 _index) external {
        require(msg.sender == bridge, "Only bridge");
        require(_user != address(0), "Invalid user address");
        require(genesis.hasProfile(_user), "Profile does not exist");
        
        genesis.removePortfolioItem(_user, _index);
        
        emit PortfolioItemRemoved(_user, _index);
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
