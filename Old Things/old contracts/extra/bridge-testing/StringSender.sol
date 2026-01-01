// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StringSender is OAppSender {
    
    /// @notice Emitted when a message is sent to another chain.
    event MessageSent(string message, uint32 dstEid);
    
    /// @notice Emitted when a batch message is sent to multiple chains.
    event BatchMessageSent(string message, uint32[] dstEids);
    
    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) Ownable(_owner) {}

    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }

    // Original single-chain function
    function sendString(
        uint32 _dstEid, 
        string calldata _message, 
        bytes calldata _options
    ) external payable {
        bytes memory payload = abi.encode(_message);
        _lzSend(
            _dstEid,
            payload, 
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit MessageSent(_message, _dstEid);
    }

    // Improved multi-chain function using BatchSendMock pattern
    function sendStringToMultipleChains(
        uint32[] calldata _dstEids,
        string calldata _message,
        bytes[] calldata _options
    ) external payable {
        require(_dstEids.length == _options.length, "Arrays length mismatch");
        require(_dstEids.length > 0, "No destinations provided");
        
        bytes memory payload = abi.encode(_message);
        
        // Calculate total fees upfront (fail-fast pattern)
        MessagingFee memory totalFee = quoteMultiple(_dstEids, _message, _options, false);
        require(msg.value >= totalFee.nativeFee, "Insufficient fee provided");
        
        uint256 totalNativeFeeUsed = 0;
        uint256 remainingValue = msg.value;
        
        // Send to all destination chains
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], false);
            
            totalNativeFeeUsed += fee.nativeFee;
            remainingValue -= fee.nativeFee;
            
            // Granular fee tracking per destination
            require(remainingValue >= 0, "Insufficient fee for this destination");
            
            _lzSend(
                _dstEids[i],
                payload, 
                _options[i],
                fee,
                payable(msg.sender)
            );
            
            emit MessageSent(_message, _dstEids[i]);
        }
        
        emit BatchMessageSent(_message, _dstEids);
    }

    // Convenience function for exactly two chains
    function sendStringToTwoChains(
        uint32 _dstEid1,
        uint32 _dstEid2,
        string calldata _message,
        bytes calldata _options1,
        bytes calldata _options2
    ) external payable {
        uint32[] memory dstEids = new uint32[](2);
        bytes[] memory options = new bytes[](2);
        
        dstEids[0] = _dstEid1;
        dstEids[1] = _dstEid2;
        options[0] = _options1;
        options[1] = _options2;
        
        // Use the main multi-chain function
        this.sendStringToMultipleChains{value: msg.value}(dstEids, _message, options);
    }

    // Internal function to calculate total fees for multiple destinations
    function quoteMultiple(
        uint32[] memory _dstEids,
        string memory _message,
        bytes[] memory _options,
        bool _payInLzToken
    ) internal view returns (MessagingFee memory totalFee) {
        bytes memory payload = abi.encode(_message);
        
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], _payInLzToken);
            totalFee.nativeFee += fee.nativeFee;
            totalFee.lzTokenFee += fee.lzTokenFee;
        }
    }

    // Original quote function
    function quote(
        uint32 _dstEid, 
        string calldata _message, 
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(_message);
        MessagingFee memory fee = _quote(_dstEid, payload, _options, false);
        return fee.nativeFee;
    }

    // Quote function for two chains
    function quoteTwoChains(
        uint32 _dstEid1,
        uint32 _dstEid2,
        string calldata _message,
        bytes calldata _options1,
        bytes calldata _options2
    ) external view returns (uint256 totalFee, uint256 fee1, uint256 fee2) {
        bytes memory payload = abi.encode(_message);
        
        MessagingFee memory msgFee1 = _quote(_dstEid1, payload, _options1, false);
        MessagingFee memory msgFee2 = _quote(_dstEid2, payload, _options2, false);
        
        fee1 = msgFee1.nativeFee;
        fee2 = msgFee2.nativeFee;
        totalFee = fee1 + fee2;
    }

    // Quote function for multiple chains
    function quoteMultipleChains(
        uint32[] calldata _dstEids,
        string calldata _message,
        bytes[] calldata _options
    ) external view returns (uint256 totalFee, uint256[] memory fees) {
        require(_dstEids.length == _options.length, "Arrays length mismatch");
        
        bytes memory payload = abi.encode(_message);
        fees = new uint256[](_dstEids.length);
        
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], false);
            fees[i] = fee.nativeFee;
            totalFee += fee.nativeFee;
        }
    }

    // Public quote function that returns MessagingFee struct (similar to BatchSendMock)
    function quoteMultipleWithStruct(
        uint32[] calldata _dstEids,
        string calldata _message,
        bytes[] calldata _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory totalFee) {
        require(_dstEids.length == _options.length, "Arrays length mismatch");
        
        bytes memory payload = abi.encode(_message);
        
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], _payInLzToken);
            totalFee.nativeFee += fee.nativeFee;
            totalFee.lzTokenFee += fee.lzTokenFee;
        }
    }
}