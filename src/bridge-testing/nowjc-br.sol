// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IRewardsTrackingContract {
    function updateRewards(string memory jobId, uint256 paidAmountUSDT, uint256 totalPlatformPayments) external;
}

contract NativeOpenWorkReceiver is OApp {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
        string[] portfolioHashes;
    }
    
    struct MilestonePayment {
        string descriptionHash;
        uint256 amount;
    }
    
    struct Application {
        uint256 id;
        string jobId;
        address applicant;
        string applicationHash;
        MilestonePayment[] proposedMilestones;
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

    struct RewardBand {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 owPerDollar;
    }

    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public totalPlatformPayments;
    uint256 public jobCounter;
    string[] public allJobIds;
    mapping(address => string[]) public jobsByPoster;
    
    // Rewards state
    mapping(address => address) public userReferrers;
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    RewardBand[] public rewardBands;
    
    IRewardsTrackingContract public rewardsContract;
    
    // Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer);
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobApplication(string indexed jobId, uint256 indexed applicationId, address indexed applicant, string applicationHash);
    event JobStarted(string indexed jobId, uint256 indexed applicationId, address indexed selectedApplicant, bool useApplicantMilestones);
    event WorkSubmitted(string indexed jobId, address indexed applicant, string submissionHash, uint256 milestone);
    event PaymentReleased(string indexed jobId, address indexed jobGiver, address indexed applicant, uint256 amount, uint256 milestone);
    event MilestoneLocked(string indexed jobId, uint256 newMilestone, uint256 lockedAmount);
    event UserRated(string indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(string indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    event TokensEarned(address indexed user, uint256 tokensEarned, uint256 newCumulativeEarnings, uint256 newTotalTokens);
    
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {
        _initializeRewardBands();
    }
    
    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        string memory message = abi.decode(payload, (string));
        _processMessage(message);
    }
    
    function _processMessage(string memory message) internal {
        string[] memory parts = _split(message, ":");
        require(parts.length > 0, "Invalid message format");
        
        string memory action = parts[0];
        
        if (_compareStrings(action, "createProfile")) {
            _handleCreateProfile(parts);
        } else if (_compareStrings(action, "postJob")) {
            _handlePostJob(parts);
        } else if (_compareStrings(action, "applyToJob")) {
            _handleApplyToJob(parts);
        } else if (_compareStrings(action, "startJob")) {
            _handleStartJob(parts);
        } else if (_compareStrings(action, "submitWork")) {
            _handleSubmitWork(parts);
        } else if (_compareStrings(action, "releasePayment")) {
            _handleReleasePayment(parts);
        } else if (_compareStrings(action, "lockNextMilestone")) {
            _handleLockNextMilestone(parts);
        } else if (_compareStrings(action, "releasePaymentAndLockNext")) {
            _handleReleasePaymentAndLockNext(parts);
        } else if (_compareStrings(action, "rate")) {
            _handleRate(parts);
        } else if (_compareStrings(action, "addPortfolio")) {
            _handleAddPortfolio(parts);
        }
    }
    
    function _handleCreateProfile(string[] memory parts) internal {
        require(parts.length == 4, "Invalid createProfile format");
        address user = _parseAddress(parts[1]);
        string memory ipfsHash = parts[2];
        address referrer = _parseAddress(parts[3]);
        
        require(!hasProfile[user], "Profile already exists");
        
        profiles[user] = Profile({
            userAddress: user,
            ipfsHash: ipfsHash,
            referrerAddress: referrer,
            portfolioHashes: new string[](0)
        });
        
        hasProfile[user] = true;
        
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, ipfsHash, referrer);
    }
    
    function _handlePostJob(string[] memory parts) internal {
        require(parts.length >= 4, "Invalid postJob format");
        string memory jobId = parts[1];
        address jobGiver = _parseAddress(parts[2]);
        string memory jobDetailHash = parts[3];
        
        require(bytes(jobs[jobId].id).length == 0, "Job ID already exists");
        
        jobCounter++;
        allJobIds.push(jobId);
        jobsByPoster[jobGiver].push(jobId);
        
        Job storage newJob = jobs[jobId];
        newJob.id = jobId;
        newJob.jobGiver = jobGiver;
        newJob.jobDetailHash = jobDetailHash;
        newJob.status = JobStatus.Open;
        
        // Parse milestones (description:amount pairs starting from index 4)
        for (uint i = 4; i < parts.length; i += 2) {
            if (i + 1 < parts.length) {
                newJob.milestonePayments.push(MilestonePayment({
                    descriptionHash: parts[i],
                    amount: _parseUint(parts[i + 1])
                }));
            }
        }
        
        emit JobPosted(jobId, jobGiver, jobDetailHash);
        emit JobStatusChanged(jobId, JobStatus.Open);
    }
    
    function _handleApplyToJob(string[] memory parts) internal {
        require(parts.length >= 4, "Invalid applyToJob format");
        address applicant = _parseAddress(parts[1]);
        string memory jobId = parts[2];
        string memory applicationHash = parts[3];
        
        jobs[jobId].applicants.push(applicant);
        uint256 applicationId = ++jobApplicationCounter[jobId];
        
        Application storage newApp = jobApplications[jobId][applicationId];
        newApp.id = applicationId;
        newApp.jobId = jobId;
        newApp.applicant = applicant;
        newApp.applicationHash = applicationHash;
        
        // Parse proposed milestones
        for (uint i = 4; i < parts.length; i += 2) {
            if (i + 1 < parts.length) {
                newApp.proposedMilestones.push(MilestonePayment({
                    descriptionHash: parts[i],
                    amount: _parseUint(parts[i + 1])
                }));
            }
        }
        
        emit JobApplication(jobId, applicationId, applicant, applicationHash);
    }
    
    function _handleStartJob(string[] memory parts) internal {
        require(parts.length == 5, "Invalid startJob format");
        string memory jobId = parts[2];
        uint256 applicationId = _parseUint(parts[3]);
        bool useApplicantMilestones = _compareBool(parts[4], "true");
        
        Application storage app = jobApplications[jobId][applicationId];
        Job storage job = jobs[jobId];
        
        job.selectedApplicant = app.applicant;
        job.selectedApplicationId = applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        if (useApplicantMilestones) {
            for (uint i = 0; i < app.proposedMilestones.length; i++) {
                job.finalMilestones.push(app.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        emit JobStarted(jobId, applicationId, app.applicant, useApplicantMilestones);
        emit JobStatusChanged(jobId, JobStatus.InProgress);
    }
    
    function _handleSubmitWork(string[] memory parts) internal {
        require(parts.length == 4, "Invalid submitWork format");
        address applicant = _parseAddress(parts[1]);
        string memory jobId = parts[2];
        string memory submissionHash = parts[3];
        
        jobs[jobId].workSubmissions.push(submissionHash);
        
        emit WorkSubmitted(jobId, applicant, submissionHash, jobs[jobId].currentMilestone);
    }
    
    function _handleReleasePayment(string[] memory parts) internal {
        require(parts.length == 4, "Invalid releasePayment format");
        address jobGiver = _parseAddress(parts[1]);
        string memory jobId = parts[2];
        uint256 amount = _parseUint(parts[3]);
        
        jobs[jobId].totalPaid += amount;
        totalPlatformPayments += amount;
        
        _processRewards(jobGiver, jobId, amount);
        
        if (jobs[jobId].currentMilestone == jobs[jobId].finalMilestones.length) {
            jobs[jobId].status = JobStatus.Completed;
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(jobId, amount, totalPlatformPayments);
        }
        
        emit PaymentReleased(jobId, jobGiver, jobs[jobId].selectedApplicant, amount, jobs[jobId].currentMilestone);
    }
    
    function _handleLockNextMilestone(string[] memory parts) internal {
        require(parts.length == 4, "Invalid lockNextMilestone format");
        string memory jobId = parts[2];
        uint256 lockedAmount = _parseUint(parts[3]);
        
        jobs[jobId].currentMilestone += 1;
        
        emit MilestoneLocked(jobId, jobs[jobId].currentMilestone, lockedAmount);
    }
    
    function _handleReleasePaymentAndLockNext(string[] memory parts) internal {
        require(parts.length == 5, "Invalid releasePaymentAndLockNext format");
        address jobGiver = _parseAddress(parts[1]);
        string memory jobId = parts[2];
        uint256 releasedAmount = _parseUint(parts[3]);
        uint256 lockedAmount = _parseUint(parts[4]);
        
        jobs[jobId].totalPaid += releasedAmount;
        totalPlatformPayments += releasedAmount;
        jobs[jobId].currentMilestone += 1;
        
        _processRewards(jobGiver, jobId, releasedAmount);
        
        if (jobs[jobId].currentMilestone > jobs[jobId].finalMilestones.length) {
            jobs[jobId].status = JobStatus.Completed;
            emit JobStatusChanged(jobId, JobStatus.Completed);
        }
        
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(jobId, releasedAmount, totalPlatformPayments);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(jobId, releasedAmount, lockedAmount, jobs[jobId].currentMilestone);
    }
    
    function _handleRate(string[] memory parts) internal {
        require(parts.length == 5, "Invalid rate format");
        address rater = _parseAddress(parts[1]);
        string memory jobId = parts[2];
        address userToRate = _parseAddress(parts[3]);
        uint256 rating = _parseUint(parts[4]);
        
        jobRatings[jobId][userToRate] = rating;
        userRatings[userToRate].push(rating);
        
        emit UserRated(jobId, rater, userToRate, rating);
    }
    
    function _handleAddPortfolio(string[] memory parts) internal {
        require(parts.length == 3, "Invalid addPortfolio format");
        address user = _parseAddress(parts[1]);
        string memory portfolioHash = parts[2];
        
        profiles[user].portfolioHashes.push(portfolioHash);
        
        emit PortfolioAdded(user, portfolioHash);
    }
    
    // Rewards processing
    function _processRewards(address jobGiver, string memory jobId, uint256 amount) internal {
        address jobTaker = jobs[jobId].selectedApplicant;
        address jobGiverReferrer = userReferrers[jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        uint256 jobGiverAmount = amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = amount / 10;
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = amount / 10;
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(jobGiver, jobGiverAmount);
        }
        
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
    }
    
    function _accumulateJobTokens(address user, uint256 amountUSDT) private {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
    }
    
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) public view returns (uint256) {
        if (fromAmount >= toAmount) return 0;
        
        uint256 totalTokens = 0;
        uint256 currentAmount = fromAmount;
        
        for (uint256 i = 0; i < rewardBands.length && currentAmount < toAmount; i++) {
            RewardBand memory band = rewardBands[i];
            
            if (band.maxAmount <= currentAmount) continue;
            
            uint256 bandStart = currentAmount > band.minAmount ? currentAmount : band.minAmount;
            uint256 bandEnd = toAmount < band.maxAmount ? toAmount : band.maxAmount;
            
            if (bandStart < bandEnd) {
                uint256 amountInBand = bandEnd - bandStart;
                uint256 tokensInBand = (amountInBand * band.owPerDollar) / 1e6;
                totalTokens += tokensInBand;
                currentAmount = bandEnd;
            }
        }
        
        return totalTokens;
    }
    
    function _initializeRewardBands() private {
        rewardBands.push(RewardBand(0, 500 * 1e6, 100000 * 1e18));
        rewardBands.push(RewardBand(500 * 1e6, 1000 * 1e6, 50000 * 1e18));
        rewardBands.push(RewardBand(1000 * 1e6, 2000 * 1e6, 25000 * 1e18));
        rewardBands.push(RewardBand(2000 * 1e6, 4000 * 1e6, 12500 * 1e18));
        rewardBands.push(RewardBand(4000 * 1e6, 8000 * 1e6, 6250 * 1e18));
        rewardBands.push(RewardBand(8000 * 1e6, 16000 * 1e6, 3125 * 1e18));
        rewardBands.push(RewardBand(16000 * 1e6, 32000 * 1e6, 1562 * 1e18));
        rewardBands.push(RewardBand(32000 * 1e6, 64000 * 1e6, 781 * 1e18));
        rewardBands.push(RewardBand(64000 * 1e6, 128000 * 1e6, 391 * 1e18));
        rewardBands.push(RewardBand(128000 * 1e6, 256000 * 1e6, 195 * 1e18));
        rewardBands.push(RewardBand(256000 * 1e6, 512000 * 1e6, 98 * 1e18));
        rewardBands.push(RewardBand(512000 * 1e6, 1024000 * 1e6, 49 * 1e18));
        rewardBands.push(RewardBand(1024000 * 1e6, 2048000 * 1e6, 24 * 1e18));
        rewardBands.push(RewardBand(2048000 * 1e6, 4096000 * 1e6, 12 * 1e18));
        rewardBands.push(RewardBand(4096000 * 1e6, 8192000 * 1e6, 6 * 1e18));
        rewardBands.push(RewardBand(8192000 * 1e6, 16384000 * 1e6, 3 * 1e18));
        rewardBands.push(RewardBand(16384000 * 1e6, 32768000 * 1e6, 15 * 1e17));
        rewardBands.push(RewardBand(32768000 * 1e6, 65536000 * 1e6, 75 * 1e16));
        rewardBands.push(RewardBand(65536000 * 1e6, 131072000 * 1e6, 38 * 1e16));
        rewardBands.push(RewardBand(131072000 * 1e6, type(uint256).max, 19 * 1e16));
    }
    
    // Utility functions
    function _split(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);
        
        uint256 count = 1;
        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) count++;
        }
        
        string[] memory parts = new string[](count);
        uint256 partIndex = 0;
        uint256 startIndex = 0;
        
        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                parts[partIndex] = _substring(str, startIndex, i);
                partIndex++;
                startIndex = i + delimiterBytes.length;
                i += delimiterBytes.length - 1;
            }
        }
        parts[partIndex] = _substring(str, startIndex, strBytes.length);
        
        return parts;
    }
    
    function _substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
    
    function _parseAddress(string memory str) internal pure returns (address) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length == 42, "Invalid address length");
        
        uint256 result = 0;
        for (uint256 i = 2; i < 42; i++) {
            result *= 16;
            uint8 b = uint8(strBytes[i]);
            if (b >= 48 && b <= 57) result += b - 48;
            else if (b >= 97 && b <= 102) result += b - 87;
            else if (b >= 65 && b <= 70) result += b - 55;
        }
        
        return address(uint160(result));
    }
    
    function _parseUint(string memory str) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        uint256 result = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            uint8 b = uint8(strBytes[i]);
            require(b >= 48 && b <= 57, "Invalid number");
            result = result * 10 + (b - 48);
        }
        return result;
    }
    
    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    function _compareBool(string memory str, string memory target) internal pure returns (bool) {
        return _compareStrings(str, target);
    }
    
    // Admin functions
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        rewardsContract = IRewardsTrackingContract(_rewardsContract);
    }
    
    // View functions
    function getUserEarnedTokens(address user) external view returns (uint256) {
        return userTotalOWTokens[user];
    }
    
    function getUserRewardInfo(address user) external view returns (uint256 cumulativeEarnings, uint256 totalTokens) {
        return (userCumulativeEarnings[user], userTotalOWTokens[user]);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        return profiles[_user];
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        return jobs[_jobId];
    }
    
    function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        return jobApplications[_jobId][_applicationId];
    }
    
    function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = userRatings[_user];
        if (ratings.length == 0) return 0;
        
        uint256 totalRating = 0;
        for (uint i = 0; i < ratings.length; i++) {
            totalRating += ratings[i];
        }
        return totalRating / ratings.length;
    }
    
    function getJobCount() external view returns (uint256) { return jobCounter; }
    function getAllJobIds() external view returns (string[] memory) { return allJobIds; }
    function getJobsByPoster(address _poster) external view returns (string[] memory) { return jobsByPoster[_poster]; }
    function getJobApplicationCount(string memory _jobId) external view returns (uint256) { return jobApplicationCounter[_jobId]; }
    function isJobOpen(string memory _jobId) external view returns (bool) { return jobs[_jobId].status == JobStatus.Open; }
    function getJobStatus(string memory _jobId) external view returns (JobStatus) { return jobs[_jobId].status; }
    function jobExists(string memory _jobId) external view returns (bool) { return bytes(jobs[_jobId].id).length != 0; }
    function getUserReferrer(address user) external view returns (address) { return userReferrers[user]; }
}