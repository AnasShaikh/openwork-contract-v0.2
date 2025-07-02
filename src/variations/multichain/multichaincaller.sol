// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FixedMultiChainCaller
 * @notice Working version with proper OApp inheritance
 */
contract FixedMultiChainCaller is OApp {
    
    event MessageSent(uint32 dstEid, string message);

    constructor(address _endpoint, address _owner) 
        OApp(_endpoint, _owner) 
        Ownable(_owner) 
    {}

    /**
     * @notice Send to both chains manually
     */
    function callBothChains(
        uint32 _chainA,
        uint32 _chainB, 
        string calldata _message,
        bytes calldata _options
    ) external payable {
        bytes memory payload = abi.encode(_message);
        uint256 halfValue = msg.value / 2;
        
        // Send to chain A
        _lzSend(
            _chainA,
            payload,
            _options,
            MessagingFee(halfValue, 0),
            payable(msg.sender)
        );
        
        // Send to chain B
        _lzSend(
            _chainB,
            payload,
            _options,
            MessagingFee(msg.value - halfValue, 0),
            payable(msg.sender)
        );
        
        emit MessageSent(_chainA, _message);
        emit MessageSent(_chainB, _message);
    }

    /**
     * @notice Quote for single destination
     */
    function quote(
        uint32 _dstEid,
        string calldata _message,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(_message);
        MessagingFee memory fee = _quote(_dstEid, payload, _options, false);
        return fee.nativeFee;
    }

    /**
     * @notice Quote for both chains
     */
    function quoteBoth(
        uint32 _chainA,
        uint32 _chainB,
        string calldata _message,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(_message);
        MessagingFee memory feeA = _quote(_chainA, payload, _options, false);
        MessagingFee memory feeB = _quote(_chainB, payload, _options, false);
        return feeA.nativeFee + feeB.nativeFee;
    }

    /**
     * @notice Required override for receiving (even if we don't use it)
     */
    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata,
        address,
        bytes calldata
    ) internal override {
        // Not used in this sender-only contract
    }
}