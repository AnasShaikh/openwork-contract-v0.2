// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { GovernorUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import { GovernorSettingsUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import { GovernorCountingSimpleUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

// Interface to get earned tokens from Native OpenWork Job Contract
interface INativeOpenWorkJobContract {
    function getUserEarnedTokens(address user) external view returns (uint256);
    function getUserRewardInfo(address user) external view returns (uint256 cumulativeEarnings, uint256 totalTokens);
    function incrementGovernanceAction(address user) external;
    function teamTokensAllocated(address user) external view returns (uint256);
}

// UPDATED INTERFACE for the bridge to support new functionality
interface INativeChainBridge {
    function sendToRewardsChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function quoteRewardsChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
}

// Interface for OpenworkGenesis storage contract
interface IOpenworkGenesis {
    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 durationMinutes;
        bool isActive;
    }

    struct Earner {
        address earnerAddress;
        uint256 balance;
        uint256 total_governance_actions;
    }

    // DAO data setters
    function setStake(address staker, uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) external;
    function setEarner(address earnerAddress, uint256 balance, uint256 governanceActions) external;
    function setDelegate(address delegator, address delegatee) external;
    function setDelegatedVotingPower(address delegatee, uint256 power) external;
    function updateDelegatedVotingPower(address delegatee, uint256 powerChange, bool increase) external;
    function addProposalId(uint256 proposalId) external;
    function removeStaker(address staker) external;
    
    // NEW: Activity tracking for oracle members
    function updateMemberActivity(address member) external;

    // DAO data getters
    function getStake(address staker) external view returns (Stake memory);
    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive);
    function getEarner(address earnerAddress) external view returns (Earner memory);
    function getEarnerInfo(address earnerAddress) external view returns (address earner, uint256 balance, uint256 governanceActions);
    function getDelegate(address delegator) external view returns (address);
    function getDelegatedVotingPower(address delegatee) external view returns (uint256);
    function getAllStakers() external view returns (address[] memory);
    function getAllProposalIds() external view returns (uint256[] memory);
    function getProposalCount() external view returns (uint256);
    function getIsStaker(address staker) external view returns (bool);
    function getActiveStakersCount() external view returns (uint256);
}

