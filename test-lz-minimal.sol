// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";

contract MinimalLayerZeroTest is OAppSender {
    uint32 public targetLzEid = 40232;
    
    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) {}
    
    function oAppVersion() public pure override returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }
    
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }
    
    function testSend(string calldata message, bytes calldata lzOptions) external payable {
        bytes memory payload = abi.encode("test", message);
        MessagingFee memory fee = _quote(targetLzEid, payload, lzOptions, false);
        require(msg.value >= fee.nativeFee, "Insufficient fee");
        
        _lzSend(targetLzEid, payload, lzOptions, fee, payable(msg.sender));
    }
    
    function quoteFee(string calldata message, bytes calldata lzOptions) external view returns (uint256) {
        bytes memory payload = abi.encode("test", message);
        MessagingFee memory fee = _quote(targetLzEid, payload, lzOptions, false);
        return fee.nativeFee;
    }
}