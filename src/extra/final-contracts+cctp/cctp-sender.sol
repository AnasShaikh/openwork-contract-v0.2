// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// CCTP V2 Interface for Arbitrum Sepolia
interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;
}

contract CCTPSender is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    
    // ==================== STATE VARIABLES ====================
    
    IERC20 public usdtToken;
    ITokenMessengerV2 public cctpTokenMessenger;
    address public lowjcContract;
    bytes32 public cctpReceiverBytes32;
    
    // CCTP configuration
    uint32 public constant DESTINATION_DOMAIN = 2; // OP Sepolia domain
    uint256 public defaultMaxFee;
    uint32 public defaultFinalityThreshold;
    
    // ==================== EVENTS ====================
    
    event FundsSent(string indexed jobId, uint256 amount, bytes32 recipient);
    event CCTPConfigUpdated(address tokenMessenger, bytes32 receiver, uint256 maxFee, uint32 finality);
    event LowjcContractUpdated(address indexed oldContract, address indexed newContract);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner,
        address _usdtToken,
        address _cctpTokenMessenger,
        address _lowjcContract,
        address _cctpReceiver,
        uint256 _defaultMaxFee,
        uint32 _defaultFinalityThreshold
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        usdtToken = IERC20(_usdtToken);
        cctpTokenMessenger = ITokenMessengerV2(_cctpTokenMessenger);
        lowjcContract = _lowjcContract;
        cctpReceiverBytes32 = addressToBytes32(_cctpReceiver);
        defaultMaxFee = _defaultMaxFee;
        defaultFinalityThreshold = _defaultFinalityThreshold;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender(), "Unauthorized upgrade");
    }
    
    // ==================== MAIN FUNCTIONS ====================
    
    /**
     * @dev Send funds via CCTP to destination chain
     * Called by lowjc contract when job milestones are funded
     */
    function sendFunds(string memory _jobId, uint256 _amount) external {
        require(msg.sender == lowjcContract, "Only lowjc contract can call");
        require(_amount > 0, "Amount must be greater than zero");
        
        // Check USDT balance (should have been transferred by lowjc)
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance >= _amount, "Insufficient USDT balance");
        
        // Approve CCTP TokenMessenger
        usdtToken.approve(address(cctpTokenMessenger), _amount);
        
        // Execute CCTP burn
        cctpTokenMessenger.depositForBurn(
            _amount,
            DESTINATION_DOMAIN,
            cctpReceiverBytes32,
            address(usdtToken),
            bytes32(0), // Any caller can complete
            defaultMaxFee,
            defaultFinalityThreshold
        );
        
        emit FundsSent(_jobId, _amount, cctpReceiverBytes32);
    }
    
    /**
     * @dev Send funds with custom CCTP parameters
     */
    function sendFundsWithParams(
        string memory _jobId, 
        uint256 _amount,
        uint256 _maxFee,
        uint32 _finalityThreshold
    ) external {
        require(msg.sender == lowjcContract, "Only lowjc contract can call");
        require(_amount > 0, "Amount must be greater than zero");
        
        // Check USDT balance
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance >= _amount, "Insufficient USDT balance");
        
        // Approve CCTP TokenMessenger
        usdtToken.approve(address(cctpTokenMessenger), _amount);
        
        // Execute CCTP burn with custom parameters
        cctpTokenMessenger.depositForBurn(
            _amount,
            DESTINATION_DOMAIN,
            cctpReceiverBytes32,
            address(usdtToken),
            bytes32(0),
            _maxFee,
            _finalityThreshold
        );
        
        emit FundsSent(_jobId, _amount, cctpReceiverBytes32);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setLowjcContract(address _lowjcContract) external onlyOwner {
        require(_lowjcContract != address(0), "Invalid lowjc contract address");
        address oldContract = lowjcContract;
        lowjcContract = _lowjcContract;
        emit LowjcContractUpdated(oldContract, _lowjcContract);
    }
    
    function setCCTPConfig(
        address _tokenMessenger,
        address _receiver,
        uint256 _maxFee,
        uint32 _finalityThreshold
    ) external onlyOwner {
        require(_tokenMessenger != address(0), "Invalid token messenger address");
        require(_receiver != address(0), "Invalid receiver address");
        
        cctpTokenMessenger = ITokenMessengerV2(_tokenMessenger);
        cctpReceiverBytes32 = addressToBytes32(_receiver);
        defaultMaxFee = _maxFee;
        defaultFinalityThreshold = _finalityThreshold;
        
        emit CCTPConfigUpdated(_tokenMessenger, cctpReceiverBytes32, _maxFee, _finalityThreshold);
    }
    
    function emergencyWithdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT balance to withdraw");
        usdtToken.safeTransfer(owner(), balance);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    function addressToBytes32(address addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
    
    function bytes32ToAddress(bytes32 _bytes32) public pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getUSDTBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
    
    function getCCTPConfig() external view returns (
        address tokenMessenger,
        bytes32 receiver,
        uint32 destinationDomain,
        uint256 maxFee,
        uint32 finalityThreshold
    ) {
        return (
            address(cctpTokenMessenger),
            cctpReceiverBytes32,
            DESTINATION_DOMAIN,
            defaultMaxFee,
            defaultFinalityThreshold
        );
    }
}