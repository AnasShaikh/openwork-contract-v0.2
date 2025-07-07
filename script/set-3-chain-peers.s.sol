// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridge-testing/StringSender.sol";
import "../src/bridge-testing/StringReceiver.sol";

contract Set3ChainPeers is Script {
    // Contract addresses
    address constant ETH_SENDER = 0xE1Ba069CF6402c763097F3cE72C0AD973403c85B;
    address constant ARB_RECEIVER = 0x5Ea4BC548FeDBDD7D5a5cB178f7bc0433FA34935;
    address constant OP_RECEIVER = 0x8C47Aa93Ec73f686c94fAff1dC3E8D6e5e22ce52;
    
    // LayerZero Endpoint IDs for Sepolia testnets
    uint32 constant ETH_SEPOLIA_EID = 40161;
    uint32 constant ARB_SEPOLIA_EID = 40231;
    uint32 constant OP_SEPOLIA_EID = 40232;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 chainId = block.chainid;
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (chainId == 11155111) { // Ethereum Sepolia
            StringSender sender = StringSender(ETH_SENDER);
            
            // Set peers: ETH sender -> ARB receiver
            sender.setPeer(ARB_SEPOLIA_EID, bytes32(uint256(uint160(ARB_RECEIVER))));
            console.log("Set ETH->ARB peer");
            
            // Set peers: ETH sender -> OP receiver  
            sender.setPeer(OP_SEPOLIA_EID, bytes32(uint256(uint160(OP_RECEIVER))));
            console.log("Set ETH->OP peer");
            
        } else if (chainId == 421614) { // Arbitrum Sepolia
            StringReceiver receiver = StringReceiver(ARB_RECEIVER);
            
            // Set peers: ARB receiver -> ETH sender
            receiver.setPeer(ETH_SEPOLIA_EID, bytes32(uint256(uint160(ETH_SENDER))));
            console.log("Set ARB->ETH peer");
            
        } else if (chainId == 11155420) { // Optimism Sepolia
            StringReceiver receiver = StringReceiver(OP_RECEIVER);
            
            // Set peers: OP receiver -> ETH sender
            receiver.setPeer(ETH_SEPOLIA_EID, bytes32(uint256(uint160(ETH_SENDER))));
            console.log("Set OP->ETH peer");
            
        } else {
            revert("Unsupported chain");
        }
        
        vm.stopBroadcast();
        
        console.log("Peers set successfully on chain:", chainId);
    }
}