// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/current/mainnet-test/wormhole-cctp-bridge.sol";

contract DeployWormholeCCTPTestnet is Script {
    // Testnet contract addresses
    
    // Wormhole Core addresses
    address constant WORMHOLE_ARB_SEPOLIA = 0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35;
    address constant WORMHOLE_OP_SEPOLIA = 0x31377888146f3253211EFEf5c676D41ECe7D58Fe;
    
    // Circle CCTP V2 addresses (same on all testnets)
    address constant TOKEN_MESSENGER_V2 = 0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA;
    address constant MESSAGE_TRANSMITTER_V2 = 0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275;
    
    // USDC testnet addresses
    address constant USDC_ARB_SEPOLIA = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant USDC_OP_SEPOLIA = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;
    
    // Wormhole chain IDs
    uint16 constant WORMHOLE_CHAIN_ARB_SEPOLIA = 23;
    uint16 constant WORMHOLE_CHAIN_OP_SEPOLIA = 24;
    
    // Circle domains
    uint32 constant DOMAIN_ARB_SEPOLIA = 3;
    uint32 constant DOMAIN_OP_SEPOLIA = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("WALL2_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy on Arbitrum Sepolia
        if (block.chainid == 421614) { // Arbitrum Sepolia chain ID
            console.log("Deploying WormholeCCTPBridge on Arbitrum Sepolia...");
            
            WormholeCCTPBridge arbBridge = new WormholeCCTPBridge(
                WORMHOLE_ARB_SEPOLIA,
                TOKEN_MESSENGER_V2,
                MESSAGE_TRANSMITTER_V2,
                USDC_ARB_SEPOLIA
            );
            
            console.log("Arbitrum Sepolia Bridge deployed at:", address(arbBridge));
            
            // Set domain mapping for Optimism Sepolia
            arbBridge.setDomainMapping(WORMHOLE_CHAIN_OP_SEPOLIA, DOMAIN_OP_SEPOLIA);
            console.log("Domain mapping set: OP Sepolia chain", WORMHOLE_CHAIN_OP_SEPOLIA, "-> domain", DOMAIN_OP_SEPOLIA);
        }
        
        // Deploy on Optimism Sepolia
        if (block.chainid == 11155420) { // Optimism Sepolia chain ID
            console.log("Deploying WormholeCCTPBridge on Optimism Sepolia...");
            
            WormholeCCTPBridge opBridge = new WormholeCCTPBridge(
                WORMHOLE_OP_SEPOLIA,
                TOKEN_MESSENGER_V2,
                MESSAGE_TRANSMITTER_V2,
                USDC_OP_SEPOLIA
            );
            
            console.log("Optimism Sepolia Bridge deployed at:", address(opBridge));
            
            // Set domain mapping for Arbitrum Sepolia
            opBridge.setDomainMapping(WORMHOLE_CHAIN_ARB_SEPOLIA, DOMAIN_ARB_SEPOLIA);
            console.log("Domain mapping set: Arb Sepolia chain", WORMHOLE_CHAIN_ARB_SEPOLIA, "-> domain", DOMAIN_ARB_SEPOLIA);
        }

        vm.stopBroadcast();
    }
}