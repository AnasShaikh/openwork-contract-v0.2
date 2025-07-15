// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ILayerZeroEndpointV2, MessagingParams, MessagingFee } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

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
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // LAYERZERO ENDPOINT
    ILayerZeroEndpointV2 public endpoint;
    mapping(uint32 => bytes32) public peers;

    // APP LOGIC
    IERC20 public usdtToken;
    ILocalOpenWorkJobContract public jobContract;
    uint32 public chainId;
    uint32 public nativeChainEid;

    mapping(string => bool) public jobDisputeExists;
    mapping(string => DisputeFees) public disputeFees;
    mapping(string => mapping(address => uint256)) public claimableAmount;
    mapping(string => mapping(address => bool)) public hasClaimed;
    uint256 public minDisputeFee;

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

    // EVENTS
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
    constructor() initializer {}

    function initialize(
        address _endpoint,
        address _owner,
        address _usdtToken,
        uint32 _chainId,
        uint32 _nativeChainEid
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        endpoint = ILayerZeroEndpointV2(_endpoint);
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;
        nativeChainEid = _nativeChainEid;
        minDisputeFee = 50 * 10**6;
    }

    // UUPS authorize
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ----------------------
    // LAYERZERO SEND / QUOTE
    // ----------------------

    function _lzSend(
        uint32 _dstEid,
        bytes memory _payload,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal {
        require(peers[_dstEid] != bytes32(0), "Peer not set");

        MessagingParams memory params = MessagingParams({
            dstEid: _dstEid,
            receiver: peers[_dstEid],
            message: _payload,
            options: _options,
            payInLzToken: false
        });

        endpoint.send{value: _fee.nativeFee}(params, _refundAddress);
        emit CrossChainMessageSent("custom", _dstEid, _payload);
    }

    function quoteMessage(
        uint32 _dstEid,
        bytes memory _payload,
        bytes memory _options,
        address _payer
    ) external view returns (MessagingFee memory) {
        require(peers[_dstEid] != bytes32(0), "Peer not set");

        MessagingParams memory params = MessagingParams({
            dstEid: _dstEid,
            receiver: peers[_dstEid],
            message: _payload,
            options: _options,
            payInLzToken: false
        });

        return endpoint.quote(params, _payer);
    }

    function setPeer(uint32 _eid, bytes32 _peer) external onlyOwner {
        peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }

    // ----------------------
    // DISPUTE AND FEES LOGIC
    // ----------------------

    function _handleFinalizeDispute(string memory disputeId, bool winningSide) internal {
        require(disputeFees[disputeId].totalFees > 0, "Dispute does not exist");
        require(!disputeFees[disputeId].isFinalized, "Dispute already finalized");

        DisputeFees storage dispute = disputeFees[disputeId];
        dispute.winningSide = winningSide;
        dispute.isFinalized = true;

        if (dispute.votes.length > 0) {
            uint256 totalWinningVotingPower = winningSide ? dispute.totalVotingPowerFor : dispute.totalVotingPowerAgainst;
            if (totalWinningVotingPower > 0) {
                for (uint256 i = 0; i < dispute.votes.length; i++) {
                    VoteRecord memory vote = dispute.votes[i];
                    if (vote.voteFor == winningSide) {
                        uint256 voterShare = (vote.votingPower * dispute.totalFees) / totalWinningVotingPower;
                        claimableAmount[disputeId][vote.claimAddress] = voterShare;
                        hasClaimed[disputeId][vote.claimAddress] = true;
                        require(usdtToken.transfer(vote.claimAddress, voterShare), "Fee transfer failed");
                        emit FeesClaimed(disputeId, vote.claimAddress, voterShare);
                    }
                }
            }
        }

        if (address(jobContract) != address(0)) {
            jobContract.resolveDispute(disputeId, winningSide);
        }

        emit DisputeFeesFinalized(disputeId, winningSide, dispute.totalFees);
    }

    function _handleRecordVote(string memory disputeId, address voter, address claimAddress, uint256 votingPower, bool voteFor) internal {
        require(disputeFees[disputeId].totalFees > 0, "Dispute does not exist");
        require(!disputeFees[disputeId].isFinalized, "Dispute already finalized");

        disputeFees[disputeId].votes.push(VoteRecord({
            voter: voter,
            claimAddress: claimAddress,
            votingPower: votingPower,
            voteFor: voteFor
        }));

        if (voteFor) {
            disputeFees[disputeId].totalVotingPowerFor += votingPower;
        } else {
            disputeFees[disputeId].totalVotingPowerAgainst += votingPower;
        }

        emit VoteRecorded(disputeId, voter, claimAddress, votingPower, voteFor);
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

    // ----------------------
    // OWNER WITHDRAW
    // ----------------------

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

    uint256[50] private __gap;
}
