// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface InativeDAO {
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external;
}

interface IRewardsContract {
    function notifyGovernanceAction(address account) external;
    function getUserJobRewardInfo(address user) external view returns (
        uint256 cumulativeEarnings,
        uint256 totalJobTokens
    );
}

contract MainDAO is Governor, GovernorSettings, GovernorCountingSimple {
    IERC20 public openworkToken;
    IRewardsContract public rewardsContract;
    uint256 public constant MIN_STAKE = 100 * 10**18;
    
    // Cross-chain receiver contract address
    InativeDAO public nativeDAO;
    
    // Simplified authorization system
    mapping(address => bool) public authorizedContracts;
    
    // Governance parameters (updatable)
    uint256 public proposalStakeThreshold = 100 * 10**18;
    uint256 public votingStakeThreshold = 50 * 10**18;
    uint256 public unstakeDelay = 24 hours;
    
    // Reward-based governance thresholds
    uint256 public proposalRewardThreshold = 100 * 10**18;
    uint256 public votingRewardThreshold = 100 * 10**18;
    
    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 durationMinutes;
    }

    struct Earner {
        address earnerAddress;
        uint256 balance;
        uint256 cumulativeEarnings;
    }

    mapping(address => Earner) public earners;
    mapping(address => Stake) public stakes;
    mapping(address => uint256) public unstakeRequestTime;
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotingPower;
    mapping(address => bool) public isStaker;
    
    // Helper functions for easier testing
    uint256[] public proposalIds;
    address[] public allStakers;
    
    // Cross-chain events
    event CrossChainSendFailed(address indexed staker, string reason);
    event CrossChainSendSuccess(address indexed staker);
    
    // Events
    event StakeRemoved(address indexed staker, uint256 amount);
    event UnstakeRequested(address indexed staker, uint256 requestTime, uint256 availableTime);
    event EarnerUpdated(address indexed earner, uint256 newBalance, uint256 governanceActionsDeprecated, uint256 cumulativeEarnings);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event AuthorizedContractUpdated(address indexed contractAddr, bool authorized);
    event RewardsContractUpdated(address indexed newRewardsContract);
    event RewardThresholdUpdated(string thresholdType, uint256 newThreshold);
    
    constructor(address _openworkToken) 
        Governor("OpenWorkDAO")
        GovernorSettings(
            1 minutes,
            5 minutes,
            100 * 10**18
        )
    {
        openworkToken = IERC20(_openworkToken);
    }
    
    // Set rewards contract
    function setRewardsContract(address _rewardsContract) external  {
        require(_rewardsContract != address(0), "Invalid rewards contract address");
        rewardsContract = IRewardsContract(_rewardsContract);
        emit RewardsContractUpdated(_rewardsContract);
    }
    
    // Set cross-chain receiver contract
    function setnativeDAO(address _receiver) external onlyGovernance {
        nativeDAO = InativeDAO(_receiver);
    }
    
    // Simplified authorization function
    function setAuthorizedContract(address _contract, bool _authorized) external  {
        authorizedContracts[_contract] = _authorized;
        emit AuthorizedContractUpdated(_contract, _authorized);
    }
    
    // Internal function to send stake data cross-chain
    function _sendStakeDataCrossChain(address staker, bool isActive) internal {
        if (address(nativeDAO) == address(0)) return;
        
        Stake memory userStake = stakes[staker];
        
        try nativeDAO.updateStakeData(
            staker,
            userStake.amount,
            userStake.unlockTime,
            userStake.durationMinutes,
            isActive
        ) {
            emit CrossChainSendSuccess(staker);
        } catch Error(string memory reason) {
            emit CrossChainSendFailed(staker, reason);
        } catch {
            emit CrossChainSendFailed(staker, "Unknown error");
        }
    }
    
    // Check if user has sufficient stake or reward tokens for governance actions
    function _hasGovernanceEligibility(address account, uint256 stakeThreshold, uint256 rewardThreshold) internal view returns (bool) {
        // Check stake eligibility
        if (stakes[account].amount >= stakeThreshold) {
            return true;
        }
        
        // Check reward eligibility
        if (address(rewardsContract) != address(0)) {
            (, uint256 totalJobTokens) = rewardsContract.getUserJobRewardInfo(account);
            if (totalJobTokens >= rewardThreshold) {
                return true;
            }
        }
        
        return false;
    }
    
    // Helper function to increment governance actions for earners
    function _incrementEarnerGovernanceActions(address account) private {
        // Notify rewards contract of governance action
        if (address(rewardsContract) != address(0)) {
            rewardsContract.notifyGovernanceAction(account);
        }
    }
    
    // Simplified public function for authorized contracts
    function incrementEarnerGovernanceActions(address account) external {
        require(authorizedContracts[msg.sender], "Not authorized");
        _incrementEarnerGovernanceActions(account);
    }
    
    // STAKING FUNCTIONS
    
    function stake(uint256 amount, uint256 durationMinutes) external {
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
        
        // Send stake data cross-chain
        _sendStakeDataCrossChain(msg.sender, true);
    }
    
    function unstake() external {
        Stake memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");
        require(block.timestamp >= userStake.unlockTime, "Stake still locked");
        
        if (unstakeRequestTime[msg.sender] == 0) {
            unstakeRequestTime[msg.sender] = block.timestamp;
            emit UnstakeRequested(msg.sender, block.timestamp, block.timestamp + unstakeDelay);
        } else {
            require(block.timestamp >= unstakeRequestTime[msg.sender] + unstakeDelay, "Unstake delay not met");

            if (stakes[msg.sender].amount == 0) {
                isStaker[msg.sender] = false;
            }
            
            delete stakes[msg.sender];
            delete unstakeRequestTime[msg.sender];
            openworkToken.transfer(msg.sender, userStake.amount);
            
            // Send updated stake data (inactive) cross-chain
            _sendStakeDataCrossChain(msg.sender, false);
        }
    }
    
    function removeStake(address staker, uint256 removeAmount) external onlyGovernance {
        require(stakes[staker].amount > 0, "No stake found");
        require(removeAmount <= stakes[staker].amount, "Remove amount exceeds stake");
        
        stakes[staker].amount -= removeAmount;
        
        bool isActive = true;
        if (stakes[staker].amount < MIN_STAKE) {
            delete stakes[staker];
            isActive = false;
        }
        
        emit StakeRemoved(staker, removeAmount);
        
        // Send updated stake data cross-chain
        _sendStakeDataCrossChain(staker, isActive);
    }

    // EARNER MANAGEMENT FUNCTIONS

    function addOrUpdateEarner(address earnerAddress, uint256 balance, uint256 cumulativeEarnings) external {
        require(earnerAddress != address(0), "Invalid earner address");
        require(authorizedContracts[msg.sender] || address(this) == address(this), "Not authorized");
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            cumulativeEarnings: cumulativeEarnings
        });
        
        emit EarnerUpdated(earnerAddress, balance, 0, cumulativeEarnings);
    }

    // Legacy function for backward compatibility
    function addOrUpdateEarnerLegacy(address earnerAddress, uint256 balance) external onlyGovernance {
        require(earnerAddress != address(0), "Invalid earner address");
        
        uint256 existingCumulativeEarnings = 0;
        if (earners[earnerAddress].earnerAddress != address(0)) {
            existingCumulativeEarnings = earners[earnerAddress].cumulativeEarnings;
        }
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            cumulativeEarnings: existingCumulativeEarnings
        });
        
        emit EarnerUpdated(earnerAddress, balance, 0, existingCumulativeEarnings);
    }
    
    // DELEGATION FUNCTIONS
    
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
    
    // Required IERC6372 implementations
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }
    
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // VIEW FUNCTIONS
    
    function getAllStakers() external view returns (address[] memory) {
        return allStakers;
    }

    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool hasStake) {
        Stake memory userStake = stakes[staker];
        return (userStake.amount, userStake.unlockTime, userStake.durationMinutes, userStake.amount > 0);
    }
    
    function getEarner(address earnerAddress) external view returns (address, uint256, uint256) {
        Earner memory earner = earners[earnerAddress];
        return (earner.earnerAddress, earner.balance, earner.cumulativeEarnings);
    }
    
    // Legacy function for backward compatibility
    function getEarnerLegacy(address earnerAddress) external view returns (address, uint256, uint256) {
        Earner memory earner = earners[earnerAddress];
        return (earner.earnerAddress, earner.balance, 0); // governance actions now tracked in rewards contract
    }
    
    function getUnstakeAvailableTime(address staker) external view returns (uint256) {
        if (unstakeRequestTime[staker] == 0) return 0;
        return unstakeRequestTime[staker] + unstakeDelay;
    }
    
    function getVotingPower(address account) external view returns (uint256 own, uint256 delegated, uint256 reward, uint256 total) {
        Stake memory userStake = stakes[account];
        own = userStake.amount > 0 ? userStake.amount * userStake.durationMinutes : 0;
        delegated = delegatedVotingPower[account];
        
        // Add reward-based voting power
        reward = 0;
        if (address(rewardsContract) != address(0)) {
            (, uint256 totalJobTokens) = rewardsContract.getUserJobRewardInfo(account);
            reward = totalJobTokens;
        }
        
        total = own + delegated + reward;
    }
    
    function getGovernanceEligibility(address account) external view returns (bool canPropose, bool canVote, uint256 stakeAmount, uint256 rewardTokens) {
        stakeAmount = stakes[account].amount;
        
        if (address(rewardsContract) != address(0)) {
            (, rewardTokens) = rewardsContract.getUserJobRewardInfo(account);
        }
        
        canPropose = _hasGovernanceEligibility(account, proposalStakeThreshold, proposalRewardThreshold);
        canVote = _hasGovernanceEligibility(account, votingStakeThreshold, votingRewardThreshold);
    }
    
    // GOVERNANCE FUNCTIONS
    
    function _getVotes(address account, uint256, bytes memory) internal view override returns (uint256) {
        Stake memory userStake = stakes[account];
        uint256 ownPower = 0;
        if (userStake.amount > 0) {
            ownPower = userStake.amount * userStake.durationMinutes;
        }
        
        // Add reward-based voting power
        uint256 rewardPower = 0;
        if (address(rewardsContract) != address(0)) {
            (, uint256 totalJobTokens) = rewardsContract.getUserJobRewardInfo(account);
            rewardPower = totalJobTokens; // 1:1 mapping of reward tokens to voting power
        }
        
        uint256 totalPower = ownPower + delegatedVotingPower[account] + rewardPower;
        return totalPower;
    }
    
    function hasVoted(uint256 proposalId, address account) public view override(IGovernor, GovernorCountingSimple) returns (bool) {
        return super.hasVoted(proposalId, account);
    }
    
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal override returns (uint256) {
        require(
            _hasGovernanceEligibility(account, votingStakeThreshold, votingRewardThreshold),
            "Insufficient stake or reward tokens to vote"
        );
        
        // Increment governance actions if account is an earner
        _incrementEarnerGovernanceActions(account);
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override returns (uint256) {
        require(
            _hasGovernanceEligibility(msg.sender, proposalStakeThreshold, proposalRewardThreshold),
            "Insufficient stake or reward tokens to propose"
        );
        
        // Increment governance actions if caller is an earner
        _incrementEarnerGovernanceActions(msg.sender);
        
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        proposalIds.push(proposalId);
        return proposalId;
    }
    
    function quorum(uint256) public pure override returns (uint256) {
        return 50 * 10**18;
    }
    
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
    
    // ADMIN FUNCTIONS
    
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
    
    function updateUnstakeDelay(uint256 newDelay) external onlyGovernance {
        unstakeDelay = newDelay;
    }
    
    function updateQuorum(uint256 newQuorum) external onlyGovernance {
        // Implementation needed with state variable
    }
}