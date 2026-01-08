// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILocalOpenWorkJobContract {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
    struct MilestonePayment {
    string descriptionHash;
    uint256 amount;
}

struct Job {
    string id;
    address jobGiver;
    address[] applicants;
    string jobDetailHash;
    JobStatus status;
    string[] workSubmissions;
    MilestonePayment[] milestonePayments;
    MilestonePayment[] finalMilestones;
    uint256 totalPaid;
    uint256 currentLockedAmount;
    uint256 currentMilestone;
    address selectedApplicant;
    uint256 selectedApplicationId;
    uint256 totalEscrowed;
    uint256 totalReleased;
}
    
    function getJob(string memory _jobId) external view returns (Job memory);
    function resolveDispute(string memory jobId, bool jobGiverWins) external;
}

interface ILayerZeroBridge {
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

interface ICCTPSender {
    function sendFast(uint256 amount, uint32 domain, bytes32 mintRecipient, uint256 nonce) external;
}

contract LocalAthena is 
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    
    IERC20 public usdcToken;
    ILocalOpenWorkJobContract public jobContract;
    ILayerZeroBridge public bridge;
    uint32 public chainId;
    
    // CCTP Integration (similar to LOWJC)
    address public cctpSender;
    address public nativeAthenaRecipient;
    uint32 public nativeChainDomain; // 3 for Arbitrum Sepolia
    
    struct VoteRecord {
        address voter;
        address claimAddress;
        uint256 votingPower;
        bool voteFor;
    }
    
    struct DisputeFees {
        uint256 totalFees;
        uint256 totalVotingPowerFor;
        uint256 totalVotingPowerAgainst;
        bool winningSide;
        bool isFinalized;
        address disputeRaiser;
        VoteRecord[] votes;
    }
    
    mapping(string => bool) public jobDisputeExists;
    mapping(string => DisputeFees) public disputeFees;
    mapping(string => mapping(address => uint256)) public claimableAmount;
    mapping(string => mapping(address => bool)) public hasClaimed;
    uint256 public minDisputeFee;

    // Admin pattern
    mapping(address => bool) public admins;

    // Storage gap for upgrade safety
    uint256[50] private __gap;

    // Events
    event DisputeRaised(address indexed caller, string jobId, uint256 feeAmount);
    event SkillVerificationSubmitted(address indexed caller, string targetOracleName, uint256 feeAmount);
    event AthenaAsked(address indexed caller, string targetOracle, uint256 feeAmount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event JobContractSet(address indexed jobContract);
    event BridgeSet(address indexed bridge);
    event MinDisputeFeeSet(uint256 newMinFee);
    event VoteRecorded(string indexed disputeId, address indexed voter, address indexed claimAddress, uint256 votingPower, bool voteFor);
    event DisputeFeesFinalized(string indexed disputeId, bool winningSide, uint256 totalFees);
    event FeesClaimed(string indexed disputeId, address indexed claimAddress, uint256 amount);
    event CCTPSenderSet(address indexed cctpSender);
    event NativeAthenaRecipientSet(address indexed recipient);
    event NativeChainDomainSet(uint32 domain);
    event FeeRoutedToNative(uint256 feeAmount, address indexed nativeRecipient);
    event AdminUpdated(address indexed admin, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner,
        address _usdcToken,
        uint32 _chainId,
        address _bridge,
        address _cctpSender,
        address _nativeAthenaRecipient
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        admins[_owner] = true;
        usdcToken = IERC20(_usdcToken);
        chainId = _chainId;
        bridge = ILayerZeroBridge(_bridge);
        cctpSender = _cctpSender;
        nativeAthenaRecipient = _nativeAthenaRecipient;
        nativeChainDomain = 3; // Arbitrum Sepolia
        minDisputeFee = 50 * 10**6; // 50 USDC (6 decimals)
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == address(bridge), "Only bridge can upgrade");
        upgradeToAndCall(newImplementation, "");
    }

    function setAdmin(address _admin, bool _status) external onlyOwner {
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    // ==================== CCTP CONFIGURATION ====================
    
    function setCCTPSender(address _cctpSender) external onlyOwner {
        require(_cctpSender != address(0), "CCTP sender cannot be zero address");
        cctpSender = _cctpSender;
        emit CCTPSenderSet(_cctpSender);
    }
    
    function setNativeAthenaRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Recipient cannot be zero address");
        nativeAthenaRecipient = _recipient;
        emit NativeAthenaRecipientSet(_recipient);
    }
    
