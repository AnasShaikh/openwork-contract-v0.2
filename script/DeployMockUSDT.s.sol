// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Script.sol";
import "../src/mocks/MockUSDT.sol";

contract DeployMockUSDTScript is Script {
    function run() external {
        vm.startBroadcast();
        
        // Deploy with 1 million USDT initial supply
        new SampleUSDT(1000000);
        
        vm.stopBroadcast();
    }
}