// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StringSender is OAppSender {
    constructor(address _endpoint, address _owner) OAppCore(_endpoint, _owner) Ownable(_owner) {}

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

    function quote(
        uint32 _dstEid, 
        string calldata _message, 
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(_message);
        MessagingFee memory fee = _quote(_dstEid, payload, _options, false);
        return fee.nativeFee;
    }
}