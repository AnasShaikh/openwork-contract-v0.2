pragma solidity ^0.8.22;
import "forge-std/Script.sol";
import "../src/bridged/native-openwork-job-refined.sol";

contract DeployNativeScript is Script {
    function run() external {
        vm.startBroadcast();
        new NativeOpenWorkJobContract(
            0x6EDCE65403992e310A62460808c4b910D972f10f, // LayerZero endpoint Arbitrum Sepolia
            0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef  // Your wallet as owner
        );
        vm.stopBroadcast();
    }
}