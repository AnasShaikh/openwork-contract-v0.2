pragma solidity ^0.8.22;
import "forge-std/Script.sol";
import "../src/bridged/local-openwork-job.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        new LocalOpenWorkJobContract(
            0x6EDCE65403992e310A62460808c4b910D972f10f, // LayerZero endpoint
            msg.sender, // owner
            0x403a1eea6FF82152F88Da33a51c439f7e2C85665  // USDT
        );
        vm.stopBroadcast();
    }
}