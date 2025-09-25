// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@across-protocol/contracts/interfaces/V3SpokePoolInterface.sol";

contract CrossChainHelloWorld {
    // Across SpokePool addresses
    address public constant OP_SPOKE_POOL = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address public constant ARB_SPOKE_POOL = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;
    
    // Chain IDs
    uint256 public constant OP_MAINNET_ID = 10;
    uint256 public constant ARB_MAINNET_ID = 42161;
    
    // Events
    event HelloSent(address indexed sender, uint256 indexed depositId, string message);
    event HelloReceived(address indexed sender, string message, uint256 timestamp);
    
    // Storage
    mapping(uint256 => string) public receivedMessages;
    uint256 public messageCount;
    
    // Send hello from OP Mainnet to Arbitrum
    function sendHello(string memory message) external payable {
        require(block.chainid == OP_MAINNET_ID, "Must call from OP Mainnet");
        require(bytes(message).length > 0, "Message cannot be empty");
        
        // Encode the message and receiver address
        bytes memory messageData = abi.encode(message, msg.sender);
        
        // Send via Across Protocol
        V3SpokePoolInterface spokePool = V3SpokePoolInterface(OP_SPOKE_POOL);
        
        spokePool.depositV3{value: msg.value}(
            msg.sender,                    // depositor
            address(this),                 // recipient (this contract on destination)
            address(0),                    // inputToken (ETH)
            address(0),                    // outputToken (ETH)
            msg.value,                     // inputAmount
            msg.value,                     // outputAmount
            ARB_MAINNET_ID,               // destinationChainId
            address(0),                    // exclusiveRelayer
            uint32(block.timestamp + 3600), // quoteTimestamp (1 hour from now)
            uint32(block.timestamp + 7200), // fillDeadline (2 hours from now)
            0,                            // exclusivityDeadline
            messageData                   // message
        );
        
        emit HelloSent(msg.sender, 0, message); // depositId will be emitted by SpokePool's FundsDeposited event
    }
    
    // Receive hello on Arbitrum (called by Across relayers)
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address relayer,
        bytes memory message
    ) external {
        require(block.chainid == ARB_MAINNET_ID, "Must be called on Arbitrum");
        require(msg.sender == ARB_SPOKE_POOL, "Only Across SpokePool can call");
        
        // Decode the message
        (string memory helloMessage, address originalSender) = abi.decode(message, (string, address));
        
        // Store the received message
        receivedMessages[messageCount] = helloMessage;
        messageCount++;
        
        emit HelloReceived(originalSender, helloMessage, block.timestamp);
    }
    
    // View functions
    function getLastMessage() external view returns (string memory) {
        if (messageCount == 0) return "";
        return receivedMessages[messageCount - 1];
    }
    
    function getMessage(uint256 index) external view returns (string memory) {
        return receivedMessages[index];
    }
    
    // Utility function to estimate fees (call this before sending)
    function estimateFees() external view returns (uint256) {
        // This is a rough estimate - actual fees depend on gas prices and bridge state
        // You should call the SpokePool's suggestedFee functions for accurate estimates
        return 0.001 ether; // Rough estimate
    }
}

// Deployment script (save as deploy.js)
/*
const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying CrossChainHelloWorld...");
    
    // Deploy on OP Mainnet first
    const HelloWorld = await ethers.getContractFactory("CrossChainHelloWorld");
    const opContract = await HelloWorld.deploy();
    await opContract.deployed();
    console.log("OP Mainnet contract deployed to:", opContract.address);
    
    // Deploy on Arbitrum
    const arbContract = await HelloWorld.deploy();
    await arbContract.deployed();
    console.log("Arbitrum contract deployed to:", arbContract.address);
    
    console.log("\nTo send a hello:");
    console.log(`opContract.sendHello("Hello from OP!", { value: ethers.utils.parseEther("0.001") })`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
*/

// Usage example:
/*
1. Deploy contract on both OP Mainnet and Arbitrum
2. On OP Mainnet, call: sendHello("Hello Arbitrum!", { value: 0.001 ETH })
3. Wait for Across relayers to process (usually 2-10 minutes)
4. Check Arbitrum contract for received message: getLastMessage()
*/