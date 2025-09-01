// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChainBHandler
 * @notice Simplified handler that receives messages and stores them
 * @dev Based on the working ArrayReceiver pattern
 */
contract ChainBHandler is OApp {
    /// @notice Stores the last received message
    string public lastMessage;
    
    /// @notice Stores processing timestamp
    uint256 public lastProcessedAt;
    
    /// @notice Simple state that changes with each message
    bool public toggleState;
    
    /// @notice Event emitted when a message is processed
    event MessageReceived(string message, uint32 srcEid, uint256 timestamp, bool newState);

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
        
        // Process the message on Chain B (different logic than Chain A)
        lastMessage = incomingMessage;
        lastProcessedAt = block.timestamp;
        toggleState = !toggleState; // Toggle state with each message
        
        emit MessageReceived(incomingMessage, _origin.srcEid, lastProcessedAt, toggleState);
    }

    /**
     * @notice Get current state information
     */
    function getState() external view returns (string memory message, uint256 timestamp, bool state) {
        return (lastMessage, lastProcessedAt, toggleState);
    }

    /**
     * @notice Reset the toggle state (for testing)
     */
    function resetState() external onlyOwner {
        toggleState = false;
    }
}