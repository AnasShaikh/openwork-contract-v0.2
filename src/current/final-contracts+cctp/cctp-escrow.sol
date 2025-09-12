// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// CCTP Hook Receiver Interface
interface ICCTPHookReceiver {
    function onCCTPReceive(
        bytes32 sender,
        uint256 amount,
        bytes calldata hookData
    ) external returns (bool);
}

// Interface for the main job contract
interface INativeJobContract {
    function jobExists(string memory jobId) external view returns (bool);
    function getJobGiver(string memory jobId) external view returns (address);
    function getJobWorker(string memory jobId) external view returns (address);
    function notifyEscrowReceived(string memory jobId, address sender, uint256 amount, uint256 milestone) external;
    function updateJobPaidAmount(string memory jobId, uint256 amount) external;
}

contract CCTPEscrowManager is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ICCTPHookReceiver
{
    using SafeERC20 for IERC20;
    
    // ==================== STATE VARIABLES ====================
    
    // USDC token for escrow
    IERC20 public usdcToken;
    
    // CCTP integration
    address public messageTransmitter; // CCTP MessageTransmitter contract
    mapping(address => bool) public authorizedCCTPSenders; // Authorized local chain CCTP senders
    
    // Main job contract reference
    INativeJobContract public jobContract;
    
    // Authorized contracts that can release funds
    mapping(address => bool) public authorizedReleaseContracts;
    
    // Job escrow tracking
    mapping(string => uint256) public jobEscrowBalance; // jobId => total USDC escrowed
    mapping(string => uint256) public jobReleasedBalance; // jobId => total USDC released
    mapping(string => uint256) public jobCurrentLockedAmount; // jobId => current milestone locked amount
    
    // Platform escrow totals
    uint256 public totalEscrowedUSDC;
    uint256 public totalReleasedUSDC;

    // ==================== EVENTS ====================
    
    event CCTPPaymentReceived(string indexed jobId, address indexed sender, uint256 amount, uint256 milestone, string paymentType);
    event USDCEscrowed(string indexed jobId, address indexed jobGiver, uint256 amount, uint256 totalEscrowed);
    event USDCReleased(string indexed jobId, address indexed recipient, uint256 amount, string releaseType);
    event CCTPSenderAuthorized(address indexed sender, bool authorized);
    event DisputeResolved(string indexed jobId, bool jobGiverWins, address indexed winner, uint256 amount);
    event ReleaseContractAuthorized(address indexed contractAddress, bool authorized);
    event JobContractUpdated(address indexed oldContract, address indexed newContract);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _jobContract,
        address _usdcToken,
        address _messageTransmitter
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        jobContract = INativeJobContract(_jobContract);
        usdcToken = IERC20(_usdcToken);
        messageTransmitter = _messageTransmitter;
    }

    // ==================== CCTP INTEGRATION ====================
    
    /**
     * @dev CCTP Hook receiver - automatically called when USDC is received via CCTP
     */
    function onCCTPReceive(
        bytes32 sender,
        uint256 amount,
        bytes calldata hookData
    ) external override returns (bool) {
        require(msg.sender == messageTransmitter, "Only MessageTransmitter can call");
        
        address senderAddress = address(uint160(uint256(sender)));
        require(authorizedCCTPSenders[senderAddress], "Unauthorized CCTP sender");
        
        // Decode hook data to get job information
        (string memory hookMessage, uint256[] memory hookNumbers) = abi.decode(hookData, (string, uint256[]));
        
        // Parse hook message to determine action and jobId
        if (bytes(hookMessage).length > 0) {
            _processCCTPPayment(senderAddress, amount, hookMessage, hookNumbers);
        }
        
        return true;
    }
    
    /**
     * @dev Process CCTP payment based on hook data
     */
    function _processCCTPPayment(
        address sender,
        uint256 amount,
        string memory hookMessage,
        uint256[] memory hookNumbers
    ) internal {
        // Extract job ID from hook message
        string memory jobId;
        string memory action;
        
        if (_startsWith(hookMessage, "startJob:")) {
            action = "startJob";
            jobId = _substring(hookMessage, 9); // Remove "startJob:" prefix
        } else if (_startsWith(hookMessage, "lockMilestone:")) {
            action = "lockMilestone";
            jobId = _substring(hookMessage, 14); // Remove "lockMilestone:" prefix
        } else {
            revert("Invalid hook message format");
        }
        
        require(jobContract.jobExists(jobId), "Job does not exist");
        
        uint256 milestone = hookNumbers.length > 0 ? hookNumbers[0] : 1;
        uint256 expectedAmount = hookNumbers.length > 1 ? hookNumbers[1] : amount;
        
        require(amount == expectedAmount, "Amount mismatch");
        
        // Update escrow tracking
        jobEscrowBalance[jobId] += amount;
        jobCurrentLockedAmount[jobId] = amount;
        totalEscrowedUSDC += amount;
        
        // Notify main job contract
        jobContract.notifyEscrowReceived(jobId, sender, amount, milestone);
        
        emit CCTPPaymentReceived(jobId, sender, amount, milestone, action);
        emit USDCEscrowed(jobId, sender, amount, jobEscrowBalance[jobId]);
    }

    // ==================== PAYMENT RELEASE FUNCTIONS ====================
    
    /**
     * @dev Release payment to worker
     */
    function releasePayment(string memory _jobId, uint256 _amount) external {
        require(authorizedReleaseContracts[msg.sender], "Not authorized to release funds");
        require(jobCurrentLockedAmount[_jobId] >= _amount, "Insufficient locked amount");
        
        address worker = jobContract.getJobWorker(_jobId);
        require(worker != address(0), "No worker assigned");
        
        // Transfer USDC to worker
        usdcToken.safeTransfer(worker, _amount);
        
        // Update tracking
        jobCurrentLockedAmount[_jobId] -= _amount;
        jobReleasedBalance[_jobId] += _amount;
        totalReleasedUSDC += _amount;
        
        // Notify job contract of payment
        jobContract.updateJobPaidAmount(_jobId, _amount);
        
        emit USDCReleased(_jobId, worker, _amount, "payment");
    }
    
    /**
     * @dev Release payment and prepare for next milestone
     */
    function releasePaymentAndLockNext(string memory _jobId, uint256 _releasedAmount, uint256 _lockedAmount) external {
        require(authorizedReleaseContracts[msg.sender], "Not authorized to release funds");
        require(jobCurrentLockedAmount[_jobId] >= _releasedAmount, "Insufficient locked amount");
        
        address worker = jobContract.getJobWorker(_jobId);
        require(worker != address(0), "No worker assigned");
        
        // Release current payment
        if (_releasedAmount > 0) {
            usdcToken.safeTransfer(worker, _releasedAmount);
            
            jobCurrentLockedAmount[_jobId] -= _releasedAmount;
            jobReleasedBalance[_jobId] += _releasedAmount;
            totalReleasedUSDC += _releasedAmount;
            
            // Notify job contract of payment
            jobContract.updateJobPaidAmount(_jobId, _releasedAmount);
            
            emit USDCReleased(_jobId, worker, _releasedAmount, "payment");
        }
        
        // Note: _lockedAmount will be added when CCTP payment arrives
    }

    // ==================== DISPUTE RESOLUTION ====================
    
    /**
     * @dev Resolve dispute by releasing funds to winner
     */
    function resolveDispute(string memory _jobId, bool _jobGiverWins) external {
        require(authorizedReleaseContracts[msg.sender], "Not authorized to resolve disputes");
        require(jobContract.jobExists(_jobId), "Job does not exist");
        require(jobCurrentLockedAmount[_jobId] > 0, "No funds escrowed");
        
        address winner;
        uint256 amount = jobCurrentLockedAmount[_jobId];
        
        if (_jobGiverWins) {
            // Job giver wins - refund the escrowed amount
            winner = jobContract.getJobGiver(_jobId);
            usdcToken.safeTransfer(winner, amount);
            emit USDCReleased(_jobId, winner, amount, "dispute_refund");
        } else {
            // Job taker wins - release payment to them
            winner = jobContract.getJobWorker(_jobId);
            usdcToken.safeTransfer(winner, amount);
            
            // Notify job contract of payment since this counts as a payment
            jobContract.updateJobPaidAmount(_jobId, amount);
            emit USDCReleased(_jobId, winner, amount, "dispute_release");
        }
        
        // Clear escrowed amount
        jobCurrentLockedAmount[_jobId] = 0;
        jobReleasedBalance[_jobId] += amount;
        totalReleasedUSDC += amount;
        
        emit DisputeResolved(_jobId, _jobGiverWins, winner, amount);
    }

    // ==================== UTILITY FUNCTIONS ====================
    
    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        
        if (strBytes.length < prefixBytes.length) return false;
        
        for (uint i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }
    
    function _substring(string memory str, uint startIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(startIndex < strBytes.length, "Start index out of bounds");
        
        bytes memory result = new bytes(strBytes.length - startIndex);
        for (uint i = startIndex; i < strBytes.length; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    // ==================== ADMIN FUNCTIONS ====================
    
    function authorizeCCTPSender(address sender, bool authorized) external onlyOwner {
        authorizedCCTPSenders[sender] = authorized;
        emit CCTPSenderAuthorized(sender, authorized);
    }
    
    function authorizeReleaseContract(address contractAddress, bool authorized) external onlyOwner {
        authorizedReleaseContracts[contractAddress] = authorized;
        emit ReleaseContractAuthorized(contractAddress, authorized);
    }
    
    function setMessageTransmitter(address _messageTransmitter) external onlyOwner {
        require(_messageTransmitter != address(0), "Invalid address");
        messageTransmitter = _messageTransmitter;
    }
    
    function setUSDCToken(address _usdcToken) external onlyOwner {
        require(_usdcToken != address(0), "Invalid address");
        usdcToken = IERC20(_usdcToken);
    }
    
    function setJobContract(address _jobContract) external onlyOwner {
        require(_jobContract != address(0), "Invalid address");
        address oldContract = address(jobContract);
        jobContract = INativeJobContract(_jobContract);
        emit JobContractUpdated(oldContract, _jobContract);
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender(), "Unauthorized upgrade");
    }

    // ==================== VIEW FUNCTIONS ====================
    
    function getJobEscrowBalance(string memory _jobId) external view returns (uint256 escrowed, uint256 released, uint256 currentLocked) {
        escrowed = jobEscrowBalance[_jobId];
        released = jobReleasedBalance[_jobId];
        currentLocked = jobCurrentLockedAmount[_jobId];
    }
    
    function getTotalEscrowStats() external view returns (uint256 totalEscrowed, uint256 totalReleased, uint256 totalLocked) {
        totalEscrowed = totalEscrowedUSDC;
        totalReleased = totalReleasedUSDC;
        totalLocked = totalEscrowed - totalReleased;
    }
    
    function getUSDCBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
    function emergencyWithdrawUSDC() external onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "No USDC balance to withdraw");
        usdcToken.safeTransfer(owner(), balance);
    }
    
    function emergencyWithdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}