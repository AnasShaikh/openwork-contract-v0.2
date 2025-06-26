// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import "../rewards-calc-maindao.sol";

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

contract maindao is Governor, GovernorSettings, GovernorCountingSimple, OApp {
    IERC20 public openworkToken;
    RewardsCalculator public rewardsCalculator;
    uint256 public constant MIN_STAKE = 100 * 10**18;
    
    // Cross-chain receiver contract address
    InativeDAO public nativeDAO;
    
    // Simplified authorization system
    mapping(address => bool) public authorizedContracts;
    
    // Governance parameters (updatable)
    uint256 public proposalStakeThreshold = 100 * 10**18;
    uint256 public votingStakeThreshold = 50 * 10**18;
    uint256 public unstakeDelay = 24 hours;
    
    // Platform total tracking
    uint256 public totalPlatformPayments;
    
    // Rewards tracking
    mapping(address => uint256) public claimedRewards;
    
    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 durationMinutes;
    }

    struct Earner {
        address earnerAddress;
        uint256 balance;
        uint256 total_governance_actions;
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
    
    // Cross-chain execution tracking
    mapping(bytes32 => bool) public executedMessages;
    
    // Access control for multiple local contracts (LayerZero)
    mapping(uint32 => mapping(bytes32 => bool)) public authorizedLocalContracts;
    
    // Cross-chain events
    event CrossChainSendFailed(address indexed staker, string reason);
    event CrossChainSendSuccess(address indexed staker);
    event CrossChainMessageReceived(bytes32 indexed messageId, string indexed messageType, address indexed executor);
    event LocalContractAuthorized(uint32 indexed eid, bytes32 indexed localContract);
    event LocalContractDeauthorized(uint32 indexed eid, bytes32 indexed localContract);
    
    // Events
    event StakeRemoved(address indexed staker, uint256 amount);
    event UnstakeRequested(address indexed staker, uint256 requestTime, uint256 availableTime);
    event EarnerUpdated(address indexed earner, uint256 newBalance, uint256 totalGovernanceActions, uint256 cumulativeEarnings);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event AuthorizedContractUpdated(address indexed contractAddr, bool authorized);
    event PlatformTotalUpdated(uint256 newTotal);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsCalculatorUpdated(address indexed newCalculator);
    
    constructor(
        address _openworkToken, 
        address _rewardsCalculator,
        address _endpoint,
        address _owner
    ) 
        Governor("OpenWorkDAO")
        GovernorSettings(
            1 minutes,
            5 minutes,
            100 * 10**18
        )
        OApp(_endpoint, _owner)
        Ownable(_owner)
    {
        openworkToken = IERC20(_openworkToken);
        rewardsCalculator = RewardsCalculator(_rewardsCalculator);
    }
    
    // Access control functions for multiple local contracts
    function addAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyGovernance {
        authorizedLocalContracts[_eid][_localContract] = true;
        emit LocalContractAuthorized(_eid, _localContract);
    }
    
    function removeAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyGovernance {
        authorizedLocalContracts[_eid][_localContract] = false;
        emit LocalContractDeauthorized(_eid, _localContract);
    }
    
    function isAuthorizedLocal(uint32 _eid, bytes32 _localContract) external view returns (bool) {
        return authorizedLocalContracts[_eid][_localContract];
    }
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        // Prevent replay attacks
        require(!executedMessages[_guid], "Message already executed");
        executedMessages[_guid] = true;
        
        // Verify sender is authorized
        require(authorizedLocalContracts[_origin.srcEid][_origin.sender], "Unauthorized local contract");
        
        string memory messageType = abi.decode(payload, (string));
        
        emit CrossChainMessageReceived(_guid, messageType, msg.sender);
        
        if (keccak256(bytes(messageType)) == keccak256(bytes("UPDATE_EARNER"))) {
            (, address earnerAddress, uint256 balance, uint256 governanceActions, uint256 cumulativeEarnings, uint256 platformTotal) = 
                abi.decode(payload, (string, address, uint256, uint256, uint256, uint256));
            addOrUpdateEarner(earnerAddress, balance, governanceActions, cumulativeEarnings, platformTotal);
        }
    }
    
    // Set rewards calculator contract
    function setRewardsCalculator(address _rewardsCalculator) external onlyGovernance {
        require(_rewardsCalculator != address(0), "Invalid rewards calculator address");
        rewardsCalculator = RewardsCalculator(_rewardsCalculator);
        emit RewardsCalculatorUpdated(_rewardsCalculator);
    }
    
    // Set cross-chain receiver contract
    function setnativeDAO(address _receiver) external onlyGovernance {
        nativeDAO = InativeDAO(_receiver);
    }
    
    // Simplified authorization function
    function setAuthorizedContract(address _contract, bool _authorized) external onlyGovernance {
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
    
    // Helper function to increment governance actions for earners
    function _incrementEarnerGovernanceActions(address account) private {
        // Check if the account is an earner (has a non-zero balance or exists in mapping)
        if (earners[account].earnerAddress != address(0)) {
            earners[account].total_governance_actions += 1;
            emit EarnerUpdated(
                account, 
                earners[account].balance, 
                earners[account].total_governance_actions,
                earners[account].cumulativeEarnings
            );
        }
    }
    
    // Simplified public function for authorized contracts
    function incrementEarnerGovernanceActions(address account) external {
        require(authorizedContracts[msg.sender], "Not authorized");
        _incrementEarnerGovernanceActions(account);
    }
    
    // REWARDS CLAIMING FUNCTIONS
    
    function calculateTotalRewards(address user) public view returns (uint256) {
        uint256 governanceActions = earners[user].total_governance_actions;
        if (governanceActions == 0) return 0;
        
        return rewardsCalculator.calculateTotalRewards(governanceActions, totalPlatformPayments);
    }
    
    function getClaimableRewards(address user) public view returns (uint256) {
        uint256 totalRewards = calculateTotalRewards(user);
        uint256 alreadyClaimed = claimedRewards[user];
        
        if (totalRewards <= alreadyClaimed) return 0;
        return totalRewards - alreadyClaimed;
    }
    
    function getCurrentRewardPerAction() public view returns (uint256) {
        return rewardsCalculator.getCurrentRewardPerAction(totalPlatformPayments);
    }
    
    function getCurrentRewardBand() public view returns (uint256 minValue, uint256 maxValue, uint256 rewardPerAction) {
        uint256 bandIndex = rewardsCalculator.getCurrentBandIndex(totalPlatformPayments);
        return rewardsCalculator.getRewardBand(bandIndex);
    }
    
    function claimRewards() external {
        require(earners[msg.sender].earnerAddress != address(0), "User is not an earner");
        require(earners[msg.sender].total_governance_actions > 0, "No governance actions performed");
        
        uint256 claimableAmount = getClaimableRewards(msg.sender);
        require(claimableAmount > 0, "No rewards to claim");
        
        // Check contract has enough tokens
        require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");
        
        // Update claimed amount
        claimedRewards[msg.sender] += claimableAmount;
        
        // Transfer tokens to user
        require(openworkToken.transfer(msg.sender, claimableAmount), "Token transfer failed");
        
        emit RewardsClaimed(msg.sender, claimableAmount);
    }
    
    // View function to get user's reward info
    function getUserRewardInfo(address user) external view returns (
        uint256 totalGovernanceActions,
        uint256 totalRewardsEarned,
        uint256 claimedAmount,
        uint256 claimableAmount,
        uint256 currentRewardPerAction
    ) {
        totalGovernanceActions = earners[user].total_governance_actions;
        totalRewardsEarned = calculateTotalRewards(user);
        claimedAmount = claimedRewards[user];
        claimableAmount = getClaimableRewards(user);
        currentRewardPerAction = getCurrentRewardPerAction();
    }
    
    // EXISTING FUNCTIONS (unchanged)
    
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

    // Updated function with platform total parameter
    function addOrUpdateEarner(address earnerAddress, uint256 balance, uint256 governanceActions, uint256 cumulativeEarnings, uint256 platformTotal) public {
        require(earnerAddress != address(0), "Invalid earner address");
        require(authorizedContracts[msg.sender] || address(this) == address(this), "Not authorized");
        
        // Update platform total if it's greater than current
        if (platformTotal > totalPlatformPayments) {
            totalPlatformPayments = platformTotal;
            emit PlatformTotalUpdated(platformTotal);
        }
        
        // If earner exists, preserve governance actions unless explicitly updating
        uint256 finalGovernanceActions = governanceActions;
        if (earners[earnerAddress].earnerAddress != address(0) && governanceActions == 0) {
            finalGovernanceActions = earners[earnerAddress].total_governance_actions;
        }
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            total_governance_actions: finalGovernanceActions,
            cumulativeEarnings: cumulativeEarnings
        });
        
        emit EarnerUpdated(earnerAddress, balance, finalGovernanceActions, cumulativeEarnings);
    }

    // Backward compatibility function without platform total
    function addOrUpdateEarnerWithoutPlatformTotal(address earnerAddress, uint256 balance, uint256 governanceActions, uint256 cumulativeEarnings) external {
        require(earnerAddress != address(0), "Invalid earner address");
        require(authorizedContracts[msg.sender] || address(this) == address(this), "Not authorized");
        
        // If earner exists, preserve governance actions unless explicitly updating
        uint256 finalGovernanceActions = governanceActions;
        if (earners[earnerAddress].earnerAddress != address(0) && governanceActions == 0) {
            finalGovernanceActions = earners[earnerAddress].total_governance_actions;
        }
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            total_governance_actions: finalGovernanceActions,
            cumulativeEarnings: cumulativeEarnings
        });
        
        emit EarnerUpdated(earnerAddress, balance, finalGovernanceActions, cumulativeEarnings);
    }
    
    // Legacy function for backward compatibility (without cumulativeEarnings)
    function addOrUpdateEarnerLegacy(address earnerAddress, uint256 balance, uint256 governanceActions) external onlyGovernance {
        require(earnerAddress != address(0), "Invalid earner address");
        
        uint256 existingCumulativeEarnings = 0;
        if (earners[earnerAddress].earnerAddress != address(0)) {
            existingCumulativeEarnings = earners[earnerAddress].cumulativeEarnings;
        }
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            total_governance_actions: governanceActions,
            cumulativeEarnings: existingCumulativeEarnings
        });
        
        emit EarnerUpdated(earnerAddress, balance, governanceActions, existingCumulativeEarnings);
    }
    
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

    function getAllStakers() external view returns (address[] memory) {
        return allStakers;
    }

    function getStakerInfo(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool hasStake) {
        Stake memory userStake = stakes[staker];
        return (userStake.amount, userStake.unlockTime, userStake.durationMinutes, userStake.amount > 0);
    }
    
    function getEarner(address earnerAddress) external view returns (address, uint256, uint256, uint256) {
        Earner memory earner = earners[earnerAddress];
        return (earner.earnerAddress, earner.balance, earner.total_governance_actions, earner.cumulativeEarnings);
    }
    
    // Legacy function for backward compatibility
    function getEarnerLegacy(address earnerAddress) external view returns (address, uint256, uint256) {
        Earner memory earner = earners[earnerAddress];
        return (earner.earnerAddress, earner.balance, earner.total_governance_actions);
    }
    
    // Getter function for platform total
    function getTotalPlatformPayments() external view returns (uint256) {
        return totalPlatformPayments;
    }

    // Admin function to manually update platform total if needed
    function updatePlatformTotal(uint256 newTotal) external onlyGovernance {
        require(newTotal >= totalPlatformPayments, "Cannot decrease platform total");
        totalPlatformPayments = newTotal;
        emit PlatformTotalUpdated(newTotal);
    }
    
    function _getVotes(address account, uint256, bytes memory) internal view override returns (uint256) {
        Stake memory userStake = stakes[account];
        uint256 ownPower = 0;
        if (userStake.amount > 0) {
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
        require(stakes[account].amount >= votingStakeThreshold, "Insufficient stake to vote");
        
        // Increment governance actions if account is an earner
        _incrementEarnerGovernanceActions(account);
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override returns (uint256) {
        require(stakes[msg.sender].amount >= proposalStakeThreshold, "Insufficient stake to propose");
        
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
    
    function updateProposalStakeThreshold(uint256 newThreshold) external onlyGovernance {
        proposalStakeThreshold = newThreshold;
    }
    
    function updateVotingStakeThreshold(uint256 newThreshold) external onlyGovernance {
        votingStakeThreshold = newThreshold;
    }
    
    function updateUnstakeDelay(uint256 newDelay) external onlyGovernance {
        unstakeDelay = newDelay;
    }
    
    function getUnstakeAvailableTime(address staker) external view returns (uint256) {
        if (unstakeRequestTime[staker] == 0) return 0;
        return unstakeRequestTime[staker] + unstakeDelay;
    }
    
    function getVotingPower(address account) external view returns (uint256 own, uint256 delegated, uint256 total) {
        Stake memory userStake = stakes[account];
        own = userStake.amount > 0 ? userStake.amount * userStake.durationMinutes : 0;
        delegated = delegatedVotingPower[account];
        total = own + delegated;
    }
    
    function updateQuorum(uint256 newQuorum) external onlyGovernance {
        // Implementation needed with state variable
    }
}