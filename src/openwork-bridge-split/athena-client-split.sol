// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
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

contract AthenaClientContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable usdtToken;
    ILocalOpenWorkJobContract public jobContract;
    ILayerZeroBridge public bridge;
    uint32 public immutable chainId;
    
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
    uint256 public minDisputeFee = 50 * 10**6; // 50 USDT (6 decimals)
    
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
    
    constructor(
        address _owner,
        address _usdtToken,
        uint32 _chainId,
        address _bridge
    ) Ownable(_owner) {
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;
        bridge = ILayerZeroBridge(_bridge);
    }
    
    // ==================== MESSAGE HANDLERS ====================
    
    function handleFinalizeDispute(string memory disputeId, bool winningSide) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        require(disputeFees[disputeId].totalFees > 0, "Dispute does not exist");
        require(!disputeFees[disputeId].isFinalized, "Dispute already finalized");
        
        DisputeFees storage dispute = disputeFees[disputeId];
        dispute.winningSide = winningSide;
        dispute.isFinalized = true;
        
        // Distribute fees automatically using locally stored vote data
        if (dispute.votes.length > 0) {
            uint256 totalWinningVotingPower = winningSide ? dispute.totalVotingPowerFor : dispute.totalVotingPowerAgainst;
            
            if (totalWinningVotingPower > 0) {
                for (uint256 i = 0; i < dispute.votes.length; i++) {
                    VoteRecord memory vote = dispute.votes[i];
                    
                    if (vote.voteFor == winningSide) {
                        uint256 voterShare = (vote.votingPower * dispute.totalFees) / totalWinningVotingPower;
                        
                        // Store for reference
                        claimableAmount[disputeId][vote.claimAddress] = voterShare;
                        // Mark as automatically claimed
                        hasClaimed[disputeId][vote.claimAddress] = true;
                        
                        // Automatically transfer
                        require(usdtToken.transfer(vote.claimAddress, voterShare), "Fee transfer failed");
                        emit FeesClaimed(disputeId, vote.claimAddress, voterShare);
                    }
                }
            }
        }
        
        // AUTO-RESOLVE THE DISPUTE IN LOWJC
        if (address(jobContract) != address(0)) {
            jobContract.resolveDispute(disputeId, winningSide);
        }
        
        emit DisputeFeesFinalized(disputeId, winningSide, dispute.totalFees);
    }
    
    function handleRecordVote(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) external {
        require(msg.sender == address(bridge), "Only bridge can call this function");
        require(disputeFees[disputeId].totalFees > 0, "Dispute does not exist");
        require(!disputeFees[disputeId].isFinalized, "Dispute already finalized");
        
        // Record the vote
        disputeFees[disputeId].votes.push(VoteRecord({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));
        
        // Update totals
        if (voteFor) {
            disputeFees[disputeId].totalVotingPowerFor += votingPower;
        } else {
            disputeFees[disputeId].totalVotingPowerAgainst += votingPower;
        }
        
        emit VoteRecorded(disputeId, voter, claimAddress, votingPower, voteFor);
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
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        require(address(jobContract) != address(0), "Job contract not set");
        require(!jobDisputeExists[_jobId], "Dispute already exists for this job");
        require(_feeAmount >= minDisputeFee, "Fee below minimum required");
        
        // Get job details and validate caller involvement
        ILocalOpenWorkJobContract.Job memory job = jobContract.getJob(_jobId);
        require(bytes(job.id).length > 0, "Job does not exist");
        
        // Check if job is in progress (status 1 = InProgress)
        require(job.status == ILocalOpenWorkJobContract.JobStatus.InProgress, "Job must be in progress to raise dispute");
        
        // Check if caller is involved in the job (either job giver or selected applicant)
        require(
            msg.sender == job.jobGiver || msg.sender == job.selectedApplicant,
            "Only job participants can raise disputes"
        );
        
        // Transfer USDT from caller to this contract only after validation
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
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
        
        // Send cross-chain message to Native Athena
        bytes memory payload = abi.encode("raiseDispute", _jobId, _disputeHash, _oracleName, _feeAmount, msg.sender);
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
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Send cross-chain message to Native Athena
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
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Send cross-chain message to Native Athena
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
        return usdtToken.balanceOf(address(this));
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
    
    // Owner function to withdraw collected fees
    function withdrawFees(uint256 _amount) external onlyOwner {
        require(_amount <= usdtToken.balanceOf(address(this)), "Insufficient contract balance");
        require(usdtToken.transfer(owner(), _amount), "Transfer failed");
        
        emit FeesWithdrawn(owner(), _amount);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    function emergencyWithdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT balance to withdraw");
        usdtToken.safeTransfer(owner(), balance);
    }
}