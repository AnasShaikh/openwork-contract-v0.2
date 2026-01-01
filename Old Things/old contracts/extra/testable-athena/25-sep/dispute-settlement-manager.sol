// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interfaces for integration
interface INativeAthena {
    function usdcToken() external view returns (IERC20);
    function accumulatedFees() external view returns (uint256);
}

interface INOWJC {
    function getJob(string memory _jobId) external view returns (
        string memory id,
        address jobGiver,
        address[] memory applicants,
        string memory jobDetailHash,
        uint8 status,
        string[] memory workSubmissions,
        uint256 totalPaid,
        uint256 currentMilestone,
        address selectedApplicant,
        uint256 selectedApplicationId
    );
    function releasePaymentCrossChain(
        string memory _jobId,
        address _recipient,
        uint256 _amount,
        uint32 _targetChainDomain
    ) external;
}

interface IOpenworkGenesis {
    struct Application {
        uint256 id;
        string jobId;
        address applicant;
        string applicationHash;
    }
    
    function getJobApplication(string memory jobId, uint256 applicationId) external view returns (Application memory);
}

interface ICCTPTransceiver {
    function sendFast(
        address recipient,
        uint256 amount,
        uint32 targetDomain,
        bytes calldata data
    ) external;
}

/**
 * @title DisputeSettlementManager
 * @notice Handles complete dispute settlement with fee distribution and cross-chain winner payments
 * @dev Called by Native Athena to settle disputes in a single transaction
 */
