// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppCore } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppCore.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CrossChainMessenger is OAppCore, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    string public latestMessage;

    event MessageReceived(uint32 srcEid, bytes32 sender, string message);
    event MessageSent(uint32 dstEid, bytes32 receiver, string message);

    constructor(address _endpoint) OAppCore(_endpoint) {
        _disableInitializers();
    }

    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
        // No __UUPSUpgradeable_init() needed, as UUPSUpgradeable has no initializer
    }

    function sendMessage(
        uint32 _dstEid,
        bytes32 _receiver,
        string calldata _message
    ) external payable {
        bytes memory _payload = abi.encode(_message);
        _lzSend(
            _dstEid,
            _payload,
            "", // options (empty for simplicity)
            msg.value, // native fee
            address(0) // refund address (zero for simplicity)
        );
        emit MessageSent(_dstEid, _receiver, _message);
    }

    function _lzReceive(
        uint32 _srcEid,
        bytes32 _sender,
        bytes calldata _payload
    ) internal override {
        string memory message = abi.decode(_payload, (string));
        latestMessage = message;
        emit MessageReceived(_srcEid, _sender, message);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}