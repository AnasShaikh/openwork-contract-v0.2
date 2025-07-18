// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/current/openwork-bsp-upg.sol/native-athena-upg.sol";

contract AddOracleScript is Script {
    function run() external {
        vm.startBroadcast();
        
        NativeAthena athena = NativeAthena(payable(0x878D27D8c774FaD49c327773836A42623ad80231));
        
        address[] memory members = new address[](3);
        members[0] = 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef;
        members[1] = 0xfD08836eeE6242092a9c869237a8d122275b024A;
        members[2] = 0x1D06bb4395AE7BFe9264117726D069C251dC27f5;
        
        athena.addSingleOracle("general", members, "General Oracle", "QmHash123");
        
        vm.stopBroadcast();
    }
}