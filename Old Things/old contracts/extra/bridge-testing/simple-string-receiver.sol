// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StringReceiver is OApp {
    string public lastMessage;
    
    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) Ownable(_owner) {}

    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        lastMessage = abi.decode(payload, (string));
    }
}