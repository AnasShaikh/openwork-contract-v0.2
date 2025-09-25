// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCTPSender, CCTPBase} from "wormhole-solidity-sdk/CCTPBase.sol";
import {IERC20} from "wormhole-solidity-sdk/interfaces/IERC20.sol";

/**
 * @title MinimalWormholeCCTP
 * @notice Demonstrates USDC + message transfer in ONE atomic transaction
 * @dev This contract proves that Wormhole+CCTP can send USDC with payload atomically
 */
contract MinimalWormholeCCTP is CCTPSender {
    
    uint256 constant GAS_LIMIT = 200_000;
    
    // Events
    event USDCSentWithMessage(
        uint16 indexed targetChain, 
        address indexed recipient, 
        uint256 amount,
        string message,
        uint64 sequence
    );
    
    event USDCReceivedWithMessage(
        address indexed recipient, 
        uint256 amount,
        string message,
        uint16 sourceChain
    );
    
    constructor(
        address _wormholeRelayer,
        address _wormhole,
        address _circleMessageTransmitter,
        address _circleTokenMessenger,
        address _usdc
    ) 
        CCTPBase(
            _wormholeRelayer,
            _wormhole,
            _circleMessageTransmitter,
            _circleTokenMessenger,
            _usdc
        ) 
    {}
    
    /**
     * @notice Send USDC with a message in ONE atomic transaction
     * @param targetChain Wormhole chain ID of destination
     * @param targetContract Address of this contract on destination chain
     * @param recipient Who receives the USDC on destination
     * @param amount USDC amount to send (6 decimals)
     * @param message Custom message to send with USDC
     */
    function sendUSDCWithMessage(
        uint16 targetChain,
        address targetContract,
        address recipient,
        uint256 amount,
        string memory message
    ) external payable {
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient");
        require(bytes(message).length > 0, "Message cannot be empty");
        
        // Calculate required fee for cross-chain delivery
        uint256 cost = quoteCrossChainDeposit(targetChain);
        require(msg.value >= cost, "Insufficient fee for cross-chain delivery");
        
        // Transfer USDC from sender to this contract
        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        
        // Encode recipient and message as payload
        bytes memory payload = abi.encode(recipient, message);
        
        // 🎯 ONE TRANSACTION: Send USDC + message with automatic relay
        uint64 sequence = sendUSDCWithPayloadToEvm(
            targetChain,
            targetContract,
            payload,
            0,          // No receiver value needed
            GAS_LIMIT,  // Gas for destination execution
            amount      // USDC amount to transfer
        );
        
        emit USDCSentWithMessage(targetChain, recipient, amount, message, sequence);
    }
    
    /**
     * @notice Automatically called by Wormhole relayer on destination chain
     * @dev This completes the cross-chain transfer without requiring a second transaction
     */
    function receivePayloadAndUSDC(
        bytes memory payload,
        uint256 amountUSDCReceived,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal virtual {
        // Decode the payload
        (address recipient, string memory message) = abi.decode(payload, (address, string));
        
        // Transfer USDC to final recipient
        IERC20(USDC).transfer(recipient, amountUSDCReceived);
        
        emit USDCReceivedWithMessage(recipient, amountUSDCReceived, message, sourceChain);
    }
    
    /**
     * @notice Get the cost for cross-chain USDC transfer
     * @param targetChain Wormhole chain ID of destination
     * @return cost Required fee in native tokens (wei)
     */
    function quoteCrossChainDeposit(uint16 targetChain) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,          // No receiver value
            GAS_LIMIT   // Gas limit for destination
        );
    }
    
    /**
     * @notice Setup CCTP domain mapping (call after deployment)
     * @param chainId Wormhole chain ID
     * @param domain CCTP domain ID
     */
    function setupCCTPDomain(uint16 chainId, uint32 domain) external {
        setCCTPDomain(chainId, domain);
    }
    
    /**
     * @notice Test function to demonstrate the atomic transfer
     * @dev This shows exactly what your lowjc-final.sol would do
     */
    function demonstrateJobPayment(
        uint16 targetChain,
        address targetContract,
        address worker,
        uint256 payment,
        string memory jobId
    ) external payable {
        string memory jobMessage = string(abi.encodePacked("Job payment for: ", jobId));
        
        this.sendUSDCWithMessage{value: msg.value}(
            targetChain,
            targetContract,
            worker,
            payment,
            jobMessage
        );
    }
}