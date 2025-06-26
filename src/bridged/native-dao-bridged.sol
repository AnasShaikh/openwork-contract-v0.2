// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

// Interface to call back to main DAO
interface IMainDAO {
    function incrementEarnerGovernanceActions(address account) external;
}

contract nativeDAO is Governor, GovernorSettings, GovernorCountingSimple, OApp {
    // Cross-chain sender contract address (authorized to send stake data) - for backward compatibility
    address public authorizedSender;
    
    // Main DAO contract for cross-contract calls
    IMainDAO public mainDAO;
    
    // Governance parameters (same as main contract)
    uint256 public proposalStakeThreshold = 100 * 10**18;
    uint256 public votingStakeThreshold = 50 * 10**18;
    
    // LayerZero configuration
    bool public useLayerZero = true;
    
    // Cross-chain execution tracking
    mapping(bytes32 => bool) public executedMessages;
    
    // Access control for multiple local contracts (LayerZero)
    mapping(uint32 => mapping(bytes32 => bool)) public authorizedLocalContracts;
    
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
    event CrossChainMessageReceived(bytes32 indexed messageId, string indexed messageType, address indexed executor);
    event LocalContractAuthorized(uint32 indexed eid, bytes32 indexed localContract);
    event LocalContractDeauthorized(uint32 indexed eid, bytes32 indexed localContract);
    
    modifier onlyAuthorizedSender() {
        require(msg.sender == authorizedSender, "Not authorized sender");
        _;
    }
    
    constructor(
        address initialOwner,
        address _endpoint
    ) 
        Governor("nativedao")
        GovernorSettings(
            1 minutes,
            5 minutes,
            100 * 10**18
        )
        OApp(_endpoint, initialOwner)
        Ownable(initialOwner)
    {}
    
    // LayerZero configuration
    function setUseLayerZero(bool _useLayerZero) external onlyOwner {
        useLayerZero = _useLayerZero;
    }
    
    // Access control functions for multiple local contracts
    function addAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
        authorizedLocalContracts[_eid][_localContract] = true;
        emit LocalContractAuthorized(_eid, _localContract);
    }
    
    function removeAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
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
        
        if (keccak256(bytes(messageType)) == keccak256(bytes("UPDATE_STAKE_DATA"))) {
            (, address staker, uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) = 
                abi.decode(payload, (string, address, uint256, uint256, uint256, bool));
            updateStakeData(staker, amount, unlockTime, durationMinutes, isActive);
        }
    }
    
    // Set authorized sender (main staking contract) - for backward compatibility
    function setAuthorizedSender(address _sender) external onlyOwner {
        address oldSender = authorizedSender;
        authorizedSender = _sender;
        emit AuthorizedSenderUpdated(oldSender, _sender);
    }
    
    // Set main DAO contract address
    function setMainDAO(address _mainDAO) external onlyOwner {
        mainDAO = IMainDAO(_mainDAO);
    }
    
    // Helper function to call main DAO
    function _callMainDAOIncrement(address account) private {
        if (address(mainDAO) == address(0)) return;
        
        try mainDAO.incrementEarnerGovernanceActions(account) {
            emit CrossContractCallSuccess(account);
        } catch Error(string memory reason) {
            emit CrossContractCallFailed(account, reason);
        } catch {
            emit CrossContractCallFailed(account, "Unknown error");
        }
    }
    
    // Receive stake data from main contract - now supports both LayerZero and direct calls
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) public {
        // Check authorization based on call type
        if (useLayerZero) {
            // LayerZero calls are authorized in _lzReceive
            require(msg.sender == address(this), "LayerZero calls only");
        } else {
            // Direct calls require authorized sender
            require(msg.sender == authorizedSender, "Not authorized sender");
        }
        
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
    
    // Public function for direct calls (backward compatibility)
    function updateStakeDataDirect(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external onlyAuthorizedSender {
        updateStakeData(staker, amount, unlockTime, durationMinutes, isActive);
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
        require(stakes[account].isActive && stakes[account].amount >= votingStakeThreshold, "Insufficient active stake to vote");
        
        // Call main DAO to increment governance actions if account is an earner
        _callMainDAOIncrement(account);
        
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public override returns (uint256) {
        require(stakes[msg.sender].isActive && stakes[msg.sender].amount >= proposalStakeThreshold, "Insufficient active stake to propose");
        
        // Call main DAO to increment governance actions if caller is an earner
        _callMainDAOIncrement(msg.sender);
        
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
}