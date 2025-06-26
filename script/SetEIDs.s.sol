// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/bridged/local-openwork-job.sol";
import "../src/bridged/native-openwork-job.sol";

contract SetEIDs is Script {
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(privateKeyString);
        address localContract = 0x08f1785174f56600bA22F8d26067b19F4C3E4231;
        address nativeContract = 0xAa65Ed34F92F5e8e2c2253863dbCe0425d6B44B2;
        
        vm.startBroadcast(deployerPrivateKey);
        
        uint256 chainId = block.chainid;
        
        if (chainId == 421614) { // Arbitrum Sepolia
            // Set destination EID to Optimism Sepolia (40232)
            LocalOpenWorkJobContract(payable(localContract)).setDestinationEid(40232);
        } else if (chainId == 11155420) { // Optimism Sepolia
            // Authorize local contract (from Arbitrum EID 40231)
            bytes32 localBytes32 = bytes32(uint256(uint160(localContract)));
            NativeOpenWorkJobContract(payable(nativeContract)).addAuthorizedLocal(40231, localBytes32);
        }
        
        vm.stopBroadcast();
    }
}