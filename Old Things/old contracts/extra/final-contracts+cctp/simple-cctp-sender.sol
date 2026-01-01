// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// CCTP V2 Interface for Arbitrum Sepolia - SIMPLE VERSION
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

contract SimpleCCTPSender is Ownable {
    using SafeERC20 for IERC20;
    
    // ==================== STATE VARIABLES ====================
    
    IERC20 public immutable usdtToken;
    ITokenMessengerV2 public immutable cctpTokenMessenger;
    address public immutable lowjcContract;
    bytes32 public immutable cctpReceiverBytes32;
    
    // CCTP configuration
    uint32 public constant DESTINATION_DOMAIN = 2; // OP Sepolia domain
    uint256 public immutable defaultMaxFee;
    uint32 public immutable defaultFinalityThreshold;
    
    // ==================== EVENTS ====================
    
    event FundsSent(string indexed jobId, uint256 amount, bytes32 recipient);
    
    constructor(
        address _owner,
        address _usdtToken,
        address _cctpTokenMessenger,
        address _lowjcContract,
        address _cctpReceiver,
        uint256 _defaultMaxFee,
        uint32 _defaultFinalityThreshold
    ) Ownable(_owner) {
        usdtToken = IERC20(_usdtToken);
        cctpTokenMessenger = ITokenMessengerV2(_cctpTokenMessenger);
        lowjcContract = _lowjcContract;
        cctpReceiverBytes32 = addressToBytes32(_cctpReceiver);
        defaultMaxFee = _defaultMaxFee;
        defaultFinalityThreshold = _defaultFinalityThreshold;
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
        
        // Execute CCTP burn - using proven pattern from working contracts
        cctpTokenMessenger.depositForBurn(
            _amount,
            DESTINATION_DOMAIN,
            cctpReceiverBytes32,
            address(usdtToken),
            bytes32(0), // Any caller can complete
            defaultMaxFee,
            defaultFinalityThreshold // Fast transfer (1000)
        );
        
        emit FundsSent(_jobId, _amount, cctpReceiverBytes32);
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
    
    // ==================== EMERGENCY FUNCTIONS ====================
    
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
}