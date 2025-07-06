// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridge-testing/StringSender.sol";
import "../src/bridge-testing/StringReceiver.sol";

contract DeployBridgeTest is Script {
    // LayerZero V2 Sepolia Endpoints
    address constant ETH_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant ARB_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant OP_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ADDRESS");
        
        // Auto-detect endpoint based on chain
        address endpoint;
        uint256 chainId = block.chainid;
        
        if (chainId == 11155111) { // Ethereum Sepolia
            endpoint = ETH_SEPOLIA_ENDPOINT;
        } else if (chainId == 421614) { // Arbitrum Sepolia
            endpoint = ARB_SEPOLIA_ENDPOINT;
        } else if (chainId == 11155420) { // Optimism Sepolia
            endpoint = OP_SEPOLIA_ENDPOINT;
        } else {
            revert("Unsupported chain");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (chainId == 11155111) { // Ethereum Sepolia - deploy sender only
            StringSender sender = new StringSender(endpoint, owner);
            console.log("StringSender deployed at:", address(sender));
        } else { // Arbitrum & Optimism Sepolia - deploy receiver only
            StringReceiver receiver = new StringReceiver(endpoint, owner);
            console.log("StringReceiver deployed at:", address(receiver));
        }
        
        vm.stopBroadcast();
        
        console.log("Chain ID:", chainId);
        console.log("Endpoint:", endpoint);
    }
}