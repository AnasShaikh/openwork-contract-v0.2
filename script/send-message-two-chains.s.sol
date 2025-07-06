// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridge-testing/StringSender.sol";

contract SendMessageTwoChains is Script {
    address constant ETH_SENDER = 0xC7D443584E0eA17acc517Ec55B2838900FfE19D7;
    
    // LayerZero Endpoint IDs for Sepolia testnets
    uint32 constant ARB_SEPOLIA_EID = 40231;
    uint32 constant OP_SEPOLIA_EID = 40232;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory message = "Hello from ETH to ARB and OP!";
        
        // Proper LayerZero v2 options format
        bytes memory options1 = abi.encodePacked(uint16(3), uint16(1), uint16(1), uint128(200000)); // 200k gas for ARB
        bytes memory options2 = abi.encodePacked(uint16(3), uint16(1), uint16(1), uint128(200000)); // 200k gas for OP
        
        StringSender sender = StringSender(ETH_SENDER);
        
        // Get quote for both chains
        (uint256 totalFee, uint256 fee1, uint256 fee2) = sender.quoteTwoChains(
            ARB_SEPOLIA_EID,
            OP_SEPOLIA_EID,
            message,
            options1,
            options2
        );
        
        console.log("Total fee required:", totalFee);
        console.log("ARB fee:", fee1);
        console.log("OP fee:", fee2);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Use fixed amount (0.07 ETH) to avoid quote fluctuations
        uint256 fixedFee = 0.07 ether;
        
        sender.sendStringToTwoChains{value: fixedFee}(
            ARB_SEPOLIA_EID,
            OP_SEPOLIA_EID,
            message,
            options1,
            options2
        );
        
        vm.stopBroadcast();
        
        console.log("Message sent to both chains!");
        console.log("Message:", message);
        console.log("Fixed fee used:", fixedFee);
        console.log("Excess will be refunded automatically");
    }
}