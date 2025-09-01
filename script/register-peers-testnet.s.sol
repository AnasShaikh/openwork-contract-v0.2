// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/current/mainnet-test/wormhole-cctp-bridge.sol";

contract RegisterPeersTestnet is Script {
    // Replace these with actual deployed addresses after deployment
    address constant ARB_BRIDGE_ADDRESS = address(0); // Update after deployment
    address constant OP_BRIDGE_ADDRESS = address(0);  // Update after deployment
    
    uint16 constant WORMHOLE_CHAIN_ARB_SEPOLIA = 23;
    uint16 constant WORMHOLE_CHAIN_OP_SEPOLIA = 24;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("WALL2_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Register peers on Arbitrum Sepolia
        if (block.chainid == 421614 && ARB_BRIDGE_ADDRESS != address(0)) {
            WormholeCCTPBridge arbBridge = WormholeCCTPBridge(ARB_BRIDGE_ADDRESS);
            
            // Register Optimism Sepolia bridge as peer
            bytes32 opPeer = bytes32(uint256(uint160(OP_BRIDGE_ADDRESS)));
            arbBridge.registerContract(WORMHOLE_CHAIN_OP_SEPOLIA, opPeer);
            
            console.log("Registered OP Sepolia peer on Arbitrum Sepolia bridge");
            console.log("OP Bridge Address:", OP_BRIDGE_ADDRESS);
            console.log("OP Peer (bytes32):", vm.toString(opPeer));
        }
        
        // Register peers on Optimism Sepolia
        if (block.chainid == 11155420 && OP_BRIDGE_ADDRESS != address(0)) {
            WormholeCCTPBridge opBridge = WormholeCCTPBridge(OP_BRIDGE_ADDRESS);
            
            // Register Arbitrum Sepolia bridge as peer
            bytes32 arbPeer = bytes32(uint256(uint160(ARB_BRIDGE_ADDRESS)));
            opBridge.registerContract(WORMHOLE_CHAIN_ARB_SEPOLIA, arbPeer);
            
            console.log("Registered Arb Sepolia peer on Optimism Sepolia bridge");
            console.log("Arb Bridge Address:", ARB_BRIDGE_ADDRESS);
            console.log("Arb Peer (bytes32):", vm.toString(arbPeer));
        }

        vm.stopBroadcast();
    }
}