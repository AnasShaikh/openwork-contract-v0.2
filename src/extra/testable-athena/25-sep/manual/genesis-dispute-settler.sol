// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Interface for Genesis contract
interface IOpenworkGenesis {
    struct Dispute {
        string jobId;
        uint256 disputedAmount;
        string hash;
        address disputeRaiserAddress;
        uint256 votesFor;
        uint256 votesAgainst;
        bool result;
        bool isVotingActive;
        bool isFinalized;
        uint256 timeStamp;
        uint256 fees;
    }
    
    function getDispute(string memory disputeId) external view returns (Dispute memory);
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
    function finalizeDispute(string memory disputeId, bool result) external;
}

// Interface for NOWJC contract
interface INativeOpenWorkJobContract {
    function releaseDisputedFunds(address _recipient, uint256 _amount, uint32 _targetChainDomain) external;
}

contract GenesisDisputeSettler {
    
    // Contract dependencies
    IOpenworkGenesis public genesis;
    INativeOpenWorkJobContract public nowjc;
    
    // Events
    event DisputeSettled(string indexed disputeId, bool winningSide, address winner, uint256 amount);
    
    constructor(address _genesis, address _nowjc) {
        require(_genesis != address(0), "Genesis address cannot be zero");
        require(_nowjc != address(0), "NOWJC address cannot be zero");
        
        genesis = IOpenworkGenesis(_genesis);
        nowjc = INativeOpenWorkJobContract(_nowjc);
    }
    
    function settleDispute(string memory _disputeId) external {
        // Get dispute data from Genesis
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        require(dispute.timeStamp > 0, "Dispute does not exist");
        require(dispute.isFinalized, "Dispute not finalized");
        
        // Calculate winning side
        bool winningSide = dispute.votesFor > dispute.votesAgainst;
        
        // Get job details from Genesis (NOT NOWJC!)
        (, address jobGiver, ,,,,,, address selectedApplicant, ) = genesis.getJob(_disputeId);
        
        // Determine winner based on voting result
        address winner = winningSide ? jobGiver : selectedApplicant;
        
        // Parse target chain domain from job ID
        uint32 winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        
        // Release disputed funds to winner
        nowjc.releaseDisputedFunds(winner, dispute.disputedAmount, winnerChainDomain);
        
        emit DisputeSettled(_disputeId, winningSide, winner, dispute.disputedAmount);
    }
    
    // Complete automated dispute resolution
    function completeDisputeResolution(string memory _disputeId) external {
        // Step 1: Get dispute data and calculate winner
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        require(dispute.timeStamp > 0, "Dispute does not exist");
        
        bool winningSide = dispute.votesFor > dispute.votesAgainst;
        
        // Step 2: Finalize dispute in Genesis if not already done
        if (!dispute.isFinalized) {
            genesis.finalizeDispute(_disputeId, winningSide);
        }
        
        // Step 3: Get job details from Genesis
        (, address jobGiver, ,,,,,, address selectedApplicant, ) = genesis.getJob(_disputeId);
        
        // Step 4: Release funds
        address winner = winningSide ? jobGiver : selectedApplicant;
        uint32 winnerChainDomain = _parseJobIdForChainDomain(_disputeId);
        
        nowjc.releaseDisputedFunds(winner, dispute.disputedAmount, winnerChainDomain);
        
        emit DisputeSettled(_disputeId, winningSide, winner, dispute.disputedAmount);
    }
    
    // Utility function to parse chain domain from job ID
    function _parseJobIdForChainDomain(string memory _jobId) internal pure returns (uint32) {
        bytes memory jobIdBytes = bytes(_jobId);
        uint256 dashIndex = 0;
        
        // Find the dash position in job ID like "40232-65"
        for (uint256 i = 0; i < jobIdBytes.length; i++) {
            if (jobIdBytes[i] == '-') {
                dashIndex = i;
                break;
            }
        }
        
        if (dashIndex == 0) return 0; // No dash found
        
        // Extract the EID part before the dash
        bytes memory eidBytes = new bytes(dashIndex);
        for (uint256 i = 0; i < dashIndex; i++) {
            eidBytes[i] = jobIdBytes[i];
        }
        
        uint32 eid = uint32(_stringToUint(string(eidBytes)));
        
        // Convert EID to CCTP domain
        if (eid == 40232) return 2; // OP Sepolia
        if (eid == 40161) return 0; // Ethereum Sepolia  
        if (eid == 40231) return 3; // Arbitrum Sepolia
        
        return 0; // Default fallback
    }
    
    // Utility function to convert string to uint
    function _stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                result = result * 10 + (uint256(uint8(b[i])) - 48);
            }
        }
        return result;
    }
    
    // View functions for debugging
    function getDisputeDetails(string memory _disputeId) external view returns (
        bool exists,
        uint256 votesFor,
        uint256 votesAgainst,
        bool winningSide,
        uint256 disputedAmount,
        bool isFinalized
    ) {
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        exists = dispute.timeStamp > 0;
        votesFor = dispute.votesFor;
        votesAgainst = dispute.votesAgainst;
        winningSide = dispute.votesFor > dispute.votesAgainst;
        disputedAmount = dispute.disputedAmount;
        isFinalized = dispute.isFinalized;
    }
    
    function getJobDetails(string memory _jobId) external view returns (
        address jobGiver,
        address selectedApplicant
    ) {
        (, address _jobGiver, ,,,,,, address _selectedApplicant, ) = genesis.getJob(_jobId);
        jobGiver = _jobGiver;
        selectedApplicant = _selectedApplicant;
    }
}