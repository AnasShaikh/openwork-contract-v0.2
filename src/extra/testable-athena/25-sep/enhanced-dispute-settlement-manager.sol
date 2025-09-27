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
    // Updated interface for ultra-minimal function
    function releaseDisputedFunds(uint256 _amount, address _winner, uint32 _winnerChainDomain) external;
}

/**
 * @title Enhanced Dispute Settlement Manager
 * @notice Handles complete dispute settlement with maximum logic centralized here
 * @dev Ultra-minimal NOWJC integration - NOWJC only does 3-line CCTP transfer
 */
contract EnhancedDisputeSettlementManager {
    using SafeERC20 for IERC20;

    // ==================== STATE VARIABLES ====================
    
    INativeAthena public nativeAthena;
    INOWJC public nowjcContract;
    IERC20 public usdcToken;
    
    address public owner;
    
    // Chain domain mappings (LayerZero EID → CCTP Domain)
    mapping(uint32 => uint32) public eidToCctpDomain;
    
    // Fixed disputed amount for current test (can be enhanced later)
    uint256 public constant DISPUTED_AMOUNT = 500000; // 0.5 USDC
    
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
    
    event DisputedFundsTransferred(
        string indexed disputeId,
        address indexed winner,
        uint256 amount,
        uint32 targetDomain
    );
    
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
        address _nowjcContract
    ) {
        owner = msg.sender;
        nativeAthena = INativeAthena(_nativeAthena);
        nowjcContract = INOWJC(_nowjcContract);
        usdcToken = nativeAthena.usdcToken();
        
        // Initialize EID to CCTP domain mappings
        _initializeChainMappings();
    }
    
    function _initializeChainMappings() internal {
        // Based on your job ID format:
        eidToCctpDomain[40232] = 2;  // OP Sepolia: EID 40232 → CCTP Domain 2
        eidToCctpDomain[40161] = 3;  // Arbitrum Sepolia: EID 40161 → CCTP Domain 3
        // Add more chains as needed
    }
    
    // ==================== MAIN SETTLEMENT FUNCTION ====================
    
    /**
     * @notice Complete dispute settlement - handles both fees AND disputed funds
     * @param _disputeId Job/Dispute ID (format: "EID-SEQUENCE" e.g. "40232-57")  
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
        
        // Step 1: Distribute fees to winning voters on Arbitrum
        uint256 feesDistributed = _distributeFees(
            _disputeId,
            _voters,
            _claimAddresses,
            _votingPowers,
            _voteDirections,
            _winningSide,
            _totalFees
        );
        
        // Step 2: Handle disputed funds cross-chain settlement
        (address winner, uint32 winnerChainDomain) = _handleDisputedFundsSettlement(_disputeId, _winningSide);
        
        emit DisputeSettled(
            _disputeId,
            _winningSide,
            winner,
            DISPUTED_AMOUNT,
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
                        // Transfer from Native Athena to voter claim address
                        usdcToken.safeTransferFrom(address(nativeAthena), _claimAddresses[i], voterShare);
                        totalDistributed += voterShare;
                        
                        emit FeeDistributed(_disputeId, _voters[i], _claimAddresses[i], voterShare);
                    }
                }
            }
        }
        
        return totalDistributed;
    }
    
    /**
     * @notice Handle disputed funds settlement cross-chain (NEW LOGIC)
     * @dev This does ALL the complex logic - NOWJC just does minimal CCTP transfer
     */
    function _handleDisputedFundsSettlement(
        string memory _disputeId, 
        bool _winningSide
    ) internal returns (address winner, uint32 winnerChainDomain) {
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
            // selectedApplicationId
        ) = nowjcContract.getJob(_disputeId);
        
        // Determine winner based on voting result
        winner = _winningSide ? jobGiver : selectedApplicant;
        
        // Parse job ID to get winner's chain domain
        // Job ID format: "40232-57" → EID 40232 → CCTP domain 2 (OP Sepolia)
        winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        
        // Transfer USDC from Native Athena to NOWJC for disputed amount
        usdcToken.safeTransferFrom(address(nativeAthena), address(nowjcContract), DISPUTED_AMOUNT);
        
        // Call ultra-minimal NOWJC function - it only does CCTP sendFast()
        nowjcContract.releaseDisputedFunds(DISPUTED_AMOUNT, winner, winnerChainDomain);
        
        emit DisputedFundsTransferred(_disputeId, winner, DISPUTED_AMOUNT, winnerChainDomain);
        
        return (winner, winnerChainDomain);
    }
    
    /**
     * @notice Parse job ID to extract LayerZero EID and convert to CCTP domain
     * @dev Job ID format: "EID-SEQUENCE" (e.g., "40232-57")
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
        address _nowjc
    ) external onlyOwner {
        nativeAthena = INativeAthena(_nativeAthena);
        nowjcContract = INOWJC(_nowjc);
        usdcToken = nativeAthena.usdcToken();
    }
    
    function addChainMapping(uint32 _eid, uint32 _cctpDomain) external onlyOwner {
        eidToCctpDomain[_eid] = _cctpDomain;
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
        
        winner = _winningSide ? jobGiver : selectedApplicant;
        winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        disputedAmount = DISPUTED_AMOUNT;
        
        return (winner, winnerChainDomain, disputedAmount);
    }
}