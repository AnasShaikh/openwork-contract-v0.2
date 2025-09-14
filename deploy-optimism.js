const { ethers } = require("hardhat");
const fs = require('fs');

// Configuration
const WALL2_PRIVATE_KEY = "0720f50ce9cdedb2677f92f40fa9b6eea44fe60508b01eebdcd25500728c71ea";
const WALL2_ADDRESS = "0xfD08836eeE6242092a9c869237a8d122275b024A";

// OP Sepolia addresses
const USDT_OP_SEPOLIA = "0x5fd84259d66Cd46123540766Be93DFE6D43130D7";
const CCTP_MESSAGE_TRANSMITTER = "0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275";
const LAYERZERO_ENDPOINT_OP = "0x6EDCE65403992e310A62460808c4b910D972f10f";

// Chain EIDs
const ARB_SEPOLIA_EID = 40231;
const OP_SEPOLIA_EID = 40232;
const ETHEREUM_SEPOLIA_EID = 40161; // Main chain for rewards

// Placeholder addresses - will need actual Genesis and Rewards contracts
const GENESIS_CONTRACT = "0x0000000000000000000000000000000000000001"; // TODO: Replace with actual
const REWARDS_CONTRACT = "0x0000000000000000000000000000000000000002"; // TODO: Replace with actual

async function main() {
    console.log("🚀 Starting OP Sepolia deployment...");
    
    // Load Arbitrum deployment addresses
    let arbitrumAddresses;
    try {
        const deploymentData = JSON.parse(fs.readFileSync('deployment-addresses.json', 'utf8'));
        arbitrumAddresses = deploymentData.arbitrum;
        console.log("📄 Loaded Arbitrum addresses:", arbitrumAddresses);
    } catch (error) {
        console.error("❌ Failed to load Arbitrum addresses. Run deploy-arbitrum.js first.");
        process.exit(1);
    }
    
    // Setup wallet
    const provider = new ethers.JsonRpcProvider(process.env.OPTIMISM_SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(WALL2_PRIVATE_KEY, provider);
    
    console.log("Deploying from wallet:", wallet.address);
    console.log("Wallet balance:", ethers.formatEther(await provider.getBalance(wallet.address)), "ETH");

    // ==== 1. Deploy CCTP Receiver ====
    console.log("\n📡 Deploying CCTP Receiver...");
    const CCTPReceiver = await ethers.getContractFactory("CCTPReceiver", wallet);
    const cctpReceiver = await CCTPReceiver.deploy();
    await cctpReceiver.waitForDeployment();
    const cctpReceiverAddress = await cctpReceiver.getAddress();
    console.log("✅ CCTP Receiver deployed to:", cctpReceiverAddress);

    // ==== 2. Deploy Native Bridge ====  
    console.log("\n🌉 Deploying Native Bridge...");
    const NativeBridge = await ethers.getContractFactory("NativeChainBridge", wallet);
    const nativeBridge = await NativeBridge.deploy(
        LAYERZERO_ENDPOINT_OP,
        WALL2_ADDRESS,
        ETHEREUM_SEPOLIA_EID  // mainChainEid
    );
    await nativeBridge.waitForDeployment();
    const nativeBridgeAddress = await nativeBridge.getAddress();
    console.log("✅ Native Bridge deployed to:", nativeBridgeAddress);

    // ==== 3. Deploy NOWJC ====
    console.log("\n💼 Deploying NOWJC...");
    const NOWJC = await ethers.getContractFactory("NativeOpenWorkJobContract", wallet);
    const nowjc = await NOWJC.deploy();
    await nowjc.waitForDeployment();
    const nowjcAddress = await nowjc.getAddress();
    console.log("✅ NOWJC deployed to:", nowjcAddress);

    // ==== 4. Initialize Contracts ====
    console.log("\n⚙️ Initializing contracts...");
    
    // Initialize CCTP Receiver
    await cctpReceiver.initialize(
        WALL2_ADDRESS,            // owner
        USDT_OP_SEPOLIA,         // usdtToken
        CCTP_MESSAGE_TRANSMITTER, // messageTransmitter
        nowjcAddress             // nowjcContract
    );
    console.log("✅ CCTP Receiver initialized");

    // Initialize NOWJC
    await nowjc.initialize(
        WALL2_ADDRESS,      // owner
        nativeBridgeAddress, // bridge
        GENESIS_CONTRACT,   // genesis (placeholder)
        REWARDS_CONTRACT,   // rewardsContract (placeholder)
        USDT_OP_SEPOLIA,   // usdtToken
        cctpReceiverAddress // cctpReceiver
    );
    console.log("✅ NOWJC initialized");

    // ==== 5. Configure Native Bridge ====
    console.log("\n🔧 Configuring native bridge...");
    await nativeBridge.authorizeContract(nowjcAddress, true);
    await nativeBridge.setNativeOpenWorkJobContract(nowjcAddress);
    await nativeBridge.addLocalChain(ARB_SEPOLIA_EID); // Add Arbitrum as authorized local chain
    console.log("✅ NOWJC authorized and configured on native bridge");

    // ==== 6. Update Arbitrum CCTP Sender with receiver address ====
    console.log("\n🔄 Updating CCTP Sender with receiver address...");
    
    // Connect to Arbitrum CCTP Sender
    const arbProvider = new ethers.JsonRpcProvider(process.env.ARBITRUM_SEPOLIA_RPC_URL);
    const arbWallet = new ethers.Wallet(WALL2_PRIVATE_KEY, arbProvider);
    const cctpSenderContract = await ethers.getContractAt("CCTPSender", arbitrumAddresses.cctpSender, arbWallet);
    
    // Update CCTP config with real receiver address
    await cctpSenderContract.setCCTPConfig(
        "0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA", // tokenMessenger (same)
        cctpReceiverAddress,                           // receiver (updated)
        ethers.parseUnits("1000", 6),                 // maxFee (same)
        1000                                          // finalityThreshold (same)
    );
    console.log("✅ CCTP Sender updated with receiver address");

    // ==== 7. Update deployment addresses file ====
    const deploymentData = JSON.parse(fs.readFileSync('deployment-addresses.json', 'utf8'));
    deploymentData.optimism = {
        cctpReceiver: cctpReceiverAddress,
        nativeBridge: nativeBridgeAddress,
        nowjc: nowjcAddress,
        chainId: OP_SEPOLIA_EID
    };
    fs.writeFileSync('deployment-addresses.json', JSON.stringify(deploymentData, null, 2));

    // ==== 8. Summary ====
    console.log("\n🎉 OP Sepolia Deployment Complete!");
    console.log("================================");
    console.log("CCTP Receiver: ", cctpReceiverAddress);
    console.log("Native Bridge: ", nativeBridgeAddress);  
    console.log("NOWJC:         ", nowjcAddress);
    console.log("================================");
    console.log("Owner:         ", WALL2_ADDRESS);
    console.log("USDT Token:    ", USDT_OP_SEPOLIA);
    console.log("CCTP Transmitter:", CCTP_MESSAGE_TRANSMITTER);

    console.log("\n🔗 Cross-Chain Configuration:");
    console.log("ARB CCTP Sender updated with OP receiver:", cctpReceiverAddress);
    
    console.log("\n⚠️  NEXT STEPS:");
    console.log("1. Replace Genesis contract placeholder:", GENESIS_CONTRACT);
    console.log("2. Replace Rewards contract placeholder:", REWARDS_CONTRACT);  
    console.log("3. Configure LayerZero peers between bridges");
    console.log("4. Test CCTP cross-chain transfer");
}

main().catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exitCode = 1;
});