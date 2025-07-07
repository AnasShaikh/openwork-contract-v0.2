// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {VotingToken} from "../src/openwork-w1.sol/openwork-token.sol";
import {RewardsReceiver} from "../src/bridge-testing/m-rewards-br.sol";

contract DeployRewards is Script {
    // LayerZero V2 Endpoint for Ethereum Sepolia
    address constant LZ_ENDPOINT_SEPOLIA = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    
    function run() external {
        // Get deployment parameters from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        
        console.log("Deploying contracts...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Owner:", ownerAddress);
        console.log("LayerZero Endpoint:", LZ_ENDPOINT_SEPOLIA);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy VotingToken (OpenWork Token) first
        console.log("\n1. Deploying VotingToken...");
        VotingToken openworkToken = new VotingToken(ownerAddress);
        console.log("VotingToken deployed at:", address(openworkToken));
        console.log("Token name:", openworkToken.name());
        console.log("Token symbol:", openworkToken.symbol());
        console.log("Initial supply:", openworkToken.totalSupply());
        
        // Deploy RewardsReceiver contract
        console.log("\n2. Deploying RewardsReceiver...");
        RewardsReceiver rewardsReceiver = new RewardsReceiver(
            LZ_ENDPOINT_SEPOLIA,
            ownerAddress,
            address(openworkToken)
        );
        console.log("RewardsReceiver deployed at:", address(rewardsReceiver));
        
        // Transfer some tokens to the RewardsReceiver contract for governance rewards
        console.log("\n3. Transferring tokens to RewardsReceiver for rewards...");
        uint256 rewardPoolAmount = 500_000 * 10**18; // 500k tokens for rewards
        openworkToken.transfer(address(rewardsReceiver), rewardPoolAmount);
        console.log("Transferred", rewardPoolAmount / 10**18, "tokens to RewardsReceiver");
        
        vm.stopBroadcast();
        
        // Log final deployment info
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Ethereum Sepolia");
        console.log("VotingToken:", address(openworkToken));
        console.log("RewardsReceiver:", address(rewardsReceiver));
        console.log("Owner:", ownerAddress);
        console.log("LayerZero Endpoint:", LZ_ENDPOINT_SEPOLIA);
        
        // Log verification commands
        console.log("\n=== VERIFICATION COMMANDS ===");
        console.log("VotingToken verification:");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(address(openworkToken)),
            " src/openwork-w1.sol/openwork-token.sol:VotingToken",
            " --chain-id 11155111",
            " --etherscan-api-key $ETHERSCAN_API_KEY",
            " --constructor-args $(cast abi-encode 'constructor(address)' ",
            vm.toString(ownerAddress),
            ")"
        ));
        
        console.log("\nRewardsReceiver verification:");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(address(rewardsReceiver)),
            " src/bridge-testing/m-rewards-br.sol:RewardsReceiver",
            " --chain-id 11155111",
            " --etherscan-api-key $ETHERSCAN_API_KEY",
            " --constructor-args $(cast abi-encode 'constructor(address,address,address)' ",
            vm.toString(LZ_ENDPOINT_SEPOLIA),
            " ",
            vm.toString(ownerAddress),
            " ",
            vm.toString(address(openworkToken)),
            ")"
        ));
    }
}