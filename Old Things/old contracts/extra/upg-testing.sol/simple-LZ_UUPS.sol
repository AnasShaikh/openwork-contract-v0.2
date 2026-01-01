// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract SenderContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    ILayerZeroEndpointV2 public endpoint;
    mapping(uint32 => bytes32) public peers;
    
    event MessageSent(uint32 dstEid, bytes32 to, string message, uint256 value);
    
    function initialize(address _endpoint, address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        endpoint = ILayerZeroEndpointV2(_endpoint);
    }
    
    function sendMessage(uint32 _dstEid, string calldata _message, uint256 _value, bytes calldata _options) external payable {
        require(peers[_dstEid] != bytes32(0), "Peer not set");
        
        bytes memory payload = abi.encode(_message, _value);
        
        MessagingParams memory params = MessagingParams({
            dstEid: _dstEid,
            receiver: peers[_dstEid],
            message: payload,
            options: _options,
            payInLzToken: false
        });
        
        endpoint.send{value: msg.value}(params, msg.sender);
        
        emit MessageSent(_dstEid, peers[_dstEid], _message, _value);
    }
    
    function quote(uint32 _dstEid, string calldata _message, uint256 _value, bytes calldata _options) external view returns (MessagingFee memory fee) {
        require(peers[_dstEid] != bytes32(0), "Peer not set");
        
        bytes memory payload = abi.encode(_message, _value);
        
        MessagingParams memory params = MessagingParams({
            dstEid: _dstEid,
            receiver: peers[_dstEid],
            message: payload,
            options: _options,
            payInLzToken: false
        });
        
        return endpoint.quote(params, msg.sender);
    }
    
    function setPeer(uint32 _eid, bytes32 _peer) external onlyOwner {
        peers[_eid] = _peer;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}