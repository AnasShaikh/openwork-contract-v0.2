// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Interface for OpenworkGenesis storage contract (data source)
interface IOpenworkGenesis {
    function getUserReferrer(address user) external view returns (address);
    function totalPlatformPayments() external view returns (uint256);
    function getUserTotalGovernanceActions(address user) external view returns (uint256);
    function setUserTotalOWTokens(address user, uint256 tokens) external;
    function getUserEarnedTokens(address user) external view returns (uint256);
}

// Interface for ProfileGenesis contract (profile/referrer data)
interface IProfileGenesis {
    function getUserReferrer(address user) external view returns (address);
}

contract OpenWorkRewardsContract is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ==================== REWARD STRUCTURES ====================
    
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }
    
    struct UserBandRewards {
        uint256 band;              // Reward band (0, 1, 2, etc.)
        uint256 tokensEarned;      // Total tokens earned in this band
        uint256 tokensClaimable;   // Tokens unlocked by governance actions
        uint256 tokensClaimed;     // Tokens already claimed
    }

    // ==================== STATE VARIABLES ====================
    
    // Reference to job contract (NOWJC) - only it can call this contract
    address public jobContract;
    
    // Optional reference to Genesis for referrer data (can be null)
    IOpenworkGenesis public genesis;
    
    // Reference to ProfileGenesis for profile/referrer data
    IProfileGenesis public profileGenesis;
    
    // Reward bands array
    RewardBand[] public rewardBands;
    
    // Platform-wide tracking (synced from NOWJC)
    uint256 public totalPlatformPayments;
    uint256 public currentPlatformBand;
    
    // Band-specific user rewards tracking
    mapping(address => UserBandRewards[]) public userBandRewards;
    mapping(address => mapping(uint256 => uint256)) public userBandIndex; // user => band => array index
    mapping(address => mapping(uint256 => bool)) public userHasBandRewards; // user => band => exists
    
    // User totals for quick access
    mapping(address => uint256) public userTotalTokensEarned;
    mapping(address => uint256) public userTotalTokensClaimed;
    
    // Governance actions tracking by band
    mapping(address => mapping(uint256 => uint256)) public userGovernanceActionsByBand; // user => band => actions
    mapping(address => uint256) public userTotalGovernanceActions;

    // ==================== EVENTS ====================
    
    event TokensEarnedInBand(
        address indexed user, 
        uint256 tokensEarned, 
        uint256 indexed band, 
        uint256 newBandTotal,
        uint256 newUserTotal
    );
    event GovernanceActionRecorded(
        address indexed user, 
        uint256 indexed band, 
        uint256 newBandActions,
        uint256 newTotalActions
    );
    event JobContractUpdated(address indexed oldContract, address indexed newContract);

    // ==================== MODIFIERS ====================
    
    modifier onlyJobContract() {
        require(msg.sender == jobContract, "Only job contract can call");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _jobContract,
        address _genesis
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        jobContract = _jobContract;
        genesis = IOpenworkGenesis(_genesis);
        totalPlatformPayments = 0;
        currentPlatformBand = 0;
        
        _initializeRewardBands();
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender(), "Unauthorized upgrade");
    }

    // ==================== ADMIN FUNCTIONS ====================
    
    function setJobContract(address _jobContract) external onlyOwner {
        address oldContract = jobContract;
        jobContract = _jobContract;
        emit JobContractUpdated(oldContract, _jobContract);
    }
    
    function setGenesis(address _genesis) external onlyOwner {
        genesis = IOpenworkGenesis(_genesis);
    }
    
    function setProfileGenesis(address _profileGenesis) external onlyOwner {
        profileGenesis = IProfileGenesis(_profileGenesis);
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

    // ==================== BAND CALCULATION FUNCTIONS ====================
    
    function getCurrentBand() public view returns (uint256) {
        for (uint256 i = 0; i < rewardBands.length; i++) {
            if (totalPlatformPayments >= rewardBands[i].minAmount && 
                totalPlatformPayments <= rewardBands[i].maxAmount) {
                return i;
            }
        }
        
        return rewardBands.length > 0 ? rewardBands.length - 1 : 0;
    }

    // ==================== CORE FUNCTIONS CALLED BY NOWJC ====================
    
    /**
     * @dev Process job payment and award tokens to users
     * Called by NOWJC when payment is released
     */
    function processJobPayment(
        address jobGiver,
        address jobTaker, 
        uint256 amount,
        uint256 newPlatformTotal
    ) external onlyJobContract returns (uint256[] memory tokensAwarded) {
        // Update platform tracking
        totalPlatformPayments = newPlatformTotal;
        
        // Get referrers (from ProfileGenesis if available, fallback to old Genesis)
        address jobGiverReferrer = address(0);
        address jobTakerReferrer = address(0);
        
        if (address(profileGenesis) != address(0)) {
            jobGiverReferrer = profileGenesis.getUserReferrer(jobGiver);
            jobTakerReferrer = profileGenesis.getUserReferrer(jobTaker);
        } else if (address(genesis) != address(0)) {
            jobGiverReferrer = genesis.getUserReferrer(jobGiver);
            jobTakerReferrer = genesis.getUserReferrer(jobTaker);
        }
        
        // Calculate reward distribution
        uint256 jobGiverAmount = amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && 
            jobTakerReferrer != jobTaker && 
            jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Award tokens and track amounts
        tokensAwarded = new uint256[](3); // [jobGiver, jobGiverReferrer, jobTakerReferrer]
        
        if (jobGiverAmount > 0) {
            tokensAwarded[0] = _awardTokensInCurrentBand(jobGiver, jobGiverAmount, newPlatformTotal - amount);
        }
        
        if (jobGiverReferrerAmount > 0) {
            tokensAwarded[1] = _awardTokensInCurrentBand(jobGiverReferrer, jobGiverReferrerAmount, newPlatformTotal - amount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            tokensAwarded[2] = _awardTokensInCurrentBand(jobTakerReferrer, jobTakerReferrerAmount, newPlatformTotal - amount);
        }
        
        return tokensAwarded;
    }

    /**
     * @dev Award tokens to user in current platform band
     */
    function _awardTokensInCurrentBand(
        address user, 
        uint256 amountUSDT, 
        uint256 platformTotalBefore
    ) internal returns (uint256) {
        uint256 currentBand = getCurrentBand();
        uint256 newPlatformTotal = platformTotalBefore + amountUSDT;
        
        // Calculate tokens based on platform-wide progression
        uint256 tokensToAward = calculateTokensForRange(platformTotalBefore, newPlatformTotal);
        
        if (tokensToAward == 0) return 0;
        
        // Add to user's band-specific rewards
        if (userHasBandRewards[user][currentBand]) {
            // User already has rewards in this band - add to existing
            uint256 bandIndex = userBandIndex[user][currentBand];
            userBandRewards[user][bandIndex].tokensEarned += tokensToAward;
        } else {
            // First time earning in this band - create new entry
            UserBandRewards memory newBandReward = UserBandRewards({
                band: currentBand,
                tokensEarned: tokensToAward,
                tokensClaimable: 0,  // Will be calculated when needed
                tokensClaimed: 0
            });
            
            userBandRewards[user].push(newBandReward);
            userBandIndex[user][currentBand] = userBandRewards[user].length - 1;
            userHasBandRewards[user][currentBand] = true;
        }
        
        // Update user total
        userTotalTokensEarned[user] += tokensToAward;
        
        emit TokensEarnedInBand(
            user, 
            tokensToAward, 
            currentBand, 
            _getUserTokensInBand(user, currentBand),
            userTotalTokensEarned[user]
        );
        
        return tokensToAward;
    }

    /**
     * @dev Record governance action for user in current band
     * Called by NOWJC when user performs governance action
     */
    function recordGovernanceAction(address user) external onlyJobContract {
        uint256 currentBand = getCurrentBand();
        
        // Record in current band
        userGovernanceActionsByBand[user][currentBand]++;
        
        // Also increment total
        userTotalGovernanceActions[user]++;
        
        emit GovernanceActionRecorded(
            user, 
            currentBand, 
            userGovernanceActionsByBand[user][currentBand],
            userTotalGovernanceActions[user]
        );
    }

    // ==================== NEW: SIMPLIFIED CLAIMABLE CALCULATION ====================
    
    /**
     * @dev Calculate user's total claimable tokens (simplified for sync)
     * This is the main function NOWJC calls for cross-chain sync
     */
    function getUserTotalClaimableTokens(address user) external view returns (uint256) {
        uint256 totalClaimable = 0;
        UserBandRewards[] memory rewards = userBandRewards[user];
        
        for (uint256 i = 0; i < rewards.length; i++) {
            UserBandRewards memory bandReward = rewards[i];
            uint256 bandClaimable = _calculateBandClaimable(user, bandReward);
            totalClaimable += bandClaimable;
        }
        
        return totalClaimable;
    }
    
    /**
     * @dev Calculate claimable tokens for a specific band
     */
    function _calculateBandClaimable(address user, UserBandRewards memory bandReward) internal view returns (uint256) {
        // Get user's governance actions in this specific band
        uint256 govActionsInBand = userGovernanceActionsByBand[user][bandReward.band];
        
        // Get reward rate for this band
        uint256 rewardRate = rewardBands[bandReward.band].owPerDollar;
        
        // Calculate max tokens claimable based on governance actions
        uint256 maxClaimableFromGovActions = govActionsInBand * rewardRate;
        
        // Claimable = min(tokensEarned, maxFromGovActions) - alreadyClaimed
        uint256 availableToEarn = bandReward.tokensEarned > bandReward.tokensClaimed ? 
            bandReward.tokensEarned - bandReward.tokensClaimed : 0;
        
        return availableToEarn > maxClaimableFromGovActions ? 
            maxClaimableFromGovActions : availableToEarn;
    }

    /**
     * @dev Mark tokens as claimed (called by NOWJC after successful cross-chain claim)
     */
    function markTokensClaimed(address user, uint256 amountClaimed) external onlyJobContract returns (bool) {
        uint256 remainingToClaim = amountClaimed;
        
        // Mark claimed from bands in order (FIFO)
        for (uint256 i = 0; i < userBandRewards[user].length && remainingToClaim > 0; i++) {
            UserBandRewards memory bandReward = userBandRewards[user][i];
            uint256 bandClaimable = _calculateBandClaimable(user, bandReward);
            
            if (bandClaimable > 0) {
                uint256 claimFromThisBand = remainingToClaim > bandClaimable ? 
                    bandClaimable : remainingToClaim;
                
                // Update claimed amount for this band
                uint256 bandIndex = userBandIndex[user][bandReward.band];
                userBandRewards[user][bandIndex].tokensClaimed += claimFromThisBand;
                
                remainingToClaim -= claimFromThisBand;
            }
        }
        
        // Update user total claimed
        userTotalTokensClaimed[user] += amountClaimed;
        
        return true;
    }

    // ==================== TOKEN CALCULATION FUNCTIONS ====================
    
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

    // ==================== VIEW FUNCTIONS ====================
    
    function getUserBandRewards(address user) external view returns (UserBandRewards[] memory) {
        return userBandRewards[user];
    }
    
    function getUserRewardsInBand(address user, uint256 band) external view returns (UserBandRewards memory) {
        require(userHasBandRewards[user][band], "No rewards in this band");
        uint256 bandIndex = userBandIndex[user][band];
        return userBandRewards[user][bandIndex];
    }
    
    function _getUserTokensInBand(address user, uint256 band) internal view returns (uint256) {
        if (!userHasBandRewards[user][band]) return 0;
        uint256 bandIndex = userBandIndex[user][band];
        return userBandRewards[user][bandIndex].tokensEarned;
    }
    
    function getUserTotalTokensEarned(address user) external view returns (uint256) {
        return userTotalTokensEarned[user];
    }
    
    function getUserTotalTokensClaimed(address user) external view returns (uint256) {
        return userTotalTokensClaimed[user];
    }
    
    function getUserGovernanceActionsInBand(address user, uint256 band) external view returns (uint256) {
        return userGovernanceActionsByBand[user][band];
    }
    
    function getUserTotalGovernanceActions(address user) external view returns (uint256) {
        return userTotalGovernanceActions[user];
    }
    
    function getRewardBandsCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) {
        require(index < rewardBands.length, "Invalid band index");
        RewardBand memory band = rewardBands[index];
        return (band.minAmount, band.maxAmount, band.owPerDollar);
    }
    
    function getPlatformBandInfo() external view returns (
        uint256 currentBand,
        uint256 currentTotal,
        uint256 bandMinAmount,
        uint256 bandMaxAmount,
        uint256 governanceRewardRate
    ) {
        currentBand = getCurrentBand();
        currentTotal = totalPlatformPayments;
        
        if (currentBand < rewardBands.length) {
            RewardBand memory band = rewardBands[currentBand];
            bandMinAmount = band.minAmount;
            bandMaxAmount = band.maxAmount;
            governanceRewardRate = band.owPerDollar;
        }
    }
}