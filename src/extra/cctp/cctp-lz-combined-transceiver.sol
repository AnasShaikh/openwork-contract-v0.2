// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

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

interface IMessageTransmitterV2 {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external;
}

/**
 * @title CCTPLayerZeroCombinedTransceiver
 * @dev Combined CCTP V2 Fast Transfer + LayerZero messaging in a single transaction
 * Enables atomic cross-chain USDC transfers with accompanying data messages
 */
contract CCTPLayerZeroCombinedTransceiver is OAppSender, OAppReceiver {
    
    // ==================== CCTP V2 CONTRACTS ====================
    ITokenMessengerV2 public immutable tokenMessenger;
    IMessageTransmitterV2 public immutable messageTransmitter;
    IERC20 public immutable usdc;
    
    // ==================== DOMAIN MAPPINGS ====================
    struct ChainConfig {
        uint32 cctpDomain;
        uint32 lzEid;
        bool isActive;
    }
    
    mapping(uint32 => ChainConfig) public chainConfigs;
    uint32[] public supportedChains;
    
    // ==================== EVENTS ====================
    event CombinedTransferSent(
        uint256 amount,
        uint32 destinationDomain,
        uint32 destinationLzEid,
        bytes32 mintRecipient,
        uint256 maxFee,
        string message,
        uint256[] numbers
    );
    
    event CombinedTransferReceived(
        bytes cctpMessage,
        bytes cctpAttestation,
        string lzMessage,
        uint256[] lzNumbers
    );
    
    event LayerZeroMessageReceived(
        uint32 srcEid,
        bytes32 sender,
        string message,
        uint256[] numbers
    );

    constructor(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc,
        address _lzEndpoint,
        address _owner
    ) OAppCore(_lzEndpoint, _owner) Ownable(_owner) {
        tokenMessenger = ITokenMessengerV2(_tokenMessenger);
        messageTransmitter = IMessageTransmitterV2(_messageTransmitter);
        usdc = IERC20(_usdc);
    }

    // ==================== CONFIGURATION ====================
    
    /**
     * @dev Configure supported chain mappings (CCTP domain to LayerZero EID)
     */
    function setChainConfig(
        uint32 chainId,
        uint32 cctpDomain,
        uint32 lzEid,
        bool isActive
    ) external onlyOwner {
        chainConfigs[chainId] = ChainConfig(cctpDomain, lzEid, isActive);
        
        if (isActive && !_isChainSupported(chainId)) {
            supportedChains.push(chainId);
        }
    }
    
    function _isChainSupported(uint32 chainId) internal view returns (bool) {
        for (uint i = 0; i < supportedChains.length; i++) {
            if (supportedChains[i] == chainId) return true;
        }
        return false;
    }

    // ==================== COMBINED SEND FUNCTIONS ====================

    /**
     * @dev Send CCTP + LayerZero message atomically
     * @param destinationChainId Target chain identifier
     * @param usdcAmount USDC amount to send (6 decimals)
     * @param mintRecipient CCTP recipient address as bytes32
     * @param maxFee Maximum fee for CCTP fast transfer
     * @param message Text message to send via LayerZero
     * @param numbers Array of numbers to send via LayerZero
     * @param lzOptions LayerZero execution options
     */
    function sendCombined(
        uint32 destinationChainId,
        uint256 usdcAmount,
        bytes32 mintRecipient,
        uint256 maxFee,
        string calldata message,
        uint256[] calldata numbers,
        bytes calldata lzOptions
    ) external payable {
        ChainConfig memory config = chainConfigs[destinationChainId];
        require(config.isActive, "Chain not supported");
        require(usdcAmount > 0, "Amount must be greater than 0");
        require(bytes(message).length > 0, "Message cannot be empty");

        // Step 1: Execute CCTP Fast Transfer
        _executeCCTPTransfer(
            usdcAmount,
            config.cctpDomain,
            mintRecipient,
            maxFee
        );

        // Step 2: Send LayerZero Message
        _sendLayerZeroMessage(
            config.lzEid,
            message,
            numbers,
            lzOptions
        );

        emit CombinedTransferSent(
            usdcAmount,
            config.cctpDomain,
            config.lzEid,
            mintRecipient,
            maxFee,
            message,
            numbers
        );
    }

    /**
     * @dev Internal CCTP transfer execution
     */
    function _executeCCTPTransfer(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee
    ) internal {
        // Transfer USDC from sender to contract
        usdc.transferFrom(msg.sender, address(this), amount);
        
        // Approve TokenMessenger to burn USDC
        usdc.approve(address(tokenMessenger), amount);
        
        // Execute fast transfer (1000 = fast finality threshold)
        tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdc),
            bytes32(0), // Allow any caller on destination
            maxFee,
            1000 // Fast transfer threshold
        );
    }

    /**
     * @dev Internal LayerZero message sending
     */
    function _sendLayerZeroMessage(
        uint32 dstEid,
        string calldata message,
        uint256[] calldata numbers,
        bytes calldata options
    ) internal {
        // Encode message data
        bytes memory payload = abi.encode(message, numbers);
        
        // Send LayerZero message
        _lzSend(
            dstEid,
            payload,
            options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
    }

    // ==================== COMBINED RECEIVE FUNCTIONS ====================

    /**
     * @dev Receive CCTP message and complete transfer
     */
    function receiveCCTP(
        bytes calldata message,
        bytes calldata attestation
    ) external {
        messageTransmitter.receiveMessage(message, attestation);
        
        emit CombinedTransferReceived(message, attestation, "", new uint256[](0));
    }

    /**
     * @dev LayerZero message receiver - called automatically by LZ endpoint
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        // Decode LayerZero message
        (string memory message, uint256[] memory numbers) = abi.decode(payload, (string, uint256[]));
        
        emit LayerZeroMessageReceived(_origin.srcEid, _origin.sender, message, numbers);
    }

    // ==================== QUOTE FUNCTIONS ====================

    /**
     * @dev Get LayerZero messaging fee quote
     */
    function quoteLzFee(
        uint32 destinationChainId,
        string calldata message,
        uint256[] calldata numbers,
        bytes calldata options
    ) external view returns (uint256 fee) {
        ChainConfig memory config = chainConfigs[destinationChainId];
        require(config.isActive, "Chain not supported");
        
        bytes memory payload = abi.encode(message, numbers);
        MessagingFee memory msgFee = _quote(config.lzEid, payload, options, false);
        return msgFee.nativeFee;
    }

    /**
     * @dev Get combined fees (CCTP is paid separately in maxFee parameter)
     */
    function quoteCombinedFee(
        uint32 destinationChainId,
        string calldata message,
        uint256[] calldata numbers,
        bytes calldata options
    ) external view returns (uint256 lzFee) {
        return this.quoteLzFee(destinationChainId, message, numbers, options);
    }

    // ==================== UTILITY FUNCTIONS ====================

    /**
     * @dev Convert address to bytes32 for CCTP
     */
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @dev Convert bytes32 to address
     */
    function bytes32ToAddress(bytes32 b) external pure returns (address) {
        return address(uint160(uint256(b)));
    }

    /**
     * @dev Get supported chains list
     */
    function getSupportedChains() external view returns (uint32[] memory) {
        return supportedChains;
    }

    /**
     * @dev Get chain configuration
     */
    function getChainConfig(uint32 chainId) external view returns (ChainConfig memory) {
        return chainConfigs[chainId];
    }

    // ==================== OAPP OVERRIDES ====================
    
    /**
     * @dev Override version conflict between OAppSender and OAppReceiver
     */
    function oAppVersion() 
        public 
        pure 
        override(OAppReceiver, OAppSender) 
        returns (uint64 senderVersion, uint64 receiverVersion) 
    {
        return (1, 1);
    }

    // Allow contract to receive ETH for LayerZero fees
    receive() external payable {}
}