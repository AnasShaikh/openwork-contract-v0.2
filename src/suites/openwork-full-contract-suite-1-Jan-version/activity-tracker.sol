// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title ActivityTracker
 * @notice Tracks oracle member activity and oracle active status
 * @dev Separated from Genesis due to contract size limits (EIP-170: 24KB)
 *
 * This contract stores:
 * - memberLastActivity: When each oracle member last participated (voted/proposed)
 * - oracleActiveStatus: Whether each oracle has enough active members
 *
 * Activity tracking enables the system to:
 * 1. Ensure oracles have engaged members (90-day activity threshold)
 * 2. Prevent disputes from going to stale/inactive oracles
 * 3. Incentivize ongoing participation from oracle members
 *
 * Authorized callers:
 * - NativeAthena: Updates member activity on voting, sets oracle status
 * - NativeDAO: Updates member activity on governance actions
 * - OracleManager: Initializes member activity when adding to oracles
 */
contract ActivityTracker is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ==================== STORAGE ====================

    /// @notice Timestamp of last activity for each oracle member
    /// @dev Updated when member votes or proposes; 0 = never active
    mapping(address => uint256) public memberLastActivity;

    /// @notice Whether each oracle is considered "active" (has enough active members)
    /// @dev Set by NativeAthena.updateOracleActiveStatus() based on member activity
    mapping(string => bool) public oracleActiveStatus;

    /// @notice Addresses authorized to update activity data
    /// @dev NativeAthena, NativeDAO, OracleManager
    mapping(address => bool) public authorizedCallers;

    /// @notice Addresses authorized to upgrade the contract
    mapping(address => bool) public admins;

    // Storage gap for future upgrades (50 slots)
    uint256[50] private __gap;

    // ==================== EVENTS ====================

    /// @notice Emitted when a member's activity timestamp is updated
    event MemberActivityUpdated(address indexed member, uint256 timestamp);

    /// @notice Emitted when a new member's activity is initialized (first time only)
    event MemberActivityInitialized(address indexed member, uint256 timestamp);

    /// @notice Emitted when an oracle's active status changes
    event OracleActiveStatusUpdated(string indexed oracleName, bool isActive);

    /// @notice Emitted when an authorized caller is added or removed
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);

    /// @notice Emitted when an admin is added or removed
    event AdminUpdated(address indexed admin, bool status);

    /// @notice Emitted when ActivityTracker reference is set on another contract
    event ActivityTrackerConfigured(address indexed targetContract);

    // ==================== MODIFIERS ====================

    /// @notice Restricts function to authorized callers or owner
    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    /// @notice Restricts function to admins or owner
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner(), "Not admin");
        _;
    }

    // ==================== INITIALIZATION ====================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _owner Address that will own the contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        admins[_owner] = true;
    }

    /// @notice Authorize upgrade (admin only)
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(admins[msg.sender], "Not admin");
    }

    // ==================== AUTHORIZED FUNCTIONS ====================

    /// @notice Update a member's last activity timestamp to current time
    /// @dev Called by NativeAthena and NativeDAO when member votes/proposes
    /// @param member Address of the oracle member
    function updateMemberActivity(address member) external onlyAuthorized {
        memberLastActivity[member] = block.timestamp;
        emit MemberActivityUpdated(member, block.timestamp);
    }

    /// @notice Batch update multiple members' activity timestamps
    /// @dev Gas-efficient for updating many members at once
    /// @param members Array of member addresses to update
    function updateMemberActivities(address[] calldata members) external onlyAuthorized {
        uint256 timestamp = block.timestamp;
        for (uint256 i = 0; i < members.length; i++) {
            memberLastActivity[members[i]] = timestamp;
            emit MemberActivityUpdated(members[i], timestamp);
        }
    }

    /// @notice Initialize a member's activity timestamp (only if not already set)
    /// @dev Called by OracleManager when adding new members to oracles
    /// @dev Only sets if member has no prior activity (lastActivity == 0)
    /// @param member Address of the member to initialize
    function initializeMemberActivity(address member) external onlyAuthorized {
        if (memberLastActivity[member] == 0) {
            memberLastActivity[member] = block.timestamp;
            emit MemberActivityInitialized(member, block.timestamp);
        }
    }

    /// @notice Batch initialize multiple members' activity timestamps
    /// @dev Called by OracleManager when creating oracles with multiple members
    /// @param members Array of member addresses to initialize
    function initializeMemberActivities(address[] calldata members) external onlyAuthorized {
        uint256 timestamp = block.timestamp;
        for (uint256 i = 0; i < members.length; i++) {
            if (memberLastActivity[members[i]] == 0) {
                memberLastActivity[members[i]] = timestamp;
                emit MemberActivityInitialized(members[i], timestamp);
            }
        }
    }

    /// @notice Set an oracle's active status
    /// @dev Called by NativeAthena.updateOracleActiveStatus() after counting active members
    /// @param oracleName Name of the oracle
    /// @param isActive Whether the oracle is active (has enough active members)
    function setOracleActiveStatus(string memory oracleName, bool isActive) external onlyAuthorized {
        oracleActiveStatus[oracleName] = isActive;
        emit OracleActiveStatusUpdated(oracleName, isActive);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /// @notice Add or remove an authorized caller
    /// @dev Authorized callers can update member activity and oracle status
    /// @param caller Address to authorize or deauthorize
    /// @param authorized True to authorize, false to deauthorize
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /// @notice Add or remove an admin
    /// @dev Admins can upgrade the contract
    /// @param admin Address to add or remove as admin
    /// @param status True to add as admin, false to remove
    function setAdmin(address admin, bool status) external onlyOwner {
        admins[admin] = status;
        emit AdminUpdated(admin, status);
    }

    /// @notice Emergency override to set a member's activity timestamp
    /// @dev Owner only - use for data corrections or bootstrapping existing members
    /// @param member Address of the member
    /// @param timestamp Timestamp to set (use current timestamp for "active now")
    function setMemberActivityOverride(address member, uint256 timestamp) external onlyOwner {
        memberLastActivity[member] = timestamp;
        emit MemberActivityUpdated(member, timestamp);
    }

    /// @notice Batch emergency override for multiple members
    /// @dev Owner only - useful for initializing multiple existing oracle members
    /// @param members Array of member addresses
    /// @param timestamp Timestamp to set for all members
    function setMemberActivitiesOverride(address[] calldata members, uint256 timestamp) external onlyOwner {
        for (uint256 i = 0; i < members.length; i++) {
            memberLastActivity[members[i]] = timestamp;
            emit MemberActivityUpdated(members[i], timestamp);
        }
    }

    /// @notice Emergency override to set an oracle's active status
    /// @dev Owner only - use to force oracle active/inactive for testing or emergencies
    /// @param oracleName Name of the oracle
    /// @param isActive Status to set
    function setOracleActiveStatusOverride(string memory oracleName, bool isActive) external onlyOwner {
        oracleActiveStatus[oracleName] = isActive;
        emit OracleActiveStatusUpdated(oracleName, isActive);
    }

    // ==================== VIEW FUNCTIONS ====================

    /// @notice Check if an address is an authorized caller
    /// @param caller Address to check
    /// @return True if authorized
    function isAuthorized(address caller) external view returns (bool) {
        return authorizedCallers[caller] || caller == owner();
    }

    /// @notice Check if an address is an admin
    /// @param admin Address to check
    /// @return True if admin
    function isAdmin(address admin) external view returns (bool) {
        return admins[admin] || admin == owner();
    }

    /// @notice Get multiple members' activity timestamps in one call
    /// @param members Array of member addresses
    /// @return timestamps Array of activity timestamps (0 = never active)
    function getMemberActivities(address[] calldata members) external view returns (uint256[] memory timestamps) {
        timestamps = new uint256[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            timestamps[i] = memberLastActivity[members[i]];
        }
    }
}
