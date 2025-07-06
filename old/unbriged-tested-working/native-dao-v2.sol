// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Interface to call back to main DAO
interface IMainDAO {
    function incrementEarnerGovernanceActions(address account) external;
}

// Interface to get earned tokens from Native OpenWork Job Contract
interface INativeOpenWorkJobContract {
    function getUserEarnedTokens(address user) external view returns (uint256);
    function getUserRewardInfo(address user) external view returns (uint256 cumulativeEarnings, uint256 totalTokens);
}

// Interface to notify governance actions in Rewards Contract
interface IRewardsContract {
    function notifyGovernanceAction(address account) external;
}

contract nativeDAO is Governor, GovernorSettings, GovernorCountingSimple, Ownable {
    // Cross-chain sender contract address (authorized to send stake data)
    address public authorizedSender;
    
    // Main DAO contract for cross-contract calls
    IMainDAO public mainDAO;
    
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // Rewards Contract for governance action tracking
    IRewardsContract public rewardsContract;
    
    // Governance parameters (same as main contract)
    uint256 public proposalStakeThreshold = 100 * 10**18;
    uint256 public votingStakeThreshold = 50 * 10**18;
    
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

    mapping(address => Earner) public earners;
    mapping(address => Stake) public stakes;
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotingPower;
    mapping(address => bool) public isStaker;
    
    // Helper arrays
    uint256[] public proposalIds;
    address[] public allStakers;
    
    // Events
    event StakeDataReceived(address indexed staker, uint256 amount, bool isActive);
    event AuthorizedSenderUpdated(address indexed oldSender, address indexed newSender);
    event EarnerUpdated(address indexed earner, uint256 newBalance, uint256 totalGovernanceActions);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event CrossContractCallFailed(address indexed account, string reason);
    event CrossContractCallSuccess(address indexed account);
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event RewardsContractUpdated(address indexed oldContract, address indexed newContract);
    event EarnedTokensUsedForGovernance(address indexed user, uint256 earnedTokens, string action);
    event GovernanceActionNotified(address indexed user, string action);
    event GovernanceActionIncremented(address indexed user, string action); // ADDED: Missing event declaration
    
    modifier onlyAuthorizedSender() {
        require(msg.sender == authorizedSender, "Not authorized sender");
        _;
    }
    
    constructor(address initialOwner) 
        Governor("nativedao")
        GovernorSettings(
            1 minutes,
            5 minutes,
            100 * 10**18
        )
        Ownable(initialOwner)
    {}
    
    // Set authorized sender (main staking contract)
    function setAuthorizedSender(address _sender) external onlyOwner {
        address oldSender = authorizedSender;
        authorizedSender = _sender;
        emit AuthorizedSenderUpdated(oldSender, _sender);
    }
    
    // Set main DAO contract address
    function setMainDAO(address _mainDAO) external onlyOwner {
        mainDAO = IMainDAO(_mainDAO);
    }
    
    // Set Native OpenWork Job Contract address
    function setNOWJContract(address _nowjContract) external onlyOwner {
        address oldContract = address(nowjContract);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        emit NOWJContractUpdated(oldContract, _nowjContract);
    }
    
    // Set Rewards Contract address
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        address oldContract = address(rewardsContract);
        rewardsContract = IRewardsContract(_rewardsContract);
        emit RewardsContractUpdated(oldContract, _rewardsContract);
    }
    
    // ADDED: Helper function to notify rewards contract about governance actions
    function _notifyRewardsContract(address account, string memory actionType) private {
        if (address(rewardsContract) != address(0)) {
            try rewardsContract.notifyGovernanceAction(account) {
                emit GovernanceActionNotified(account, actionType);
            } catch Error(string memory reason) {
                emit CrossContractCallFailed(account, string(abi.encodePacked("Rewards notification failed: ", reason)));
            } catch {
                emit CrossContractCallFailed(account, "Rewards notification failed: Unknown error");
            }
        }
    }
    
    // ADDED: Helper function to call main DAO increment function
    function _callMainDAOIncrement(address account) private {
        if (address(mainDAO) != address(0)) {
            try mainDAO.incrementEarnerGovernanceActions(account) {
                emit CrossContractCallSuccess(account);
            } catch Error(string memory reason) {
                emit CrossContractCallFailed(account, string(abi.encodePacked("MainDAO increment failed: ", reason)));
            } catch {
                emit CrossContractCallFailed(account, "MainDAO increment failed: Unknown error");
            }
        }
    }
    
    // Helper function to increment governance actions for earners (like Main DAO)
    function _incrementGovernanceActions(address account, string memory actionType) private {
        // Notify rewards contract of governance action
        _notifyRewardsContract(account, actionType);
        
        // Also call main DAO for cross-contract compatibility
        _callMainDAOIncrement(account);
        
        // Emit local event
        emit GovernanceActionIncremented(account, actionType);
    }

    // ==================== GOVERNANCE ELIGIBILITY CHECK FUNCTIONS ====================
    
    /**
     * @notice Check if user has sufficient stake OR earned tokens for proposals
     * @param account The user address to check
     * @return True if user meets proposal requirements
     */
    function canPropose(address account) public view returns (bool) {
        // First check if user has sufficient active stake
        if (stakes[account].isActive && stakes[account].amount >= proposalStakeThreshold) {
            return true;
        }
        
        // If no sufficient stake, check earned tokens from NOWJ contract
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            return earnedTokens >= proposalStakeThreshold;
        }
        
        return false;
    }
    
    /**
     * @notice Check if user has sufficient stake OR earned tokens for voting
     * @param account The user address to check
     * @return True if user meets voting requirements
     */
    function canVote(address account) public view returns (bool) {
        // First check if user has sufficient active stake
        if (stakes[account].isActive && stakes[account].amount >= votingStakeThreshold) {
            return true;
        }
        
        // If no sufficient stake, check earned tokens from NOWJ contract
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            return earnedTokens >= votingStakeThreshold;
        }
        
        return false;
    }

    /**
     * @notice Get user's governance power from stake and earned tokens
     * @param account The user address
     * @return stakeAmount Current active stake amount
     * @return earnedTokens Total earned tokens from NOWJ
     * @return canProposeFlag Whether user can propose
     * @return canVoteFlag Whether user can vote
     */
    function getUserGovernancePower(address account) external view returns (
        uint256 stakeAmount,
        uint256 earnedTokens,
        bool canProposeFlag,
        bool canVoteFlag
    ) {
        Stake memory userStake = stakes[account];
        stakeAmount = (userStake.isActive) ? userStake.amount : 0;
        
        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            earnedTokens = nowjContract.getUserEarnedTokens(account);
        }
        
        canProposeFlag = canPropose(account);
        canVoteFlag = canVote(account);
    }

    // ==================== EXISTING CONTRACT FUNCTIONS (UPDATED) ====================
    
    // Receive stake data from main contract
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external onlyAuthorizedSender {
        stakes[staker] = Stake({
            amount: amount,
            unlockTime: unlockTime,
            durationMinutes: durationMinutes,
            isActive: isActive
        });
        
        // Update staker tracking
        if (isActive && !isStaker[staker]) {
            allStakers.push(staker);
            isStaker[staker] = true;
        } else if (!isActive && isStaker[staker]) {
            isStaker[staker] = false;
        }
        
        emit StakeDataReceived(staker, amount, isActive);
    }
    
    // Governance functions to manage earners (similar to main contract)
    function addOrUpdateEarner(address earnerAddress, uint256 balance, uint256 governanceActions) external onlyGovernance {
        require(earnerAddress != address(0), "Invalid earner address");
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            total_governance_actions: governanceActions
        });
        
        emit EarnerUpdated(earnerAddress, balance, governanceActions);
    }
    
    // Delegation function
    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        require(delegatee != currentDelegate, "Already delegated to this address");
        require(stakes[msg.sender].isActive && stakes[msg.sender].amount > 0, "No active stake to delegate");
        
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
    
    // Required IERC6372 implementations
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }
    
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // View functions
    function getAllStakers() external view returns (address[] memory) {
        return allStakers;
    }

    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) {
        Stake memory userStake = stakes[staker];
        return (userStake.amount, userStake.unlockTime, userStake.durationMinutes, userStake.isActive);
    }
    
    function getEarner(address earnerAddress) external view returns (address, uint256, uint256) {
        Earner memory earner = earners[earnerAddress];
        return (earner.earnerAddress, earner.balance, earner.total_governance_actions);
    }
    
    // Governor required functions
    function _getVotes(address account, uint256, bytes memory) internal view override returns (uint256) {
        Stake memory userStake = stakes[account];
        uint256 ownPower = 0;
        if (userStake.isActive && userStake.amount > 0) {
            ownPower = userStake.amount * userStake.durationMinutes;
        }
        
        uint256 totalPower = ownPower + delegatedVotingPower[account];
        return totalPower;
    }
    
    function hasVoted(uint256 proposalId, address account) public view override(IGovernor, GovernorCountingSimple) returns (bool) {
        return super.hasVoted(proposalId, account);
    }
    
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal override returns (uint256) {
        
        // UPDATED: Check if user can vote (stake OR earned tokens)
        require(canVote(account), "Insufficient stake or earned tokens to vote");
        
        // Emit event if user is using earned tokens (no active stake)
        if (!stakes[account].isActive || stakes[account].amount < votingStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
                if (earnedTokens >= votingStakeThreshold) {
                    emit EarnedTokensUsedForGovernance(account, earnedTokens, "vote");
                }
            }
        }
        
        // ADDED: Increment governance actions for voting
        _incrementGovernanceActions(account, "vote");
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override returns (uint256) {
        
        // UPDATED: Check if user can propose (stake OR earned tokens)
        require(canPropose(msg.sender), "Insufficient stake or earned tokens to propose");
        
        // Emit event if user is using earned tokens (no active stake)
        if (!stakes[msg.sender].isActive || stakes[msg.sender].amount < proposalStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(msg.sender);
                if (earnedTokens >= proposalStakeThreshold) {
                    emit EarnedTokensUsedForGovernance(msg.sender, earnedTokens, "propose");
                }
            }
        }
        
        // UPDATED: Increment governance actions for proposing
        _incrementGovernanceActions(msg.sender, "propose");
        
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        proposalIds.push(proposalId);
        return proposalId;
    }
    
    function quorum(uint256) public pure override returns (uint256) {
        return 50 * 10**18;
    }
    
    // Required overrides
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }
    
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }
    
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
    
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
    
    function getAllProposalIds() external view returns (uint256[] memory ids, ProposalState[] memory states) {
        ids = new uint256[](proposalIds.length);
        states = new ProposalState[](proposalIds.length);
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            ids[i] = proposalIds[i];
            states[i] = state(proposalIds[i]);
        }
    }
    
    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }
    
    // Admin functions
    function updateProposalStakeThreshold(uint256 newThreshold) external onlyGovernance {
        proposalStakeThreshold = newThreshold;
    }
    
    function updateVotingStakeThreshold(uint256 newThreshold) external onlyGovernance {
        votingStakeThreshold = newThreshold;
    }
    
    function getVotingPower(address account) external view returns (uint256 own, uint256 delegated, uint256 total) {
        Stake memory userStake = stakes[account];
        own = (userStake.isActive && userStake.amount > 0) ? userStake.amount * userStake.durationMinutes : 0;
        delegated = delegatedVotingPower[account];
        total = own + delegated;
    }

    // ==================== NEW VIEW FUNCTIONS FOR EARNED TOKENS ====================
    
    /**
     * @notice Get comprehensive governance info for a user
     * @param account The user address
     * @return hasActiveStake Whether user has active stake
     * @return stakeAmount Current stake amount
     * @return earnedTokens Earned tokens from NOWJ
     * @return meetsProposalThreshold Can propose
     * @return meetsVotingThreshold Can vote
     * @return votingPower Current voting power
     */
    function getComprehensiveGovernanceInfo(address account) external view returns (
        bool hasActiveStake,
        uint256 stakeAmount,
        uint256 earnedTokens,
        bool meetsProposalThreshold,
        bool meetsVotingThreshold,
        uint256 votingPower
    ) {
        Stake memory userStake = stakes[account];
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

    /**
     * @notice Check current thresholds
     * @return proposalThreshold_ Current proposal threshold
     * @return votingThreshold_ Current voting threshold
     */
    function getGovernanceThresholds() external view returns (uint256 proposalThreshold_, uint256 votingThreshold_) {
        return (proposalStakeThreshold, votingStakeThreshold);
    }
}