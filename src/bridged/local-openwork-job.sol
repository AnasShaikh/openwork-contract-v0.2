// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LocalOpenWorkJobContract is OApp, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    enum JobStatus {
        Open,           // Job posted, accepting applications
        InProgress,     // Job started, work in progress
        Completed,      // All milestones completed
        Cancelled       // Job cancelled
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
        uint256 jobId;
        address applicant;
        string applicationHash;
        MilestonePayment[] proposedMilestones;
    }
    
    struct Job {
        uint256 id;
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
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => mapping(uint256 => Application)) public jobApplications;
    mapping(uint256 => uint256) public jobApplicationCounter;
    mapping(uint256 => mapping(address => uint256)) public jobRatings;
    mapping(address => uint256[]) public userRatings;
    uint256 public jobCounter;
    
    // USDT specific
    IERC20 public immutable usdtToken;    
    // LayerZero configuration
    uint32 public destinationEid;
    uint32 public immutable chainId;  // ADD: Chain ID for composite job IDs
    mapping(bytes32 => bool) public sentMessages;
    
    // Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer);
    event JobPosted(uint256 indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobApplication(uint256 indexed jobId, uint256 indexed applicationId, address indexed applicant, string applicationHash);
    event JobStarted(uint256 indexed jobId, uint256 indexed applicationId, address indexed selectedApplicant, bool useApplicantMilestones);
    event WorkSubmitted(uint256 indexed jobId, address indexed applicant, string submissionHash, uint256 milestone);
    event PaymentReleased(uint256 indexed jobId, address indexed jobGiver, address indexed applicant, uint256 amount, uint256 milestone);
    event MilestoneLocked(uint256 indexed jobId, uint256 newMilestone, uint256 lockedAmount);
    event UserRated(uint256 indexed jobId, address indexed rater, address indexed rated, uint256 rating);
    event PortfolioAdded(address indexed user, string portfolioHash);
    event USDTEscrowed(uint256 indexed jobId, address indexed jobGiver, uint256 amount);
    event CrossChainMessageSent(bytes32 indexed messageId, string messageType, uint256 indexed jobId);
    event MessageReceived(uint32 indexed srcEid, bytes32 indexed guid, string messageType);
    event JobStatusChanged(uint256 indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(uint256 indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    
    constructor(
        address _endpoint,
        address _owner,
        address _usdtToken,
        uint32 _chainId  // ADD: Chain ID parameter
    ) OApp(_endpoint, _owner) Ownable(msg.sender) {
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;  // ADD: Store chain ID
        transferOwnership(_owner);
    }
    
    function setDestinationEid(uint32 _destinationEid) external onlyOwner {
        destinationEid = _destinationEid;
    }
    
    // Profile Management
    function createProfile(
        string memory _ipfsHash, 
        address _referrerAddress,
        bytes calldata _options
    ) external payable nonReentrant {
        require(!hasProfile[msg.sender], "Profile already exists");
        
        // Execute local logic
        profiles[msg.sender] = Profile({
            userAddress: msg.sender,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        
        hasProfile[msg.sender] = true;
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "CREATE_PROFILE",
            msg.sender,
            _ipfsHash,
            _referrerAddress
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress);
        emit CrossChainMessageSent(receipt.guid, "CREATE_PROFILE", 0);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    // Job Management - Using composite job IDs
    function postJob(
        string memory _jobDetailHash, 
        MilestonePayment[] memory _milestonePayments,
        bytes calldata _options
    ) external payable nonReentrant {
        require(hasProfile[msg.sender], "Must have profile to post job");
        require(_milestonePayments.length > 0, "Must have at least one milestone");
        
        uint256 totalAmount = 0;
        for (uint i = 0; i < _milestonePayments.length; i++) {
            totalAmount += _milestonePayments[i].amount;
        }
        require(totalAmount > 0, "Total amount must be greater than 0");
        
        jobCounter++;
        uint256 compositeJobId = (uint256(chainId) << 128) | jobCounter;  // CREATE: Composite job ID
        
        Job storage newJob = jobs[compositeJobId];  // Use composite ID
        newJob.id = compositeJobId;
        newJob.jobGiver = msg.sender;
        newJob.jobDetailHash = _jobDetailHash;
        newJob.status = JobStatus.Open;
        newJob.totalPaid = 0;
        newJob.currentLockedAmount = 0;
        newJob.currentMilestone = 0;
        newJob.selectedApplicant = address(0);
        newJob.selectedApplicationId = 0;
        newJob.totalEscrowed = 0;
        newJob.totalReleased = 0;
        
        for (uint i = 0; i < _milestonePayments.length; i++) {
            newJob.milestonePayments.push(_milestonePayments[i]);
        }
        
        // Send cross-chain message with composite job ID
        bytes memory payload = abi.encode(
            "POST_JOB",
            compositeJobId,  // Send composite job ID
            msg.sender,
            _jobDetailHash,
            _milestonePayments,
            totalAmount
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobPosted(compositeJobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(compositeJobId, JobStatus.Open);
        emit CrossChainMessageSent(receipt.guid, "POST_JOB", compositeJobId);
    }
    
    function getJob(uint256 _jobId) public view returns (Job memory) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    // Application Management
    function applyToJob(
        uint256 _jobId, 
        string memory _applicationHash, 
        MilestonePayment[] memory _proposedMilestones,
        bytes calldata _options
    ) external payable nonReentrant {
        require(hasProfile[msg.sender], "Must have profile to apply");
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.Open, "Job is not open");
        require(jobs[_jobId].jobGiver != msg.sender, "Cannot apply to own job");
        require(_proposedMilestones.length > 0, "Must propose at least one milestone");
        
        // Check if already applied
        for (uint i = 0; i < jobs[_jobId].applicants.length; i++) {
            require(jobs[_jobId].applicants[i] != msg.sender, "Already applied to this job");
        }
        
        jobs[_jobId].applicants.push(msg.sender);
        
        // Create application
        jobApplicationCounter[_jobId]++;
        uint256 applicationId = jobApplicationCounter[_jobId];
        
        Application storage newApplication = jobApplications[_jobId][applicationId];
        newApplication.id = applicationId;
        newApplication.jobId = _jobId;
        newApplication.applicant = msg.sender;
        newApplication.applicationHash = _applicationHash;
        
        for (uint i = 0; i < _proposedMilestones.length; i++) {
            newApplication.proposedMilestones.push(_proposedMilestones[i]);
        }
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "APPLY_TO_JOB",
            msg.sender,
            _jobId,
            _applicationHash,
            _proposedMilestones
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobApplication(_jobId, applicationId, msg.sender, _applicationHash);
        emit CrossChainMessageSent(receipt.guid, "APPLY_TO_JOB", _jobId);
    }
    
    function getApplication(uint256 _jobId, uint256 _applicationId) public view returns (Application memory) {
        require(jobApplications[_jobId][_applicationId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_applicationId];
    }
    
    // Job Execution - BACKWARD COMPATIBLE: Keep original function signature
    function startJob(
        uint256 _applicationId, 
        bool _useApplicantMilestones,
        bytes calldata _options
    ) external payable nonReentrant {
        // Find job ID by searching through applications (backward compatibility)
        uint256 jobId = 0;
        for (uint256 i = 1; i <= jobCounter; i++) {
            uint256 compositeJobId = (uint256(chainId) << 128) | i;
            if (jobApplications[compositeJobId][_applicationId].id == _applicationId) {
                jobId = compositeJobId;
                break;
            }
        }
        require(jobId != 0, "Application does not exist");
        
        Application storage application = jobApplications[jobId][_applicationId];
        Job storage job = jobs[jobId];
        
        require(job.jobGiver == msg.sender, "Only job giver can start job");
        require(job.status == JobStatus.Open, "Job is not open");
        require(application.applicant != address(0), "Invalid application");
        
        // Set selected applicant and application
        job.selectedApplicant = application.applicant;
        job.selectedApplicationId = _applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        // Choose and store final milestones
        if (_useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                job.finalMilestones.push(application.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        // Lock first milestone payment
        require(job.finalMilestones.length > 0, "No milestones defined");
        uint256 firstMilestoneAmount = job.finalMilestones[0].amount;
        
        // Transfer USDT to contract for escrow
        usdtToken.safeTransferFrom(msg.sender, address(this), firstMilestoneAmount);
        
        job.currentLockedAmount = firstMilestoneAmount;
        job.totalEscrowed += firstMilestoneAmount;
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "START_JOB",
            msg.sender,
            jobId,  // Send the found job ID
            _applicationId,
            _useApplicantMilestones
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobStarted(jobId, _applicationId, application.applicant, _useApplicantMilestones);
        emit JobStatusChanged(jobId, JobStatus.InProgress);
        emit USDTEscrowed(jobId, msg.sender, firstMilestoneAmount);
        emit CrossChainMessageSent(receipt.guid, "START_JOB", jobId);
    }
    
    // NEW: Alternative function that takes job ID directly (for advanced usage)
    function startJobWithId(
        uint256 _jobId,
        uint256 _applicationId, 
        bool _useApplicantMilestones,
        bytes calldata _options
    ) external payable nonReentrant {
        require(jobs[_jobId].id != 0, "Job does not exist");
        
        Application storage application = jobApplications[_jobId][_applicationId];
        Job storage job = jobs[_jobId];
        
        require(job.jobGiver == msg.sender, "Only job giver can start job");
        require(job.status == JobStatus.Open, "Job is not open");
        require(application.applicant != address(0), "Invalid application");
        
        // Set selected applicant and application
        job.selectedApplicant = application.applicant;
        job.selectedApplicationId = _applicationId;
        job.status = JobStatus.InProgress;
        job.currentMilestone = 1;
        
        // Choose and store final milestones
        if (_useApplicantMilestones) {
            for (uint i = 0; i < application.proposedMilestones.length; i++) {
                job.finalMilestones.push(application.proposedMilestones[i]);
            }
        } else {
            for (uint i = 0; i < job.milestonePayments.length; i++) {
                job.finalMilestones.push(job.milestonePayments[i]);
            }
        }
        
        // Lock first milestone payment
        require(job.finalMilestones.length > 0, "No milestones defined");
        uint256 firstMilestoneAmount = job.finalMilestones[0].amount;
        
        // Transfer USDT to contract for escrow
        usdtToken.safeTransferFrom(msg.sender, address(this), firstMilestoneAmount);
        
        job.currentLockedAmount = firstMilestoneAmount;
        job.totalEscrowed += firstMilestoneAmount;
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "START_JOB",
            msg.sender,
            _jobId,
            _applicationId,
            _useApplicantMilestones
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit JobStarted(_jobId, _applicationId, application.applicant, _useApplicantMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
        emit USDTEscrowed(_jobId, msg.sender, firstMilestoneAmount);
        emit CrossChainMessageSent(receipt.guid, "START_JOB", _jobId);
    }
    
    function submitWork(
        uint256 _jobId, 
        string memory _submissionHash,
        bytes calldata _options
    ) external payable nonReentrant {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant == msg.sender, "Only selected applicant can submit work");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "SUBMIT_WORK",
            msg.sender,
            _jobId,
            _submissionHash
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit WorkSubmitted(_jobId, msg.sender, _submissionHash, jobs[_jobId].currentMilestone);
        emit CrossChainMessageSent(receipt.guid, "SUBMIT_WORK", _jobId);
    }
    
    function releasePayment(
        uint256 _jobId,
        bytes calldata _options
    ) external payable nonReentrant {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].jobGiver == msg.sender, "Only job giver can release payment");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant != address(0), "No applicant selected");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        require(jobs[_jobId].currentLockedAmount > 0, "No payment locked");
        
        uint256 amount = jobs[_jobId].currentLockedAmount;
        
        // Transfer USDT to the selected applicant
        usdtToken.safeTransfer(jobs[_jobId].selectedApplicant, amount);
        
        // Update job state
        jobs[_jobId].totalPaid += amount;
        jobs[_jobId].totalReleased += amount;
        jobs[_jobId].currentLockedAmount = 0;
        
        // Check if all milestones completed
        if (jobs[_jobId].currentMilestone == jobs[_jobId].finalMilestones.length) {
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "RELEASE_PAYMENT",
            msg.sender,
            _jobId,
            amount
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit PaymentReleased(_jobId, msg.sender, jobs[_jobId].selectedApplicant, amount, jobs[_jobId].currentMilestone);
        emit CrossChainMessageSent(receipt.guid, "RELEASE_PAYMENT", _jobId);
    }
    
    function lockNextMilestone(
        uint256 _jobId,
        bytes calldata _options
    ) external payable nonReentrant {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].jobGiver == msg.sender, "Only job giver can lock milestone");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].currentLockedAmount == 0, "Previous payment not released");
        require(jobs[_jobId].currentMilestone < jobs[_jobId].finalMilestones.length, "All milestones already completed");
        
        // Increment to next milestone
        jobs[_jobId].currentMilestone += 1;
        uint256 nextMilestoneAmount = jobs[_jobId].finalMilestones[jobs[_jobId].currentMilestone - 1].amount;
        
        // Transfer USDT to contract for escrow
        usdtToken.safeTransferFrom(msg.sender, address(this), nextMilestoneAmount);
        
        jobs[_jobId].currentLockedAmount = nextMilestoneAmount;
        jobs[_jobId].totalEscrowed += nextMilestoneAmount;
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "LOCK_NEXT_MILESTONE",
            msg.sender,
            _jobId,
            nextMilestoneAmount
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit MilestoneLocked(_jobId, jobs[_jobId].currentMilestone, nextMilestoneAmount);
        emit USDTEscrowed(_jobId, msg.sender, nextMilestoneAmount);
        emit CrossChainMessageSent(receipt.guid, "LOCK_NEXT_MILESTONE", _jobId);
    }
    
    // COMBINED FUNCTION: Release current payment AND lock next milestone
    function releasePaymentAndLockNext(
        uint256 _jobId,
        bytes calldata _options
    ) external payable nonReentrant {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].jobGiver == msg.sender, "Only job giver can release and lock");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant != address(0), "No applicant selected");
        require(jobs[_jobId].currentLockedAmount > 0, "No payment locked");
        require(jobs[_jobId].currentMilestone < jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        uint256 releaseAmount = jobs[_jobId].currentLockedAmount;
        
        // Release current payment
        usdtToken.safeTransfer(jobs[_jobId].selectedApplicant, releaseAmount);
        jobs[_jobId].totalPaid += releaseAmount;
        jobs[_jobId].totalReleased += releaseAmount;
        
        // Increment milestone
        jobs[_jobId].currentMilestone += 1;
        
        uint256 nextMilestoneAmount = 0;
        if (jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length) {
            nextMilestoneAmount = jobs[_jobId].finalMilestones[jobs[_jobId].currentMilestone - 1].amount;
            
            // Lock next milestone payment
            usdtToken.safeTransferFrom(msg.sender, address(this), nextMilestoneAmount);
            jobs[_jobId].currentLockedAmount = nextMilestoneAmount;
            jobs[_jobId].totalEscrowed += nextMilestoneAmount;
        } else {
            // All milestones completed
            jobs[_jobId].currentLockedAmount = 0;
            jobs[_jobId].status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "RELEASE_AND_LOCK",
            msg.sender,
            _jobId,
            releaseAmount,
            nextMilestoneAmount
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, releaseAmount, nextMilestoneAmount, jobs[_jobId].currentMilestone);
        emit CrossChainMessageSent(receipt.guid, "RELEASE_AND_LOCK", _jobId);
    }
    
    // Rating System
    function rate(
        uint256 _jobId, 
        address _userToRate, 
        uint256 _rating,
        bytes calldata _options
    ) external payable nonReentrant {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress || jobs[_jobId].status == JobStatus.Completed, "Job must be started");
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(jobRatings[_jobId][_userToRate] == 0, "User already rated for this job");
        
        bool isAuthorized = false;
        
        // Check if caller is job giver rating the selected applicant
        if (msg.sender == jobs[_jobId].jobGiver && _userToRate == jobs[_jobId].selectedApplicant) {
            isAuthorized = true;
        }
        // Check if caller is selected applicant rating the job giver
        else if (msg.sender == jobs[_jobId].selectedApplicant && _userToRate == jobs[_jobId].jobGiver) {
            isAuthorized = true;
        }
        
        require(isAuthorized, "Not authorized to rate this user for this job");
        
        jobRatings[_jobId][_userToRate] = _rating;
        userRatings[_userToRate].push(_rating);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "RATE_USER",
            msg.sender,
            _jobId,
            _userToRate,
            _rating
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit UserRated(_jobId, msg.sender, _userToRate, _rating);
        emit CrossChainMessageSent(receipt.guid, "RATE_USER", _jobId);
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
    
    // Portfolio Management
    function addPortfolio(
        string memory _portfolioHash,
        bytes calldata _options
    ) external payable nonReentrant {
        require(hasProfile[msg.sender], "Profile does not exist");
        require(bytes(_portfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        profiles[msg.sender].portfolioHashes.push(_portfolioHash);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "ADD_PORTFOLIO",
            msg.sender,
            _portfolioHash
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit PortfolioAdded(msg.sender, _portfolioHash);
        emit CrossChainMessageSent(receipt.guid, "ADD_PORTFOLIO", 0);
    }
    
    // LayerZero receive function
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address, // _executor - unused
        bytes calldata // _extraData - unused
    ) internal override {
        // Decode the message
        (string memory messageType) = abi.decode(payload, (string));
        
        emit MessageReceived(_origin.srcEid, _guid, messageType);
    }
    
    // Quote functions for gas estimation
    function quoteCreateProfile(
        string memory _ipfsHash, 
        address _referrerAddress,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(
            "CREATE_PROFILE",
            msg.sender,
            _ipfsHash,
            _referrerAddress
        );
        MessagingFee memory fee = _quote(destinationEid, payload, _options, false);
        return fee.nativeFee;
    }
    
    function quotePostJob(
        string memory _jobDetailHash, 
        MilestonePayment[] memory _milestonePayments,
        bytes calldata _options
    ) external view returns (uint256) {
        uint256 totalAmount = 0;
        for (uint i = 0; i < _milestonePayments.length; i++) {
            totalAmount += _milestonePayments[i].amount;
        }
        
        // Simulate composite job ID for quote
        uint256 compositeJobId = (uint256(chainId) << 128) | (jobCounter + 1);
        
        bytes memory payload = abi.encode(
            "POST_JOB",
            compositeJobId,
            msg.sender,
            _jobDetailHash,
            _milestonePayments,
            totalAmount
        );
        MessagingFee memory fee = _quote(destinationEid, payload, _options, false);
        return fee.nativeFee;
    }
    
    // Emergency functions
    function emergencyWithdraw(uint256 _jobId) external onlyOwner {
        require(jobs[_jobId].id != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.Open, "Can only withdraw from open jobs");
        
        uint256 remainingAmount = jobs[_jobId].totalEscrowed - jobs[_jobId].totalReleased;
        if (remainingAmount > 0) {
            usdtToken.safeTransfer(jobs[_jobId].jobGiver, remainingAmount);
            jobs[_jobId].totalReleased = jobs[_jobId].totalEscrowed;
        }
    }
    
    // Utility functions
    function getJobCount() external view returns (uint256) {
        return jobCounter;
    }
    
    function getJobApplicationCount(uint256 _jobId) external view returns (uint256) {
        return jobApplicationCounter[_jobId];
    }
    
    function isJobOpen(uint256 _jobId) external view returns (bool) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId].status == JobStatus.Open;
    }
    
    function getEscrowBalance(uint256 _jobId) external view returns (uint256 escrowed, uint256 released, uint256 remaining) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        escrowed = jobs[_jobId].totalEscrowed;
        released = jobs[_jobId].totalReleased;
        remaining = escrowed - released;
    }
    
    function getJobStatus(uint256 _jobId) external view returns (JobStatus) {
        require(jobs[_jobId].id != 0, "Job does not exist");
        return jobs[_jobId].status;
    }
    
    // Helper function to get chain ID and local counter from composite job ID
    function decomposeJobId(uint256 _compositeJobId) external pure returns (uint32 extractedChainId, uint256 localJobId) {
        extractedChainId = uint32(_compositeJobId >> 128);
        localJobId = uint256(uint128(_compositeJobId));
    }
    
    // Helper function to create composite job ID
    function createCompositeJobId(uint32 _chainId, uint256 _localJobId) external pure returns (uint256) {
        return (uint256(_chainId) << 128) | _localJobId;
    }
    
    // Withdraw contract balance (owner only)
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Receive function to accept ETH
    receive() external payable {}
}