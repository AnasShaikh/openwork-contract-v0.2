// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "forge-std/Script.sol";

interface IOApp {
    function setPeer(uint32 _eid, bytes32 _peer) external;
}

interface INativeContract {
    function addAuthorizedLocal(uint32 _eid, bytes32 _localContract) external;
}

contract SetPeersScript is Script {
    // Contract addresses
    address constant LOCAL_CONTRACT = 0x08f1785174f56600bA22F8d26067b19F4C3E4231;  // Arbitrum Sepolia
    address constant NATIVE_CONTRACT = 0xAa65Ed34F92F5e8e2c2253863dbCe0425d6B44B2; // Optimism Sepolia
    
    // EIDs
    uint32 constant ARB_SEPOLIA_EID = 40231;
    uint32 constant OP_SEPOLIA_EID = 40232;
    
    function run() external {
        vm.startBroadcast();
        
        // Convert addresses to bytes32
        bytes32 localContractBytes32 = bytes32(uint256(uint160(LOCAL_CONTRACT)));
        bytes32 nativeContractBytes32 = bytes32(uint256(uint160(NATIVE_CONTRACT)));
        
        // Determine which network we're on and set appropriate peer
        uint256 chainId = block.chainid;
        
        if (chainId == 421614) { // Arbitrum Sepolia
            console.log("Setting peer on Arbitrum Sepolia (Local Contract)");
            console.log("Local Contract:", LOCAL_CONTRACT);
            console.log("Setting peer to Native Contract on OP Sepolia");
            
            // Set peer: Local contract points to Native contract on OP Sepolia
            IOApp(LOCAL_CONTRACT).setPeer(OP_SEPOLIA_EID, nativeContractBytes32);
            console.log("Peer set successfully on Local Contract");
            
        } else if (chainId == 11155420) { // Optimism Sepolia
            console.log("Setting peer on Optimism Sepolia (Native Contract)");
            console.log("Native Contract:", NATIVE_CONTRACT);
            console.log("Setting peer to Local Contract on Arb Sepolia");
            
            // Set peer: Native contract points to Local contract on Arb Sepolia
            IOApp(NATIVE_CONTRACT).setPeer(ARB_SEPOLIA_EID, localContractBytes32);
            console.log("Peer set successfully on Native Contract");
            
            // Also authorize the local contract
            INativeContract(NATIVE_CONTRACT).addAuthorizedLocal(ARB_SEPOLIA_EID, localContractBytes32);
            console.log("Local contract authorized successfully");
            
        } else {
            revert("Unsupported network");
        }
        
        vm.stopBroadcast();
    }
}