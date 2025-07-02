// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Interface for your deployed contract
interface IUltraSimpleMultiCaller {
    function sendToChainA(uint32 _dstEid, string calldata _message, bytes calldata _options) external payable;
    function sendToChainB(uint32 _dstEid, string calldata _message, bytes calldata _options) external payable;
    function callBothChainsManual(uint32 _chainA, uint32 _chainB, string calldata _message, bytes calldata _options) external payable;
    function quote(uint32 _dstEid, string calldata _message, bytes calldata _options) external view returns (uint256);
}

contract TestMultiChainCaller is Script {
    // Your deployed contract address
    address constant DEPLOYED_CONTRACT = 0x2dB299dE397B145F57E034abbD85043B3DF138D9;
    
    // LayerZero Endpoint IDs for testnets
    uint32 constant OPTIMISM_SEPOLIA_EID = 40232;
    uint32 constant ARBITRUM_SEPOLIA_EID = 40231;
    
    IUltraSimpleMultiCaller multiCaller;
    
    function setUp() public {
        multiCaller = IUltraSimpleMultiCaller(DEPLOYED_CONTRACT);
    }
    
    function run() public {
        vm.startBroadcast();
        
        console.log("Testing deployed contract at:", DEPLOYED_CONTRACT);
        console.log("Sender address:", msg.sender);
        console.log("Balance:", msg.sender.balance);
        
        // Test 1: Quote for individual chains
        console.log("\n=== TESTING QUOTES ===");
        
        try multiCaller.quote(OPTIMISM_SEPOLIA_EID, "hello", "0x") returns (uint256 feeOp) {
            console.log("Optimism Sepolia quote:", feeOp);
        } catch {
            console.log("Quote for Optimism failed");
        }
        
        try multiCaller.quote(ARBITRUM_SEPOLIA_EID, "hello", "0x") returns (uint256 feeArb) {
            console.log("Arbitrum Sepolia quote:", feeArb);
        } catch {
            console.log("Quote for Arbitrum failed");
        }
        
        // Test 2: Send to individual chain (Optimism first)
        console.log("\n=== TESTING SINGLE CHAIN (OPTIMISM) ===");
        try multiCaller.quote(OPTIMISM_SEPOLIA_EID, "hello", "0x") returns (uint256 fee) {
            if (fee > 0 && msg.sender.balance >= fee) {
                multiCaller.sendToChainA{value: fee * 12 / 10}(OPTIMISM_SEPOLIA_EID, "hello from sepolia", "0x");
                console.log("Successfully sent to Optimism Sepolia");
            } else {
                console.log("Insufficient balance or zero fee for Optimism");
            }
        } catch Error(string memory reason) {
            console.log("Optimism send failed:", reason);
        } catch {
            console.log("Optimism send failed with unknown error");
        }
        
        // Test 3: Send to individual chain (Arbitrum)
        console.log("\n=== TESTING SINGLE CHAIN (ARBITRUM) ===");
        try multiCaller.quote(ARBITRUM_SEPOLIA_EID, "hello", "0x") returns (uint256 fee) {
            if (fee > 0 && msg.sender.balance >= fee) {
                multiCaller.sendToChainB{value: fee * 12 / 10}(ARBITRUM_SEPOLIA_EID, "hello from sepolia", "0x");
                console.log("Successfully sent to Arbitrum Sepolia");
            } else {
                console.log("Insufficient balance or zero fee for Arbitrum");
            }
        } catch Error(string memory reason) {
            console.log("Arbitrum send failed:", reason);
        } catch {
            console.log("Arbitrum send failed with unknown error");
        }
        
        // Test 4: Send to both chains
        console.log("\n=== TESTING DUAL CHAIN ===");
        try multiCaller.quote(OPTIMISM_SEPOLIA_EID, "hello", "0x") returns (uint256 feeOp) {
            try multiCaller.quote(ARBITRUM_SEPOLIA_EID, "hello", "0x") returns (uint256 feeArb) {
                uint256 totalFee = feeOp + feeArb;
                if (totalFee > 0 && msg.sender.balance >= totalFee) {
                    multiCaller.callBothChainsManual{value: totalFee * 12 / 10}(
                        ARBITRUM_SEPOLIA_EID, 
                        OPTIMISM_SEPOLIA_EID, 
                        "dual hello from sepolia", 
                        "0x"
                    );
                    console.log("Successfully sent to both chains");
                } else {
                    console.log("Insufficient balance for dual send");
                }
            } catch {
                console.log("Failed to get Arbitrum quote for dual send");
            }
        } catch {
            console.log("Failed to get Optimism quote for dual send");
        }
        
        vm.stopBroadcast();
    }
}