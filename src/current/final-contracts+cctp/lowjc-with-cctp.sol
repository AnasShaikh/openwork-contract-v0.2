// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface ILayerZeroBridge {
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function sendToRewardsChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function sendToTwoChains(
        string memory _functionName,
        bytes memory _rewardsPayload,
        bytes memory _nativePayload,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external payable;
    
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
    
    function quoteRewardsChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
    
    function quoteTwoChains(
        bytes calldata _rewardsPayload,
        bytes calldata _nativePayload,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 nativeFee);
}

interface ITokenMessenger {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

interface IMessageTransmitter {
    function sendMessageWithCaller(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes32 destinationCaller,
        bytes calldata messageBody
    ) external returns (uint64 nonce);
}

contract CrossChainLocalOpenWorkJobContract is 
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    
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
    
    IERC20 public usdcToken;    
    uint32 public chainId;
    uint32 public nativeDomain; // CCTP domain for native chain
    ILayerZeroBridge public bridge;
    ITokenMessenger public tokenMessenger;
    IMessageTransmitter public messageTransmitter;
    address public nativeChainRecipient; // NOWJC contract address on native chain
    
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
    event USDCEscrowed(string indexed jobId, address indexed jobGiver, uint256 amount);
    event JobStatusChanged(string indexed jobId, JobStatus newStatus);
    event PaymentReleasedAndNextMilestoneLocked(string indexed jobId, uint256 releasedAmount, uint256 lockedAmount, uint256 milestone);
    event PlatformTotalUpdated(uint256 newTotal);
    event DisputeResolved(string indexed jobId, bool jobGiverWins, address winner, uint256 amount);
    event BridgeSet(address indexed bridge);
    event CCTPPaymentSent(string indexed jobId, uint64 cctpNonce, uint256 amount, uint256 milestone, string paymentType);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner, 
        address _usdcToken, 
        uint32 _chainId,
        address _bridge,
        address _cctpSender,
        uint32 _nativeDomain,
        address _nativeChainRecipient
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        usdcToken = IERC20(_usdcToken);
        chainId = _chainId;
        bridge = ILayerZeroBridge(_bridge);
        tokenMessenger = ITokenMessenger(_cctpSender);
        // messageTransmitter will be set separately via setMessageTransmitter
        nativeDomain = _nativeDomain;
        nativeChainRecipient = _nativeChainRecipient;
    }
    
function _authorizeUpgrade(address /* newImplementation */) internal view override {
    require(owner() == _msgSender() || address(bridge) == _msgSender(), "Unauthorized upgrade");
}

    // ==================== CCTP FAST TRANSFER (MAINNET PATTERN) ====================
    
    /**
     * @dev Fast transfer function following proven mainnet pattern
     * Matches the successful sendFast interface from mainnet logs
     */
    function sendFast(
        uint256 amount,
        uint32 destinationDomain, 
        bytes32 mintRecipient,
        uint256 maxFee
    ) external returns (uint64) {
        require(amount > 0, "Amount must be greater than 0");
        require(usdcToken.balanceOf(msg.sender) >= amount, "Insufficient USDC balance");
        require(usdcToken.allowance(msg.sender, address(this)) >= amount, "Insufficient USDC allowance");
        
        // Transfer USDC from sender to this contract
        usdcToken.transferFrom(msg.sender, address(this), amount);
        
        // Approve TokenMessenger to burn USDC
        usdcToken.approve(address(tokenMessenger), amount);
        
        // Execute CCTP depositForBurn (proven working pattern)
        uint64 nonce = tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdcToken)
        );
        
        return nonce;
    }

