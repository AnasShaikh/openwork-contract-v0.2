// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";

interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external returns (uint64 nonce);
}

contract CCTPLayerZeroSender is OAppSender, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ==================== CONTRACTS ====================
    ITokenMessengerV2 public immutable tokenMessengerV2;
    IERC20 public immutable usdc;
    
    // ==================== CONFIG ====================
    uint32 public constant DEFAULT_MAX_FEE = 10000; // 0.01 USDC
    uint32 public constant SOFT_FINALITY = 1000;      // Fast Transfer
    
    // Destination chain configs
    uint32 public targetCctpDomain;    // CCTP domain for USDC
    uint32 public targetLzEid;         // LayerZero EID for data
    bytes32 public cctpRecipient;      // CCTP USDC recipient
    
    // ==================== TRACKING ====================
    struct CombinedTransfer {
        address sender;
        uint256 usdcAmount;
        string message;
        uint256[] numbers;
        uint64 cctpNonce;
        uint256 timestamp;
    }
    
    mapping(uint256 => CombinedTransfer) public transfers;
    uint256 public transferCount;
    
    // ==================== EVENTS ====================
    event CombinedTransferSent(
        uint256 indexed transferId,
        address indexed sender,
        uint256 usdcAmount,
        uint64 cctpNonce,
        string message,
        uint256[] numbers
    );
    
    constructor(
        address _endpoint,
        address _owner,
        address _tokenMessengerV2,
        address _usdc,
        uint32 _targetCctpDomain,
        uint32 _targetLzEid,
        bytes32 _cctpRecipient
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        tokenMessengerV2 = ITokenMessengerV2(_tokenMessengerV2);
        usdc = IERC20(_usdc);
        targetCctpDomain = _targetCctpDomain;
        targetLzEid = _targetLzEid;
        cctpRecipient = _cctpRecipient;
    }
    
    // Override the oAppVersion function
    function oAppVersion() public pure override returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }
    
    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }
    
    // ==================== MAIN FUNCTION ====================
    
    /**
     * @dev Send USDC via CCTP and data via LayerZero in one transaction
     * @param usdcAmount USDC amount to send (6 decimals)
     * @param message Text message to send via LayerZero
     * @param numbers Array of numbers to send via LayerZero
     * @param lzOptions LayerZero options for gas
     */
    function sendCombined(
        uint256 usdcAmount,
        string calldata message,
        uint256[] calldata numbers,
        bytes calldata lzOptions
    ) external payable nonReentrant {
        require(usdcAmount > 0, "USDC amount must be > 0");
        require(bytes(message).length > 0, "Message cannot be empty");
        
        uint256 transferId = ++transferCount;
        
        // 1. Send USDC via CCTP
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        usdc.approve(address(tokenMessengerV2), usdcAmount);
        
        uint64 cctpNonce = tokenMessengerV2.depositForBurn(
            usdcAmount,
            targetCctpDomain,
            cctpRecipient,
            address(usdc),
            bytes32(0), // destinationCaller - anyone can call
            DEFAULT_MAX_FEE,
            SOFT_FINALITY
        );
        
        // 2. Send data via LayerZero
        bytes memory lzPayload = abi.encode("combinedTransfer", transferId, msg.sender, message, numbers);
        
        // Calculate the exact LayerZero fee needed
        MessagingFee memory lzFee = _quote(targetLzEid, lzPayload, lzOptions, false);
        require(msg.value >= lzFee.nativeFee, "Insufficient LayerZero fee");
        
        _lzSend(
            targetLzEid,
            lzPayload,
            lzOptions,
            lzFee,
            payable(msg.sender)
        );
        
        // 3. Store transfer data
        transfers[transferId] = CombinedTransfer({
            sender: msg.sender,
            usdcAmount: usdcAmount,
            message: message,
            numbers: numbers,
            cctpNonce: cctpNonce,
            timestamp: block.timestamp
        });
        
        emit CombinedTransferSent(transferId, msg.sender, usdcAmount, cctpNonce, message, numbers);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getTransfer(uint256 transferId) external view returns (CombinedTransfer memory) {
        return transfers[transferId];
    }
    
    function quoteLzFee(
        string calldata message,
        uint256[] calldata numbers,
        bytes calldata lzOptions
    ) external view returns (uint256) {
        uint256 dummyTransferId = transferCount + 1;
        bytes memory payload = abi.encode("combinedTransfer", dummyTransferId, msg.sender, message, numbers);
        MessagingFee memory fee = _quote(targetLzEid, payload, lzOptions, false);
        return fee.nativeFee;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function updateTargets(
        uint32 _targetCctpDomain,
        uint32 _targetLzEid,
        bytes32 _cctpRecipient
    ) external onlyOwner {
        targetCctpDomain = _targetCctpDomain;
        targetLzEid = _targetLzEid;
        cctpRecipient = _cctpRecipient;
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
        
        uint256 usdcBalance = usdc.balanceOf(address(this));
        if (usdcBalance > 0) {
            usdc.safeTransfer(owner(), usdcBalance);
        }
    }
    
    receive() external payable {}
}