// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

contract CCTPv2Transceiver {
    ITokenMessengerV2 public immutable tokenMessenger;
    IMessageTransmitterV2 public immutable messageTransmitter;
    IERC20 public immutable usdc;
    
    event FastTransferSent(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee
    );
    
    event FastTransferReceived(
        bytes message,
        bytes attestation
    );

    constructor(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc
    ) {
        tokenMessenger = ITokenMessengerV2(_tokenMessenger);
        messageTransmitter = IMessageTransmitterV2(_messageTransmitter);
        usdc = IERC20(_usdc);
    }

    // Send USDC via CCTP V2 Fast Transfer
    function sendFast(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        uint256 maxFee
    ) external {
        // Transfer USDC from sender to contract
        usdc.transferFrom(msg.sender, address(this), amount);
        
        // Approve TokenMessenger to burn USDC
        usdc.approve(address(tokenMessenger), amount);
        
        // Perform fast transfer (minFinalityThreshold <= 1000 for fast)
        tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdc),
            bytes32(0), // Allow any caller on destination
            maxFee,
            1000 // Fast transfer threshold
        );
        
        emit FastTransferSent(amount, destinationDomain, mintRecipient, maxFee);
    }

    // Receive USDC via CCTP V2
    function receive(
        bytes calldata message,
        bytes calldata attestation
    ) external {
        messageTransmitter.receiveMessage(message, attestation);
        
        emit FastTransferReceived(message, attestation);
    }

    // Helper: Convert address to bytes32
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}