    function setNativeChainDomain(uint32 _domain) external onlyOwner {
        nativeChainDomain = _domain;
        emit NativeChainDomainSet(_domain);
    }
    
    // ==================== FEE ROUTING FUNCTION ====================
    
    function routeFeeToNative(uint256 _feeAmount) internal {
        require(cctpSender != address(0), "CCTP sender not set");
        require(nativeAthenaRecipient != address(0), "Native recipient not set");
        
        // Approve CCTP sender to transfer USDC
        usdcToken.approve(cctpSender, _feeAmount);
        
        // Create mint recipient bytes32
        bytes32 mintRecipient = bytes32(uint256(uint160(nativeAthenaRecipient)));
        
        // Send via CCTP to native chain
        ICCTPSender(cctpSender).sendFast(_feeAmount, nativeChainDomain, mintRecipient, 1000);
        
        emit FeeRoutedToNative(_feeAmount, nativeAthenaRecipient);
    }
    
    // ==================== MESSAGE HANDLERS ====================
    
    function handleFinalizeDisputeWithVotes(
        string memory disputeId, 
        bool winningSide, 
        uint256 votesFor, 
        uint256 votesAgainst,
        address[] memory voters,
        address[] memory claimAddresses,
        uint256[] memory votingPowers,
        bool[] memory voteDirections
    ) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        require(disputeFees[disputeId].totalFees > 0, "Dispute does not exist");
        require(!disputeFees[disputeId].isFinalized, "Dispute already finalized");
        require(voters.length == claimAddresses.length && voters.length == votingPowers.length && voters.length == voteDirections.length, "Array length mismatch");
        
        DisputeFees storage dispute = disputeFees[disputeId];
        dispute.winningSide = winningSide;
        dispute.isFinalized = true;
        dispute.totalVotingPowerFor = votesFor;
        dispute.totalVotingPowerAgainst = votesAgainst;
        
        // Add all voter records at once
        for (uint256 i = 0; i < voters.length; i++) {
            dispute.votes.push(VoteRecord({
                voter: voters[i],
                claimAddress: claimAddresses[i],
                votingPower: votingPowers[i],
                voteFor: voteDirections[i]
            }));
            
            emit VoteRecorded(disputeId, voters[i], claimAddresses[i], votingPowers[i], voteDirections[i]);
        }
        
        // CHANGED: Route fees to native chain instead of paying locally
        if (dispute.votes.length > 0) {
            // Route collected fees to Native Athena via CCTP
            routeFeeToNative(dispute.totalFees);
            
            // Send payment instruction via LayerZero
            bytes memory feePayload = abi.encode(
                "processFeePayment",
                disputeId,
                voters,
                claimAddresses,
                votingPowers,
                voteDirections,
                winningSide,
                dispute.totalFees
            );
            
            // Send LayerZero message with fee payment data
            bytes memory bridgeOptions = abi.encodePacked(uint16(1), uint256(200000)); // Basic options
            bridge.sendToNativeChain("processFeePayment", feePayload, bridgeOptions);
        }
        
        // AUTO-RESOLVE THE DISPUTE IN LOWJC
        if (address(jobContract) != address(0)) {
            jobContract.resolveDispute(disputeId, winningSide);
        }
        
