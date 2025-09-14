const { ethers } = require("hardhat");

// Configuration
const WALL2_PRIVATE_KEY = "0720f50ce9cdedb2677f92f40fa9b6eea44fe60508b01eebdcd25500728c71ea";
const WALL2_ADDRESS = "0xfD08836eeE6242092a9c869237a8d122275b024A";

// Arbitrum Sepolia addresses
const USDT_ARBITRUM = "0x403a1eea6FF82152F88Da33a51c439f7e2C85665";
const CCTP_TOKEN_MESSENGER = "0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA";
const LAYERZERO_ENDPOINT_ARB = "0x6EDCE65403992e310A62460808c4b910D972f10f";

// Chain EIDs
const ARB_SEPOLIA_EID = 40231;
const OP_SEPOLIA_EID = 40232;
const ETHEREUM_SEPOLIA_EID = 40161; // Main chain for rewards

// CCTP Configuration
const DEFAULT_MAX_FEE = ethers.parseUnits("1000", 6); // 1000 USDT max fee
const DEFAULT_FINALITY_THRESHOLD = 1000; // Fast finality

async function main() {
    console.log("🚀 Starting Arbitrum Sepolia deployment...");
    
    // Setup wallet
    const provider = new ethers.JsonRpcProvider(process.env.ARBITRUM_SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(WALL2_PRIVATE_KEY, provider);
    
    console.log("Deploying from wallet:", wallet.address);
    console.log("Wallet balance:", ethers.formatEther(await provider.getBalance(wallet.address)), "ETH");

    // ==== 1. Deploy CCTP Sender ====
    console.log("\n📡 Deploying CCTP Sender...");
    const CCTPSender = await ethers.getContractFactory("CCTPSender", wallet);
    const cctpSender = await CCTPSender.deploy();
    await cctpSender.waitForDeployment();
    const cctpSenderAddress = await cctpSender.getAddress();
    console.log("✅ CCTP Sender deployed to:", cctpSenderAddress);

    // ==== 2. Deploy Local Bridge ====
    console.log("\n🌉 Deploying Local Bridge...");
    const LocalBridge = await ethers.getContractFactory("LayerZeroBridge", wallet);
    const localBridge = await LocalBridge.deploy(
        LAYERZERO_ENDPOINT_ARB,
        WALL2_ADDRESS,
        OP_SEPOLIA_EID,  // nativeChainEid
        ETHEREUM_SEPOLIA_EID, // mainChainEid  
        ARB_SEPOLIA_EID  // thisLocalChainEid
    );
    await localBridge.waitForDeployment();
    const localBridgeAddress = await localBridge.getAddress();
    console.log("✅ Local Bridge deployed to:", localBridgeAddress);

    // ==== 3. Deploy LOWJC ====
    console.log("\n💼 Deploying LOWJC...");
    const LOWJC = await ethers.getContractFactory("CrossChainLocalOpenWorkJobContract", wallet);
    const lowjc = await LOWJC.deploy();
    await lowjc.waitForDeployment();
    const lowjcAddress = await lowjc.getAddress();
    console.log("✅ LOWJC deployed to:", lowjcAddress);

    // ==== 4. Initialize Contracts ====
    console.log("\n⚙️ Initializing contracts...");
    
    // Initialize CCTP Sender (need receiver address - will update later)
    const tempReceiverAddress = "0x0000000000000000000000000000000000000000"; // Temporary
    await cctpSender.initialize(
        WALL2_ADDRESS,           // owner
        USDT_ARBITRUM,          // usdtToken
        CCTP_TOKEN_MESSENGER,   // cctpTokenMessenger
        lowjcAddress,           // lowjcContract
        tempReceiverAddress,    // cctpReceiver (temp)
        DEFAULT_MAX_FEE,        // defaultMaxFee
        DEFAULT_FINALITY_THRESHOLD // defaultFinalityThreshold
    );
    console.log("✅ CCTP Sender initialized");

    // Initialize LOWJC
    await lowjc.initialize(
        WALL2_ADDRESS,      // owner
        USDT_ARBITRUM,     // usdtToken
        ARB_SEPOLIA_EID,   // chainId
        localBridgeAddress, // bridge
        cctpSenderAddress  // cctpSender
    );
    console.log("✅ LOWJC initialized");

    // ==== 5. Configure Bridge ====
    console.log("\n🔧 Configuring bridge...");
    await localBridge.authorizeContract(lowjcAddress, true);
    console.log("✅ LOWJC authorized on bridge");

    // ==== 6. Summary ====
    console.log("\n🎉 Arbitrum Sepolia Deployment Complete!");
    console.log("================================");
    console.log("CCTP Sender:   ", cctpSenderAddress);
    console.log("Local Bridge:  ", localBridgeAddress);
    console.log("LOWJC:         ", lowjcAddress);
    console.log("================================");
    console.log("Owner:         ", WALL2_ADDRESS);
    console.log("USDT Token:    ", USDT_ARBITRUM);
    console.log("CCTP Messenger:", CCTP_TOKEN_MESSENGER);
    
    // Save addresses to file for OP Sepolia deployment
    const fs = require('fs');
    const deploymentData = {
        arbitrum: {
            cctpSender: cctpSenderAddress,
            localBridge: localBridgeAddress,  
            lowjc: lowjcAddress,
            chainId: ARB_SEPOLIA_EID
        }
    };
    fs.writeFileSync('deployment-addresses.json', JSON.stringify(deploymentData, null, 2));
    console.log("📄 Addresses saved to deployment-addresses.json");
}

main().catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exitCode = 1;
});