contract NativeDAO is 
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // Bridge for cross-chain communication
    INativeChainBridge public bridge;
    
    // Genesis storage contract
    IOpenworkGenesis public genesis;
    
    // Governance parameters (same as main contract)
    uint256 public proposalStakeThreshold;
    uint256 public votingStakeThreshold;
    
    // Reward-based governance thresholds
    uint256 public proposalRewardThreshold;
    uint256 public votingRewardThreshold;

    // Governance/Admin pattern
    mapping(address => bool) public admins;

    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 durationMinutes;
        bool isActive;
    }

    struct Earner {
        address earnerAddress;
        uint256 balance;
        uint256 total_governance_actions;
    }
    
    // Events
    event AdminUpdated(address indexed admin, bool status);
    event StakeDataReceived(address indexed staker, uint256 amount, bool isActive);
    event EarnerUpdated(address indexed earner, uint256 newBalance, uint256 totalGovernanceActions);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event CrossContractCallFailed(address indexed account, string reason);
    event CrossContractCallSuccess(address indexed account);
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);
    event EarnedTokensUsedForGovernance(address indexed user, uint256 earnedTokens, string action);
    event GovernanceActionNotified(address indexed user, string action);
    event RewardThresholdUpdated(string thresholdType, uint256 newThreshold);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _owner, address _bridge, address _genesis) public initializer {
        __Governor_init("CrossChainNativeDAO");
        __GovernorSettings_init(
            1 minutes,
            5 minutes,
            100 * 10**18
        );
        __GovernorCountingSimple_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        bridge = INativeChainBridge(_bridge);
        genesis = IOpenworkGenesis(_genesis);

        // Initialize governance parameters
        proposalStakeThreshold = 100 * 10**18;
        votingStakeThreshold = 50 * 10**18;
        proposalRewardThreshold = 100 * 10**18;
        votingRewardThreshold = 100 * 10**18;

        // Owner is default admin
        admins[_owner] = true;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(admins[_msgSender()], "Admin");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(admins[msg.sender], "Admin");
        upgradeToAndCall(newImplementation, "");
    }

    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || _msgSender() == _executor(), "Unauthorized");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }
    
    // ==================== CONTRACT SETUP FUNCTIONS ====================
    
    function setNOWJContract(address _nowjContract) external onlyOwner {
        address oldContract = address(nowjContract);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        emit NOWJContractUpdated(oldContract, _nowjContract);
    }
    
    function setBridge(address _bridge) external onlyOwner {
        address oldBridge = address(bridge);
        bridge = INativeChainBridge(_bridge);
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    function setGenesis(address _genesis) external onlyOwner {
        address oldGenesis = address(genesis);
        genesis = IOpenworkGenesis(_genesis);
        emit GenesisUpdated(oldGenesis, _genesis);
    }
    
    // ==================== GOVERNANCE ELIGIBILITY CHECK FUNCTIONS ====================
    
    function _hasGovernanceEligibility(address account, uint256 stakeThreshold, uint256 rewardThreshold) internal view returns (bool) {
        // Check stake eligibility from Genesis
        IOpenworkGenesis.Stake memory stake = genesis.getStake(account);
        if (stake.isActive && stake.amount >= stakeThreshold) {
            return true;
        }
        
        // Check earned + team tokens eligibility
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            uint256 teamTokens = nowjContract.teamTokensAllocated(account);
            if ((earnedTokens + teamTokens) >= rewardThreshold) {
                return true;
            }
        }
        
        return false;
    }
    
    function canPropose(address account) public view returns (bool) {
        return _hasGovernanceEligibility(account, proposalStakeThreshold, proposalRewardThreshold);
    }
    
    function canVote(address account) public view returns (bool) {
        return _hasGovernanceEligibility(account, votingStakeThreshold, votingRewardThreshold);
    }

    function getUserGovernancePower(address account) external view returns (
        uint256 stakeAmount,
        uint256 earnedTokens,
        bool canProposeFlag,
        bool canVoteFlag
    ) {
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(account);
        stakeAmount = (userStake.isActive) ? userStake.amount : 0;

        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            uint256 earned = nowjContract.getUserEarnedTokens(account);
            uint256 teamTokens = nowjContract.teamTokensAllocated(account);
            earnedTokens = earned + teamTokens;
        }
        
        canProposeFlag = canPropose(account);
        canVoteFlag = canVote(account);
    }

    // ==================== DIRECT STAKE DATA UPDATE (for local use) ====================
    
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external {
        require(msg.sender == address(bridge), "Bridge");
        
        // Store in Genesis
        genesis.setStake(staker, amount, unlockTime, durationMinutes, isActive);
        
        emit StakeDataReceived(staker, amount, isActive);
    }
    
    // ==================== EARNER MANAGEMENT ====================
    
    function addOrUpdateEarner(address earnerAddress, uint256 balance, uint256 governanceActions) external onlyGovernance {
        require(earnerAddress != address(0), "Invalid address");
        
        // Store in Genesis
        genesis.setEarner(earnerAddress, balance, governanceActions);
        
        emit EarnerUpdated(earnerAddress, balance, governanceActions);
    }
    
    // ==================== DELEGATION FUNCTIONS ====================
    
    function delegate(address delegatee) external {
        address currentDelegate = genesis.getDelegate(msg.sender);
        require(delegatee != currentDelegate, "Already delegated");
        
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(msg.sender);
        require(userStake.isActive && userStake.amount > 0, "No stake");
        
        uint256 delegatorPower = userStake.amount * userStake.durationMinutes;
        
        if (currentDelegate != address(0)) {
            genesis.updateDelegatedVotingPower(currentDelegate, delegatorPower, false);
        }
        
        if (delegatee != address(0)) {
            genesis.updateDelegatedVotingPower(delegatee, delegatorPower, true);
        }
        
        genesis.setDelegate(msg.sender, delegatee);
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
    
    function getAllStakers() external view returns (address[] memory) {
        return genesis.getAllStakers();
    }

    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) {
        return genesis.getStakerInfo(staker);
    }
    
    function getEarner(address earnerAddress) external view returns (address, uint256, uint256) {
        return genesis.getEarnerInfo(earnerAddress);
    }
    
    function getVotingPower(address account) external view returns (uint256 own, uint256 delegated, uint256 reward, uint256 total) {
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(account);
        own = (userStake.isActive && userStake.amount > 0) ? userStake.amount * userStake.durationMinutes : 0;
        delegated = genesis.getDelegatedVotingPower(account);
        
        // Add reward-based voting power (earned + team tokens)
        reward = 0;
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            uint256 teamTokens = nowjContract.teamTokensAllocated(account);
            reward = earnedTokens + teamTokens;
        }
        
        total = own + delegated + reward;
    }
    
    function getGovernanceEligibility(address account) external view returns (bool canProposeFlag, bool canVoteFlag, uint256 stakeAmount, uint256 rewardTokens) {
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(account);
        stakeAmount = userStake.isActive ? userStake.amount : 0;
        
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            uint256 teamTokens = nowjContract.teamTokensAllocated(account);
            rewardTokens = earnedTokens + teamTokens;
        }
        
        canProposeFlag = canPropose(account);
        canVoteFlag = canVote(account);
    }
    
    function getComprehensiveGovernanceInfo(address account) external view returns (
        bool hasActiveStake,
        uint256 stakeAmount,
        uint256 earnedTokens,
        bool meetsProposalThreshold,
        bool meetsVotingThreshold,
        uint256 votingPower
    ) {
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(account);
        hasActiveStake = userStake.isActive;
        stakeAmount = hasActiveStake ? userStake.amount : 0;
        
        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            earnedTokens = nowjContract.getUserEarnedTokens(account);
        }
        
        meetsProposalThreshold = canPropose(account);
        meetsVotingThreshold = canVote(account);
        votingPower = _getVotes(account, 0, "");
    }

    function getGovernanceThresholds() external view returns (uint256 proposalStakeThreshold_, uint256 votingStakeThreshold_, uint256 proposalRewardThreshold_, uint256 votingRewardThreshold_) {
        return (proposalStakeThreshold, votingStakeThreshold, proposalRewardThreshold, votingRewardThreshold);
    }
    
    // ==================== GOVERNOR REQUIRED FUNCTIONS ====================
    
    function _getVotes(address account, uint256, bytes memory) internal view override returns (uint256) {
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(account);
        uint256 ownPower = 0;
        if (userStake.isActive && userStake.amount > 0) {
            ownPower = userStake.amount * userStake.durationMinutes;
        }
        
        // Add reward-based voting power
        uint256 rewardPower = 0;
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            rewardPower = earnedTokens; // 1:1 mapping of earned tokens to voting power
        }
        
        uint256 totalPower = ownPower + genesis.getDelegatedVotingPower(account) + rewardPower;
        return totalPower;
    }
    
    function hasVoted(uint256 proposalId, address account) public view override(IGovernor, GovernorCountingSimpleUpgradeable) returns (bool) {
        return super.hasVoted(proposalId, account);
    }
    
    // ==================== VOTING FUNCTIONS ====================
    
    // REVISED: _castVote now includes NOWJC governance action increment
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal override returns (uint256) {
        
        require(canVote(account), "Cannot vote");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(account);
        if (!userStake.isActive || userStake.amount < votingStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
                if (earnedTokens >= votingRewardThreshold) {
                    emit EarnedTokensUsedForGovernance(account, earnedTokens, "vote");
                }
            }
        }
        
        // NEW: Record member activity for oracle tracking
        genesis.updateMemberActivity(account);
        
        // IMPORTANT: Call local NOWJC to increment governance action
        require(address(nowjContract) != address(0), "NOWJ not set");
        nowjContract.incrementGovernanceAction(account);
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    // REVISED: propose now includes NOWJC governance action increment
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override returns (uint256) {
        
        require(canPropose(msg.sender), "Cannot propose");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        IOpenworkGenesis.Stake memory userStake = genesis.getStake(msg.sender);
        if (!userStake.isActive || userStake.amount < proposalStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(msg.sender);
                if (earnedTokens >= proposalRewardThreshold) {
                    emit EarnedTokensUsedForGovernance(msg.sender, earnedTokens, "propose");
                }
            }
        }
        
        // NEW: Record member activity for oracle tracking
        genesis.updateMemberActivity(msg.sender);
        
        // IMPORTANT: Call local NOWJC to increment governance action
        require(address(nowjContract) != address(0), "NOWJ not set");
        nowjContract.incrementGovernanceAction(msg.sender);
        
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        genesis.addProposalId(proposalId);
        return proposalId;
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
    
    function proposalThreshold() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.proposalThreshold();
    }
    
    function getActiveProposalIds() external view returns (uint256[] memory activeIds, ProposalState[] memory states) {
        uint256[] memory allProposalIds = genesis.getAllProposalIds();
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            if (state(allProposalIds[i]) == ProposalState.Active) {
                activeCount++;
            }
        }
        
        activeIds = new uint256[](activeCount);
        states = new ProposalState[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            ProposalState currentState = state(allProposalIds[i]);
            if (currentState == ProposalState.Active) {
                activeIds[index] = allProposalIds[i];
                states[index] = currentState;
                index++;
            }
        }
    }
    
    function getAllProposalIds() external view returns (uint256[] memory ids, ProposalState[] memory states) {
        uint256[] memory allProposalIds = genesis.getAllProposalIds();
        ids = new uint256[](allProposalIds.length);
        states = new ProposalState[](allProposalIds.length);
        
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            ids[i] = allProposalIds[i];
            states[i] = state(allProposalIds[i]);
        }
    }
    
    function getProposalCount() external view returns (uint256) {
        return genesis.getProposalCount();
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function updateProposalStakeThreshold(uint256 newThreshold) external onlyGovernance {
        proposalStakeThreshold = newThreshold;
        emit RewardThresholdUpdated("proposalStake", newThreshold);
    }
    
    function updateVotingStakeThreshold(uint256 newThreshold) external onlyGovernance {
        votingStakeThreshold = newThreshold;
        emit RewardThresholdUpdated("votingStake", newThreshold);
    }
    
    function updateProposalRewardThreshold(uint256 newThreshold) external onlyGovernance {
        proposalRewardThreshold = newThreshold;
        emit RewardThresholdUpdated("proposalReward", newThreshold);
    }
    
    function updateVotingRewardThreshold(uint256 newThreshold) external onlyGovernance {
        votingRewardThreshold = newThreshold;
        emit RewardThresholdUpdated("votingReward", newThreshold);
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================

    function withdraw() external {
        require(admins[msg.sender], "Admin");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Failed");
    }
    
    // Allow contract to receive ETH for paying LayerZero fees
    receive() external payable override {}
}
