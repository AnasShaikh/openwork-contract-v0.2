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
    
    struct Job {
        string id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        uint8 status;
        string[] workSubmissions;
        uint256 totalPaid;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
    }
    
    function getDispute(string memory disputeId) external view returns (Dispute memory);
    function getJob(string memory _jobId) external view returns (Job memory);
}

// Interface for NOWJC contract
interface INativeOpenWorkJobContract {
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
    function releaseDisputedFunds(address _recipient, uint256 _amount, uint32 _targetChainDomain) external;
}

contract MicroDisputeSettler {
    
    // Contract dependencies
    IOpenworkGenesis public genesis;
    INativeOpenWorkJobContract public nowjc;
    
    constructor(address _genesis, address _nowjc) {
        genesis = IOpenworkGenesis(_genesis);
        nowjc = INativeOpenWorkJobContract(_nowjc);
    }
    
    // MICRO FUNCTION 1: Just return true
    function microTest1() external pure returns (bool) {
        return true;
    }
    
    // MICRO FUNCTION 2: Just emit an event
    event MicroTest(string message);
    function microTest2() external {
        emit MicroTest("Function executed successfully");
    }
    
    // MICRO FUNCTION 3: Just accept a string parameter
    function microTest3(string memory _disputeId) external pure returns (string memory) {
        return _disputeId;
    }
    
    // MICRO FUNCTION 4: Just call Genesis getDispute
    function microTest4(string memory _disputeId) external view returns (uint256) {
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        return dispute.votesFor;
    }
    
    // MICRO FUNCTION 5: Just call Genesis getJob (STRUCT FIXED)
    function microTest5(string memory _disputeId) external view returns (address) {
        IOpenworkGenesis.Job memory job = genesis.getJob(_disputeId);
        return job.jobGiver;
    }
    
    // MICRO FUNCTION 6: Just do a calculation
    function microTest6(string memory _disputeId) external view returns (bool) {
        IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(_disputeId);
        return dispute.votesFor > dispute.votesAgainst;
    }
    
    // MICRO FUNCTION 7: Just parse chain domain
    function microTest7(string memory _disputeId) external pure returns (uint32) {
        return _parseJobIdForChainDomain(_disputeId);
    }
    
    // MICRO FUNCTION 8: Call NOWJC with hardcoded values
    function microTest8() external {
        nowjc.releaseDisputedFunds(
            0xfD08836eeE6242092a9c869237a8d122275b024A, 
            100000, 
            3
        );
    }
    
    // MICRO FUNCTION 9: Call NOWJC with parameters
    function microTest9(address recipient, uint256 amount, uint32 domain) external {
        nowjc.releaseDisputedFunds(recipient, amount, domain);
    }
    
    // MICRO FUNCTION 10: The original function but broken into steps
    function microSettleDispute(string memory _disputeId) external {
        require(false, "MICRO: Entry point reached");
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
}