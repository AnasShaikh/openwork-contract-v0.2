// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridge-testing/StringSender.sol";

contract DeployStringSender is Script {
    // LayerZero V2 Endpoints
    address constant ETHEREUM_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant OPTIMISM_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant ARBITRUM_SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying StringSender contract...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        // Determine which network we're deploying to
        address endpoint = getEndpointForChain();
        
        vm.startBroadcast(deployerPrivateKey);
        
        StringSender stringSender = new StringSender(endpoint, deployer);
        
        vm.stopBroadcast();
        
        console.log("StringSender deployed to:", address(stringSender));
        console.log("Endpoint used:", endpoint);
        console.log("Owner:", deployer);
        
        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "StringSender deployed at: ", 
                vm.toString(address(stringSender)),
                "\nEndpoint: ",
                vm.toString(endpoint),
                "\nOwner: ",
                vm.toString(deployer)
            )
        );
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log(deploymentInfo);
    }
    
    function getEndpointForChain() internal view returns (address) {
        uint256 chainId = block.chainid;
        
        if (chainId == 11155111) {
            // Ethereum Sepolia
            console.log("Deploying to Ethereum Sepolia");
            return ETHEREUM_SEPOLIA_ENDPOINT;
        } else if (chainId == 11155420) {
            // Optimism Sepolia
            console.log("Deploying to Optimism Sepolia");
            return OPTIMISM_SEPOLIA_ENDPOINT;
        } else if (chainId == 421614) {
            // Arbitrum Sepolia
            console.log("Deploying to Arbitrum Sepolia");
            return ARBITRUM_SEPOLIA_ENDPOINT;
        } else {
            revert("Unsupported network");
        }
    }
}