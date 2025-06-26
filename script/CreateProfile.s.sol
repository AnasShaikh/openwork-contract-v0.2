// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "forge-std/Script.sol";

interface ILocalContract {
    struct MilestonePayment {
        string descriptionHash;
        uint256 amount;
    }
    
    function createProfile(
        string memory _ipfsHash, 
        address _referrerAddress, 
        uint256 _rating,
        bytes calldata _options
    ) external payable;
    
    function quoteCreateProfile(
        string memory _ipfsHash, 
        address _referrerAddress, 
        uint256 _rating,
        bytes calldata _options
    ) external view returns (uint256);
    
    function hasProfile(address user) external view returns (bool);
    
    function setDestinationEid(uint32 _destinationEid) external;
}

contract CreateProfileScript is Script {
    address constant LOCAL_CONTRACT = 0x6633080966E94540C70DD1C233A90d1DceC79569;
    uint32 constant OP_SEPOLIA_EID = 40232;
    
    function run() external {
        vm.startBroadcast();
        
        ILocalContract localContract = ILocalContract(LOCAL_CONTRACT);
        
        // First set the destination EID (only owner can do this)
        console.log("Setting destination EID to Optimism Sepolia:", OP_SEPOLIA_EID);
        try localContract.setDestinationEid(OP_SEPOLIA_EID) {
            console.log("Destination EID set successfully");
        } catch {
            console.log("Could not set destination EID (might not be owner or already set)");
        }
        
        // Check if profile already exists
        bool profileExists = localContract.hasProfile(msg.sender);
        if (profileExists) {
            console.log("Profile already exists for address:", msg.sender);
            vm.stopBroadcast();
            return;
        }
        
        // Profile data
        string memory ipfsHash = "QmExampleProfileHash123456789";
        address referrerAddress = address(0); // No referrer
        uint256 rating = 5; // Initial rating
        
        // LayerZero options (empty for default)
        bytes memory options = "";
        
        console.log("=== Creating Profile ===");
        console.log("User:", msg.sender);
        console.log("IPFS Hash:", ipfsHash);
        console.log("Referrer:", referrerAddress);
        console.log("Rating:", rating);
        
        // Get quote for gas estimation
        uint256 quotedFee = localContract.quoteCreateProfile(
            ipfsHash,
            referrerAddress,
            rating,
            options
        );
        
        console.log("Quoted LayerZero fee:", quotedFee);
        console.log("Sending with extra buffer...");
        
        // Add 20% buffer to quoted fee
        uint256 feeWithBuffer = quotedFee + (quotedFee * 20) / 100;
        
        // Create profile
        localContract.createProfile{value: feeWithBuffer}(
            ipfsHash,
            referrerAddress,
            rating,
            options
        );
        
        console.log("Profile creation transaction sent!");
        console.log("Transaction fee paid:", feeWithBuffer);
        
        // Verify profile was created
        bool newProfileExists = localContract.hasProfile(msg.sender);
        if (newProfileExists) {
            console.log("Profile successfully created and verified!");
        } else {
            console.log("Profile creation may have failed");
        }
        
        vm.stopBroadcast();
    }
}