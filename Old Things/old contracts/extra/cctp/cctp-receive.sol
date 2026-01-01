// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMessageTransmitter {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool success);
}

contract CCTPMint {
    IMessageTransmitter constant MESSAGE_TRANSMITTER = 
        IMessageTransmitter(0x7865fAfC2db2093669d92c0F33AeEF291086BEFD);
    
    event USDCMinted(address indexed recipient, bytes32 messageHash);
    
    function mintUSDC(bytes calldata message, bytes calldata attestation) external {
        bool success = MESSAGE_TRANSMITTER.receiveMessage(message, attestation);
        require(success, "Mint failed");
        
        emit USDCMinted(msg.sender, keccak256(message));
    }
}