// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CrossChainLocalOpenWorkJobContract is OAppSender, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
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
        uint256 currentLockedAmount;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
        uint256 totalEscrowed;
        uint256 totalReleased;
    }
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    mapping(string => Job) public jobs;
    mapping(string => mapping(uint256 => Application)) public jobApplications;
    mapping(string => uint256) public jobApplicationCounter;
    mapping(string => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public jobCounter;
    address public athenaClientContract;

    
    // Platform total tracking for rewards (local tracking only)
    uint256 public totalPlatformPayments;
    
    IERC20 public immutable usdtToken;    
    uint32 public immutable chainId;
    
    // Chain endpoints for cross-chain communication
    uint32 public rewardsChainEid;    // Chain where RewardsContract is deployed
    uint32 public nativeChainEid;     // Chain where NativeOpenWorkJobContract is deployed
    
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
    event USDTEscrowed(string indexed jobId, address indexed jobGiver, uint256 amount);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(string indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    event PlatformTotalUpdated(uint256 newTotal);
    event CrossChainMessageSent(string indexed functionName, uint32[] dstEids, bytes payload);
    event DisputeResolved(string indexed jobId, bool jobGiverWins, address winner, uint256 amount);
    
    constructor(
        address _endpoint,
        address _owner, 
        address _usdtToken, 
        uint32 _chainId,
        uint32 _rewardsChainEid,
        uint32 _nativeChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;
        rewardsChainEid = _rewardsChainEid;
        nativeChainEid = _nativeChainEid;
    }
    
    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }
    
    /**
     * @notice Update chain endpoints (admin function)
     */
    function updateChainEndpoints(uint32 _rewardsChainEid, uint32 _nativeChainEid) external onlyOwner {
        rewardsChainEid = _rewardsChainEid;
        nativeChainEid = _nativeChainEid;
    }
    
    // Profile Management
    function createProfile(
        string memory _ipfsHash, 
        address _referrerAddress,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(!hasProfile[msg.sender], "Profile already exists");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        // Create profile locally
        profiles[msg.sender] = Profile({
            userAddress: msg.sender,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        hasProfile[msg.sender] = true;
        
        // Send cross-chain messages
        uint32[] memory dstEids = new uint32[](2);
        bytes[] memory options = new bytes[](2);
        
        dstEids[0] = rewardsChainEid;
        dstEids[1] = nativeChainEid;
        options[0] = _rewardsOptions;
        options[1] = _nativeOptions;
        
        // Encode different payloads for different contracts
        bytes memory rewardsPayload = abi.encode("createProfile", msg.sender, _referrerAddress);
        bytes memory nativePayload = abi.encode("createProfile", msg.sender, _ipfsHash, _referrerAddress);
        
        _sendToTwoChains(dstEids, rewardsPayload, nativePayload, options);
        
        emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress);
        emit CrossChainMessageSent("createProfile", dstEids, abi.encode(msg.sender, _ipfsHash, _referrerAddress));
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    // Job Management
    function postJob(
        string memory _jobDetailHash, 
        string[] memory _descriptions, 
        uint256[] memory _amounts,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(_descriptions.length > 0, "Must have at least one milestone");
        require(_descriptions.length == _amounts.length, "Descriptions and amounts length mismatch");
        
        uint256 calculatedTotal = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            calculatedTotal += _amounts[i];
        }
        require(calculatedTotal > 0, "Total amount must be greater than 0");
        
        string memory jobId = string(abi.encodePacked(Strings.toString(chainId), "-", Strings.toString(++jobCounter)));
        
        Job storage newJob = jobs[jobId];
        newJob.id = jobId;
        newJob.jobGiver = msg.sender;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newJob.milestonePayments.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        // Send to native chain
        bytes memory payload = abi.encode("postJob", jobId, msg.sender, _jobDetailHash, _descriptions, _amounts);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobPosted(jobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(jobId, JobStatus.Open);
        emit CrossChainMessageSent("postJob", _getSingleChainArray(nativeChainEid), payload);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    // Application Management
    function applyToJob(
        string memory _jobId, 
        string memory _appHash, 
        string[] memory _descriptions, 
        uint256[] memory _amounts,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(hasProfile[msg.sender], "Must have profile to apply");
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.Open, "Job is not open");
        require(jobs[_jobId].jobGiver != msg.sender, "Cannot apply to own job");
        require(_descriptions.length > 0, "Must propose at least one milestone");
        require(_descriptions.length == _amounts.length, "Descriptions and amounts length mismatch");
        
        address[] memory applicants = jobs[_jobId].applicants;
        for (uint i = 0; i < applicants.length; i++) {
            require(applicants[i] != msg.sender, "Already applied to this job");
        }
        
        jobs[_jobId].applicants.push(msg.sender);
        uint256 appId = ++jobApplicationCounter[_jobId];
        
        Application storage newApp = jobApplications[_jobId][appId];
        newApp.id = appId;
        newApp.jobId = _jobId;
        newApp.applicant = msg.sender;
        newApp.applicationHash = _appHash;
        
        for (uint i = 0; i < _descriptions.length; i++) {
            newApp.proposedMilestones.push(MilestonePayment({
                descriptionHash: _descriptions[i],
                amount: _amounts[i]
            }));
        }
        
        // Send to native chain
        bytes memory payload = abi.encode("applyToJob", msg.sender, _jobId, _appHash, _descriptions, _amounts);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobApplication(_jobId, appId, msg.sender, _appHash);
        emit CrossChainMessageSent("applyToJob", _getSingleChainArray(nativeChainEid), payload);
    }
    
    function getApplication(string memory _jobId, uint256 _appId) public view returns (Application memory) {
        require(jobApplications[_jobId][_appId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_appId];
    }
    
    // Job startup
    function startJob(
        string memory _jobId, 
        uint256 _appId, 
        bool _useAppMilestones,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        
        Application storage app = jobApplications[_jobId][_appId];
        Job storage job = jobs[_jobId];
        
        require(job.jobGiver == msg.sender, "Only job giver can start job");
        require(job.status == JobStatus.Open, "Job is not open");
        require(app.applicant != address(0), "Invalid application");
        
        job.selectedApplicant = app.applicant;
        job.selectedApplicationId = _appId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        MilestonePayment[] memory srcMilestones = _useAppMilestones ? app.proposedMilestones : job.milestonePayments;
        
        for (uint i = 0; i < srcMilestones.length; i++) {
            job.finalMilestones.push(srcMilestones[i]);
        }
        
        uint256 firstAmount = job.finalMilestones[0].amount;
        usdtToken.safeTransferFrom(msg.sender, address(this), firstAmount);
        job.currentLockedAmount = firstAmount;
        job.totalEscrowed += firstAmount;
        
        // Send to native chain
        bytes memory payload = abi.encode("startJob", msg.sender, _jobId, _appId, _useAppMilestones);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobStarted(_jobId, _appId, app.applicant, _useAppMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
        emit USDTEscrowed(_jobId, msg.sender, firstAmount);
        emit CrossChainMessageSent("startJob", _getSingleChainArray(nativeChainEid), payload);
    }
    
    function submitWork(
        string memory _jobId, 
        string memory _submissionHash,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant == msg.sender, "Only selected applicant can submit work");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        // Send to native chain
        bytes memory payload = abi.encode("submitWork", msg.sender, _jobId, _submissionHash);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit WorkSubmitted(_jobId, msg.sender, _submissionHash, jobs[_jobId].currentMilestone);
        emit CrossChainMessageSent("submitWork", _getSingleChainArray(nativeChainEid), payload);
    }
    
    function releasePayment(
        string memory _jobId,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.jobGiver == msg.sender, "Only job giver can release payment");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.selectedApplicant != address(0), "No applicant selected");
        require(job.currentMilestone <= job.finalMilestones.length, "All milestones completed");
        require(job.currentLockedAmount > 0, "No payment locked");
        
        uint256 amount = job.currentLockedAmount;
        usdtToken.safeTransfer(job.selectedApplicant, amount);
        
        job.totalPaid += amount;
        job.totalReleased += amount;
        job.currentLockedAmount = 0;
        
        // Update local platform total
        totalPlatformPayments += amount;
        
        if (job.currentMilestone == job.finalMilestones.length) {
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Send cross-chain messages
        uint32[] memory dstEids = new uint32[](2);
        bytes[] memory options = new bytes[](2);
        
        dstEids[0] = rewardsChainEid;
        dstEids[1] = nativeChainEid;
        options[0] = _rewardsOptions;
        options[1] = _nativeOptions;
        
        bytes memory rewardsPayload = abi.encode("updateRewardsOnPayment", job.jobGiver, job.selectedApplicant, amount);
        bytes memory nativePayload = abi.encode("releasePayment", msg.sender, _jobId, amount);
        
        _sendToTwoChains(dstEids, rewardsPayload, nativePayload, options);
        
        emit PaymentReleased(_jobId, msg.sender, job.selectedApplicant, amount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
        emit CrossChainMessageSent("releasePayment", dstEids, abi.encode(_jobId, amount));
    }
    
    function lockNextMilestone(
        string memory _jobId,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.jobGiver == msg.sender, "Only job giver can lock milestone");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.currentLockedAmount == 0, "Previous payment not released");
        require(job.currentMilestone < job.finalMilestones.length, "All milestones already completed");
        
        job.currentMilestone += 1;
        uint256 nextAmount = job.finalMilestones[job.currentMilestone - 1].amount;
        
        usdtToken.safeTransferFrom(msg.sender, address(this), nextAmount);
        
        job.currentLockedAmount = nextAmount;
        job.totalEscrowed += nextAmount;
        
        // Send to native chain
        bytes memory payload = abi.encode("lockNextMilestone", msg.sender, _jobId, nextAmount);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit MilestoneLocked(_jobId, job.currentMilestone, nextAmount);
        emit USDTEscrowed(_jobId, msg.sender, nextAmount);
        emit CrossChainMessageSent("lockNextMilestone", _getSingleChainArray(nativeChainEid), payload);
    }
    
    function releaseAndLockNext(
        string memory _jobId,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.jobGiver == msg.sender, "Only job giver can release and lock");
        require(job.status == JobStatus.InProgress, "Job must be in progress");
        require(job.selectedApplicant != address(0), "No applicant selected");
        require(job.currentLockedAmount > 0, "No payment locked");
        require(job.currentMilestone < job.finalMilestones.length, "All milestones completed");
        
        uint256 releaseAmount = job.currentLockedAmount;
        
        usdtToken.safeTransfer(job.selectedApplicant, releaseAmount);
        job.totalPaid += releaseAmount;
        job.totalReleased += releaseAmount;
        
        // Update local platform total
        totalPlatformPayments += releaseAmount;
        
        job.currentMilestone += 1;
        
        uint256 nextAmount = 0;
        if (job.currentMilestone <= job.finalMilestones.length) {
            nextAmount = job.finalMilestones[job.currentMilestone - 1].amount;
            
            usdtToken.safeTransferFrom(msg.sender, address(this), nextAmount);
            job.currentLockedAmount = nextAmount;
            job.totalEscrowed += nextAmount;
        } else {
            job.currentLockedAmount = 0;
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Send cross-chain messages
        uint32[] memory dstEids = new uint32[](2);
        bytes[] memory options = new bytes[](2);
        
        dstEids[0] = rewardsChainEid;
        dstEids[1] = nativeChainEid;
        options[0] = _rewardsOptions;
        options[1] = _nativeOptions;
        
        bytes memory rewardsPayload = abi.encode("updateRewardsOnPayment", job.jobGiver, job.selectedApplicant, releaseAmount);
        bytes memory nativePayload = abi.encode("releasePaymentAndLockNext", msg.sender, _jobId, releaseAmount, nextAmount);
        
        _sendToTwoChains(dstEids, rewardsPayload, nativePayload, options);
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, releaseAmount, nextAmount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
        emit CrossChainMessageSent("releaseAndLockNext", dstEids, abi.encode(_jobId, releaseAmount, nextAmount));
    }
    
    function rate(
        string memory _jobId, 
        address _userToRate, 
        uint256 _rating,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        require(job.status == JobStatus.InProgress || job.status == JobStatus.Completed, "Job must be started");
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(jobRatings[_jobId][_userToRate] == 0, "User already rated for this job");
        
        bool isAuth = (msg.sender == job.jobGiver && _userToRate == job.selectedApplicant) ||
                      (msg.sender == job.selectedApplicant && _userToRate == job.jobGiver);
        require(isAuth, "Not authorized to rate this user for this job");
        
        jobRatings[_jobId][_userToRate] = _rating;
        userRatings[_userToRate].push(_rating);
        
        // Send to native chain
        bytes memory payload = abi.encode("rate", msg.sender, _jobId, _userToRate, _rating);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit UserRated(_jobId, msg.sender, _userToRate, _rating);
        emit CrossChainMessageSent("rate", _getSingleChainArray(nativeChainEid), payload);
    }
    
    function getRating(address _user) public view returns (uint256) {
        uint256[] memory ratings = userRatings[_user];
        if (ratings.length == 0) return 0;
        
        uint256 total = 0;
        for (uint i = 0; i < ratings.length; i++) {
            total += ratings[i];
        }
        return total / ratings.length;
    }
    
    function addPortfolio(
        string memory _portfolioHash,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(hasProfile[msg.sender], "Profile does not exist");
        require(bytes(_portfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        profiles[msg.sender].portfolioHashes.push(_portfolioHash);
        
        // Send to native chain
        bytes memory payload = abi.encode("addPortfolio", msg.sender, _portfolioHash);
        _lzSend(
            nativeChainEid,
            payload,
            _nativeOptions,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit PortfolioAdded(msg.sender, _portfolioHash);
        emit CrossChainMessageSent("addPortfolio", _getSingleChainArray(nativeChainEid), payload);
    }
    
    // Internal helper functions
    function _sendToTwoChains(
        uint32[] memory _dstEids,
        bytes memory _payload1,
        bytes memory _payload2,
        bytes[] memory _options
    ) internal {
        require(_dstEids.length == 2, "Must have exactly 2 destinations");
        require(_options.length == 2, "Must have exactly 2 option sets");
        
        // Calculate total fees upfront
        MessagingFee memory fee1 = _quote(_dstEids[0], _payload1, _options[0], false);
        MessagingFee memory fee2 = _quote(_dstEids[1], _payload2, _options[1], false);
        uint256 totalFee = fee1.nativeFee + fee2.nativeFee;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to first chain
        _lzSend(
            _dstEids[0],
            _payload1,
            _options[0],
            fee1,
            payable(msg.sender)
        );
        
        // Send to second chain
        _lzSend(
            _dstEids[1],
            _payload2,
            _options[1],
            fee2,
            payable(msg.sender)
        );
    
    
    }

    function resolveDispute(string memory _jobId, bool _jobGiverWins) external {
    // Only allow Athena Client contract to call this
    require(msg.sender == address(athenaClientContract), "Only Athena Client can resolve disputes");
    
    Job storage job = jobs[_jobId];
    require(bytes(job.id).length != 0, "Job does not exist");
    require(job.status == JobStatus.InProgress, "Job must be in progress");
    require(job.currentLockedAmount > 0, "No funds escrowed");
    
    address winner;
    uint256 amount = job.currentLockedAmount;
    
    if (_jobGiverWins) {
        // Job giver wins - refund the escrowed amount
        winner = job.jobGiver;
        usdtToken.safeTransfer(job.jobGiver, amount);
    } else {
        // Job taker wins - release payment to them
        winner = job.selectedApplicant;
        usdtToken.safeTransfer(job.selectedApplicant, amount);
        
        // Update platform totals since this counts as a payment
        totalPlatformPayments += amount;
        job.totalPaid += amount;
        emit PlatformTotalUpdated(totalPlatformPayments);
    }
    
    // Clear escrowed amount and mark job as completed
    job.currentLockedAmount = 0;
    job.totalReleased += amount;
    job.status = JobStatus.Completed;
    
    emit DisputeResolved(_jobId, _jobGiverWins, winner, amount);
    emit JobStatusChanged(_jobId, JobStatus.Completed);
}

    function setAthenaClientContract(address _athenaClient) external onlyOwner {
    require(_athenaClient != address(0), "Athena client address cannot be zero");
    athenaClientContract = _athenaClient;
}
    
    function _getSingleChainArray(uint32 _chainEid) internal pure returns (uint32[] memory) {
        uint32[] memory result = new uint32[](1);
        result[0] = _chainEid;
        return result;
    }
    
    // Quote functions
    function quoteCreateProfile(
        string calldata _ipfsHash,
        address _referrerAddress,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 nativeFee) {
        bytes memory rewardsPayload = abi.encode("createProfile", msg.sender, _referrerAddress);
        bytes memory nativePayload = abi.encode("createProfile", msg.sender, _ipfsHash, _referrerAddress);
        
        MessagingFee memory msgFee1 = _quote(rewardsChainEid, rewardsPayload, _rewardsOptions, false);
        MessagingFee memory msgFee2 = _quote(nativeChainEid, nativePayload, _nativeOptions, false);
        
        rewardsFee = msgFee1.nativeFee;
        nativeFee = msgFee2.nativeFee;
        totalFee = rewardsFee + nativeFee;
    }
    
    function quoteSingleChain(
        string calldata _functionName,
        bytes calldata _payload,
        bytes calldata _options,
        uint32 _destinationEid
    ) external view returns (uint256 fee) {
        MessagingFee memory msgFee = _quote(_destinationEid, _payload, _options, false);
        return msgFee.nativeFee;
    }
    
    function quoteDualChain(
        bytes calldata _rewardsPayload,
        bytes calldata _nativePayload,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 nativeFee) {
        MessagingFee memory msgFee1 = _quote(rewardsChainEid, _rewardsPayload, _rewardsOptions, false);
        MessagingFee memory msgFee2 = _quote(nativeChainEid, _nativePayload, _nativeOptions, false);
        
        rewardsFee = msgFee1.nativeFee;
        nativeFee = msgFee2.nativeFee;
        totalFee = rewardsFee + nativeFee;
    }
    
    // View functions
    function getJobCount() external view returns (uint256) { return jobCounter; }
    function getJobApplicationCount(string memory _jobId) external view returns (uint256) { return jobApplicationCounter[_jobId]; }
    function isJobOpen(string memory _jobId) external view returns (bool) { 
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open; 
    }
    function getEscrowBalance(string memory _jobId) external view returns (uint256 escrowed, uint256 released, uint256 remaining) {
        Job storage job = jobs[_jobId];
        require(bytes(job.id).length != 0, "Job does not exist");
        escrowed = job.totalEscrowed;
        released = job.totalReleased;
        remaining = escrowed - released;
    }
    function getJobStatus(string memory _jobId) external view returns (JobStatus) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId].status;
    }
    function getTotalPlatformPayments() external view returns (uint256) {
        return totalPlatformPayments;
    }
    
    // Admin functions
    function updateLocalPlatformTotal(uint256 newTotal) external onlyOwner {
        require(newTotal >= totalPlatformPayments, "Cannot decrease platform total");
        totalPlatformPayments = newTotal;
        emit PlatformTotalUpdated(newTotal);
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