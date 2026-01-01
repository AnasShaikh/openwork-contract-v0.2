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
        uint256 owPerDollar;    // OW tokens per USDT for earning (scaled by 1e18)
        uint256 tokensPerGovernanceAction;  // OW tokens unlocked per governance action (scaled by 1e18)
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

    // ==================== TEAM TOKENS POOL ====================

    // Pool configuration (adjustable)
    uint256 public TEAM_TOKENS_POOL = 150_000_000 * 1e18;  // 150M team tokens (adjustable)
    uint256 public teamTokensPerGovAction = 150_000 * 1e18;  // Default: 1000 actions for 150M (adjustable)

    // DAO integration (allows DAO to allocate team tokens)
    address public nativeDAO;

    // Team member allocations
    mapping(address => uint256) public teamTokensAllocated;  // Each member's total allocation
    mapping(address => uint256) public teamTokensClaimed;    // Amount already claimed
    mapping(address => bool) public isTeamMember;            // Quick membership check
    address[] public teamMembers;                            // List of all team members
    uint256 public totalTeamTokensAllocated;                 // Sum of all allocations (for validation)

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

    // Team tokens events
    event TeamTokensAllocated(address indexed member, uint256 amount, uint256 totalAllocated);
    event TeamTokensClaimed(address indexed member, uint256 amount);
    event TeamTokensPoolUpdated(uint256 oldPool, uint256 newPool);
    event TeamTokenRateUpdated(uint256 oldRate, uint256 newRate, uint256 actionsRequired);
    event NativeDAOUpdated(address indexed oldDAO, address indexed newDAO);

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

    // ==================== TEAM TOKENS ADMIN FUNCTIONS ====================

    /**
     * @dev Set native DAO address (allows DAO to allocate team tokens)
     */
    function setNativeDAO(address _nativeDAO) external onlyOwner {
        address oldDAO = nativeDAO;
        nativeDAO = _nativeDAO;
        emit NativeDAOUpdated(oldDAO, _nativeDAO);
    }

    /**
     * @dev Allocate team tokens to members (owner or DAO only)
     * @param members Array of member addresses
     * @param amounts Array of token amounts (overwrites existing allocations)
     */
    function allocateTeamTokens(
        address[] calldata members,
        uint256[] calldata amounts
    ) external {
        require(
            msg.sender == owner() || msg.sender == nativeDAO,
            "Only owner or DAO"
        );
        require(members.length == amounts.length, "Array length mismatch");

        for (uint256 i = 0; i < members.length; i++) {
            address member = members[i];
            uint256 newAmount = amounts[i];

            require(member != address(0), "Invalid address");
            require(newAmount > 0, "Amount must be positive");

            // Get old allocation to properly track total
            uint256 oldAllocation = teamTokensAllocated[member];

            // Update allocations (overwrites existing)
            if (!isTeamMember[member]) {
                isTeamMember[member] = true;
                teamMembers.push(member);
            }

            teamTokensAllocated[member] = newAmount;

            // Update total: subtract old, add new
            totalTeamTokensAllocated = totalTeamTokensAllocated - oldAllocation + newAmount;

            emit TeamTokensAllocated(member, newAmount, totalTeamTokensAllocated);
        }

        // Validate total doesn't exceed pool
        require(totalTeamTokensAllocated <= TEAM_TOKENS_POOL, "Exceeds team tokens pool");
    }

    /**
     * @dev Adjust team tokens pool size (owner only)
     * @param newPool New pool size (cannot reduce below already allocated)
     */
    function setTeamTokensPool(uint256 newPool) external onlyOwner {
        require(newPool >= totalTeamTokensAllocated, "Cannot reduce below allocated");
        uint256 oldPool = TEAM_TOKENS_POOL;
        TEAM_TOKENS_POOL = newPool;
        emit TeamTokensPoolUpdated(oldPool, newPool);
    }

    /**
     * @dev Adjust team token unlock rate (owner or DAO)
     * @param desiredActions Number of actions required to unlock full pool
     */
    function setTeamTokenActionRequirement(uint256 desiredActions) external {
        require(
            msg.sender == owner() || msg.sender == nativeDAO,
            "Only owner or DAO"
        );
        require(desiredActions >= 100, "Min 100 actions");
        require(desiredActions <= 10_000_000, "Max 10M actions");

        uint256 newRate = TEAM_TOKENS_POOL / desiredActions;
        require(newRate >= 1000 * 1e18, "Min 1k tokens per action");

        uint256 oldRate = teamTokensPerGovAction;
        teamTokensPerGovAction = newRate;

        emit TeamTokenRateUpdated(oldRate, newRate, desiredActions);
    }

    /**
     * @dev TEST ONLY: Manually set governance actions for testing
     * WARNING: This bypasses normal governance flow - only for testnets
     */
    function setGovernanceActionsForTesting(address user, uint256 actions) external onlyOwner {
        userTotalGovernanceActions[user] = actions;
    }

    /**
     * @dev Emergency admin function to manually adjust team tokens claimed
     * USE CASE: When callbacks fail and accounting becomes incorrect on native chain
     * WARNING: Only use when absolutely necessary - can bypass normal claim flow
     */
    function adminSetTeamTokensClaimed(address user, uint256 amount) external onlyOwner {
        require(isTeamMember[user], "Not a team member");
        require(amount <= teamTokensAllocated[user], "Cannot exceed allocation");
        teamTokensClaimed[user] = amount;
        emit TeamTokensClaimed(user, amount);
    }

    // ==================== REWARD BANDS INITIALIZATION ====================
    
    function _initializeRewardBands() private {
        // 20 reward bands, each distributing 30M OW tokens
        // Format: minAmount (USDT 6 decimals), maxAmount, owPerDollar (earning rate, 18 decimals), tokensPerGovernanceAction (unlock rate, 18 decimals)
        
        rewardBands.push(RewardBand(0, 100000 * 1e6, 300 * 1e18, 10000 * 1e18));                    // Band 0: $0-$100k, 3,000 actions needed
        rewardBands.push(RewardBand(100000 * 1e6, 200000 * 1e6, 300 * 1e18, 5000 * 1e18));         // Band 1: $100k-$200k, 6,000 actions
        rewardBands.push(RewardBand(200000 * 1e6, 400000 * 1e6, 150 * 1e18, 2500 * 1e18));         // Band 2: $200k-$400k, 12,000 actions
        rewardBands.push(RewardBand(400000 * 1e6, 800000 * 1e6, 75 * 1e18, 1250 * 1e18));          // Band 3: $400k-$800k, 24,000 actions
        rewardBands.push(RewardBand(800000 * 1e6, 1600000 * 1e6, 375 * 1e17, 625 * 1e18));        // Band 4: $800k-$1.6M, 48,000 actions
        rewardBands.push(RewardBand(1600000 * 1e6, 3200000 * 1e6, 1875 * 1e16, 312 * 1e18));      // Band 5: $1.6M-$3.2M, 96,153 actions
        rewardBands.push(RewardBand(3200000 * 1e6, 6400000 * 1e6, 9375 * 1e15, 156 * 1e18));      // Band 6: $3.2M-$6.4M, 192,307 actions
        rewardBands.push(RewardBand(6400000 * 1e6, 12800000 * 1e6, 46875 * 1e14, 78 * 1e18));    // Band 7: $6.4M-$12.8M, 384,615 actions
        rewardBands.push(RewardBand(12800000 * 1e6, 25600000 * 1e6, 234375 * 1e13, 39 * 1e18));  // Band 8: $12.8M-$25.6M, 769,230 actions
        rewardBands.push(RewardBand(25600000 * 1e6, 51200000 * 1e6, 1171875 * 1e12, 19 * 1e18)); // Band 9: $25.6M-$51.2M, 1.58M actions
        rewardBands.push(RewardBand(51200000 * 1e6, 102400000 * 1e6, 5859375 * 1e11, 9 * 1e18)); // Band 10: $51.2M-$102.4M, 3.33M actions
        rewardBands.push(RewardBand(102400000 * 1e6, 204800000 * 1e6, 29296875 * 1e10, 4 * 1e18)); // Band 11: $102.4M-$204.8M, 7.5M actions
        rewardBands.push(RewardBand(204800000 * 1e6, 409600000 * 1e6, 146484375 * 1e9, 2 * 1e18)); // Band 12: $204.8M-$409.6M, 15M actions
        rewardBands.push(RewardBand(409600000 * 1e6, 819200000 * 1e6, 732421875 * 1e8, 1 * 1e18)); // Band 13: $409.6M-$819.2M, 30M actions
        rewardBands.push(RewardBand(819200000 * 1e6, 1638400000 * 1e6, 3662109375 * 1e7, 1 * 1e18)); // Band 14: $819.2M-$1.6384B, 30M actions
        rewardBands.push(RewardBand(1638400000 * 1e6, 3276800000 * 1e6, 18310546875 * 1e6, 1 * 1e18)); // Band 15: $1.6384B-$3.2768B, 30M actions
        rewardBands.push(RewardBand(3276800000 * 1e6, 6553600000 * 1e6, 91552734375 * 1e5, 1 * 1e18)); // Band 16: $3.2768B-$6.5536B, 30M actions
        rewardBands.push(RewardBand(6553600000 * 1e6, 13107200000 * 1e6, 457763671875 * 1e4, 1 * 1e18)); // Band 17: $6.5536B-$13.1072B, 30M actions
        rewardBands.push(RewardBand(13107200000 * 1e6, 26214400000 * 1e6, 2288818359375 * 1e3, 1 * 1e18)); // Band 18: $13.1072B-$26.2144B, 30M actions
        rewardBands.push(RewardBand(26214400000 * 1e6, 52428800000 * 1e6, 11444091796875 * 1e2, 1 * 1e18)); // Band 19: $26.2144B-$52.4288B, 30M actions
    }
    
    /**
     * @dev Reset and reinitialize reward bands (owner only)
     * Used to fix corrupted storage from failed initialization
     */
    function resetRewardBands() external onlyOwner {
        delete rewardBands;
        _initializeRewardBands();
    }
    
    // ==================== DYNAMIC BAND MANAGEMENT ====================
    
    event RewardBandAdded(uint256 indexed bandIndex, uint256 minAmount, uint256 maxAmount, uint256 owPerDollar);
    event RewardBandUpdated(uint256 indexed bandIndex, uint256 minAmount, uint256 maxAmount, uint256 owPerDollar);
    event RewardBandRemoved(uint256 indexed bandIndex);
    event AllRewardBandsCleared();
    
    /**
     * @dev Add a new reward band to the end of the array
     * @param minAmount Minimum cumulative platform amount for this band (USDT 6 decimals)
     * @param maxAmount Maximum cumulative platform amount for this band (USDT 6 decimals)
     * @param owPerDollar OW tokens awarded per USDT for earning (18 decimals)
     * @param tokensPerGovernanceAction OW tokens unlocked per governance action (18 decimals)
     */
    function addRewardBand(uint256 minAmount, uint256 maxAmount, uint256 owPerDollar, uint256 tokensPerGovernanceAction) external onlyOwner {
        require(maxAmount > minAmount, "Invalid range");
        require(owPerDollar > 0, "Rate must be positive");
        require(tokensPerGovernanceAction > 0, "Unlock rate must be positive");
        
        // Validate continuity with previous band
        if (rewardBands.length > 0) {
            RewardBand memory lastBand = rewardBands[rewardBands.length - 1];
            require(minAmount >= lastBand.maxAmount, "Gap or overlap with previous band");
        }
        
        rewardBands.push(RewardBand(minAmount, maxAmount, owPerDollar, tokensPerGovernanceAction));
        
        emit RewardBandAdded(rewardBands.length - 1, minAmount, maxAmount, owPerDollar);
    }
    
    /**
     * @dev Update an existing reward band
     * @param index Index of the band to update
     * @param minAmount New minimum amount
     * @param maxAmount New maximum amount
     * @param owPerDollar New earning rate
     * @param tokensPerGovernanceAction New unlock rate
     */
    function updateRewardBand(uint256 index, uint256 minAmount, uint256 maxAmount, uint256 owPerDollar, uint256 tokensPerGovernanceAction) external onlyOwner {
        require(index < rewardBands.length, "Invalid band index");
        require(maxAmount > minAmount, "Invalid range");
        require(owPerDollar > 0, "Rate must be positive");
        require(tokensPerGovernanceAction > 0, "Unlock rate must be positive");
        
        rewardBands[index] = RewardBand(minAmount, maxAmount, owPerDollar, tokensPerGovernanceAction);
        
        emit RewardBandUpdated(index, minAmount, maxAmount, owPerDollar);
    }
    
    /**
     * @dev Remove the last reward band
     * Safer than removing by index as it doesn't affect other bands
     */
    function removeLastRewardBand() external onlyOwner {
        require(rewardBands.length > 0, "No bands to remove");
        
        uint256 removedIndex = rewardBands.length - 1;
        rewardBands.pop();
        
        emit RewardBandRemoved(removedIndex);
    }
    
    /**
     * @dev Clear all reward bands (use with extreme caution!)
     * Should only be used for emergency resets
     */
    function clearAllRewardBands() external onlyOwner {
        delete rewardBands;
        emit AllRewardBandsCleared();
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

    // ==================== TEAM TOKENS CALCULATION ====================

    /**
     * @dev Calculate team tokens claimable for a user
     * Returns 0 for non-team members
     */
    function getTeamTokensClaimable(address user) public view returns (uint256) {
        if (!isTeamMember[user]) return 0;

        uint256 allocated = teamTokensAllocated[user];
        uint256 govActions = userTotalGovernanceActions[user];

        // Calculate max unlocked based on total governance actions
        uint256 maxUnlocked = govActions * teamTokensPerGovAction;

        // Can't unlock more than allocated
        uint256 totalUnlocked = maxUnlocked > allocated ? allocated : maxUnlocked;

        // Subtract already claimed
        return totalUnlocked > teamTokensClaimed[user] ?
            totalUnlocked - teamTokensClaimed[user] : 0;
    }

    // ==================== NEW: SIMPLIFIED CLAIMABLE CALCULATION ====================

    /**
     * @dev Calculate user's total claimable tokens (simplified for sync)
     * DEPRECATED: Use getUserTotalUnlockedTokens() for cross-chain sync to prevent double-claims
     * This returns current claimable (after subtracting claimed), which causes double-claim vulnerability
     */
    function getUserTotalClaimableTokens(address user) external view returns (uint256) {
        // Pool A: Earned rewards
        uint256 earnedClaimable = 0;
        UserBandRewards[] memory rewards = userBandRewards[user];

        for (uint256 i = 0; i < rewards.length; i++) {
            UserBandRewards memory bandReward = rewards[i];
            uint256 bandClaimable = _calculateBandClaimable(user, bandReward);
            earnedClaimable += bandClaimable;
        }

        // Pool B: Team tokens
        uint256 teamClaimable = getTeamTokensClaimable(user);

        // Return combined total
        return earnedClaimable + teamClaimable;
    }

    /**
     * @dev Calculate user's total UNLOCKED tokens (for cross-chain sync)
     * SECURITY FIX: Returns total unlocked ever (not current claimable)
     * Main chain subtracts totalClaimed to prevent double-claims when callbacks fail
     */
    function getUserTotalUnlockedTokens(address user) external view returns (uint256) {
        // Pool A: Earned rewards - calculate total unlocked (not claimable)
        uint256 earnedUnlocked = 0;
        UserBandRewards[] memory rewards = userBandRewards[user];

        for (uint256 i = 0; i < rewards.length; i++) {
            UserBandRewards memory bandReward = rewards[i];
            uint256 govActionsInBand = userGovernanceActionsByBand[user][bandReward.band];
            uint256 unlockRate = rewardBands[bandReward.band].tokensPerGovernanceAction;
            uint256 maxUnlockedFromGov = govActionsInBand * unlockRate;

            // Total unlocked for this band = min(earned, unlocked by gov actions)
            uint256 bandUnlocked = bandReward.tokensEarned > maxUnlockedFromGov ?
                maxUnlockedFromGov : bandReward.tokensEarned;
            earnedUnlocked += bandUnlocked;
        }

        // Pool B: Team tokens - calculate total unlocked (not claimable)
        uint256 teamUnlocked = 0;
        if (isTeamMember[user]) {
            uint256 allocated = teamTokensAllocated[user];
            uint256 govActions = userTotalGovernanceActions[user];
            uint256 maxUnlocked = govActions * teamTokensPerGovAction;
            teamUnlocked = maxUnlocked > allocated ? allocated : maxUnlocked;
        }

        return earnedUnlocked + teamUnlocked;
    }
    
    /**
     * @dev Calculate claimable tokens for a specific band
     * FIXED: Now uses tokensPerGovernanceAction instead of owPerDollar for unlock calculation
     */
    function _calculateBandClaimable(address user, UserBandRewards memory bandReward) internal view returns (uint256) {
        // Get user's governance actions in this specific band
        uint256 govActionsInBand = userGovernanceActionsByBand[user][bandReward.band];
        
        // Get governance unlock rate for this band (FIXED: was using owPerDollar earning rate)
        uint256 unlockRate = rewardBands[bandReward.band].tokensPerGovernanceAction;
        
        // Calculate max tokens claimable based on governance actions
        uint256 maxClaimableFromGovActions = govActionsInBand * unlockRate;
        
        // Claimable = min(tokensEarned, maxFromGovActions) - alreadyClaimed
        uint256 availableToEarn = bandReward.tokensEarned > bandReward.tokensClaimed ? 
            bandReward.tokensEarned - bandReward.tokensClaimed : 0;
        
        return availableToEarn > maxClaimableFromGovActions ? 
            maxClaimableFromGovActions : availableToEarn;
    }

    /**
     * @dev Mark tokens as claimed (called by NOWJC after successful cross-chain claim)
     * UPDATED: Now handles FIFO claiming from both pools (earned first, then team)
     */
    function markTokensClaimed(address user, uint256 amountClaimed) external onlyJobContract returns (bool) {
        uint256 remainingToClaim = amountClaimed;

        // STEP 1: Claim from earned rewards first (FIFO by band)
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

        // STEP 2: If remaining, claim from team tokens
        if (remainingToClaim > 0 && isTeamMember[user]) {
            uint256 teamClaimable = getTeamTokensClaimable(user);
            require(remainingToClaim <= teamClaimable, "Insufficient team tokens");

            teamTokensClaimed[user] += remainingToClaim;
            emit TeamTokensClaimed(user, remainingToClaim);
            remainingToClaim = 0;
        }

        require(remainingToClaim == 0, "Insufficient claimable balance");

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

    // ==================== TEAM TOKENS VIEW FUNCTIONS ====================

    /**
     * @dev Get comprehensive token breakdown for a user
     * Shows both earned and team tokens separately
     */
    function getUserTokenBreakdown(address user) external view returns (
        uint256 earnedTotal,
        uint256 earnedClaimable,
        uint256 earnedClaimed,
        uint256 teamAllocated,
        uint256 teamClaimable,
        uint256 teamClaimed,
        uint256 governanceActions,
        uint256 totalClaimable
    ) {
        // Earned pool data
        earnedTotal = userTotalTokensEarned[user];
        earnedClaimed = userTotalTokensClaimed[user];

        // Calculate earned claimable
        UserBandRewards[] memory rewards = userBandRewards[user];
        for (uint256 i = 0; i < rewards.length; i++) {
            earnedClaimable += _calculateBandClaimable(user, rewards[i]);
        }

        // Team pool data
        teamAllocated = teamTokensAllocated[user];
        teamClaimable = getTeamTokensClaimable(user);
        teamClaimed = teamTokensClaimed[user];

        // Global data
        governanceActions = userTotalGovernanceActions[user];
        totalClaimable = earnedClaimable + teamClaimable;
    }

    /**
     * @dev Get team pool statistics
     */
    function getTeamPoolInfo() external view returns (
        uint256 totalPool,
        uint256 tokensPerAction,
        uint256 actionsRequired,
        uint256 totalAllocated,
        uint256 totalClaimed,
        uint256 memberCount
    ) {
        totalPool = TEAM_TOKENS_POOL;
        tokensPerAction = teamTokensPerGovAction;
        actionsRequired = TEAM_TOKENS_POOL / teamTokensPerGovAction;
        totalAllocated = totalTeamTokensAllocated;

        // Calculate total claimed
        for (uint256 i = 0; i < teamMembers.length; i++) {
            totalClaimed += teamTokensClaimed[teamMembers[i]];
        }

        memberCount = teamMembers.length;
    }

    /**
     * @dev Get all team members
     */
    function getTeamMembers() external view returns (address[] memory) {
        return teamMembers;
    }

    /**
     * @dev Get team member info
     */
    function getTeamMemberInfo(address member) external view returns (
        bool isMember,
        uint256 allocated,
        uint256 claimed,
        uint256 claimable,
        uint256 govActions
    ) {
        isMember = isTeamMember[member];
        allocated = teamTokensAllocated[member];
        claimed = teamTokensClaimed[member];
        claimable = getTeamTokensClaimable(member);
        govActions = userTotalGovernanceActions[member];
    }
}
