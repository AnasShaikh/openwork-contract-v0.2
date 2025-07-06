// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChainAHandler
 * @notice Simplified handler that receives messages and stores them
 * @dev Based on the working ArrayReceiver pattern
 */
contract ChainAHandler is OApp {
    /// @notice Stores the last received message
    string public lastMessage;
    
    /// @notice Counter for processed messages
    uint256 public messageCount;
    
    /// @notice Event emitted when a message is processed
    event MessageReceived(string message, uint32 srcEid, uint256 count);

    constructor(address _endpoint, address _owner) 
        OApp(_endpoint, _owner) 
        Ownable(_owner) 
    {}

    /**
     * @notice Handles incoming messages from other chains
     * @dev Simple receive and store - no automatic responses
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // _guid
        bytes calldata payload,
        address, // _executor
        bytes calldata // _extraData
    ) internal override {
        string memory incomingMessage = abi.decode(payload, (string));
        
        // Process the message on Chain A
        lastMessage = incomingMessage;
        messageCount++;
        
        emit MessageReceived(incomingMessage, _origin.srcEid, messageCount);
    }

    /**
     * @notice Get the current state
     */
    function getState() external view returns (string memory message, uint256 count) {
        return (lastMessage, messageCount);
    }

    /**
     * @notice Reset the counter (for testing)
     */
    function resetCounter() external onlyOwner {
        messageCount = 0;
    }
}