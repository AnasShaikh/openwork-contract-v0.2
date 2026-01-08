// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { GovernorUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import { GovernorSettingsUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import { GovernorCountingSimpleUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
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

    function sendUpgradeCommand(
        uint32 targetChainId,
        address targetProxy,
        address newImplementation,
        bytes calldata _options
    ) external payable;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

/// @title ETHOpenworkDAO
/// @notice Governor contract for Openwork DAO governance on ETH Sepolia
/// @dev Implements staking, delegation, and cross-chain voting power sync
///      Compatible with OpenZeppelin Governor and Tally
contract ETHOpenworkDAO is 
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    IERC20 public openworkToken;
    IETHLZOpenworkBridge public bridge;
    uint256 public constant MIN_STAKE = 100 * 10**18;
    uint32 public chainId;
    
    // Governance parameters (updatable) - for Tally compatibility
    uint256 public proposalThresholdAmount;
    uint256 public votingThresholdAmount;
    uint256 public unstakeDelay;
    
    // Synced user reward data from NOWJC
    mapping(address => uint256) public userTotalRewards;
    
    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 durationMinutes;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public unstakeRequestTime;
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotingPower;
    mapping(address => bool) public isStaker;
    
    // Helper arrays for easier testing
    uint256[] public proposalIds;
    address[] public allStakers;

    // Governance/Admin pattern
    mapping(address => bool) public admins;

    // Storage gap for upgrade safety
    uint256[50] private __gap;

    // Events
    event AdminUpdated(address indexed admin, bool status);
    event StakeCreated(address indexed staker, uint256 amount, uint256 durationMinutes);
    event StakeRemoved(address indexed staker, uint256 amount);
    event UnstakeRequested(address indexed staker, uint256 requestTime, uint256 availableTime);
    event UnstakeCompleted(address indexed staker, uint256 amount);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event BridgeUpdated(address indexed newBridge);
    event ThresholdUpdated(string thresholdType, uint256 newThreshold);
    event StakeDataSentCrossChain(address indexed staker, bool isActive, uint256 fee);
    event GovernanceActionSentToBridge(address indexed user, string action, uint256 fee);
    event CrossContractCallFailed(address indexed account, string reason);
    event UserRewardsSynced(address indexed user, uint256 totalRewards, uint32 sourceChain);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner,
        address _openworkToken,
        uint32 _chainId,
        address _bridge
    ) public initializer {
        __Governor_init("OpenWorkDAO");
        __GovernorSettings_init(
            1 minutes,
            5 minutes,
            100 * 10**18  // This is the base proposalThreshold for Governor
        );
        __GovernorCountingSimple_init();
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        openworkToken = IERC20(_openworkToken);
        chainId = _chainId;
        bridge = IETHLZOpenworkBridge(_bridge);

        // Initialize governance parameters
        proposalThresholdAmount = 100 * 10**18;
        votingThresholdAmount = 50 * 10**18;
        unstakeDelay = 24 hours;

        // Owner is default admin
        admins[_owner] = true;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ==================== MESSAGE HANDLERS ====================

    /// @notice Handle voting power sync from Native chain via bridge
    /// @param user Address of the user
    /// @param totalRewards Total rewards determining voting power
    /// @param sourceChain LayerZero endpoint ID of source chain
    function handleSyncVotingPower(address user, uint256 totalRewards, uint32 sourceChain) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        userTotalRewards[user] = totalRewards;
        emit UserRewardsSynced(user, totalRewards, sourceChain);
    }
    
    // ==================== ADMIN FUNCTIONS ====================

    /// @notice Set the bridge contract address
    /// @param _bridge Address of the ETHLZOpenworkBridge contract
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Invalid bridge address");
        bridge = IETHLZOpenworkBridge(_bridge);
        emit BridgeUpdated(_bridge);
    }
    
    // ==================== CROSS-CHAIN MESSAGING VIA BRIDGE ====================
    
    /**
     * @notice Send governance notification to NOWJC via Bridge
     * @param account Address of the user who performed governance action
     * @param actionType Type of governance action
     * @param _options LayerZero options for the message
     */
    function _sendGovernanceNotificationViaBridge(
        address account, 
        string memory actionType,
        bytes memory _options
    ) internal {
        if (address(bridge) == address(0)) {
            emit CrossContractCallFailed(account, "Bridge not set");
            return;
        }
        
        // Prepare payload for NOWJC chain
        bytes memory payload = abi.encode("incrementGovernanceAction", account);
        
        // Send directly using user-provided msg.value and options
        try bridge.sendToNativeChain{value: msg.value}("incrementGovernanceAction", payload, _options) {
            emit GovernanceActionSentToBridge(account, actionType, msg.value);
        } catch {
            emit CrossContractCallFailed(account, "Failed to send governance action to Bridge");
        }
    }
    
    /**
     * @notice Send stake data cross-chain via Bridge
     * @param staker Address of the staker
     * @param isActive Whether stake is active
     * @param _options LayerZero options for the message
     */
    function _sendStakeDataCrossChain(
        address staker, 
        bool isActive,
        bytes memory _options
    ) internal {
        if (address(bridge) == address(0)) return;
        
        Stake memory userStake = stakes[staker];
        
        // Get fee quote from Bridge
        bytes memory payload = abi.encode(
            "updateStakeData",
            staker,
            userStake.amount,
            userStake.unlockTime,
            userStake.durationMinutes,
            isActive
        );
        
        uint256 fee = 0;
        try bridge.quoteNativeChain(payload, _options) returns (uint256 quotedFee) {
            fee = quotedFee;
        } catch {
            return;
        }
        
        // Send via Bridge if fee is available
        if (fee > 0 && address(this).balance >= fee) {
            try bridge.sendToNativeChain{value: fee}("updateStakeData", payload, _options) {
                emit StakeDataSentCrossChain(staker, isActive, fee);
            } catch {
                // Silent fail to avoid blocking other operations
            }
        }
    }
    
    // ==================== GOVERNANCE POWER CALCULATION ====================

    /// @notice Get combined governance power from stake and rewards
    /// @param account Address to query
    /// @return Combined governance power
    function getCombinedGovernancePower(address account) public view returns (uint256) {
        uint256 stakePower = stakes[account].amount;
        uint256 rewardPower = userTotalRewards[account];
        return stakePower + rewardPower;
    }

    // ==================== STAKING FUNCTIONS ====================

    /// @notice Stake tokens for governance participation
    /// @param amount Amount of tokens to stake (min 100 tokens)
    /// @param durationMinutes Lock duration in minutes (1-3)
    /// @param _options LayerZero options for cross-chain sync
    function stake(
        uint256 amount,
        uint256 durationMinutes,
        bytes calldata _options
    ) external payable nonReentrant {
        require(amount >= MIN_STAKE, "Minimum stake is 100 tokens");
        require(durationMinutes >= 1 && durationMinutes <= 3, "Duration must be 1-3 minutes");
        require(stakes[msg.sender].amount == 0, "Already staking");
        
        openworkToken.transferFrom(msg.sender, address(this), amount);
        
        stakes[msg.sender] = Stake({
            amount: amount,
            unlockTime: block.timestamp + (durationMinutes * 60),
            durationMinutes: durationMinutes
        });

        if (!isStaker[msg.sender]) {
            allStakers.push(msg.sender);
            isStaker[msg.sender] = true;
        }
        
        emit StakeCreated(msg.sender, amount, durationMinutes);
        
        // Send stake data cross-chain via Bridge
        _sendStakeDataCrossChain(msg.sender, true, _options);
    }
    
    /// @notice Unstake tokens (requires two-step process with delay)
    /// @param _options LayerZero options for cross-chain sync
    function unstake(bytes calldata _options) external payable nonReentrant {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");
        require(block.timestamp >= userStake.unlockTime, "Stake still locked");
        
        if (unstakeRequestTime[msg.sender] == 0) {
            unstakeRequestTime[msg.sender] = block.timestamp;
            emit UnstakeRequested(msg.sender, block.timestamp, block.timestamp + unstakeDelay);
        } else {
            require(block.timestamp >= unstakeRequestTime[msg.sender] + unstakeDelay, "Unstake delay not met");

            uint256 stakeAmount = userStake.amount;
            
            delete stakes[msg.sender];
            delete unstakeRequestTime[msg.sender];
            
            if (stakes[msg.sender].amount == 0) {
                isStaker[msg.sender] = false;
            }
            
            openworkToken.transfer(msg.sender, stakeAmount);
            
            emit UnstakeCompleted(msg.sender, stakeAmount);
            
            // Send updated stake data (inactive) cross-chain via Bridge
            _sendStakeDataCrossChain(msg.sender, false, _options);
        }
    }
    
    /// @notice Remove stake from an address (governance only - for slashing)
    /// @param staker Address to remove stake from
    /// @param removeAmount Amount to remove
    /// @param _options LayerZero options for cross-chain sync
    function removeStake(
        address staker,
        uint256 removeAmount,
        bytes calldata _options
    ) external payable onlyGovernance nonReentrant {
        require(stakes[staker].amount > 0, "No stake found");
        require(removeAmount <= stakes[staker].amount, "Remove amount exceeds stake");
        
        stakes[staker].amount -= removeAmount;
        
        bool isActive = true;
        if (stakes[staker].amount < MIN_STAKE) {
            delete stakes[staker];
            isActive = false;
        }
        
        emit StakeRemoved(staker, removeAmount);
        
        // Send updated stake data cross-chain via Bridge
        _sendStakeDataCrossChain(staker, isActive, _options);
    }
    
    // ==================== DELEGATION FUNCTIONS ====================

    /// @notice Delegate voting power to another address
    /// @param delegatee Address to delegate to (zero to revoke)
    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        require(delegatee != currentDelegate, "Already delegated to this address");
        require(stakes[msg.sender].amount > 0, "No stake to delegate");
        
        uint256 delegatorPower = stakes[msg.sender].amount * stakes[msg.sender].durationMinutes;
        
        if (currentDelegate != address(0)) {
            delegatedVotingPower[currentDelegate] -= delegatorPower;
        }
        
        if (delegatee != address(0)) {
            delegatedVotingPower[delegatee] += delegatorPower;
        }
        
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
    }
    
    // ==================== IERC6372 IMPLEMENTATIONS ====================
    
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }
    
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // ==================== VIEW FUNCTIONS ====================

    /// @notice Get all addresses that have staked
    /// @return Array of staker addresses
    function getAllStakers() external view returns (address[] memory) {
        return allStakers;
    }

    /// @notice Get detailed staker information
    /// @param staker Address to query
    /// @return amount Staked amount
    /// @return unlockTime Timestamp when stake unlocks
    /// @return durationMinutes Lock duration in minutes
    /// @return hasStake Whether address has an active stake
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool hasStake) {
        Stake memory userStake = stakes[staker];
        return (userStake.amount, userStake.unlockTime, userStake.durationMinutes, userStake.amount > 0);
    }
    
    /// @notice Get when unstake becomes available after request
    /// @param staker Address to query
    /// @return Timestamp when unstake available (0 if not requested)
    function getUnstakeAvailableTime(address staker) external view returns (uint256) {
        if (unstakeRequestTime[staker] == 0) return 0;
        return unstakeRequestTime[staker] + unstakeDelay;
    }
    
    /// @notice Get detailed voting power breakdown
    /// @param account Address to query
    /// @return own Own staking power
    /// @return delegated Power delegated to this address
    /// @return reward Power from rewards
    /// @return total Total voting power
    function getVotingPower(address account) external view returns (uint256 own, uint256 delegated, uint256 reward, uint256 total) {
        Stake memory userStake = stakes[account];
        own = userStake.amount > 0 ? userStake.amount * userStake.durationMinutes : 0;
        delegated = delegatedVotingPower[account];
        reward = userTotalRewards[account];
        total = own + delegated + reward;
    }
    
    /// @notice Check governance eligibility for an account
    /// @param account Address to check
    /// @return canPropose Whether account can create proposals
    /// @return canVote Whether account can vote
    /// @return stakeAmount Current stake amount
    /// @return rewardTokens Reward tokens from Native chain
    /// @return combinedPower Combined governance power
    /// @return votingPower Actual voting power
    function getGovernanceEligibility(address account) external view returns (bool canPropose, bool canVote, uint256 stakeAmount, uint256 rewardTokens, uint256 combinedPower, uint256 votingPower) {
        stakeAmount = stakes[account].amount;
        rewardTokens = userTotalRewards[account];
        combinedPower = getCombinedGovernancePower(account);
        votingPower = _getVotes(account, 0, "");
        
        canPropose = combinedPower >= proposalThresholdAmount;
        canVote = combinedPower >= votingThresholdAmount;
    }
    
    // ==================== GOVERNOR OVERRIDES FOR TALLY COMPATIBILITY ====================
    
    /**
     * @dev Override _getVotes to include cross-chain reward data in voting power
     * This ensures Tally sees the complete voting power including rewards
     */
    function _getVotes(address account, uint256, bytes memory) internal view override returns (uint256) {
        Stake memory userStake = stakes[account];
        uint256 ownPower = 0;
        if (userStake.amount > 0) {
            ownPower = userStake.amount * userStake.durationMinutes;
        }
        
        // Add reward-based voting power using synced data
        uint256 rewardPower = userTotalRewards[account];
        
        uint256 totalPower = ownPower + delegatedVotingPower[account] + rewardPower;
        return totalPower;
    }
    
    /**
     * @dev Override proposalThreshold for Tally compatibility
     * Returns our custom threshold that considers stake + rewards
     */
    function proposalThreshold() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return proposalThresholdAmount;
    }
    
    /**
     * @dev Override _castVote to add cross-chain governance notification
     * But let Governor handle eligibility checks using our _getVotes() function
     */
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal override returns (uint256) {
        
        // Send governance notification to NOWJC via Bridge if msg.value provided
        if (msg.value > 0) {
            _sendGovernanceNotificationViaBridge(account, "vote", "");
        }
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    /**
     * Override propose to add cross-chain governance notification  
     * But let Governor handle eligibility checks using our proposalThreshold()
     */
    function propose(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        string memory description,
        bytes calldata _options
    ) external payable returns (uint256) {
        
        // Send governance notification to NOWJC via Bridge
        _sendGovernanceNotificationViaBridge(msg.sender, "propose", _options);
        
        uint256 proposalId = GovernorUpgradeable.propose(targets, values, calldatas, description);
        proposalIds.push(proposalId);
        return proposalId;
    }
    
    /**
     * @dev Additional castVote function with options for cross-chain calls
     */
    function castVote(
        uint256 proposalId, 
        uint8 support,
        bytes calldata _options
    ) external payable returns (uint256) {
        
        // Send governance notification to NOWJC via Bridge
        _sendGovernanceNotificationViaBridge(msg.sender, "vote", _options);
        
        return _castVote(proposalId, msg.sender, support, "", "");
    }
    
    function hasVoted(uint256 proposalId, address account) public view override(IGovernor, GovernorCountingSimpleUpgradeable) returns (bool) {
        return super.hasVoted(proposalId, account);
    }
    
    function quorum(uint256) public pure override returns (uint256) {
        return 50 * 10**18;
    }
    
    function votingDelay() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }
    
    function votingPeriod() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }
    
    /// @notice Get all currently active proposals
    /// @return activeIds Array of active proposal IDs
    /// @return states Array of proposal states
    function getActiveProposalIds() external view returns (uint256[] memory activeIds, ProposalState[] memory states) {
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (state(proposalIds[i]) == ProposalState.Active) {
                activeCount++;
            }
        }
        
        activeIds = new uint256[](activeCount);
        states = new ProposalState[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            ProposalState currentState = state(proposalIds[i]);
            if (currentState == ProposalState.Active) {
                activeIds[index] = proposalIds[i];
                states[index] = currentState;
                index++;
            }
        }
    }
    
    /// @notice Get all proposals with their states
    /// @return ids Array of all proposal IDs
    /// @return states Array of proposal states
    function getAllProposalIds() external view returns (uint256[] memory ids, ProposalState[] memory states) {
        ids = new uint256[](proposalIds.length);
        states = new ProposalState[](proposalIds.length);
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            ids[i] = proposalIds[i];
            states[i] = state(proposalIds[i]);
        }
    }
    
    /// @notice Get total number of proposals created
    /// @return Number of proposals
    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }
    
    // ==================== QUOTE FUNCTIONS ====================

    /// @notice Get fee quote for stake update cross-chain message
    /// @param staker Address of the staker
    /// @param isActive Whether stake is active
    /// @param _options LayerZero options
    /// @return fee Native token fee required
    function quoteStakeUpdate(
        address staker,
        bool isActive,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;
        
        Stake memory userStake = stakes[staker];
        bytes memory payload = abi.encode(
            "updateStakeData",
            staker,
            userStake.amount,
            userStake.unlockTime,
            userStake.durationMinutes,
            isActive
        );
        return bridge.quoteNativeChain(payload, _options);
    }
    
    /// @notice Get fee quote for governance notification cross-chain message
    /// @param account Address performing governance action
    /// @param _options LayerZero options
    /// @return fee Native token fee required
    function quoteGovernanceNotification(
        address account,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (address(bridge) == address(0)) return 0;
        
        bytes memory payload = abi.encode("incrementGovernanceAction", account);
        return bridge.quoteNativeChain(payload, _options);
    }
    
    // ==================== GOVERNANCE ADMIN FUNCTIONS ====================

    /// @notice Update the proposal threshold (governance only)
    /// @param newThreshold New threshold amount
    function updateProposalThreshold(uint256 newThreshold) external onlyGovernance {
        proposalThresholdAmount = newThreshold;
        emit ThresholdUpdated("proposalThreshold", newThreshold);
    }
    
    /// @notice Update the voting threshold (governance only)
    /// @param newThreshold New threshold amount
    function updateVotingThreshold(uint256 newThreshold) external onlyGovernance {
        votingThresholdAmount = newThreshold;
        emit ThresholdUpdated("votingThreshold", newThreshold);
    }

    /// @notice Update the unstake delay period (governance only)
    /// @param newDelay New delay in seconds
    function updateUnstakeDelay(uint256 newDelay) external onlyGovernance {
        unstakeDelay = newDelay;
    }
    
    // ==================== ADMIN MANAGEMENT ====================

    /// @notice Set admin status for an address
    /// @param _admin Address to modify
    /// @param _status True to grant admin, false to revoke
    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || _msgSender() == _executor(), "Only owner or governance");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    // ==================== EMERGENCY FUNCTIONS ====================

    /// @notice Withdraw accumulated ETH from the contract
    function withdraw() external {
        require(admins[msg.sender], "Only admin");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed");
    }

    /// @notice Upgrade a contract on this or another chain
    /// @param targetChainId Chain ID where contract is deployed
    /// @param targetProxy Proxy contract address to upgrade
    /// @param newImplementation New implementation address
    /// @param _options LayerZero options for cross-chain
    function upgradeContract(
        uint32 targetChainId,
        address targetProxy,
        address newImplementation,
        bytes calldata _options
    ) external payable {
        require(admins[msg.sender], "Only admin");
        if (targetChainId == chainId) {
            IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
        } else {
            bridge.sendUpgradeCommand{value: msg.value}(
                targetChainId,
                targetProxy,
                newImplementation,
                _options
            );
        }
    }

    /// @notice Emergency withdraw tokens from the contract
    /// @param amount Amount of tokens to withdraw
    function emergencyWithdrawTokens(uint256 amount) external {
        require(admins[msg.sender], "Only admin");
        require(openworkToken.transfer(msg.sender, amount), "Token transfer failed");
    }
}