// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract SimpleProxy {
    address public immutable implementation;
    
    constructor(address _implementation, bytes memory _data) {
        implementation = _implementation;
        
        // Initialize the implementation if data is provided
        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }
    
    fallback() external payable {
        address impl = implementation;
        assembly {
            // Copy msg.data to memory
            calldatacopy(0, 0, calldatasize())
            
            // Call the implementation
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            
            // Copy the returned data
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    receive() external payable {}
}