contract DisputeSettlementManager {
    using SafeERC20 for IERC20;

    // ==================== STATE VARIABLES ====================
    
    INativeAthena public nativeAthena;
    INOWJC public nowjcContract;
    IOpenworkGenesis public genesis;
    ICCTPTransceiver public cctpTransceiver;
    IERC20 public usdcToken;
    
    address public owner;
    
    // Chain domain mappings (LayerZero EID → CCTP Domain)
    mapping(uint32 => uint32) public eidToCctpDomain;
    
    // Fee tracking
    uint256 public accumulatedFees;
    
    // ==================== EVENTS ====================
    
    event DisputeSettled(
        string indexed disputeId,
        bool winningSide,
        address winner,
        uint256 disputedAmount,
        uint32 winnerChainDomain,
        uint256 feesDistributed
    );
    
    event FeeDistributed(
        string indexed disputeId,
        address indexed voter,
        address indexed claimAddress,
        uint256 amount
    );
    
    event CrossChainPaymentSent(
        string indexed disputeId,
        address indexed winner,
        uint256 amount,
        uint32 targetDomain
    );
    
    event ContractsUpdated(address nativeAthena, address nowjc, address genesis, address cctp);
    
    // ==================== MODIFIERS ====================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyNativeAthena() {
        require(msg.sender == address(nativeAthena), "Only Native Athena can call");
        _;
    }
    
    // ==================== CONSTRUCTOR ====================
    
    constructor(
        address _nativeAthena,
        address _nowjcContract,
        address _genesis,
        address _cctpTransceiver
    ) {
        owner = msg.sender;
        nativeAthena = INativeAthena(_nativeAthena);
        nowjcContract = INOWJC(_nowjcContract);
        genesis = IOpenworkGenesis(_genesis);
        cctpTransceiver = ICCTPTransceiver(_cctpTransceiver);
        
        usdcToken = nativeAthena.usdcToken();
        
        // Initialize EID to CCTP domain mappings
        _initializeChainMappings();
    }
    
    function _initializeChainMappings() internal {
        // Based on your documentation:
        eidToCctpDomain[40232] = 2;  // OP Sepolia: EID 40232 → CCTP Domain 2
        eidToCctpDomain[40161] = 3;  // Arbitrum Sepolia: EID 40161 → CCTP Domain 3
        // Add more chains as needed
    }
    
    // ==================== MAIN SETTLEMENT FUNCTION ====================
    
    /**
     * @notice Complete dispute settlement with fee distribution and cross-chain winner payment
     * @param _disputeId Job/Dispute ID
     * @param _voters Array of voter addresses
     * @param _claimAddresses Array of fee claim addresses (corresponding to voters)
     * @param _votingPowers Array of voting powers (corresponding to voters)
     * @param _voteDirections Array of vote directions (corresponding to voters)
     * @param _winningSide True if job giver wins, false if applicant wins
     * @param _totalFees Total fees to distribute to winning voters
     */
    function settleDispute(
        string memory _disputeId,
        address[] memory _voters,
        address[] memory _claimAddresses,
        uint256[] memory _votingPowers,
        bool[] memory _voteDirections,
        bool _winningSide,
        uint256 _totalFees
    ) external onlyNativeAthena {
        require(_voters.length == _claimAddresses.length, "Array length mismatch");
        require(_voters.length == _votingPowers.length, "Array length mismatch");
        require(_voters.length == _voteDirections.length, "Array length mismatch");
        
        // Step 1: Distribute fees to winning voters
        uint256 feesDistributed = _distributeFees(
            _disputeId,
            _voters,
            _claimAddresses,
            _votingPowers,
            _voteDirections,
            _winningSide,
            _totalFees
        );
        
        // Step 2: Pay dispute winner cross-chain
        (address winner, uint256 disputedAmount, uint32 winnerChainDomain) = _payDisputeWinner(
            _disputeId,
            _winningSide
        );
        
        emit DisputeSettled(
            _disputeId,
            _winningSide,
            winner,
            disputedAmount,
            winnerChainDomain,
            feesDistributed
        );
    }
    
    // ==================== INTERNAL FUNCTIONS ====================
    
    /**
     * @notice Distribute fees to winning voters (existing working logic)
     */
    function _distributeFees(
        string memory _disputeId,
        address[] memory _voters,
        address[] memory _claimAddresses,
        uint256[] memory _votingPowers,
        bool[] memory _voteDirections,
        bool _winningSide,
        uint256 _totalFees
    ) internal returns (uint256 totalDistributed) {
        // Calculate total winning voting power
        uint256 totalWinningVotingPower = 0;
        for (uint256 i = 0; i < _voters.length; i++) {
            if (_voteDirections[i] == _winningSide) {
                totalWinningVotingPower += _votingPowers[i];
            }
        }
        
        // Distribute fees to winning voters
        if (totalWinningVotingPower > 0) {
            for (uint256 i = 0; i < _voters.length; i++) {
                if (_voteDirections[i] == _winningSide) {
                    uint256 voterShare = (_votingPowers[i] * _totalFees) / totalWinningVotingPower;
                    
                    if (voterShare > 0) {
                        usdcToken.safeTransfer(_claimAddresses[i], voterShare);
                        accumulatedFees -= voterShare;
                        totalDistributed += voterShare;
                        
                        emit FeeDistributed(_disputeId, _voters[i], _claimAddresses[i], voterShare);
                    }
                }
            }
        }
        
        return totalDistributed;
    }
    
    /**
     * @notice Pay dispute winner cross-chain (new logic)
     */
    function _payDisputeWinner(
        string memory _disputeId,
        bool _winningSide
    ) internal returns (address winner, uint256 disputedAmount, uint32 winnerChainDomain) {
        // Get job details from NOWJC
        (
            ,  // jobId
            address jobGiver,
            ,  // applicants
            ,  // jobDetailHash
            ,  // status
            ,  // workSubmissions
            ,  // totalPaid
            ,  // currentMilestone
            address selectedApplicant,
            uint256 selectedApplicationId
        ) = nowjcContract.getJob(_disputeId);
        
        // Determine winner and their preferred chain
        if (_winningSide) {
            // Job giver wins
            winner = jobGiver;
            winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        } else {
            // Selected applicant wins
            winner = selectedApplicant;
            // For now, assume same chain as job (we could enhance this later)
            winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        }
        
        // For this implementation, assume disputed amount is a fixed amount
        // In production, this should come from job milestone data
        disputedAmount = 500000; // 0.5 USDC (500,000 wei)
        
        // Send payment cross-chain via NOWJC
        if (winner != address(0) && disputedAmount > 0) {
            nowjcContract.releasePaymentCrossChain(
                _disputeId,
                winner,
                disputedAmount,
                winnerChainDomain
            );
            
            emit CrossChainPaymentSent(_disputeId, winner, disputedAmount, winnerChainDomain);
        }
        
        return (winner, disputedAmount, winnerChainDomain);
    }
    
    /**
     * @notice Parse job ID to extract LayerZero EID and convert to CCTP domain
     * @dev Job ID format: "EID-SEQUENCE" (e.g., "40232-55")
     */
    function _parseJobIdForChainDomain(string memory _jobId) internal view returns (uint32) {
        bytes memory jobIdBytes = bytes(_jobId);
        uint256 dashPosition = 0;
        
        // Find the dash position
        for (uint256 i = 0; i < jobIdBytes.length; i++) {
            if (jobIdBytes[i] == "-") {
                dashPosition = i;
                break;
            }
        }
        
        if (dashPosition == 0) {
            // No dash found, return default domain (Arbitrum = 3)
            return 3;
        }
        
        // Extract EID part (before dash)
        bytes memory eidBytes = new bytes(dashPosition);
        for (uint256 i = 0; i < dashPosition; i++) {
            eidBytes[i] = jobIdBytes[i];
        }
        
        // Convert bytes to uint32 EID
        uint32 eid = _bytesToUint32(eidBytes);
        
        // Map EID to CCTP domain
        uint32 cctpDomain = eidToCctpDomain[eid];
        if (cctpDomain == 0) {
            // Unknown EID, default to native chain (Arbitrum = 3)
            return 3;
        }
        
        return cctpDomain;
    }
    
    /**
     * @notice Convert bytes to uint32
     */
    function _bytesToUint32(bytes memory _bytes) internal pure returns (uint32) {
        uint32 result = 0;
        for (uint256 i = 0; i < _bytes.length; i++) {
            if (_bytes[i] >= "0" && _bytes[i] <= "9") {
                result = result * 10 + uint32(uint8(_bytes[i]) - 48);
            }
        }
        return result;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function updateContracts(
        address _nativeAthena,
        address _nowjc,
        address _genesis,
        address _cctp
    ) external onlyOwner {
        nativeAthena = INativeAthena(_nativeAthena);
        nowjcContract = INOWJC(_nowjc);
        genesis = IOpenworkGenesis(_genesis);
        cctpTransceiver = ICCTPTransceiver(_cctp);
        
        usdcToken = nativeAthena.usdcToken();
        
        emit ContractsUpdated(_nativeAthena, _nowjc, _genesis, _cctp);
    }
    
    function addChainMapping(uint32 _eid, uint32 _cctpDomain) external onlyOwner {
        eidToCctpDomain[_eid] = _cctpDomain;
    }
    
    function updateAccumulatedFees() external onlyOwner {
        accumulatedFees = nativeAthena.accumulatedFees();
    }
    
    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner, _amount);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getChainDomainMapping(uint32 _eid) external view returns (uint32) {
        return eidToCctpDomain[_eid];
    }
    
    function parseJobIdForChainDomain(string memory _jobId) external view returns (uint32) {
        return _parseJobIdForChainDomain(_jobId);
    }
    
    function getDisputeWinnerInfo(string memory _disputeId, bool _winningSide) external view returns (
        address winner,
        uint32 winnerChainDomain,
        uint256 disputedAmount
    ) {
        (
            ,  // jobId
            address jobGiver,
            ,  // applicants
            ,  // jobDetailHash
            ,  // status
            ,  // workSubmissions
            ,  // totalPaid
            ,  // currentMilestone
            address selectedApplicant,
            // selectedApplicationId
        ) = nowjcContract.getJob(_disputeId);
        
        if (_winningSide) {
            winner = jobGiver;
        } else {
            winner = selectedApplicant;
        }
        
        winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        disputedAmount = 500000; // Fixed for now
        
        return (winner, winnerChainDomain, disputedAmount);
    }
}