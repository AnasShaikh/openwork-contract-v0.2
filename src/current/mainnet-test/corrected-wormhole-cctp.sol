// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCTPSender, CCTPReceiver, CCTPBase} from "wormhole-solidity-sdk/CCTPBase.sol";
import {IERC20} from "wormhole-solidity-sdk/interfaces/IERC20.sol";

/**
 * @title CorrectedWormholeCCTP  
 * @notice Fixed payload encoding/decoding mismatch bug
 */
contract CorrectedWormholeCCTP is CCTPSender {
    
    uint256 constant GAS_LIMIT = 500_000; // Increased gas limit
    
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
     * @notice Send USDC with message in ONE atomic transaction
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
        
        uint256 cost = quoteCrossChainDeposit(targetChain);
        require(msg.value >= cost, "Insufficient fee for cross-chain delivery");
        
        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        
        // FIX: Encode amount first, then the user payload
        bytes memory userPayload = abi.encode(recipient, message);
        bytes memory payload = abi.encode(amount, userPayload);
        
        uint64 sequence = sendUSDCWithPayloadToEvm(
            targetChain,
            targetContract,
            payload,
            0,
            GAS_LIMIT,
            amount
        );
        
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

        // FIX: Now correctly decode the structured payload
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
        // FIX: Now correctly decode the user payload
        (address recipient, string memory message) = abi.decode(payload, (address, string));
        
        IERC20(USDC).transfer(recipient, amountUSDCReceived);
        
        emit USDCReceivedWithMessage(recipient, amountUSDCReceived, message, sourceChain);
    }
    
    function quoteCrossChainDeposit(uint16 targetChain) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }
    
    function setupCCTPDomain(uint16 chainId, uint32 domain) external {
        setCCTPDomain(chainId, domain);
    }
}