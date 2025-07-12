// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Interface to get earned tokens from Native OpenWork Job Contract
interface INativeOpenWorkJobContract {
    function getUserEarnedTokens(address user) external view returns (uint256);
    function getUserRewardInfo(address user) external view returns (uint256 cumulativeEarnings, uint256 totalTokens);
}

// Interface to notify governance actions in Rewards Contract
interface IRewardsContract {
    function notifyGovernanceAction(address account) external;
}

contract CrossChainNativeDAO is Governor, GovernorSettings, GovernorCountingSimple, OAppReceiver, OAppSender {
    // Native OpenWork Job Contract for earned tokens check
    INativeOpenWorkJobContract public nowjContract;
    
    // Rewards Contract for governance action tracking (local reference for fallback)
    IRewardsContract public rewardsContract;
    
    // Cross-chain settings
    uint32 public rewardsChainEid = 40161; // ETH Sepolia by default
    
    // Governance parameters (same as main contract)
    uint256 public proposalStakeThreshold = 100 * 10**18;
    uint256 public votingStakeThreshold = 50 * 10**18;
    
    // Reward-based governance thresholds
    uint256 public proposalRewardThreshold = 100 * 10**18;
    uint256 public votingRewardThreshold = 100 * 10**18;
    
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
    event EarnerUpdated(address indexed earner, uint256 newBalance, uint256 totalGovernanceActions);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event CrossContractCallFailed(address indexed account, string reason);
    event CrossContractCallSuccess(address indexed account);
    event NOWJContractUpdated(address indexed oldContract, address indexed newContract);
    event RewardsContractUpdated(address indexed oldContract, address indexed newContract);
    event EarnedTokensUsedForGovernance(address indexed user, uint256 earnedTokens, string action);
    event GovernanceActionNotified(address indexed user, string action);
    event GovernanceActionIncremented(address indexed user, string action);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event CrossChainGovernanceNotificationSent(address indexed user, string action, uint32 targetChain, uint256 fee);
    event RewardThresholdUpdated(string thresholdType, uint256 newThreshold);
    event RewardsChainEidUpdated(uint32 oldEid, uint32 newEid);
    
    constructor(address _endpoint, address _owner) 
        Governor("CrossChainNativeDAO")
        GovernorSettings(
            1 minutes,
            5 minutes,
            100 * 10**18
        )
        OAppCore(_endpoint, _owner)
        Ownable(_owner)
    {}

    // Override the conflicting oAppVersion function
    function oAppVersion() public pure override(OAppReceiver, OAppSender) returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }

    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }

    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid (not used)
        bytes calldata _message,
        address, // _executor (not used)
        bytes calldata // _extraData (not used)
    ) internal override {
        (string memory functionName) = abi.decode(_message, (string));
        
        if (keccak256(bytes(functionName)) == keccak256(bytes("updateStakeData"))) {
            (, address staker, uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) = abi.decode(_message, (string, address, uint256, uint256, uint256, bool));
            _handleUpdateStakeData(staker, amount, unlockTime, durationMinutes, isActive);
        }
        
        emit CrossChainMessageReceived(functionName, _origin.srcEid, _message);
    }

    // ==================== MESSAGE HANDLERS ====================
    
    function _handleUpdateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) internal {
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
    
    // ==================== CONTRACT SETUP FUNCTIONS ====================
    
    function setNOWJContract(address _nowjContract) external onlyOwner {
        address oldContract = address(nowjContract);
        nowjContract = INativeOpenWorkJobContract(_nowjContract);
        emit NOWJContractUpdated(oldContract, _nowjContract);
    }
    
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        address oldContract = address(rewardsContract);
        rewardsContract = IRewardsContract(_rewardsContract);
        emit RewardsContractUpdated(oldContract, _rewardsContract);
    }
    
    function updateRewardsChainEid(uint32 _rewardsChainEid) external onlyOwner {
        uint32 oldEid = rewardsChainEid;
        rewardsChainEid = _rewardsChainEid;
        emit RewardsChainEidUpdated(oldEid, _rewardsChainEid);
    }
    
    // ==================== CROSS-CHAIN MESSAGING ====================
    
    function _sendGovernanceNotificationCrossChain(
        address account, 
        string memory actionType,
        bytes memory _rewardsOptions
    ) internal {
        if (rewardsChainEid == 0) {
            // Fallback to local rewards contract if no cross-chain setup
            _notifyRewardsContractLocal(account, actionType);
            return;
        }
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        
        MessagingFee memory fee = _quote(rewardsChainEid, payload, _rewardsOptions, false);
        
        _lzSend(
            rewardsChainEid,
            payload,
            _rewardsOptions,
            fee,
            payable(msg.sender)
        );
        
        emit CrossChainGovernanceNotificationSent(account, actionType, rewardsChainEid, fee.nativeFee);
    }
    
    // ==================== HELPER FUNCTIONS ====================
    
    function _notifyRewardsContractLocal(address account, string memory actionType) private {
        if (address(rewardsContract) != address(0)) {
            try rewardsContract.notifyGovernanceAction(account) {
                emit GovernanceActionNotified(account, actionType);
            } catch Error(string memory reason) {
                emit CrossContractCallFailed(account, string(abi.encodePacked("Local rewards notification failed: ", reason)));
            } catch {
                emit CrossContractCallFailed(account, "Local rewards notification failed: Unknown error");
            }
        }
    }
    
    // Modified to accept user-provided options
    function _incrementGovernanceActions(address account, string memory actionType, bytes memory _options) private {
        // Send cross-chain notification to rewards contract with user-provided options
        _sendGovernanceNotificationCrossChain(account, actionType, _options);
        
        // Emit local event
        emit GovernanceActionIncremented(account, actionType);
    }

    // ==================== GOVERNANCE ELIGIBILITY CHECK FUNCTIONS ====================
    
    function _hasGovernanceEligibility(address account, uint256 stakeThreshold, uint256 rewardThreshold) internal view returns (bool) {
        // Check stake eligibility
        if (stakes[account].isActive && stakes[account].amount >= stakeThreshold) {
            return true;
        }
        
        // Check earned tokens eligibility
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            if (earnedTokens >= rewardThreshold) {
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
        Stake memory userStake = stakes[account];
        stakeAmount = (userStake.isActive) ? userStake.amount : 0;
        
        earnedTokens = 0;
        if (address(nowjContract) != address(0)) {
            earnedTokens = nowjContract.getUserEarnedTokens(account);
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
    ) external onlyOwner {
        _handleUpdateStakeData(staker, amount, unlockTime, durationMinutes, isActive);
    }
    
    // ==================== EARNER MANAGEMENT ====================
    
    function addOrUpdateEarner(address earnerAddress, uint256 balance, uint256 governanceActions) external onlyGovernance {
        require(earnerAddress != address(0), "Invalid earner address");
        
        earners[earnerAddress] = Earner({
            earnerAddress: earnerAddress,
            balance: balance,
            total_governance_actions: governanceActions
        });
        
        emit EarnerUpdated(earnerAddress, balance, governanceActions);
    }
    
    // ==================== DELEGATION FUNCTIONS ====================
    
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
    
    // ==================== IERC6372 IMPLEMENTATIONS ====================
    
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }
    
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // ==================== VIEW FUNCTIONS ====================
    
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
    
    function getVotingPower(address account) external view returns (uint256 own, uint256 delegated, uint256 reward, uint256 total) {
        Stake memory userStake = stakes[account];
        own = (userStake.isActive && userStake.amount > 0) ? userStake.amount * userStake.durationMinutes : 0;
        delegated = delegatedVotingPower[account];
        
        // Add reward-based voting power
        reward = 0;
        if (address(nowjContract) != address(0)) {
            uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
            reward = earnedTokens;
        }
        
        total = own + delegated + reward;
    }
    
    function getGovernanceEligibility(address account) external view returns (bool canProposeFlag, bool canVoteFlag, uint256 stakeAmount, uint256 rewardTokens) {
        Stake memory userStake = stakes[account];
        stakeAmount = userStake.isActive ? userStake.amount : 0;
        
        if (address(nowjContract) != address(0)) {
            rewardTokens = nowjContract.getUserEarnedTokens(account);
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

    function getGovernanceThresholds() external view returns (uint256 proposalStakeThreshold_, uint256 votingStakeThreshold_, uint256 proposalRewardThreshold_, uint256 votingRewardThreshold_) {
        return (proposalStakeThreshold, votingStakeThreshold, proposalRewardThreshold, votingRewardThreshold);
    }
    
    function getRewardsChainEid() external view returns (uint32) {
        return rewardsChainEid;
    }
    
    // ==================== GOVERNOR REQUIRED FUNCTIONS ====================
    
    function _getVotes(address account, uint256, bytes memory) internal view override returns (uint256) {
        Stake memory userStake = stakes[account];
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
        
        uint256 totalPower = ownPower + delegatedVotingPower[account] + rewardPower;
        return totalPower;
    }
    
    function hasVoted(uint256 proposalId, address account) public view override(IGovernor, GovernorCountingSimple) returns (bool) {
        return super.hasVoted(proposalId, account);
    }
    
    // ==================== MODIFIED VOTING FUNCTIONS ====================
    
    // New function with user-provided options
    function castVoteWithOptions(
        uint256 proposalId, 
        uint8 support, 
        string calldata reason,
        bytes calldata _options
    ) external payable returns (uint256) {
        require(canVote(msg.sender), "Insufficient stake or earned tokens to vote");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        if (!stakes[msg.sender].isActive || stakes[msg.sender].amount < votingStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(msg.sender);
                if (earnedTokens >= votingRewardThreshold) {
                    emit EarnedTokensUsedForGovernance(msg.sender, earnedTokens, "vote");
                }
            }
        }
        
        // Increment governance actions for voting with user-provided options
        _incrementGovernanceActions(msg.sender, "vote", _options);
        
        return _castVote(proposalId, msg.sender, support, reason, "");
    }
    
    // Modified original _castVote to use default options when called from Governor
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal override returns (uint256) {
        
        require(canVote(account), "Insufficient stake or earned tokens to vote");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        if (!stakes[account].isActive || stakes[account].amount < votingStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(account);
                if (earnedTokens >= votingRewardThreshold) {
                    emit EarnedTokensUsedForGovernance(account, earnedTokens, "vote");
                }
            }
        }
        
        // Use default options when called from Governor base functions
       // bytes memory defaultOptions = "0x0003010011010000000000000000000000000007a120";
        //_incrementGovernanceActions(account, "vote", defaultOptions);
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    // New function with user-provided options
    function proposeWithOptions(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        string memory description,
        bytes calldata _options
    ) external payable returns (uint256) {
        
        require(canPropose(msg.sender), "Insufficient stake or earned tokens to propose");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        if (!stakes[msg.sender].isActive || stakes[msg.sender].amount < proposalStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(msg.sender);
                if (earnedTokens >= proposalRewardThreshold) {
                    emit EarnedTokensUsedForGovernance(msg.sender, earnedTokens, "propose");
                }
            }
        }
        
        // Increment governance actions for proposing with user-provided options
        _incrementGovernanceActions(msg.sender, "propose", _options);
        
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        proposalIds.push(proposalId);
        return proposalId;
    }
    
    // Modified original propose to use default options
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override returns (uint256) {
        
        require(canPropose(msg.sender), "Insufficient stake or earned tokens to propose");
        
        // Emit event if user is using earned tokens (no active stake above threshold)
        if (!stakes[msg.sender].isActive || stakes[msg.sender].amount < proposalStakeThreshold) {
            if (address(nowjContract) != address(0)) {
                uint256 earnedTokens = nowjContract.getUserEarnedTokens(msg.sender);
                if (earnedTokens >= proposalRewardThreshold) {
                    emit EarnedTokensUsedForGovernance(msg.sender, earnedTokens, "propose");
                }
            }
        }
        
        // Use default options when called from Governor base functions
        bytes memory defaultOptions = "0x0003010011010000000000000000000000000007a120";
        _incrementGovernanceActions(msg.sender, "propose", defaultOptions);
        
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
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteGovernanceNotification(
        address account,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        if (rewardsChainEid == 0) return 0;
        
        bytes memory payload = abi.encode("notifyGovernanceAction", account);
        MessagingFee memory msgFee = _quote(rewardsChainEid, payload, _options, false);
        return msgFee.nativeFee;
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
}