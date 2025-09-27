// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface ITokenMessenger {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

contract CCTPBurn {
    ITokenMessenger constant TOKEN_MESSENGER = ITokenMessenger(0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5);
    IERC20 constant USDC = IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
    uint32 constant OP_SEPOLIA_DOMAIN = 2;
    
    event MessageSent(bytes32 indexed messageHash, uint64 nonce);
    
    function sendToOpSepolia(uint256 amount, address recipient) external {
        // Transfer USDC from user
        USDC.transferFrom(msg.sender, address(this), amount);
        
        // Approve and burn
        USDC.approve(address(TOKEN_MESSENGER), amount);
        
        uint64 nonce = TOKEN_MESSENGER.depositForBurn(
            amount,
            OP_SEPOLIA_DOMAIN,
            bytes32(uint256(uint160(recipient))),
            address(USDC)
        );
        
        // The actual MessageSent event is emitted by MessageTransmitter
        // This is just for our tracking
        emit MessageSent(bytes32(uint256(nonce)), nonce);
    }
}