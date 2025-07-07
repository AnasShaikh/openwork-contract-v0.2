// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StringSender is OAppSender {
    
    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) Ownable(_owner) {}

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
    }

    // New multi-chain function - sends to 2 chains in one call
    function sendStringToTwoChains(
        uint32 _dstEid1,
        uint32 _dstEid2,
        string calldata _message,
        bytes calldata _options1,
        bytes calldata _options2
    ) external payable {
        bytes memory payload = abi.encode(_message);
        
        // Get quotes for both chains
        MessagingFee memory fee1 = _quote(_dstEid1, payload, _options1, false);
        MessagingFee memory fee2 = _quote(_dstEid2, payload, _options2, false);
        
        uint256 totalFee = fee1.nativeFee + fee2.nativeFee;
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to first chain
        _lzSend(
            _dstEid1,
            payload, 
            _options1,
            MessagingFee(fee1.nativeFee, 0),
            payable(msg.sender)
        );
        
        // Send to second chain
        _lzSend(
            _dstEid2,
            payload, 
            _options2,
            MessagingFee(fee2.nativeFee, 0),
            payable(msg.sender)
        );
        
        // Refund excess fee if any
        uint256 excess = msg.value - totalFee;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

    // Alternative approach using arrays for more flexibility
    function sendStringToMultipleChains(
        uint32[] calldata _dstEids,
        string calldata _message,
        bytes[] calldata _options
    ) external payable {
        require(_dstEids.length == _options.length, "Arrays length mismatch");
        require(_dstEids.length > 0, "No destinations provided");
        
        bytes memory payload = abi.encode(_message);
        uint256 totalFee = 0;
        
        // Calculate total fee required
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], false);
            totalFee += fee.nativeFee;
        }
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        uint256 usedFee = 0;
        
        // Send to all destination chains
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], false);
            
            _lzSend(
                _dstEids[i],
                payload, 
                _options[i],
                MessagingFee(fee.nativeFee, 0),
                payable(msg.sender)
            );
            
            usedFee += fee.nativeFee;
        }
        
        // Refund excess fee if any
        uint256 excess = msg.value - usedFee;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

    // Original quote function (fixed syntax)
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
}