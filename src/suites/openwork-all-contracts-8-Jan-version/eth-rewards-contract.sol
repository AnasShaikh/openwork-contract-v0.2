// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IETHOpenworkDAO {
    function handleUpdateStakeDataFromRewards(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external;
}

interface IETHLZOpenworkBridge {
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;

    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
}

/**
 * @title MainRewardsContract (Non-Upgradeable)
 * @notice Handles token distribution and claiming on the main chain
 * @dev This contract is NOT upgradeable - changes are permanent after deployment
 *
 * SECURITY FEATURES:
 * - emergencyUpdateUserBalance can only INCREASE balances (no stealing)
 * - emergencyWithdraw available (transfer ownership to multisig for safety)
 * - No upgrade functions
 */
contract ETHRewardsContract is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IERC20 public openworkToken;
    IETHOpenworkDAO public mainDAO;
    IETHLZOpenworkBridge public bridge;

    // User referrer mapping
    mapping(address => address) public userReferrers;

    // Simplified rewards tracking - just claimable balances
    mapping(address => uint256) public userClaimableBalance;
    mapping(address => uint256) public userTotalClaimed;
    mapping(address => uint256) public userTotalUnlocked; // SECURITY FIX: Track total unlocked to prevent double-claims

    // Cross-chain tracking
    mapping(uint32 => bool) public authorizedChains;
    mapping(uint32 => string) public chainNames;

    // Admin pattern
    mapping(address => bool) public admins;

    // Events
    event ProfileCreated(address indexed user, address indexed referrer, uint32 indexed sourceChain);
    event ClaimableBalanceUpdated(address indexed user, uint256 newBalance, uint32 indexed sourceChain);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ContractUpdated(string contractType, address newAddress);
    event AuthorizedChainUpdated(uint32 indexed chainEid, bool authorized, string chainName);
    event StakeDataForwarded(address indexed staker, bool isActive);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event EmergencyBalanceIncrease(address indexed user, uint256 oldBalance, uint256 newBalance);
    event AdminUpdated(address indexed admin, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _openworkToken, address _bridge) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        openworkToken = IERC20(_openworkToken);
        bridge = IETHLZOpenworkBridge(_bridge);
        admins[_owner] = true;
        _initializeAuthorizedChains();
    }

    // ==================== MESSAGE HANDLERS ====================

    function handleCreateProfile(address user, address referrer, uint32 sourceChain) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        _createProfile(user, referrer, sourceChain);
    }

    function handleStakeDataUpdate(address staker, uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive, uint32 /* sourceChain */) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");

        // Forward to Main DAO locally
        if (address(mainDAO) != address(0)) {
            try mainDAO.handleUpdateStakeDataFromRewards(staker, amount, unlockTime, durationMinutes, isActive) {
                emit StakeDataForwarded(staker, isActive);
            } catch {
                // Log error but don't revert to avoid blocking other messages
            }
        }
    }

    /**
     * @dev Handle sync of rewards from native chain
     * SECURITY FIX: Now receives total unlocked (not claimable) and calculates claimable
     * This prevents double-claims when callbacks fail by using totalClaimed as source of truth
     */
    function handleSyncClaimableRewards(
        address user,
        uint256 totalUnlocked,
        uint32 sourceChain
    ) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");

        // Store total unlocked tokens
        userTotalUnlocked[user] = totalUnlocked;

        // Calculate claimable = totalUnlocked - totalClaimed
        // This prevents double-claims even when native callbacks fail
        uint256 claimable = totalUnlocked > userTotalClaimed[user] ?
            totalUnlocked - userTotalClaimed[user] : 0;

        userClaimableBalance[user] = claimable;

        emit ClaimableBalanceUpdated(user, claimable, sourceChain);
    }

    // ==================== ADMIN FUNCTIONS ====================

    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = address(bridge);
        bridge = IETHLZOpenworkBridge(_bridge);
        emit BridgeUpdated(oldBridge, _bridge);
    }

    function setOpenworkToken(address _token) external onlyOwner {
        openworkToken = IERC20(_token);
        emit ContractUpdated("OpenworkToken", _token);
    }

    function setMainDAO(address _mainDAO) external onlyOwner {
        mainDAO = IETHOpenworkDAO(_mainDAO);
        emit ContractUpdated("MainDAO", _mainDAO);
    }

    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || msg.sender == address(mainDAO), "Auth");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    // ==================== CROSS-CHAIN SETUP FUNCTIONS ====================

    function _initializeAuthorizedChains() private {
        // Authorize common testnets by default
        authorizedChains[40161] = true; // ETH Sepolia
        authorizedChains[40232] = true; // OP Sepolia
        authorizedChains[40231] = true; // Arbitrum Sepolia

        chainNames[40161] = "Ethereum Sepolia";
        chainNames[40232] = "Optimism Sepolia";
        chainNames[40231] = "Arbitrum Sepolia";
    }

    function updateAuthorizedChain(uint32 _chainEid, bool _authorized, string memory _chainName) external onlyOwner {
        authorizedChains[_chainEid] = _authorized;
        if (_authorized && bytes(_chainName).length > 0) {
            chainNames[_chainEid] = _chainName;
        }
        emit AuthorizedChainUpdated(_chainEid, _authorized, _chainName);
    }

    // ==================== INTERNAL CORE FUNCTIONS ====================

    function _createProfile(address user, address referrer, uint32 sourceChain) internal {
        require(user != address(0), "Invalid user address");

        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }

        emit ProfileCreated(user, referrer, sourceChain);
    }

    // ==================== REWARDS CLAIMING FUNCTIONS ====================

    /**
     * @dev Claim available rewards tokens
     * Users can claim their full claimable balance
     */
    function claimRewards(bytes calldata _options) external payable nonReentrant {
        uint256 claimableAmount = userClaimableBalance[msg.sender];
        require(claimableAmount > 0, "No rewards to claim");

        // Check contract has enough tokens
        require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");

        // Reset user's claimable balance
        userClaimableBalance[msg.sender] = 0;

        // Update claimed amount
        userTotalClaimed[msg.sender] += claimableAmount;

        // Transfer tokens to user
        require(openworkToken.transfer(msg.sender, claimableAmount), "Token transfer failed");

        // Notify native chain of successful claim
        if (address(bridge) != address(0)) {
            bytes memory payload = abi.encode(
                "updateUserClaimData",
                msg.sender,
                claimableAmount
            );

            bridge.sendToNativeChain{value: msg.value}(
                "updateUserClaimData",
                payload,
                _options
            );
        }

        emit RewardsClaimed(msg.sender, claimableAmount);
    }

    /**
     * @dev Get user's current claimable balance
     */
    function getClaimableRewards(address user) public view returns (uint256) {
        return userClaimableBalance[user];
    }

    // ==================== CROSS-CHAIN STAKE UPDATE FUNCTIONS ====================

    function sendStakeUpdateCrossChain(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive,
        bytes calldata _options
    ) external payable {
        require(msg.sender == address(mainDAO), "Only Main DAO can send stake updates");
        require(address(bridge) != address(0), "Bridge not set");

        bytes memory payload = abi.encode(
            "updateStakeData",
            staker,
            amount,
            unlockTime,
            durationMinutes,
            isActive
        );

        bridge.sendToNativeChain{value: msg.value}("updateStakeData", payload, _options);
    }

    function quoteStakeUpdate(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;

        bytes memory payload = abi.encode(
            "updateStakeData",
            staker,
            amount,
            unlockTime,
            durationMinutes,
            isActive
        );
        return bridge.quoteNativeChain(payload, _options);
    }

    // ==================== VIEW FUNCTIONS ====================

    function getUserRewardInfo(address user) external view returns (
        uint256 claimableAmount,
        uint256 totalClaimed
    ) {
        claimableAmount = userClaimableBalance[user];
        totalClaimed = userTotalClaimed[user];
    }

    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }

    // Cross-chain info functions
    function getAuthorizedChains() external view returns (uint32[] memory chains, bool[] memory authorized, string[] memory names) {
        // Get common testnet chains
        uint32[] memory commonChains = new uint32[](3);
        commonChains[0] = 40161; // ETH Sepolia
        commonChains[1] = 40232; // OP Sepolia
        commonChains[2] = 40231; // Arbitrum Sepolia

        chains = new uint32[](commonChains.length);
        authorized = new bool[](commonChains.length);
        names = new string[](commonChains.length);

        for (uint256 i = 0; i < commonChains.length; i++) {
            chains[i] = commonChains[i];
            authorized[i] = authorizedChains[commonChains[i]];
            names[i] = chainNames[commonChains[i]];
        }
    }

    function quoteClaimSync(
        address user,
        uint256 claimAmount,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;

        bytes memory payload = abi.encode(
            "updateUserClaimData",
            user,
            claimAmount
        );
        return bridge.quoteNativeChain(payload, _options);
    }

    function isChainAuthorized(uint32 chainEid) external view returns (bool) {
        return authorizedChains[chainEid];
    }

    function getChainName(uint32 chainEid) external view returns (string memory) {
        return chainNames[chainEid];
    }

    // ==================== EMERGENCY ADMIN FUNCTIONS ====================

    /**
     * @dev Emergency function to increase a user's balance
     * @notice SECURITY: Can only INCREASE balance, never decrease (prevents theft)
     * @param user The user whose balance to increase
     * @param newBalance The new balance (must be higher than current)
     */
    function emergencyUpdateUserBalance(address user, uint256 newBalance) external onlyOwner {
        uint256 currentBalance = userClaimableBalance[user];
        require(newBalance > currentBalance, "Can only increase balance");

        userClaimableBalance[user] = newBalance;
        emit EmergencyBalanceIncrease(user, currentBalance, newBalance);
        emit ClaimableBalanceUpdated(user, newBalance, 0);
    }

    /**
     * @dev Emergency token withdrawal
     * @notice Consider transferring ownership to a multisig before mainnet
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(openworkToken.transfer(owner(), amount), "Token transfer failed");
    }

    // Allow contract to receive ETH for paying LayerZero fees
    receive() external payable {}
}