function upgradeFromDAO(address newImplementation) external {
    require(msg.sender == address(bridge), "Only bridge can upgrade");
    upgradeToAndCall(newImplementation, "");
}    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Bridge address cannot be zero");
        bridge = ILayerZeroBridge(_bridge);
        emit BridgeSet(_bridge);
    }
    
    function setAthenaClientContract(address _athenaClient) external onlyOwner {
        require(_athenaClient != address(0), "Athena client address cannot be zero");
        athenaClientContract = _athenaClient;
    }
    
    function setTokenMessenger(address _tokenMessenger) external onlyOwner {
        require(_tokenMessenger != address(0), "Token messenger cannot be zero");
        tokenMessenger = ITokenMessenger(_tokenMessenger);
    }
    
    function setMessageTransmitter(address _messageTransmitter) external onlyOwner {
        require(_messageTransmitter != address(0), "Message transmitter cannot be zero");
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
    }
    
    function setNativeChainRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Recipient cannot be zero");
        nativeChainRecipient = _recipient;
    }
    
    function setNativeDomain(uint32 _nativeDomain) external onlyOwner {
        nativeDomain = _nativeDomain;
    }
    
    // ==================== PROFILE MANAGEMENT ====================
    
  function createProfile(
    string memory _ipfsHash, 
    address _referrerAddress,
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
    
    // Send to native chain only
    bytes memory nativePayload = abi.encode("createProfile", msg.sender, _ipfsHash, _referrerAddress);
    bridge.sendToNativeChain{value: msg.value}("createProfile", nativePayload, _nativeOptions);
    
    emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress);
}
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    // ==================== JOB MANAGEMENT ====================
    
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
        bridge.sendToNativeChain{value: msg.value}("postJob", payload, _nativeOptions);
        
        emit JobPosted(jobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(jobId, JobStatus.Open);
    }
    
    function getJob(string memory _jobId) public view returns (Job memory) {
        require(bytes(jobs[_jobId].id).length != 0, "Job does not exist");
        return jobs[_jobId];
    }
    
    // ==================== APPLICATION MANAGEMENT ====================
    
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
        bridge.sendToNativeChain{value: msg.value}("applyToJob", payload, _nativeOptions);
        
        emit JobApplication(_jobId, appId, msg.sender, _appHash);
    }
    
    function getApplication(string memory _jobId, uint256 _appId) public view returns (Application memory) {
        require(jobApplications[_jobId][_appId].id != 0, "Application does not exist");
        return jobApplications[_jobId][_appId];
    }
    
    // ==================== JOB STARTUP WITH CCTP ====================
    
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
        
        // Send USDC via CCTP to native chain for escrow  
        require(usdcToken.balanceOf(msg.sender) >= firstAmount, "Insufficient USDC balance");
        require(usdcToken.allowance(msg.sender, address(this)) >= firstAmount, "Insufficient USDC allowance for contract");
        
        // Use CCTP Fast Transfer following proven mainnet pattern
        // Transfer USDC from job giver to this contract first
        usdcToken.transferFrom(msg.sender, address(this), firstAmount);
        
        // Approve TokenMessenger to burn USDC
        usdcToken.approve(address(tokenMessenger), firstAmount);
        
        // Execute CCTP Fast Transfer (proven working pattern)
        bytes32 recipient = bytes32(uint256(uint160(nativeChainRecipient)));
        uint64 cctpNonce = tokenMessenger.depositForBurn(
            firstAmount,
            nativeDomain,
            recipient,
            address(usdcToken)
        );
        
        job.currentLockedAmount = firstAmount;
        job.totalEscrowed += firstAmount;
        
        // Send job state to native chain
        bytes memory payload = abi.encode("startJob", msg.sender, _jobId, _appId, _useAppMilestones);
        bridge.sendToNativeChain{value: msg.value}("startJob", payload, _nativeOptions);
        
        emit JobStarted(_jobId, _appId, app.applicant, _useAppMilestones);
        emit JobStatusChanged(_jobId, JobStatus.InProgress);
        emit USDCEscrowed(_jobId, msg.sender, firstAmount);
        emit CCTPPaymentSent(_jobId, cctpNonce, firstAmount, 1, "startJob");
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
        bridge.sendToNativeChain{value: msg.value}("submitWork", payload, _nativeOptions);
        
        emit WorkSubmitted(_jobId, msg.sender, _submissionHash, jobs[_jobId].currentMilestone);
    }
    
    // ==================== PAYMENT FUNCTIONS (STATE ONLY) ====================
    
    function releasePayment(
        string memory _jobId,
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
        
        // Update local state (no actual USDC transfer here)
        job.totalPaid += amount;
        job.totalReleased += amount;
        job.currentLockedAmount = 0;
        
        // Update local platform total
        totalPlatformPayments += amount;
        
        if (job.currentMilestone == job.finalMilestones.length) {
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Send release request to native chain (actual USDC transfer happens there)
        bytes memory nativePayload = abi.encode("releasePayment", msg.sender, _jobId, amount);
        bridge.sendToNativeChain{value: msg.value}("releasePayment", nativePayload, _nativeOptions);
        
        emit PaymentReleased(_jobId, msg.sender, job.selectedApplicant, amount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
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
        
        // Send USDC via CCTP to native chain for next milestone
        require(usdcToken.balanceOf(msg.sender) >= nextAmount, "Insufficient USDC balance");
        require(usdcToken.allowance(msg.sender, address(tokenMessenger)) >= nextAmount, "Insufficient USDC allowance");
        
        // Transfer USDC from job giver to this contract
        usdcToken.transferFrom(msg.sender, address(this), nextAmount);
        
        // Approve TokenMessenger to burn USDC
        usdcToken.approve(address(tokenMessenger), nextAmount);
        
        // Burn USDC and send via CCTP to native chain escrow
        bytes32 recipient = bytes32(uint256(uint160(nativeChainRecipient)));
        uint64 cctpNonce = tokenMessenger.depositForBurn(
            nextAmount,
            nativeDomain,
            recipient,
            address(usdcToken)
        );
        
        job.currentLockedAmount = nextAmount;
        job.totalEscrowed += nextAmount;
        
        // Send state update to native chain
        bytes memory payload = abi.encode("lockNextMilestone", msg.sender, _jobId, nextAmount);
        bridge.sendToNativeChain{value: msg.value}("lockNextMilestone", payload, _nativeOptions);
        
        emit MilestoneLocked(_jobId, job.currentMilestone, nextAmount);
        emit USDCEscrowed(_jobId, msg.sender, nextAmount);
        emit CCTPPaymentSent(_jobId, cctpNonce, nextAmount, job.currentMilestone, "lockMilestone");
    }
    
    function releaseAndLockNext(
        string memory _jobId,
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
        
        // Update local state for released payment
        job.totalPaid += releaseAmount;
        job.totalReleased += releaseAmount;
        totalPlatformPayments += releaseAmount;
        
        job.currentMilestone += 1;
        
        uint256 nextAmount = 0;
        uint64 cctpNonce = 0;
        
        if (job.currentMilestone <= job.finalMilestones.length) {
            nextAmount = job.finalMilestones[job.currentMilestone - 1].amount;
            
            // Send USDC via CCTP for next milestone
            require(usdcToken.balanceOf(msg.sender) >= nextAmount, "Insufficient USDC balance");
            require(usdcToken.allowance(msg.sender, address(tokenMessenger)) >= nextAmount, "Insufficient USDC allowance");
            
            // Transfer USDC from job giver to this contract
            usdcToken.transferFrom(msg.sender, address(this), nextAmount);
            
            // Approve TokenMessenger to burn USDC
            usdcToken.approve(address(tokenMessenger), nextAmount);
            
            // Burn USDC and send via CCTP to native chain escrow
            bytes32 recipient = bytes32(uint256(uint160(nativeChainRecipient)));
            cctpNonce = tokenMessenger.depositForBurn(
                nextAmount,
                nativeDomain,
                recipient,
                address(usdcToken)
            );
            
            job.currentLockedAmount = nextAmount;
            job.totalEscrowed += nextAmount;
        } else {
            job.currentLockedAmount = 0;
            job.status = JobStatus.Completed;
            emit JobStatusChanged(_jobId, JobStatus.Completed);
        }
        
        // Send combined request to native chain
        bytes memory nativePayload = abi.encode("releasePaymentAndLockNext", msg.sender, _jobId, releaseAmount, nextAmount);
        bridge.sendToNativeChain{value: msg.value}("releaseAndLockNext", nativePayload, _nativeOptions);
        
        emit PaymentReleasedAndNextMilestoneLocked(_jobId, releaseAmount, nextAmount, job.currentMilestone);
        emit PlatformTotalUpdated(totalPlatformPayments);
        
        if (nextAmount > 0) {
            emit USDCEscrowed(_jobId, msg.sender, nextAmount);
            emit CCTPPaymentSent(_jobId, cctpNonce, nextAmount, job.currentMilestone, "lockMilestone");
        }
    }
    
    // ==================== RATING SYSTEM ====================
    
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
        bridge.sendToNativeChain{value: msg.value}("rate", payload, _nativeOptions);
        
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
    
    function addPortfolio(
        string memory _portfolioHash,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(hasProfile[msg.sender], "Profile does not exist");
        require(bytes(_portfolioHash).length > 0, "Portfolio hash cannot be empty");
        
        profiles[msg.sender].portfolioHashes.push(_portfolioHash);
        
        // Send to native chain
        bytes memory payload = abi.encode("addPortfolio", msg.sender, _portfolioHash);
        bridge.sendToNativeChain{value: msg.value}("addPortfolio", payload, _nativeOptions);
        
        emit PortfolioAdded(msg.sender, _portfolioHash);
    }
    
    // ==================== DISPUTE RESOLUTION ====================
    
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
            // Job giver wins - native chain will refund the escrowed amount
            winner = job.jobGiver;
        } else {
            // Job taker wins - native chain will release payment to them
            winner = job.selectedApplicant;
            
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

    // ==================== VIEW FUNCTIONS ====================
    
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
    
    // ==================== ADMIN FUNCTIONS ====================
    
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
    
    function emergencyWithdrawUSDC() external onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "No USDC balance to withdraw");
        usdcToken.transfer(owner(), balance);
    }

}