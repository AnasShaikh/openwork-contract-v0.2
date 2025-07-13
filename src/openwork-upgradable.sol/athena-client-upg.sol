// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
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



contract AthenaClientContract is 
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    
    ILayerZeroEndpointV2 public endpoint;
    IERC20 public usdtToken;
    ILocalOpenWorkJobContract public jobContract;
    uint32 public chainId;
    
    // Chain endpoints for cross-chain communication
    uint32 public nativeChainEid;     // Chain where NativeAthena is deployed
    mapping(uint32 => bytes32) public peers;
    
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
    
    // Events
    event DisputeRaised(address indexed caller, string jobId, uint256 feeAmount);
    event SkillVerificationSubmitted(address indexed caller, string targetOracleName, uint256 feeAmount);
    event AthenaAsked(address indexed caller, string targetOracle, uint256 feeAmount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event JobContractSet(address indexed jobContract);
    event MinDisputeFeeSet(uint256 newMinFee);
    event VoteRecorded(string indexed disputeId, address indexed voter, address indexed claimAddress, uint256 votingPower, bool voteFor);
    event DisputeFeesFinalized(string indexed disputeId, bool winningSide, uint256 totalFees);
    event FeesClaimed(string indexed disputeId, address indexed claimAddress, uint256 amount);
    event CrossChainMessageSent(string indexed functionName, uint32 dstEid, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceChain, bytes data);
    event NativeChainUpdated(uint32 newChainEid);
    event PeerSet(uint32 eid, bytes32 peer);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _endpoint,
        address _owner,
        address _usdtToken,
        uint32 _chainId,
        uint32 _nativeChainEid
    ) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        endpoint = ILayerZeroEndpointV2(_endpoint);
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;
        nativeChainEid = _nativeChainEid;
        minDisputeFee = 50 * 10**6; // 50 USDT (6 decimals)
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function lzReceive(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 /*_nonce*/,
        bytes calldata _message
    ) external {
        require(msg.sender == address(endpoint), "Only endpoint can call");
        require(peers[_srcEid] == _sender, "Invalid sender");
        
        (string memory functionName) = abi.decode(_message, (string));
        
        if (keccak256(bytes(functionName)) == keccak256(bytes("finalizeDispute"))) {
            (, string memory disputeId, bool winningSide) = abi.decode(_message, (string, string, bool));
            _handleFinalizeDispute(disputeId, winningSide);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("recordVote"))) {
            (, string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) = abi.decode(_message, (string, string, address, address, uint256, bool));
            _handleRecordVote(disputeId, voter, claimAddress, votingPower, voteFor);
        }
        
        emit CrossChainMessageReceived(functionName, _srcEid, _message);
    }
    
    // ==================== MESSAGE HANDLERS ====================
    
    function _handleFinalizeDispute(string memory disputeId, bool winningSide) internal {
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
    
    function _handleRecordVote(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) internal {
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
    
    // ==================== LAYERZERO SEND FUNCTIONS ====================
    
    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes calldata _options
    ) internal {
        require(peers[_dstEid] != bytes32(0), "Peer not set");
        
        MessagingParams memory params = MessagingParams({
            dstEid: _dstEid,
            receiver: peers[_dstEid],
            message: _message,
            options: _options,
            payInLzToken: false
        });
        
        endpoint.send{value: msg.value}(params, msg.sender);
    }
    
    function quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes calldata _options
    ) public view returns (MessagingFee memory fee) {
        require(peers[_dstEid] != bytes32(0), "Peer not set");
        
        MessagingParams memory params = MessagingParams({
            dstEid: _dstEid,
            receiver: peers[_dstEid],
            message: _message,
            options: _options,
            payInLzToken: false
        });
        
        return endpoint.quote(params, msg.sender);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setPeer(uint32 _eid, bytes32 _peer) external onlyOwner {
        peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }
    
    function updateNativeChainEid(uint32 _nativeChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        emit NativeChainUpdated(_nativeChainEid);
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
        bytes calldata _options
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
        _lzSend(nativeChainEid, payload, _options);
        
        emit DisputeRaised(msg.sender, _jobId, _feeAmount);
        emit CrossChainMessageSent("raiseDispute", nativeChainEid, payload);
    }
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName,
        bytes calldata _options
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Send cross-chain message to Native Athena
        bytes memory payload = abi.encode("submitSkillVerification", msg.sender, _applicationHash, _feeAmount, _targetOracleName);
        _lzSend(nativeChainEid, payload, _options);
        
        emit SkillVerificationSubmitted(msg.sender, _targetOracleName, _feeAmount);
        emit CrossChainMessageSent("submitSkillVerification", nativeChainEid, payload);
    }
    
    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        uint256 _feeAmount,
        bytes calldata _options
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
        _lzSend(nativeChainEid, payload, _options);
        
        emit AthenaAsked(msg.sender, _targetOracle, _feeAmount);
        emit CrossChainMessageSent("askAthena", nativeChainEid, payload);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getClaimableAmount(string memory disputeId, address claimAddress) external view returns (uint256) {
        if (hasClaimed[disputeId][claimAddress]) {
            return 0;
        }
        return claimableAmount[disputeId][claimAddress];
    }
    
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
    
    function getContractBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
    
    function getNativeChainEid() external view returns (uint32) {
        return nativeChainEid;
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
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
    
    // ==================== OWNER FUNCTIONS ====================
    
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