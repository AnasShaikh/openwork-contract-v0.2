// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract TestOptionsBuilder is Script {
    using OptionsBuilder for bytes;

    function run() external {
        // Generate options for different gas limits
        bytes memory options700k = OptionsBuilder.newOptions().addExecutorLzReceiveOption(700000, 0);
        bytes memory options1M = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1000000, 0);
        
        console.log("700K gas options:");
        console.logBytes(options700k);
        
        console.log("\n1M gas options:");
        console.logBytes(options1M);
        
        // Now test with actual contract call
        uint256 privateKey = vm.envUint("WALL2_KEY");
        address contractAddress = 0x896a3Bc6ED01f549Fe20bD1F25067951913b793C;
        address wall2Address = vm.envAddress("WALL2_ADDRESS");
        
        vm.startBroadcast(privateKey);
        
        string[] memory milestones = new string[](2);
        milestones[0] = "Milestone 1";
        milestones[1] = "Milestone 2";
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500000;
        amounts[1] = 500000;
        
        // Try with 1M gas using OptionsBuilder
        (bool success, bytes memory data) = contractAddress.call{value: 0.002 ether}(
            abi.encodeWithSignature(
                "startDirectContract(address,string,string[],uint256[],uint32,bytes)",
                wall2Address,
                "TEST-OPTIONSBUILDER-1M",
                milestones,
                amounts,
                uint32(2),
                options1M
            )
        );
        
        if (success) {
            console.log("SUCCESS with 1M gas!");
        } else {
            console.log("FAILED with 1M gas");
            console.logBytes(data);
        }
        
        vm.stopBroadcast();
    }
}
