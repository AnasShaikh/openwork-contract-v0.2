// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface INativeOpenWorkJobContract {
    function createProfile(address _user, string memory _ipfsHash, address _referrerAddress) external;
    function postJob(string memory _jobId, address _jobGiver, string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external;
    function applyToJob(address _applicant, string memory _jobId, string memory _applicationHash, string[] memory _descriptions, uint256[] memory _amounts) external;
    function startJob(address _jobGiver, string memory _jobId, uint256 _applicationId, bool _useApplicantMilestones) external;
    function submitWork(address _applicant, string memory _jobId, string memory _submissionHash) external;
    function releasePayment(address _jobGiver, string memory _jobId, uint256 _amount) external;
    function lockNextMilestone(address _caller, string memory _jobId, uint256 _lockedAmount) external;
    function releasePaymentAndLockNext(address _jobGiver, string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) external;
    function rate(address _rater, string memory _jobId, address _userToRate, uint256 _rating) external;
    function addPortfolio(address _user, string memory _portfolioHash) external;
}

interface IRewardsContract {
    function createProfile(address user, address referrer) external;
    function updateRewardsOnPayment(address jobGiver, address jobTaker, uint256 amount) external;
}

contract LocalOpenWorkJobContract is Ownable, ReentrancyGuard {
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
    
    // Platform total tracking for rewards (local tracking only)
    uint256 public totalPlatformPayments;
    
    IERC20 public immutable usdtToken;    
    uint32 public immutable chainId;
    INativeOpenWorkJobContract public nativeContract;
    IRewardsContract public rewardsContract;
    
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
    event RewardsContractUpdated(address indexed newRewardsContract);
    event PlatformTotalUpdated(uint256 newTotal);
    
    constructor(address _owner, address _usdtToken, uint32 _chainId, address _nativeContract) Ownable(msg.sender) {
        usdtToken = IERC20(_usdtToken);
        chainId = _chainId;
        nativeContract = INativeOpenWorkJobContract(_nativeContract);
        transferOwnership(_owner);
    }
    
    // Set rewards contract
    function setRewardsContract(address _rewardsContract) external onlyOwner {
        require(_rewardsContract != address(0), "Invalid rewards contract address");
        rewardsContract = IRewardsContract(_rewardsContract);
        emit RewardsContractUpdated(_rewardsContract);
    }
    
    // Profile Management
    function createProfile(string memory _ipfsHash, address _referrerAddress) external nonReentrant {
        profiles[msg.sender] = Profile({
            userAddress: msg.sender,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            portfolioHashes: new string[](0)
        });
        hasProfile[msg.sender] = true;
        
        rewardsContract.createProfile(msg.sender, _referrerAddress) ;
             
        nativeContract.createProfile(msg.sender, _ipfsHash, _referrerAddress);
        
        emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress);
    }
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    // Job Management
    function postJob(string memory _jobDetailHash, string[] memory _descriptions, uint256[] memory _amounts) external nonReentrant {
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
        
        nativeContract.postJob(jobId, msg.sender, _jobDetailHash, _descriptions, _amounts);
        
        emit JobPosted(jobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(jobId, JobStatus.Open);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    // Application Management
    function applyToJob(string memory _jobId, string memory _appHash, string[] memory _descriptions, uint256[] memory _amounts) external nonReentrant {
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
        
        nativeContract.applyToJob(msg.sender, _jobId, _appHash, _descriptions, _amounts);
        
        emit JobApplication(_jobId, appId, msg.sender, _appHash);
    }
    
    function getApplication(string memory _jobId, uint256 _appId) public view returns (Application memory) {
        require(jobApplications[_jobId][_appId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_appId];
    }
    
    // Job startup
    function startJob(string memory _jobId, uint256 _appId, bool _useAppMilestones) external nonReentrant {
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
        
        nativeContract.startJob(msg.sender, _jobId, _appId, _useAppMilestones);
        
        emit JobStarted(_jobId, _appId, app.applicant, _useAppMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
        emit USDTEscrowed(_jobId, msg.sender, firstAmount);
    }
    
    function submitWork(string memory _jobId, string memory _submissionHash) external nonReentrant {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        require(jobs[_jobId].status == JobStatus.InProgress, "Job must be in progress");
        require(jobs[_jobId].selectedApplicant == msg.sender, "Only selected applicant can submit work");
        require(jobs[_jobId].currentMilestone <= jobs[_jobId].finalMilestones.length, "All milestones completed");
        
        jobs[_jobId].workSubmissions.push(_submissionHash);
        
        nativeContract.submitWork(msg.sender, _jobId, _submissionHash);
        
        emit WorkSubmitted(_jobId, msg.sender, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    function releasePayment(string memory _jobId) external nonReentrant {
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
        
        // Update local platform total and notify rewards contract
        totalPlatformPayments += amount;
        if (address(rewardsContract) != address(0)) {
            try rewardsContract.updateRewardsOnPayment(job.jobGiver, job.selectedApplicant, amount) {
                // Success
            } catch {
                // Fail silently to not break payment release
            }
        }
        
        if (job.currentMilestone == job.finalMilestones.length) {
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        nativeContract.releasePayment(msg.sender, _jobId, amount);
        
        emit PaymentReleased(_jobId, msg.sender, job.selectedApplicant, amount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
    }
    
    function lockNextMilestone(string memory _jobId) external nonReentrant {
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
        
        nativeContract.lockNextMilestone(msg.sender, _jobId, nextAmount);
        
        emit MilestoneLocked(_jobId, job.currentMilestone, nextAmount);
        emit USDTEscrowed(_jobId, msg.sender, nextAmount);
    }
    
    function releaseAndLockNext(string memory _jobId) external nonReentrant {
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
        
        // Update local platform total and notify rewards contract
        totalPlatformPayments += releaseAmount;
        if (address(rewardsContract) != address(0)) {
            try rewardsContract.updateRewardsOnPayment(job.jobGiver, job.selectedApplicant, releaseAmount) {
                // Success
            } catch {
                // Fail silently to not break payment release
            }
        }
        
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
        
        nativeContract.releasePaymentAndLockNext(msg.sender, _jobId, releaseAmount, nextAmount);
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, releaseAmount, nextAmount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
    }
    
    function rate(string memory _jobId, address _userToRate, uint256 _rating) external nonReentrant {
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
        
        nativeContract.rate(msg.sender, _jobId, _userToRate, _rating);
        
        emit UserRated(_jobId, msg.sender, _userToRate, _rating);
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
    
    function addPortfolio(string memory _portfolioHash) external nonReentrant {
        require(hasProfile[msg.sender], "Profile does not exist");
        require(bytes(_portfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        profiles[msg.sender].portfolioHashes.push(_portfolioHash);
        
        nativeContract.addPortfolio(msg.sender, _portfolioHash);
        
        emit PortfolioAdded(msg.sender, _portfolioHash);
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
}