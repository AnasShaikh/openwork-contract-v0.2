// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridge-testing/StringSender.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract SendMessageTwoChains is Script {
    using OptionsBuilder for bytes;
    
    address constant ETH_SENDER = 0xE1Ba069CF6402c763097F3cE72C0AD973403c85B;
    
    // LayerZero Endpoint IDs for Sepolia testnets
    uint32 constant ARB_SEPOLIA_EID = 40231;
    uint32 constant OP_SEPOLIA_EID = 40232;
    
    function runWithEmptyOptions() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory message = "Hello from ETH to ARB and OP!";
        
        // Empty options - LayerZero will use defaults
        bytes memory options1 = "";
        bytes memory options2 = "";
        
        StringSender sender = StringSender(ETH_SENDER);
        
        // Get quote for both chains
        (uint256 totalFee, uint256 fee1, uint256 fee2) = sender.quoteTwoChains(
            ARB_SEPOLIA_EID,
            OP_SEPOLIA_EID,
            message,
            options1,
            options2
        );
        
        console.log("Total fee required (empty options):", totalFee);
        console.log("ARB fee:", fee1);
        console.log("OP fee:", fee2);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Use quoted fee with buffer
        uint256 feeWithBuffer = (totalFee * 120) / 100; // 20% buffer for empty options
        
        sender.sendStringToTwoChains{value: feeWithBuffer}(
            ARB_SEPOLIA_EID,
            OP_SEPOLIA_EID,
            message,
            options1,
            options2
        );
        
        vm.stopBroadcast();
        
        console.log("Message sent to both chains with empty options!");
        console.log("Message:", message);
        console.log("Fee with buffer used:", feeWithBuffer);
    }
}