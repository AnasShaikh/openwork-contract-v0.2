// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMailbox {
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId);
    
    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external view returns (uint256 fee);
}

interface IInterchainGasPaymaster {
    function payForGas(
        bytes32 messageId,
        uint32 destinationDomain,
        uint256 gasAmount,
        address refundAddress
    ) external payable;
    
    function quoteGasPrice(uint32 destinationDomain)
        external
        view
        returns (uint256);
}

/**
 * @title HyperlaneSender
 * @dev Minimal contract to send messages from OP Sepolia to Arbitrum Sepolia
 */
contract HyperlaneSender {
    IMailbox public immutable mailbox;
    IInterchainGasPaymaster public immutable igp;
    
    // Hyperlane domain IDs
    uint32 public constant ARBITRUM_SEPOLIA_DOMAIN = 421614;
    
    // Events
    event MessageSent(bytes32 indexed messageId, uint256 newValue);
    
    constructor(address _mailbox, address _igp) {
        mailbox = IMailbox(_mailbox);
        igp = IInterchainGasPaymaster(_igp);
    }
    
    /**
     * @dev Send a message to update value on Arbitrum Sepolia
     * @param _receiver Address of receiver contract on Arbitrum Sepolia
     * @param _newValue New value to set
     */
    function sendMessage(address _receiver, uint256 _newValue) external payable {
        // Convert receiver address to bytes32
        bytes32 recipientAddress = bytes32(uint256(uint160(_receiver)));
        
        // Encode the message (function selector + new value)
        bytes memory messageBody = abi.encode(_newValue);
        
        // Send the message
        bytes32 messageId = mailbox.dispatch(
            ARBITRUM_SEPOLIA_DOMAIN,
            recipientAddress,
            messageBody
        );
        
        // Pay for gas on destination chain
        if (msg.value > 0) {
            igp.payForGas{value: msg.value}(
                messageId,
                ARBITRUM_SEPOLIA_DOMAIN,
                100000, // Gas limit for execution on destination
                msg.sender // Refund address
            );
        }
        
        emit MessageSent(messageId, _newValue);
    }
    
    /**
     * @dev Quote the cost to send a message
     * @param _receiver Address of receiver contract
     * @param _newValue Value to send
     */
    function quoteMessage(address _receiver, uint256 _newValue) 
        external 
        view 
        returns (uint256 fee) 
    {
        bytes32 recipientAddress = bytes32(uint256(uint160(_receiver)));
        bytes memory messageBody = abi.encode(_newValue);
        
        // Get dispatch fee
        uint256 dispatchFee = mailbox.quoteDispatch(
            ARBITRUM_SEPOLIA_DOMAIN,
            recipientAddress,
            messageBody
        );
        
        // Get gas price for destination
        uint256 gasPrice = igp.quoteGasPrice(ARBITRUM_SEPOLIA_DOMAIN);
        uint256 gasPayment = gasPrice * 100000; // 100k gas limit
        
        return dispatchFee + gasPayment;
    }
}