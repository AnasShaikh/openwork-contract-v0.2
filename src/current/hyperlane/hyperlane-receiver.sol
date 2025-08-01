// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMailbox {
    function localDomain() external view returns (uint32);
}

/**
 * @title HyperlaneReceiver
 * @dev Minimal contract to receive messages from OP Sepolia via Hyperlane
 */
contract HyperlaneReceiver {
    IMailbox public immutable mailbox;
    
    // Hyperlane domain IDs
    uint32 public constant OP_SEPOLIA_DOMAIN = 11155420;
    
    // State variable that will be updated
    uint256 public storedValue;
    address public lastSender;
    uint32 public lastOriginDomain;
    
    // Events
    event ValueUpdated(uint256 newValue, address sender, uint32 originDomain);
    event MessageReceived(uint32 origin, bytes32 sender, bytes message);
    
    // Errors
    error UnauthorizedMailbox();
    error UnauthorizedOrigin();
    
    modifier onlyMailbox() {
        if (msg.sender != address(mailbox)) revert UnauthorizedMailbox();
        _;
    }
    
    modifier onlyFromOpSepolia(uint32 _origin) {
        if (_origin != OP_SEPOLIA_DOMAIN) revert UnauthorizedOrigin();
        _;
    }
    
    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }
    
    /**
     * @dev Handle incoming messages from Hyperlane
     * @param _origin Domain ID of the origin chain
     * @param _sender Address of the sender (as bytes32)
     * @param _message The message body
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external onlyMailbox onlyFromOpSepolia(_origin) {
        
        emit MessageReceived(_origin, _sender, _message);
        
        // Decode the message to get the new value
        uint256 newValue = abi.decode(_message, (uint256));
        
        // Update the stored value
        storedValue = newValue;
        lastSender = address(uint160(uint256(_sender)));
        lastOriginDomain = _origin;
        
        emit ValueUpdated(newValue, lastSender, _origin);
    }
    
    /**
     * @dev Get current stored value
     */
    function getValue() external view returns (uint256) {
        return storedValue;
    }
    
    /**
     * @dev Get last message info
     */
    function getLastMessageInfo() external view returns (
        uint256 value,
        address sender,
        uint32 originDomain
    ) {
        return (storedValue, lastSender, lastOriginDomain);
    }
}