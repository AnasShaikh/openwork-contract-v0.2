// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridge-testing/lowjc-br.sol";
import "../src/bridge-testing/nowjc-br.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        
        if (block.chainid == 421614) { // Arbitrum Sepolia
            CrossChainOpenWorkJobContract lowjc = new CrossChainOpenWorkJobContract(
                0x6EDCE65403992e310A62460808c4b910D972f10f, // LayerZero endpoint
                msg.sender,
                0x403a1eea6FF82152F88Da33a51c439f7e2C85665, // USDT
                421614, // Arbitrum Sepolia chain ID
                40232, // OP Sepolia EID
                40232, // OP Sepolia EID (rewards)
                hex""
            );
            console.log("LOWJC deployed to:", address(lowjc));
        }
        
        if (block.chainid == 11155420) { // Optimism Sepolia
            NativeOpenWorkReceiver nowjc = new NativeOpenWorkReceiver(
                0x6EDCE65403992e310A62460808c4b910D972f10f, // LayerZero endpoint
                msg.sender
            );
            console.log("NOWJC deployed to:", address(nowjc));
        }
        
        vm.stopBroadcast();
    }
}