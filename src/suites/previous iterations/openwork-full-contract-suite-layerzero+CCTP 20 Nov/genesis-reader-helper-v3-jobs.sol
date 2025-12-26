// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title GenesisReaderHelper
 * @dev Helper contract to provide batch reading capabilities for OpenworkGenesis
 * @notice This is a stateless reader contract that queries the Genesis proxy for efficient batch operations
 */

interface IOpenworkGenesis {
    enum JobStatus {
        Open,
        InProgress,
        Completed,
        Cancelled
    }
    
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
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
    }
    
    struct SkillVerificationApplication {
        uint256 id;
        address applicant;
        string applicationHash;
        uint256 feeAmount;
        string targetOracleName;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
        bool result;
        bool isFinalized;
    }
    
    struct AskAthenaApplication {
        uint256 id;
        address applicant;
        string description;
        string hash;
        string targetOracle;
        string fees;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isVotingActive;
        uint256 timeStamp;
        bool result;
        bool isFinalized;
    }
    
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
    
    function applicationCounter() external view returns (uint256);
    function askAthenaCounter() external view returns (uint256);
    function getSkillApplication(uint256 applicationId) external view returns (SkillVerificationApplication memory);
    function getAskAthenaApplication(uint256 athenaId) external view returns (AskAthenaApplication memory);
    function getAllJobIds() external view returns (string[] memory);
    function getJob(string memory jobId) external view returns (Job memory);
    function getJobsByPoster(address poster) external view returns (string[] memory);
    function getDispute(string memory jobId) external view returns (Dispute memory);
}

