// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ILayerZeroEndpointV2 {
    function send(
        uint32 _dstEid,
        bytes32 _receiver,
        bytes calldata _message,
        bytes calldata _options,
        address _refundAddress
    ) external payable returns (uint256 fee);
    
    function quote(
        uint32 _dstEid,
        bytes32 _receiver,
        bytes calldata _message,
        bytes calldata _options
    ) external view returns (uint256 fee);
}

interface ILayerZeroReceiver {
    function lzReceive(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes calldata _payload
    ) external;
}

/**
 * @title Simple LayerZero Bridge
 * @dev Simplified bridge for testing CCTP + LayerZero integration
 */
contract SimpleLayerZeroBridge is Ownable, ILayerZeroReceiver {
    ILayerZeroEndpointV2 public endpoint;
    address public targetContract; // The contract that will receive the messages
    uint32 public peerEid; // Peer endpoint ID
    bytes32 public peer; // Peer bridge address
    
    mapping(string => bool) public supportedFunctions;
    
    event MessageSent(string functionName, bytes payload, uint32 dstEid);
    event MessageReceived(string functionName, bytes payload, uint32 srcEid);
    
    constructor(
        address _endpoint,
        address _targetContract
    ) Ownable(msg.sender) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
        targetContract = _targetContract;
        
        // Register supported functions
        supportedFunctions["receiveJobStart"] = true;
        supportedFunctions["receiveTestMessage"] = true;
    }
    
    /**
     * @dev Send message to native chain (used by sender contract)
     */
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable {
        require(supportedFunctions[_functionName], "Function not supported");
        
        bytes memory message = abi.encode(_functionName, _payload);
        
        endpoint.send{value: msg.value}(
            peerEid,
            peer,
            message,
            _options,
            msg.sender
        );
        
        emit MessageSent(_functionName, _payload, peerEid);
    }
    
    /**
     * @dev Receive message from LayerZero
     */
    function lzReceive(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes calldata _payload
    ) external override {
        require(msg.sender == address(endpoint), "Unauthorized: not endpoint");
        require(_sender == peer, "Unauthorized: invalid sender");
        
        (string memory functionName, bytes memory payload) = 
            abi.decode(_payload, (string, bytes));
        
        require(supportedFunctions[functionName], "Function not supported");
        
        // Route to target contract
        if (keccak256(bytes(functionName)) == keccak256(bytes("receiveJobStart"))) {
            (bool success,) = targetContract.call(
                abi.encodeWithSignature("receiveJobStart(bytes)", payload)
            );
            require(success, "Target contract call failed");
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("receiveTestMessage"))) {
            (bool success,) = targetContract.call(
                abi.encodeWithSignature("receiveTestMessage(bytes)", payload)
            );
            require(success, "Target contract call failed");
        }
        
        emit MessageReceived(functionName, payload, _srcEid);
    }
    
    /**
     * @dev Quote message cost
     */
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        return endpoint.quote(peerEid, peer, _payload, _options);
    }
    
    /**
     * @dev Set peer configuration
     */
    function setPeer(uint32 _peerEid, bytes32 _peer) external onlyOwner {
        peerEid = _peerEid;
        peer = _peer;
    }
    
    /**
     * @dev Update target contract
     */
    function setTargetContract(address _newTarget) external onlyOwner {
        targetContract = _newTarget;
    }
    
    /**
     * @dev Add supported function
     */
    function addSupportedFunction(string memory _functionName) external onlyOwner {
        supportedFunctions[_functionName] = true;
    }
}