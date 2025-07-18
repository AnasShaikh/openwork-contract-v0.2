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
    
    // Reward bands structure for job-based rewards
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }
    
    // Governance reward bands structure
    struct GovernanceRewardBand {
        uint256 minValue;       // Minimum USD value for this band
        uint256 maxValue;       // Maximum USD value for this band
        uint256 rewardPerAction; // OW tokens per governance action (scaled by 1e18)
    }
    
    // User tracking for job-based rewards
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    
    // Governance rewards tracking
    mapping(address => uint256) public claimedGovernanceRewards;
    mapping(address => uint256) public governanceActionCount;
    
    // Job tracking
    uint256 public currentTotalPlatformPayments;
    
    // Reward bands arrays
    RewardBand[] public rewardBands;
    GovernanceRewardBand[] public governanceRewardBands;
    
    // Cross-chain tracking
    mapping(uint32 => bool) public authorizedChains;
    mapping(uint32 => string) public chainNames;
    
    // Events
    event ProfileCreated(address indexed user, address indexed referrer, uint32 indexed sourceChain);
    event PaymentProcessed(
        address indexed jobGiver, 
        address indexed jobTaker,
        uint256 amount,
        uint256 newPlatformTotal
    );
    
    event TokensEarned(
        address indexed user, 
        uint256 tokensEarned, 
        uint256 newCumulativeEarnings,
        uint256 newTotalTokens
    );
    
    event GovernanceRewardsClaimed(address indexed user, uint256 amount);
    event GovernanceActionNotified(address indexed user, uint256 newActionCount);
    event CrossChainGovernanceActionReceived(address indexed user, uint32 indexed sourceChain, uint256 newActionCount);
    event PlatformTotalUpdated(uint256 newTotal);
    event ContractUpdated(string contractType, address newAddress);
    event AuthorizedChainUpdated(uint32 indexed chainEid, bool authorized, string chainName);
    event StakeDataForwarded(address indexed staker, bool isActive);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    
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
        _initializeRewardBands();
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
    
    function handleUpdateRewardsOnPayment(address jobGiver, address jobTaker, uint256 amount, uint32 /* sourceChain */) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        _updateRewardsOnPayment(jobGiver, jobTaker, amount);
    }
    
    function handleGovernanceActionNotification(address account, uint32 sourceChain) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        _notifyGovernanceActionCrossChain(account, sourceChain);
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
    
    // ==================== REWARD BANDS INITIALIZATION ====================
    
    function _initializeRewardBands() private {
        // Job-based reward bands
        rewardBands.push(RewardBand(0, 500 * 1e6, 100000 * 1e18));
        rewardBands.push(RewardBand(500 * 1e6, 1000 * 1e6, 50000 * 1e18));
        rewardBands.push(RewardBand(1000 * 1e6, 2000 * 1e6, 25000 * 1e18));
        rewardBands.push(RewardBand(2000 * 1e6, 4000 * 1e6, 12500 * 1e18));
        rewardBands.push(RewardBand(4000 * 1e6, 8000 * 1e6, 6250 * 1e18));
        rewardBands.push(RewardBand(8000 * 1e6, 16000 * 1e6, 3125 * 1e18));
        rewardBands.push(RewardBand(16000 * 1e6, 32000 * 1e6, 1562 * 1e18));
        rewardBands.push(RewardBand(32000 * 1e6, 64000 * 1e6, 781 * 1e18));
        rewardBands.push(RewardBand(64000 * 1e6, 128000 * 1e6, 391 * 1e18));
        rewardBands.push(RewardBand(128000 * 1e6, 256000 * 1e6, 195 * 1e18));
        rewardBands.push(RewardBand(256000 * 1e6, 512000 * 1e6, 98 * 1e18));
        rewardBands.push(RewardBand(512000 * 1e6, 1024000 * 1e6, 49 * 1e18));
        rewardBands.push(RewardBand(1024000 * 1e6, 2048000 * 1e6, 24 * 1e18));
        rewardBands.push(RewardBand(2048000 * 1e6, 4096000 * 1e6, 12 * 1e18));
        rewardBands.push(RewardBand(4096000 * 1e6, 8192000 * 1e6, 6 * 1e18));
        rewardBands.push(RewardBand(8192000 * 1e6, 16384000 * 1e6, 3 * 1e18));
        rewardBands.push(RewardBand(16384000 * 1e6, 32768000 * 1e6, 15 * 1e17));
        rewardBands.push(RewardBand(32768000 * 1e6, 65536000 * 1e6, 75 * 1e16));
        rewardBands.push(RewardBand(65536000 * 1e6, 131072000 * 1e6, 38 * 1e16));
        rewardBands.push(RewardBand(131072000 * 1e6, type(uint256).max, 19 * 1e16));
    }
    
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
    
    function _updateRewardsOnPayment(address jobGiver, address jobTaker, uint256 amount) internal {
        require(jobGiver != address(0) && jobTaker != address(0), "Invalid addresses");
        require(amount > 0, "Amount must be greater than 0");
        
        // Update platform total by adding this payment
        currentTotalPlatformPayments += amount;
        emit PlatformTotalUpdated(currentTotalPlatformPayments);
        
        // Get referrers from internal mapping
        address jobGiverReferrer = userReferrers[jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution
        uint256 jobGiverAmount = amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        
        emit PaymentProcessed(jobGiver, jobTaker, amount, currentTotalPlatformPayments);
    }
    
    function _accumulateJobTokens(address user, uint256 amountUSDT) private {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        
        // Calculate tokens based on progressive bands
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        // Update user's cumulative earnings and total tokens
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
    }
    
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) public view returns (uint256) {
        if (fromAmount >= toAmount) {
            return 0;
        }
        
        uint256 totalTokens = 0;
        uint256 currentAmount = fromAmount;
        
        for (uint256 i = 0; i < rewardBands.length && currentAmount < toAmount; i++) {
            RewardBand memory band = rewardBands[i];
            
            // Skip bands that are entirely below our starting point
            if (band.maxAmount <= currentAmount) {
                continue;
            }
            
            // Calculate the overlap with this band
            uint256 bandStart = currentAmount > band.minAmount ? currentAmount : band.minAmount;
            uint256 bandEnd = toAmount < band.maxAmount ? toAmount : band.maxAmount;
            
            if (bandStart < bandEnd) {
                uint256 amountInBand = bandEnd - bandStart;
                uint256 tokensInBand = (amountInBand * band.owPerDollar) / 1e6; // Convert USDT (6 decimals) to tokens
                totalTokens += tokensInBand;
                currentAmount = bandEnd;
            }
        }
        
        return totalTokens;
    }
    
    // ==================== GOVERNANCE REWARDS FUNCTIONS ====================
    
    function notifyGovernanceAction(address account) external {
        governanceActionCount[account]++;
        emit GovernanceActionNotified(account, governanceActionCount[account]);
    }
    
    function _notifyGovernanceActionCrossChain(address account, uint32 sourceChain) internal {
        governanceActionCount[account]++;
        emit CrossChainGovernanceActionReceived(account, sourceChain, governanceActionCount[account]);
    }
    
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
        uint256 actions = governanceActionCount[user];
        if (actions == 0) return 0;
        
        // Get total accumulated earnings from job-based rewards
        uint256 totalJobEarnings = userCumulativeEarnings[user];
        
        // Calculate reward per action based on current platform total
        uint256 rewardPerAction = getCurrentGovernanceRewardPerAction();
        
        // Total rewards = governance actions × reward per action
        // But user can only claim proportional to their job earnings
        uint256 maxPossibleRewards = actions * rewardPerAction;
        
        // User can claim rewards proportional to their contribution to platform
        if (currentTotalPlatformPayments == 0) return 0;
        
        uint256 userProportion = (totalJobEarnings * 1e18) / currentTotalPlatformPayments;
        uint256 eligibleRewards = (maxPossibleRewards * userProportion) / 1e18;
        
        return eligibleRewards;
    }
    
    function getClaimableRewards(address user) public view returns (uint256) {
        uint256 totalEligible = calculateTotalEligibleRewards(user);
        uint256 alreadyClaimed = claimedGovernanceRewards[user];
        
        if (totalEligible <= alreadyClaimed) return 0;
        return totalEligible - alreadyClaimed;
    }
    
    function claimRewards() external nonReentrant {
        require(governanceActionCount[msg.sender] > 0, "No governance actions performed");
        require(userCumulativeEarnings[msg.sender] > 0, "No earnings to base rewards on");
        
        uint256 claimableAmount = getClaimableRewards(msg.sender);
        require(claimableAmount > 0, "No rewards to claim");
        
        // Check contract has enough tokens
        require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");
        
        // Update claimed amount
        claimedGovernanceRewards[msg.sender] += claimableAmount;
        
        // Transfer tokens to user
        require(openworkToken.transfer(msg.sender, claimableAmount), "Token transfer failed");
        
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
    
    function getUserJobRewardInfo(address user) external view returns (
        uint256 cumulativeEarnings,
        uint256 totalJobTokens
    ) {
        return (userCumulativeEarnings[user], userTotalOWTokens[user]);
    }
    
    function getUserGovernanceRewardInfo(address user) external view returns (
        uint256 totalGovernanceActions,
        uint256 totalEligibleRewards,
        uint256 claimedAmount,
        uint256 claimableAmount,
        uint256 currentRewardPerAction
    ) {
        totalGovernanceActions = governanceActionCount[user];
        totalEligibleRewards = calculateTotalEligibleRewards(user);
        claimedAmount = claimedGovernanceRewards[user];
        claimableAmount = getClaimableRewards(user);
        currentRewardPerAction = getCurrentGovernanceRewardPerAction();
    }
    
    function getUserAllRewardInfo(address user) external view returns (
        uint256 cumulativeJobEarnings,
        uint256 totalJobTokens,
        uint256 totalGovernanceActions,
        uint256 totalEligibleRewards,
        uint256 claimedGovernanceRewards_,
        uint256 claimableGovernanceRewards,
        uint256 currentRewardPerAction
    ) {
        cumulativeJobEarnings = userCumulativeEarnings[user];
        totalJobTokens = userTotalOWTokens[user];
        totalGovernanceActions = governanceActionCount[user];
        totalEligibleRewards = calculateTotalEligibleRewards(user);
        claimedGovernanceRewards_ = claimedGovernanceRewards[user];
        claimableGovernanceRewards = getClaimableRewards(user);
        currentRewardPerAction = getCurrentGovernanceRewardPerAction();
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    function getCurrentTotalPlatformPayments() external view returns (uint256) {
        return currentTotalPlatformPayments;
    }
    
    function getRewardBandsCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) {
        require(index < rewardBands.length, "Invalid band index");
        RewardBand memory band = rewardBands[index];
        return (band.minAmount, band.maxAmount, band.owPerDollar);
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
    
    // Calculate job tokens for a specific amount without updating state
    function calculateJobTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + additionalAmount;
        return calculateTokensForRange(currentCumulative, newCumulative);
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
    
    function emergencyUpdateUserJobRewards(address user, uint256 newCumulativeEarnings, uint256 newTotalTokens) external onlyOwner {
        userCumulativeEarnings[user] = newCumulativeEarnings;
        userTotalOWTokens[user] = newTotalTokens;
    }
    
    function emergencyUpdateUserGovernanceRewards(address user, uint256 newActionCount, uint256 newClaimedAmount) external onlyOwner {
        governanceActionCount[user] = newActionCount;
        claimedGovernanceRewards[user] = newClaimedAmount;
    }
    
        // Emergency token withdrawal
        function emergencyWithdraw(uint256 amount) external onlyOwner {
            require(openworkToken.transfer(owner(), amount), "Token transfer failed");
        }

        // Allow contract to receive ETH for paying LayerZero fees
        receive() external payable {}
    }