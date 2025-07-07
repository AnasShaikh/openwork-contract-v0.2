// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";

interface IRewardsTrackingContract {
    function updateRewards(string memory jobId, uint256 paidAmountUSDT, uint256 totalPlatformPayments) external;
}

contract NativeOpenWorkJobContract is OAppReceiver {
    enum JobStatus {
        Open,
        InProgress,
        Completed,
        Cancelled
    }
    
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

    // ==================== REWARDS CALCULATION STRUCTURES ====================
    
    // Reward bands structure for job-based rewards (copied from main-rewards.sol)
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }

    // User referrer mapping
    mapping(address => address) public userReferrers;
    
    // User tracking for job-based rewards
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    
    // Reward bands array
    RewardBand[] public rewardBands;

    // ==================== EXISTING CONTRACT STATE ====================
    
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public totalPlatformPayments;
    
    // Job tracking variables
    uint256 public jobCounter;
    string[] public allJobIds;
    mapping(address => string[]) public jobsByPoster;
    
    IRewardsTrackingContract public rewardsContract;
    
    // ==================== EVENTS ====================
    
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
    
    // New rewards events
    event TokensEarned(address indexed user, uint256 tokensEarned, uint256 newCumulativeEarnings, uint256 newTotalTokens);
    event LayerZeroMessageReceived(uint32 srcEid, string functionName, string data);
    
    constructor(address _owner, address _endpoint) OAppCore(_endpoint, _owner) Ownable(msg.sender) {
        transferOwnership(_owner);
        _initializeRewardBands();
    }

    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        string memory message = abi.decode(_message, (string));
        
        // Parse the function call from the message
        bytes memory messageBytes = bytes(message);
        uint256 colonIndex = _findFirstColon(messageBytes);
        require(colonIndex > 0, "Invalid message format");
        
        string memory functionName = _substring(message, 0, colonIndex);
        string memory data = _substring(message, colonIndex + 1, bytes(message).length);
        
        emit LayerZeroMessageReceived(_origin.srcEid, functionName, data);
        
        // Route to appropriate function
        if (_compareStrings(functionName, "createProfile")) {
            _handleCreateProfile(data);
        } else if (_compareStrings(functionName, "postJob")) {
            _handlePostJob(data);
        } else if (_compareStrings(functionName, "applyToJob")) {
            _handleApplyToJob(data);
        } else if (_compareStrings(functionName, "submitWork")) {
            _handleSubmitWork(data);
        } else if (_compareStrings(functionName, "releasePayment")) {
            _handleReleasePayment(data);
        } else if (_compareStrings(functionName, "lockNextMilestone")) {
            _handleLockNextMilestone(data);
        } else if (_compareStrings(functionName, "releasePaymentAndLockNext")) {
            _handleReleasePaymentAndLockNext(data);
        } else if (_compareStrings(functionName, "rate")) {
            _handleRate(data);
        } else if (_compareStrings(functionName, "addPortfolio")) {
            _handleAddPortfolio(data);
        } else {
            revert("Unknown function");
        }
    }

    // ==================== MESSAGE PARSING HELPERS ====================
    
    function _findFirstColon(bytes memory data) private pure returns (uint256) {
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == 0x3A) { // ASCII for ':'
                return i;
            }
        }
        return 0;
    }
    
    function _substring(string memory str, uint256 startIndex, uint256 endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
    
    function _compareStrings(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    function _splitByColon(string memory data) private pure returns (string[] memory) {
        bytes memory dataBytes = bytes(data);
        uint256 colonCount = 0;
        
        // Count colons
        for (uint256 i = 0; i < dataBytes.length; i++) {
            if (dataBytes[i] == 0x3A) {
                colonCount++;
            }
        }
        
        string[] memory parts = new string[](colonCount + 1);
        uint256 partIndex = 0;
        uint256 startIndex = 0;
        
        for (uint256 i = 0; i <= dataBytes.length; i++) {
            if (i == dataBytes.length || dataBytes[i] == 0x3A) {
                bytes memory part = new bytes(i - startIndex);
                for (uint256 j = startIndex; j < i; j++) {
                    part[j - startIndex] = dataBytes[j];
                }
                parts[partIndex] = string(part);
                partIndex++;
                startIndex = i + 1;
            }
        }
        
        return parts;
    }
    
    function _hexStringToAddress(string memory s) private pure returns (address) {
        bytes memory ss = bytes(s);
        require(ss.length == 42, "Invalid address length");
        require(ss[0] == '0' && ss[1] == 'x', "Invalid address format");
        
        bytes memory addr = new bytes(20);
        for (uint256 i = 0; i < 20; i++) {
            addr[i] = bytes1(_fromHexChar(uint8(ss[2 + i * 2])) * 16 + _fromHexChar(uint8(ss[3 + i * 2])));
        }
        return address(uint160(bytes20(addr)));
    }
    
    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("Invalid hex character");
    }
    
    function _stringToUint(string memory s) private pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                result = result * 10 + (uint256(uint8(b[i])) - 48);
            }
        }
        return result;
    }

    // ==================== MESSAGE HANDLERS ====================
    
    function _handleCreateProfile(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid createProfile data");
        
        address user = _hexStringToAddress(parts[0]);
        string memory ipfsHash = parts[1];
        address referrerAddress = _hexStringToAddress(parts[2]);
        
        createProfile(user, ipfsHash, referrerAddress);
    }
    
    function _handlePostJob(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid postJob data");
        
        string memory jobId = parts[0];
        address jobGiver = _hexStringToAddress(parts[1]);
        string memory jobDetailHash = parts[2];
        
        // For LayerZero calls, we create minimal job entries
        // The full milestone data is stored on the local chain
        string[] memory emptyDescriptions = new string[](1);
        uint256[] memory emptyAmounts = new uint256[](1);
        emptyDescriptions[0] = "";
        emptyAmounts[0] = 0;
        
        postJob(jobId, jobGiver, jobDetailHash, emptyDescriptions, emptyAmounts);
    }
    
    function _handleApplyToJob(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid applyToJob data");
        
        address applicant = _hexStringToAddress(parts[0]);
        string memory jobId = parts[1];
        string memory applicationHash = parts[2];
        
        // For LayerZero calls, we create minimal application entries
        string[] memory emptyDescriptions = new string[](1);
        uint256[] memory emptyAmounts = new uint256[](1);
        emptyDescriptions[0] = "";
        emptyAmounts[0] = 0;
        
        applyToJob(applicant, jobId, applicationHash, emptyDescriptions, emptyAmounts);
    }
    
    function _handleSubmitWork(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid submitWork data");
        
        address applicant = _hexStringToAddress(parts[0]);
        string memory jobId = parts[1];
        string memory submissionHash = parts[2];
        
        submitWork(applicant, jobId, submissionHash);
    }
    
    function _handleReleasePayment(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid releasePayment data");
        
        address jobGiver = _hexStringToAddress(parts[0]);
        string memory jobId = parts[1];
        uint256 amount = _stringToUint(parts[2]);
        
        releasePayment(jobGiver, jobId, amount);
    }
    
    function _handleLockNextMilestone(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid lockNextMilestone data");
        
        address caller = _hexStringToAddress(parts[0]);
        string memory jobId = parts[1];
        uint256 lockedAmount = _stringToUint(parts[2]);
        
        lockNextMilestone(caller, jobId, lockedAmount);
    }
    
    function _handleReleasePaymentAndLockNext(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 4, "Invalid releasePaymentAndLockNext data");
        
        address jobGiver = _hexStringToAddress(parts[0]);
        string memory jobId = parts[1];
        uint256 releasedAmount = _stringToUint(parts[2]);
        uint256 lockedAmount = _stringToUint(parts[3]);
        
        releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount);
    }
    
    function _handleRate(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 4, "Invalid rate data");
        
        address rater = _hexStringToAddress(parts[0]);
        string memory jobId = parts[1];
        address userToRate = _hexStringToAddress(parts[2]);
        uint256 rating = _stringToUint(parts[3]);
        
        rate(rater, jobId, userToRate, rating);
    }
    
    function _handleAddPortfolio(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 2, "Invalid addPortfolio data");
        
        address user = _hexStringToAddress(parts[0]);
        string memory portfolioHash = parts[1];
        
        addPortfolio(user, portfolioHash);
    }

    // ==================== REWARDS INITIALIZATION ====================
    
    function _initializeRewardBands() private {
        // Job-based reward bands (same as main-rewards.sol)
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

    // ==================== REWARDS CALCULATION FUNCTIONS ====================
    
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) public view returns (uint256) {
        if (fromAmount >= toAmount) {
            return 0;
        }
        
        uint256 totalTokens = 0;
        uint256 currentAmount = fromAmount;
        
        for (uint256 i = 0; i < rewardBands.length && currentAmount < toAmount; i++) {
            RewardBand memory band = rewardBands[i];
            
            // Skip bands that are entirely below our starting point
            if (band.maxAmount <= currentAmount) {
                continue;
            }
            
            // Calculate the overlap with this band
            uint256 bandStart = currentAmount > band.minAmount ? currentAmount : band.minAmount;
            uint256 bandEnd = toAmount < band.maxAmount ? toAmount : band.maxAmount;
            
            if (bandStart < bandEnd) {
                uint256 amountInBand = bandEnd - bandStart;
                uint256 tokensInBand = (amountInBand * band.owPerDollar) / 1e6; // Convert USDT (6 decimals) to tokens
                totalTokens += tokensInBand;
                currentAmount = bandEnd;
            }
        }
        
        return totalTokens;
    }

    function _accumulateJobTokens(address user, uint256 amountUSDT) private {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        
        // Calculate tokens based on progressive bands
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        // Update user's cumulative earnings and total tokens
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
    }

    // ==================== PUBLIC REWARDS VIEW FUNCTIONS ====================
    
    /**
     * @notice Get the total earned tokens for a user (for DAO to check governance eligibility)
     * @param user The user address
     * @return Total earned OW tokens for the user
     */
    function getUserEarnedTokens(address user) external view returns (uint256) {
        return userTotalOWTokens[user];
    }

    /**
     * @notice Get comprehensive reward info for a user
     * @param user The user address
     * @return cumulativeEarnings Total USDT earnings
     * @return totalTokens Total OW tokens earned
     */
    function getUserRewardInfo(address user) external view returns (
        uint256 cumulativeEarnings,
        uint256 totalTokens
    ) {
        return (userCumulativeEarnings[user], userTotalOWTokens[user]);
    }

    /**
     * @notice Calculate tokens for a specific amount without updating state
     * @param user The user address
     * @param additionalAmount Additional USDT amount
     * @return Tokens that would be earned for the additional amount
     */
    function calculateTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + additionalAmount;
        return calculateTokensForRange(currentCumulative, newCumulative);
    }

    // ==================== EXISTING CONTRACT FUNCTIONS ====================
    
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        rewardsContract = IRewardsTrackingContract(_rewardsContract);
    }
    
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) public {
        require(!hasProfile[_user], "Profile already exists");
        
        profiles[_user] = Profile({
            userAddress: _user,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        
        hasProfile[_user] = true;

        // Store referrer for rewards calculation
        if (_referrerAddress != address(0) && _referrerAddress != _user) {
            userReferrers[_user] = _referrerAddress;
        }
        
        emit ProfileCreated(_user, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        return profiles[_user];
    }
    
    function postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) public {
        require(bytes(jobs[_jobId].id).length == 0, "Job ID already exists");
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        uint256 calculatedTotal = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            calculatedTotal += _amounts[i];
        }
        
        // Increment job counter and track job
        jobCounter++;
        allJobIds.push(_jobId);
        jobsByPoster[_jobGiver].push(_jobId);
        
        Job storage newJob = jobs[_jobId];
        newJob.id = _jobId;
        newJob.jobGiver = _jobGiver;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        newJob.totalPaid = 0;
        newJob.currentMilestone = 0;
        newJob.selectedApplicant = address(0);
        newJob.selectedApplicationId = 0;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        emit JobPosted(_jobId, _jobGiver, _jobDetailHash);
        emit JobStatusChanged(_jobId, JobStatus.Open);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        return jobs[_jobId];
    }
    
    function applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts) public {
        require(_descriptions.length == _amounts.length, "Array length mismatch");
        
        for (uint i = 0; i < jobs[_jobId].applicants.length; i++) {
            require(jobs[_jobId].applicants[i] != _applicant, "Already applied to this job");
        }
        
        jobs[_jobId].applicants.push(_applicant);
        
        jobApplicationCounter[_jobId]++;
        uint256 applicationId = jobApplicationCounter[_jobId];
        
        Application storage newApplication = jobApplications[_jobId][applicationId];
        newApplication.id = applicationId;
        newApplication.jobId = _jobId;
        newApplication.applicant = _applicant;
        newApplication.applicationHash = _applicationHash;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newApplication.proposedMilestones.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        emit JobApplication(_jobId, applicationId, _applicant, _applicationHash);
    }
    
    function startJob(address /* _jobGiver */, string memory _jobId, uint256 _applicationId, bool _useApplicantMilestones) external {
        Application storage application = jobApplications[_jobId][_applicationId];
        Job storage job = jobs[_jobId];
        
        job.selectedApplicant = application.applicant;
        job.selectedApplicationId = _applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        if (_useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                job.finalMilestones.push(application.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        emit JobStarted(_jobId, _applicationId, application.applicant, _useApplicantMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
    }
    
    function getApplication(string memory _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(jobApplications[_jobId][_applicationId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_applicationId];
    }
    
    function submitWork(address _applicant, string memory _jobId, string memory _submissionHash) public {
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        emit WorkSubmitted(_jobId, _applicant, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    function releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) public {
        jobs[_jobId].totalPaid += _amount;
        totalPlatformPayments += _amount;

        // ==================== REWARDS CALCULATION ====================
        address jobTaker = jobs[_jobId].selectedApplicant;
        
        // Get referrers
        address jobGiverReferrer = userReferrers[_jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution (same logic as main-rewards.sol)
        uint256 jobGiverAmount = _amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != _jobGiver) {
            jobGiverReferrerAmount = _amount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = _amount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(_jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        // ==================== END REWARDS CALCULATION ====================
        
        if (jobs[_jobId].currentMilestone == jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(_jobId, _amount, totalPlatformPayments);
        }
        
        emit PaymentReleased(_jobId, _jobGiver, jobs[_jobId].selectedApplicant, _amount, jobs[_jobId].currentMilestone);
    }
    
    function lockNextMilestone(address /* _caller */, string memory _jobId, uint256 _lockedAmount) public {
        require(jobs[_jobId].currentMilestone < jobs[_jobId].finalMilestones.length, "All milestones already completed");
        
        jobs[_jobId].currentMilestone += 1;
        
        emit MilestoneLocked(_jobId, jobs[_jobId].currentMilestone, _lockedAmount);
    }
    
    function releasePaymentAndLockNext(address _jobGiver, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) public {
        jobs[_jobId].totalPaid += _releasedAmount;
        totalPlatformPayments += _releasedAmount;

        // ==================== REWARDS CALCULATION ====================
        address jobTaker = jobs[_jobId].selectedApplicant;
        
        // Get referrers
        address jobGiverReferrer = userReferrers[_jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution (same logic as main-rewards.sol)
        uint256 jobGiverAmount = _releasedAmount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != _jobGiver) {
            jobGiverReferrerAmount = _releasedAmount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = _releasedAmount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(_jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        // ==================== END REWARDS CALCULATION ====================
        
        jobs[_jobId].currentMilestone += 1;
        
        if (jobs[_jobId].currentMilestone > jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        if (address(rewardsContract) != address(0)) {
            rewardsContract.updateRewards(_jobId, _releasedAmount, totalPlatformPayments);
        }
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, _releasedAmount, _lockedAmount, jobs[_jobId].currentMilestone);
    }
    
    function rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) public {
        bool isAuthorized = false;
        
        if (_rater == jobs[_jobId].jobGiver && _userToRate == jobs[_jobId].selectedApplicant) {
            isAuthorized = true;
        } else if (_rater == jobs[_jobId].selectedApplicant && _userToRate == jobs[_jobId].jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized to rate this user for this job");
        
        jobRatings[_jobId][_userToRate] = _rating;
        userRatings[_userToRate].push(_rating);
        
        emit UserRated(_jobId, _rater, _userToRate, _rating);
    }
    
    function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = userRatings[_user];
        if (ratings.length == 0) {
            return 0;
        }
        
        uint256 totalRating = 0;
        for (uint i = 0; i < ratings.length; i++) {
            totalRating += ratings[i];
        }
        
        return totalRating / ratings.length;
    }
    
    function addPortfolio(address _user, string memory _portfolioHash) public {
        profiles[_user].portfolioHashes.push(_portfolioHash);
        
        emit PortfolioAdded(_user, _portfolioHash);
    }
    
    function getJobCount() external view returns (uint256) {
        return jobCounter;
    }
    
    function getAllJobIds() external view returns (string[] memory) {
        return allJobIds;
    }
    
    function getJobsByPoster(address _poster) external view returns (string[] memory) {
        return jobsByPoster[_poster];
    }
    
    function getJobApplicationCount(string memory _jobId) external view returns (uint256) {
        return jobApplicationCounter[_jobId];
    }
    
    function isJobOpen(string memory _jobId) external view returns (bool) {
        return jobs[_jobId].status == JobStatus.Open;
    }
    
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        return jobs[_jobId].status;
    }
    
    function jobExists(string memory _jobId) external view returns (bool) {
        return bytes(jobs[_jobId].id).length != 0;
    }

    // ==================== ADDITIONAL REWARDS VIEW FUNCTIONS ====================
    
    function getRewardBandsCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) {
        require(index < rewardBands.length, "Invalid band index");
        RewardBand memory band = rewardBands[index];
        return (band.minAmount, band.maxAmount, band.owPerDollar);
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
}