        emit DisputeFeesFinalized(disputeId, winningSide, dispute.totalFees);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Bridge address cannot be zero");
        bridge = ILayerZeroBridge(_bridge);
        emit BridgeSet(_bridge);
    }
    
    function setJobContract(address _jobContract) external onlyOwner {
        require(_jobContract != address(0), "Job contract address cannot be zero");
        jobContract = ILocalOpenWorkJobContract(_jobContract);
        emit JobContractSet(_jobContract);
    }
    
    function setMinDisputeFee(uint256 _minFee) external onlyOwner {
        minDisputeFee = _minFee;
        emit MinDisputeFeeSet(_minFee);
    }
    
    // ==================== MAIN FUNCTIONS ====================
    
    function raiseDispute(
        string memory _jobId,
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _feeAmount,
        uint256 _disputedAmount,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        require(address(jobContract) != address(0), "Job contract not set");

        // Transfer USDC from caller to this contract
        require(
            usdcToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDC transfer failed"
        );
        
        // Initialize dispute fees tracking
        DisputeFees storage dispute = disputeFees[_jobId];
        dispute.totalFees = _feeAmount;
        dispute.totalVotingPowerFor = 0;
        dispute.totalVotingPowerAgainst = 0;
        dispute.winningSide = false;
        dispute.isFinalized = false;
        dispute.disputeRaiser = msg.sender;
        
        // Mark dispute as existing for this job
        jobDisputeExists[_jobId] = true;
        
        // CHANGED: Route fee to native chain immediately
        routeFeeToNative(_feeAmount);
        
        // Send cross-chain message to Native Athena with fee routing data
        bytes memory payload = abi.encode("raiseDispute", _jobId, _disputeHash, _oracleName, _feeAmount, _disputedAmount, msg.sender);
        bridge.sendToNativeChain{value: msg.value}("raiseDispute", payload, _nativeOptions);
        
        emit DisputeRaised(msg.sender, _jobId, _feeAmount);
    }
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Transfer USDC from caller to this contract
        require(
            usdcToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDC transfer failed"
        );
        
        // CHANGED: Route fee to native chain
        routeFeeToNative(_feeAmount);
        
        // Send cross-chain message to Native Athena with fee routing data
        bytes memory payload = abi.encode("submitSkillVerification", msg.sender, _applicationHash, _feeAmount, _targetOracleName);
        bridge.sendToNativeChain{value: msg.value}("submitSkillVerification", payload, _nativeOptions);
        
        emit SkillVerificationSubmitted(msg.sender, _targetOracleName, _feeAmount);
    }
    
    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        uint256 _feeAmount,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Convert fee amount to string for the cross-chain call
        string memory feeString = uint2str(_feeAmount);
        
        // Transfer USDC from caller to this contract
        require(
            usdcToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDC transfer failed"
        );
        
        // CHANGED: Route fee to native chain
        routeFeeToNative(_feeAmount);
        
        // Send cross-chain message to Native Athena with fee routing data
        bytes memory payload = abi.encode("askAthena", msg.sender, _description, _hash, _targetOracle, feeString);
        bridge.sendToNativeChain{value: msg.value}("askAthena", payload, _nativeOptions);
        
        emit AthenaAsked(msg.sender, _targetOracle, _feeAmount);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    // View function to get claimable amount for an address
    function getClaimableAmount(string memory disputeId, address claimAddress) external view returns (uint256) {
        if (hasClaimed[disputeId][claimAddress]) {
            return 0;
        }
        return claimableAmount[disputeId][claimAddress];
    }
    
    // View function to get dispute info
    function getDisputeInfo(string memory disputeId) external view returns (
        uint256 totalFees,
        uint256 totalVotingPowerFor,
        uint256 totalVotingPowerAgainst,
        bool winningSide,
        bool isFinalized,
        uint256 voteCount
    ) {
        DisputeFees storage dispute = disputeFees[disputeId];
        return (
            dispute.totalFees,
            dispute.totalVotingPowerFor,
            dispute.totalVotingPowerAgainst,
            dispute.winningSide,
            dispute.isFinalized,
            dispute.votes.length
        );
    }
    
    // Function to check if job exists and caller is involved
    function isCallerInvolvedInJob(string memory _jobId, address _caller) external view returns (bool) {
        require(address(jobContract) != address(0), "Job contract not set");
        
        ILocalOpenWorkJobContract.Job memory job = jobContract.getJob(_jobId);
        if (bytes(job.id).length == 0) return false;
        
        // Check if caller is job giver or selected applicant
        if (_caller == job.jobGiver || _caller == job.selectedApplicant) {
            return true;
        }
        
        // If job is still open, check if caller is an applicant
        if (job.status == ILocalOpenWorkJobContract.JobStatus.Open) {
            for (uint i = 0; i < job.applicants.length; i++) {
                if (job.applicants[i] == _caller) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    // Quote function
    function quoteSingleChain(
        string calldata /* _functionName */,
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        return bridge.quoteNativeChain(_payload, _options);
    }
    
    // View functions
    function getContractBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    // Utility function to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    // ==================== ADMIN WITHDRAWAL FUNCTIONS ====================

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
}