contract GenesisReaderHelper {
    
    IOpenworkGenesis public immutable genesis;
    
    constructor(address _genesis) {
        require(_genesis != address(0), "Invalid genesis address");
        genesis = IOpenworkGenesis(_genesis);
    }
    
    // ==================== SKILL APPLICATION BATCH GETTERS ====================
    
    /**
     * @dev Get all skill application IDs
     * @return Array of all application IDs from 0 to counter-1
     */
    function getAllSkillApplicationIds() external view returns (uint256[] memory) {
        uint256 counter = genesis.applicationCounter();
        uint256[] memory ids = new uint256[](counter);
        
        for (uint256 i = 0; i < counter; i++) {
            ids[i] = i;
        }
        
        return ids;
    }
    
    /**
     * @dev Get skill application IDs in batches
     * @param startIndex Starting index
     * @param count Number of IDs to return
     * @return Array of application IDs for the requested range
     */
    function getSkillApplicationsBatch(uint256 startIndex, uint256 count) 
        external view returns (uint256[] memory) {
        uint256 counter = genesis.applicationCounter();
        require(startIndex < counter, "Start index out of bounds");
        
        uint256 remaining = counter - startIndex;
        uint256 actualCount = count > remaining ? remaining : count;
        
        uint256[] memory ids = new uint256[](actualCount);
        for (uint256 i = 0; i < actualCount; i++) {
            ids[i] = startIndex + i;
        }
        
        return ids;
    }
    
    /**
     * @dev Get all active skill verification applications
     * @return Array of active applications
     */
    function getActiveSkillApplications() 
        external view returns (IOpenworkGenesis.SkillVerificationApplication[] memory) {
        uint256 counter = genesis.applicationCounter();
        
        // First pass: count active applications
        uint256 activeCount = 0;
        for (uint256 i = 0; i < counter; i++) {
            IOpenworkGenesis.SkillVerificationApplication memory app = genesis.getSkillApplication(i);
            if (app.isVotingActive) {
                activeCount++;
            }
        }
        
        // Second pass: collect active applications
        IOpenworkGenesis.SkillVerificationApplication[] memory activeApps = 
            new IOpenworkGenesis.SkillVerificationApplication[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < counter; i++) {
            IOpenworkGenesis.SkillVerificationApplication memory app = genesis.getSkillApplication(i);
            if (app.isVotingActive) {
                activeApps[currentIndex] = app;
                currentIndex++;
            }
        }
        
        return activeApps;
    }
    
    // ==================== ASK ATHENA BATCH GETTERS ====================
    
    /**
     * @dev Get all Ask Athena application IDs
     * @return Array of all application IDs from 0 to counter-1
     */
    function getAllAskAthenaIds() external view returns (uint256[] memory) {
        uint256 counter = genesis.askAthenaCounter();
        uint256[] memory ids = new uint256[](counter);
        
        for (uint256 i = 0; i < counter; i++) {
            ids[i] = i;
        }
        
        return ids;
    }
    
    /**
     * @dev Get Ask Athena application IDs in batches
     * @param startIndex Starting index
     * @param count Number of IDs to return
     * @return Array of application IDs for the requested range
     */
    function getAskAthenaApplicationsBatch(uint256 startIndex, uint256 count) 
        external view returns (uint256[] memory) {
        uint256 counter = genesis.askAthenaCounter();
        require(startIndex < counter, "Start index out of bounds");
        
        uint256 remaining = counter - startIndex;
        uint256 actualCount = count > remaining ? remaining : count;
        
        uint256[] memory ids = new uint256[](actualCount);
        for (uint256 i = 0; i < actualCount; i++) {
            ids[i] = startIndex + i;
        }
        
        return ids;
    }
    
    /**
     * @dev Get all active Ask Athena applications
     * @return Array of active applications
     */
    function getActiveAskAthenaApplications() 
        external view returns (IOpenworkGenesis.AskAthenaApplication[] memory) {
        uint256 counter = genesis.askAthenaCounter();
        
        // First pass: count active applications
        uint256 activeCount = 0;
        for (uint256 i = 0; i < counter; i++) {
            IOpenworkGenesis.AskAthenaApplication memory app = genesis.getAskAthenaApplication(i);
            if (app.isVotingActive) {
                activeCount++;
            }
        }
        
        // Second pass: collect active applications
        IOpenworkGenesis.AskAthenaApplication[] memory activeApps = 
            new IOpenworkGenesis.AskAthenaApplication[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < counter; i++) {
            IOpenworkGenesis.AskAthenaApplication memory app = genesis.getAskAthenaApplication(i);
            if (app.isVotingActive) {
                activeApps[currentIndex] = app;
                currentIndex++;
            }
        }
        
        return activeApps;
    }
    
    // ==================== DISPUTE BATCH GETTERS ====================
    
    /**
     * @dev Get all dispute job IDs (uses existing getAllJobIds and filters for disputes)
     * @return Array of job IDs that have disputes
     */
    function getAllDisputeIds() external view returns (string[] memory) {
        string[] memory allJobIds = genesis.getAllJobIds();
        
        // First pass: count total disputes (check multi-disputes per job)
        uint256 totalDisputes = 0;
        for (uint256 i = 0; i < allJobIds.length; i++) {
            uint256 disputeCounter = 1;
            while (disputeCounter <= 10) { // Max 10 disputes per job
                string memory disputeId = string(abi.encodePacked(allJobIds[i], "-", _toString(disputeCounter)));
                IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(disputeId);
                if (bytes(dispute.jobId).length == 0) break;
                totalDisputes++;
                disputeCounter++;
            }
        }
        
        // Second pass: collect all dispute IDs
        string[] memory disputeIds = new string[](totalDisputes);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < allJobIds.length; i++) {
            uint256 disputeCounter = 1;
            while (disputeCounter <= 10) {
                string memory disputeId = string(abi.encodePacked(allJobIds[i], "-", _toString(disputeCounter)));
                IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(disputeId);
                if (bytes(dispute.jobId).length == 0) break;
                disputeIds[currentIndex] = disputeId;
                currentIndex++;
                disputeCounter++;
            }
        }
        
        return disputeIds;
    }
    
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    /**
     * @dev Get dispute IDs in batches
     * @param startIndex Starting index in the job list
     * @param count Number of jobs to check
     * @return Array of job IDs that have disputes in the specified range
     */
    function getDisputesBatch(uint256 startIndex, uint256 count) 
        external view returns (string[] memory) {
        string[] memory allJobIds = genesis.getAllJobIds();
        require(startIndex < allJobIds.length, "Start index out of bounds");
        
        uint256 remaining = allJobIds.length - startIndex;
        uint256 actualCount = count > remaining ? remaining : count;
        
        // First pass: count disputes in range
        uint256 disputeCount = 0;
        for (uint256 i = 0; i < actualCount; i++) {
            IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(allJobIds[startIndex + i]);
            if (bytes(dispute.jobId).length > 0) {
                disputeCount++;
            }
        }
        
        // Second pass: collect dispute IDs
        string[] memory disputeIds = new string[](disputeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < actualCount; i++) {
            IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(allJobIds[startIndex + i]);
            if (bytes(dispute.jobId).length > 0) {
                disputeIds[currentIndex] = allJobIds[startIndex + i];
                currentIndex++;
            }
        }
        
        return disputeIds;
    }
    
    /**
     * @dev Get all active disputes
     * @return Array of active disputes
     */
    function getActiveDisputes() 
        external view returns (IOpenworkGenesis.Dispute[] memory) {
        string[] memory allJobIds = genesis.getAllJobIds();
        
        // First pass: count active disputes (check multi-disputes)
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allJobIds.length; i++) {
            uint256 disputeCounter = 1;
            while (disputeCounter <= 10) {
                string memory disputeId = string(abi.encodePacked(allJobIds[i], "-", _toString(disputeCounter)));
                IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(disputeId);
                if (bytes(dispute.jobId).length == 0) break;
                if (dispute.isVotingActive) {
                    activeCount++;
                }
                disputeCounter++;
            }
        }
        
        // Second pass: collect active disputes
        IOpenworkGenesis.Dispute[] memory activeDisputes = new IOpenworkGenesis.Dispute[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < allJobIds.length; i++) {
            uint256 disputeCounter = 1;
            while (disputeCounter <= 10) {
                string memory disputeId = string(abi.encodePacked(allJobIds[i], "-", _toString(disputeCounter)));
                IOpenworkGenesis.Dispute memory dispute = genesis.getDispute(disputeId);
                if (bytes(dispute.jobId).length == 0) break;
                if (dispute.isVotingActive) {
                    activeDisputes[currentIndex] = dispute;
                    currentIndex++;
                }
                disputeCounter++;
            }
        }
        
        return activeDisputes;
    }
    
    // ==================== JOB BATCH GETTERS ====================
    
    /**
     * @dev Get all jobs with specific status
     * @param status Job status to filter by (0=Open, 1=InProgress, 2=Completed, 3=Cancelled)
     * @return Array of jobs matching the status
     */
    function getJobsByStatus(IOpenworkGenesis.JobStatus status) 
        external view returns (IOpenworkGenesis.Job[] memory) {
        string[] memory allJobIds = genesis.getAllJobIds();
        
        // First pass: count jobs with matching status
        uint256 matchCount = 0;
        for (uint256 i = 0; i < allJobIds.length; i++) {
            IOpenworkGenesis.Job memory job = genesis.getJob(allJobIds[i]);
            if (job.status == status) {
                matchCount++;
            }
        }
        
        // Second pass: collect matching jobs
        IOpenworkGenesis.Job[] memory matchingJobs = new IOpenworkGenesis.Job[](matchCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < allJobIds.length; i++) {
            IOpenworkGenesis.Job memory job = genesis.getJob(allJobIds[i]);
            if (job.status == status) {
                matchingJobs[currentIndex] = job;
                currentIndex++;
            }
        }
        
        return matchingJobs;
    }
    
    /**
     * @dev Get all open jobs (status = 0)
     * @return Array of open jobs
     */
    function getOpenJobs() external view returns (IOpenworkGenesis.Job[] memory) {
        return this.getJobsByStatus(IOpenworkGenesis.JobStatus.Open);
    }
    
    /**
     * @dev Get all in-progress jobs (status = 1)
     * @return Array of in-progress jobs
     */
    function getInProgressJobs() external view returns (IOpenworkGenesis.Job[] memory) {
        return this.getJobsByStatus(IOpenworkGenesis.JobStatus.InProgress);
    }
    
    /**
     * @dev Get jobs posted by specific user, filtered by status
     * @param poster Address of job poster
     * @param status Job status to filter by
     * @return Array of user's jobs matching the status
     */
    function getJobsByPosterWithStatus(address poster, IOpenworkGenesis.JobStatus status) 
        external view returns (IOpenworkGenesis.Job[] memory) {
        string[] memory userJobIds = genesis.getJobsByPoster(poster);
        
        // First pass: count matching jobs
        uint256 matchCount = 0;
        for (uint256 i = 0; i < userJobIds.length; i++) {
            IOpenworkGenesis.Job memory job = genesis.getJob(userJobIds[i]);
            if (job.status == status) {
                matchCount++;
            }
        }
        
        // Second pass: collect matching jobs
        IOpenworkGenesis.Job[] memory matchingJobs = new IOpenworkGenesis.Job[](matchCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < userJobIds.length; i++) {
            IOpenworkGenesis.Job memory job = genesis.getJob(userJobIds[i]);
            if (job.status == status) {
                matchingJobs[currentIndex] = job;
                currentIndex++;
            }
        }
        
        return matchingJobs;
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    /**
     * @dev Get total number of skill applications
     */
    function getSkillApplicationCount() external view returns (uint256) {
        return genesis.applicationCounter();
    }
    
    /**
     * @dev Get total number of Ask Athena applications
     */
    function getAskAthenaCount() external view returns (uint256) {
        return genesis.askAthenaCounter();
    }
}
