// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IMainDAO {
    function handleUpdateStakeDataFromRewards(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external;
}

interface IThirdChainBridge {
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

contract CrossChainRewardsContract is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    IERC20 public openworkToken;
    IMainDAO public mainDAO;
    IThirdChainBridge public bridge;
    
    // User referrer mapping
    mapping(address => address) public userReferrers;
    
    // Governance reward bands structure
    struct GovernanceRewardBand {
        uint256 minValue;       // Minimum USD value for this band
        uint256 maxValue;       // Maximum USD value for this band
        uint256 rewardPerAction; // OW tokens per governance action (scaled by 1e18)
    }
    
    // Band-specific user data from sync
    mapping(address => uint256[]) public userSyncedBands;
    mapping(address => uint256[]) public userSyncedTokensPerBand;
    mapping(address => uint256) public userSyncedGovernanceActions;
    
    // Governance rewards tracking
    mapping(address => uint256) public claimedGovernanceRewards;
    
    // Job tracking
    uint256 public currentTotalPlatformPayments;
    
    // Governance reward bands array
    GovernanceRewardBand[] public governanceRewardBands;
    
    // Cross-chain tracking
    mapping(uint32 => bool) public authorizedChains;
    mapping(uint32 => string) public chainNames;
    
    // Events
    event ProfileCreated(address indexed user, address indexed referrer, uint32 indexed sourceChain);
    event GovernanceRewardsClaimed(address indexed user, uint256 amount);
    event PlatformTotalUpdated(uint256 newTotal);
    event ContractUpdated(string contractType, address newAddress);
    event AuthorizedChainUpdated(uint32 indexed chainEid, bool authorized, string chainName);
    event StakeDataForwarded(address indexed staker, bool isActive);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event RewardsSynced(address indexed user, uint256 userGovernanceActions, uint256[] userBands, uint256[] tokensPerBand, uint32 indexed sourceChain);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _owner, address _openworkToken, address _bridge) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        openworkToken = IERC20(_openworkToken);
        bridge = IThirdChainBridge(_bridge);
        _initializeGovernanceRewardBands();
        _initializeAuthorizedChains();
    }
    
function _authorizeUpgrade(address /* newImplementation */) internal view override {
    require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
}

