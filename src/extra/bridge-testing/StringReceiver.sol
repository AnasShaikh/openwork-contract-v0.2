// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppReceiver, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StringReceiver is OAppReceiver {
    
    event StringReceived(uint32 srcEid, string message);
    
    string public latestMessage;
    uint32 public latestSourceChain;
    uint256 public messageCount;
    
    constructor(address _endpoint, address _owner) 
        OAppCore(_endpoint, _owner) 
        Ownable(_owner) 
    {}
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        string memory decodedMessage = abi.decode(_message, (string));
        
        latestMessage = decodedMessage;
        latestSourceChain = _origin.srcEid;
        messageCount++;
        
        emit StringReceived(_origin.srcEid, decodedMessage);
    }
}