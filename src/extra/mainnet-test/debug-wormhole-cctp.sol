// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCTPSender, CCTPReceiver, CCTPBase} from "wormhole-solidity-sdk/CCTPBase.sol";
import {IERC20} from "wormhole-solidity-sdk/interfaces/IERC20.sol";

/**
 * @title DebugWormholeCCTP  
 * @notice Debug version with higher gas limits and detailed events
 */
contract DebugWormholeCCTP is CCTPSender {
    
    uint256 constant GAS_LIMIT = 500_000; // INCREASED from 250_000
    
    event DebugTransferStart(address from, uint256 amount, uint16 targetChain);
    event DebugUSDCApproval(uint256 amount);
    event DebugPayloadCreated(bytes payload);
    event DebugWormholeCall(uint16 targetChain, address targetContract, uint256 gasLimit);
    event DebugTransferComplete(uint64 sequence);
    
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
     * @notice Send USDC with message - DEBUG VERSION
     */
    function sendUSDCWithMessage(
        uint16 targetChain,
        address targetContract,
        address recipient,
        uint256 amount,
        string memory message
    ) external payable {
        emit DebugTransferStart(msg.sender, amount, targetChain);
        
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient");
        
        uint256 cost = quoteCrossChainDeposit(targetChain);
        require(msg.value >= cost, "Insufficient fee for cross-chain delivery");
        
        // Transfer USDC and emit debug event
        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        emit DebugUSDCApproval(amount);
        
        // Create payload and emit debug event
        bytes memory payload = abi.encode(recipient, message);
        emit DebugPayloadCreated(payload);
        
        // Debug the Wormhole call
        emit DebugWormholeCall(targetChain, targetContract, GAS_LIMIT);
        
        // Make the Wormhole call
        uint64 sequence = sendUSDCWithPayloadToEvm(
            targetChain,
            targetContract,
            payload,
            0,
            GAS_LIMIT, // Using higher gas limit
            amount
        );
        
        emit DebugTransferComplete(sequence);
        emit USDCSentWithMessage(targetChain, recipient, amount, message, sequence);
    }
    
    // Wormhole relayer calls this
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable {
        require(
            additionalMessages.length <= 1,
            "CCTP: At most one Message is supported"
        );

        uint256 amountUSDCReceived;
        if (additionalMessages.length == 1) {
            amountUSDCReceived = redeemUSDC(additionalMessages[0]);
        }

        (uint256 amount, bytes memory userPayload) = abi.decode(
            payload,
            (uint256, bytes)
        );

        require(amount == amountUSDCReceived, "Wrong amount received");

        receivePayloadAndUSDC(
            userPayload,
            amountUSDCReceived,
            sourceAddress,
            sourceChain,
            deliveryHash
        );
    }
    
    function redeemUSDC(
        bytes memory cctpMessage
    ) internal returns (uint256 amount) {
        (bytes memory message, bytes memory signature) = abi.decode(
            cctpMessage,
            (bytes, bytes)
        );
        uint256 beforeBalance = IERC20(USDC).balanceOf(address(this));
        circleMessageTransmitter.receiveMessage(message, signature);
        return IERC20(USDC).balanceOf(address(this)) - beforeBalance;
    }
    
    function receivePayloadAndUSDC(
        bytes memory payload,
        uint256 amountUSDCReceived,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal {
        (address recipient, string memory message) = abi.decode(payload, (address, string));
        
        IERC20(USDC).transfer(recipient, amountUSDCReceived);
        
        emit USDCReceivedWithMessage(recipient, amountUSDCReceived, message, sourceChain);
    }
    
    function quoteCrossChainDeposit(uint16 targetChain) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT // Using higher gas limit
        );
    }
    
    function setupCCTPDomain(uint16 chainId, uint32 domain) external {
        setCCTPDomain(chainId, domain);
    }
    
    // Simple test function without external call
    function testTransfer(
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