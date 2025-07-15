// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract ReceiverContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    ILayerZeroEndpointV2 public endpoint;
    string public message;
    uint256 public value;
    uint256 public messageCount;
    mapping(uint32 => bytes32) public peers;
    
    event MessageReceived(uint32 srcEid, bytes32 sender, string message, uint256 value);
    
    function initialize(address _endpoint, address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        endpoint = ILayerZeroEndpointV2(_endpoint);
        endpoint.setDelegate(address(this));
    }
    
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        require(msg.sender == address(endpoint), "Only endpoint");
        require(peers[_origin.srcEid] == _origin.sender, "Invalid peer");
        
        (string memory _msg, uint256 _val) = abi.decode(_message, (string, uint256));
        
        message = _msg;
        value = _val;
        messageCount++;
        
        emit MessageReceived(_origin.srcEid, _origin.sender, _msg, _val);
    }
    
    function setPeer(uint32 _eid, bytes32 _peer) external onlyOwner {
        peers[_eid] = _peer;
    }
    
    function getState() external view returns (string memory, uint256, uint256) {
        return (message, value, messageCount);
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}