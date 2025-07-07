// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "forge-std/Script.sol";

interface IOApp {
    function setPeer(uint32 _eid, bytes32 _peer) external;
}

contract SetPeers is Script {
    // Contract addresses
    address constant LOWJC_ADDRESS = 0x4Fe04e1fc08B7aa1813D0284eA3469C69d46ff14;  // Arbitrum Sepolia
    address constant NOWJC_ADDRESS = 0x68B9dA88e948899e8FD766Ec18c2424afEA55D27; // Optimism Sepolia
    
    // EIDs
    uint32 constant ARB_SEPOLIA_EID = 40231;
    uint32 constant OP_SEPOLIA_EID = 40232;
    
    function run() external {
        vm.startBroadcast();
        
        bytes32 lowjcBytes32 = bytes32(uint256(uint160(LOWJC_ADDRESS)));
        bytes32 nowjcBytes32 = bytes32(uint256(uint160(NOWJC_ADDRESS)));
        
        if (block.chainid == 421614) { // Arbitrum Sepolia
            console.log("Setting peer on LOWJC (Arbitrum)");
            IOApp(LOWJC_ADDRESS).setPeer(OP_SEPOLIA_EID, nowjcBytes32);
            console.log("LOWJC peer set to NOWJC");
            
        } else if (block.chainid == 11155420) { // Optimism Sepolia
            console.log("Setting peer on NOWJC (Optimism)");
            IOApp(NOWJC_ADDRESS).setPeer(ARB_SEPOLIA_EID, lowjcBytes32);
            console.log("NOWJC peer set to LOWJC");
            
        } else {
            revert("Unsupported network");
        }
        
        vm.stopBroadcast();
    }
}