function upgradeFromDAO(address newImplementation) external {
    require(msg.sender == address(bridge), "Only bridge can upgrade");
    upgradeToAndCall(newImplementation, "");
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
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = address(bridge);
        bridge = IThirdChainBridge(_bridge);
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    function setOpenworkToken(address _token) external onlyOwner {
        openworkToken = IERC20(_token);
        emit ContractUpdated("OpenworkToken", _token);
    }
    
    function setMainDAO(address _mainDAO) external onlyOwner {
        mainDAO = IMainDAO(_mainDAO);
        emit ContractUpdated("MainDAO", _mainDAO);
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

    function handleSyncRewards(
        address user,
        uint256 userGovernanceActions, 
        uint256[] calldata userBands,
        uint256[] calldata tokensPerBand,
        uint32 sourceChain
    ) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        require(userBands.length == tokensPerBand.length, "Array length mismatch");
        
        // Update user's synced data
        userSyncedGovernanceActions[user] = userGovernanceActions;
        userSyncedBands[user] = userBands;
        userSyncedTokensPerBand[user] = tokensPerBand;
        
        emit RewardsSynced(user, userGovernanceActions, userBands, tokensPerBand, sourceChain);
    }
    
    // ==================== GOVERNANCE REWARD BANDS INITIALIZATION ====================
    
    function _initializeGovernanceRewardBands() private {
        // Governance action reward bands
        governanceRewardBands.push(GovernanceRewardBand(0, 500 * 1e18, 100000 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(500 * 1e18, 1000 * 1e18, 50000 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(1000 * 1e18, 2000 * 1e18, 25000 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(2000 * 1e18, 4000 * 1e18, 12500 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(4000 * 1e18, 8000 * 1e18, 6250 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(8000 * 1e18, 16000 * 1e18, 3125 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(16000 * 1e18, 32000 * 1e18, 1562 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(32000 * 1e18, 64000 * 1e18, 781 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(64000 * 1e18, 128000 * 1e18, 391 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(128000 * 1e18, 256000 * 1e18, 196 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(256000 * 1e18, 512000 * 1e18, 98 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(512000 * 1e18, 1024000 * 1e18, 49 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(1024000 * 1e18, 2048000 * 1e18, 24 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(2048000 * 1e18, 4096000 * 1e18, 12 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(4096000 * 1e18, 8192000 * 1e18, 6 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(8192000 * 1e18, 16384000 * 1e18, 3 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(16384000 * 1e18, 32768000 * 1e18, 15 * 1e17));
        governanceRewardBands.push(GovernanceRewardBand(32768000 * 1e18, 65536000 * 1e18, 75 * 1e16));
        governanceRewardBands.push(GovernanceRewardBand(65536000 * 1e18, 131072000 * 1e18, 38 * 1e16));
        governanceRewardBands.push(GovernanceRewardBand(131072000 * 1e18, 262144000 * 1e18, 19 * 1e16));
    }
    
    // ==================== INTERNAL CORE FUNCTIONS ====================
    
    function _createProfile(address user, address referrer, uint32 sourceChain) internal {
        require(user != address(0), "Invalid user address");
        
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, referrer, sourceChain);
    }
    
    // ==================== GOVERNANCE REWARDS FUNCTIONS ====================
    
    function getCurrentGovernanceRewardPerAction() public view returns (uint256) {
        for (uint256 i = 0; i < governanceRewardBands.length; i++) {
            if (currentTotalPlatformPayments >= governanceRewardBands[i].minValue && 
                currentTotalPlatformPayments <= governanceRewardBands[i].maxValue) {
                return governanceRewardBands[i].rewardPerAction;
            }
        }
        
        // If platform value exceeds all bands, return the lowest reward
        if (governanceRewardBands.length > 0) {
            return governanceRewardBands[governanceRewardBands.length - 1].rewardPerAction;
        }
        
        return 0;
    }
    
    function calculateTotalEligibleRewards(address user) public view returns (uint256) {
        // Use synced band-specific data
        uint256[] memory userBands = userSyncedBands[user];
        uint256[] memory tokensPerBand = userSyncedTokensPerBand[user];
        uint256 totalGovernanceActions = userSyncedGovernanceActions[user];
        
        require(userBands.length == tokensPerBand.length, "Band data mismatch");
        
        if (totalGovernanceActions == 0 || userBands.length == 0) return 0;
        
        uint256 totalClaimableTokens = 0;
        uint256 remainingActions = totalGovernanceActions;
        
        // For each band, calculate how many tokens can be claimed
        for (uint256 i = 0; i < userBands.length; i++) {
            uint256 bandIndex = userBands[i];
            uint256 tokensInBand = tokensPerBand[i];
            
            if (bandIndex >= governanceRewardBands.length) continue;
            
            // Get reward rate for this band
            uint256 rewardRate = governanceRewardBands[bandIndex].rewardPerAction;
            
            // Calculate governance actions needed to unlock all tokens in this band
            uint256 actionsNeededForBand = tokensInBand / rewardRate;
            
            // User can claim proportionally based on their governance actions
            if (remainingActions >= actionsNeededForBand) {
                // Can claim all tokens from this band
                totalClaimableTokens += tokensInBand;
                remainingActions -= actionsNeededForBand;
            } else {
                // Can claim partial tokens from this band
                uint256 partialTokens = (remainingActions * tokensInBand) / actionsNeededForBand;
                totalClaimableTokens += partialTokens;
                remainingActions = 0; // Used up all governance actions
                break;
            }
        }
        
        return totalClaimableTokens;
    }
    
    function getClaimableRewards(address user) public view returns (uint256) {
        uint256 totalEligible = calculateTotalEligibleRewards(user);
        uint256 alreadyClaimed = claimedGovernanceRewards[user];
        
        if (totalEligible <= alreadyClaimed) return 0;
        return totalEligible - alreadyClaimed;
    }
    
    function claimRewards(bytes calldata _options) external payable nonReentrant {
        // Check if user has synced data
        uint256[] memory userBands = userSyncedBands[msg.sender];
        uint256 totalGovernanceActions = userSyncedGovernanceActions[msg.sender];
        
        require(totalGovernanceActions > 0, "No governance actions performed");
        require(userBands.length > 0, "No job tokens earned");
        
        uint256 claimableAmount = getClaimableRewards(msg.sender);
        require(claimableAmount > 0, "No rewards to claim");
        
        // Check contract has enough tokens
        require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");
        
        // Update claimed amount
        claimedGovernanceRewards[msg.sender] += claimableAmount;
        
        // Transfer tokens to user
        require(openworkToken.transfer(msg.sender, claimableAmount), "Token transfer failed");

            if (address(bridge) != address(0)) {
        bytes memory payload = abi.encode(
            "updateUserClaimData",
            msg.sender,
            claimableAmount,
            claimedGovernanceRewards[msg.sender]
        );
        
        bridge.sendToNativeChain{value: msg.value}(
            "updateUserClaimData", 
            payload, 
            _options
        );
    }
        
        emit GovernanceRewardsClaimed(msg.sender, claimableAmount);
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
    
    function getUserGovernanceRewardInfo(address user) external view returns (
        uint256 totalGovernanceActions,
        uint256 totalEligibleRewards,
        uint256 claimedAmount,
        uint256 claimableAmount,
        uint256 currentRewardPerAction
    ) {
        totalGovernanceActions = userSyncedGovernanceActions[user];
        totalEligibleRewards = calculateTotalEligibleRewards(user);
        claimedAmount = claimedGovernanceRewards[user];
        claimableAmount = getClaimableRewards(user);
        currentRewardPerAction = getCurrentGovernanceRewardPerAction();
    }
    
    function getUserSyncedData(address user) external view returns (
        uint256 syncedGovernanceActions,
        uint256[] memory syncedBands,
        uint256[] memory syncedTokensPerBand
    ) {
        syncedGovernanceActions = userSyncedGovernanceActions[user];
        syncedBands = userSyncedBands[user];
        syncedTokensPerBand = userSyncedTokensPerBand[user];
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    function getCurrentTotalPlatformPayments() external view returns (uint256) {
        return currentTotalPlatformPayments;
    }
    
    function getGovernanceRewardBandsCount() external view returns (uint256) {
        return governanceRewardBands.length;
    }
    
    function getGovernanceRewardBand(uint256 index) external view returns (uint256 minValue, uint256 maxValue, uint256 rewardPerAction) {
        require(index < governanceRewardBands.length, "Invalid band index");
        GovernanceRewardBand memory band = governanceRewardBands[index];
        return (band.minValue, band.maxValue, band.rewardPerAction);
    }
    
    function getCurrentGovernanceBandIndex() external view returns (uint256) {
        for (uint256 i = 0; i < governanceRewardBands.length; i++) {
            if (currentTotalPlatformPayments >= governanceRewardBands[i].minValue && 
                currentTotalPlatformPayments <= governanceRewardBands[i].maxValue) {
                return i;
            }
        }
        return governanceRewardBands.length > 0 ? governanceRewardBands.length - 1 : 0;
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
        uint256 totalClaimed,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;
        
        bytes memory payload = abi.encode(
            "updateUserClaimData",
            user,
            claimAmount,
            totalClaimed
        );
        return bridge.quoteNativeChain(payload, _options);
    }
    
    function isChainAuthorized(uint32 chainEid) external view returns (bool) {
        return authorizedChains[chainEid];
    }
    
    function getChainName(uint32 chainEid) external view returns (string memory) {
        return chainNames[chainEid];
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function updatePlatformTotal(uint256 newTotal) external onlyOwner {
        require(newTotal >= currentTotalPlatformPayments, "Cannot decrease platform total");
        currentTotalPlatformPayments = newTotal;
        emit PlatformTotalUpdated(newTotal);
    }
    
    function emergencyUpdateUserGovernanceRewards(address user, uint256 newClaimedAmount) external onlyOwner {
        claimedGovernanceRewards[user] = newClaimedAmount;
    }
    
    // Emergency token withdrawal
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(openworkToken.transfer(owner(), amount), "Token transfer failed");
    }

    // Allow contract to receive ETH for paying LayerZero fees
    receive() external payable {}
}