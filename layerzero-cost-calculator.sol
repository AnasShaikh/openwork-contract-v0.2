// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface ILayerZeroBridge {
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
}

/**
 * @title LayerZero Cost Calculator for CreateProfile
 * @dev Calculate minimal costs before executing createProfile
 */
contract LayerZeroCostCalculator {
    
    ILayerZeroBridge public bridge;
    
    constructor(address _bridge) {
        bridge = ILayerZeroBridge(_bridge);
    }
    
    /**
     * @dev Get the exact cost for createProfile LayerZero message
     * @param userAddress The user creating profile
     * @param ipfsHash The IPFS hash for profile data
     * @param referrerAddress The referrer address (can be address(0))
     * @param options LayerZero execution options (gas limit, etc.)
     * @return totalFee Total ETH needed for the cross-chain message
     */
    function quoteCCreateProfile(
        address userAddress,
        string memory ipfsHash,
        address referrerAddress,
        bytes calldata options
    ) external view returns (uint256 totalFee) {
        // Encode the exact same payload as createProfile function
        bytes memory payload = abi.encode("createProfile", userAddress, ipfsHash, referrerAddress);
        
        // Get LayerZero quote for native chain
        totalFee = bridge.quoteNativeChain(payload, options);
        
        return totalFee;
    }
    
    /**
     * @dev Get cost breakdown for multiple users (batch optimization)
     */
    function quoteBatchCreateProfile(
        address[] calldata users,
        string[] calldata ipfsHashes,
        address[] calldata referrers,
        bytes calldata options
    ) external view returns (uint256[] memory fees, uint256 totalCost) {
        require(users.length == ipfsHashes.length && users.length == referrers.length, "Array length mismatch");
        
        fees = new uint256[](users.length);
        
        for (uint i = 0; i < users.length; i++) {
            bytes memory payload = abi.encode("createProfile", users[i], ipfsHashes[i], referrers[i]);
            fees[i] = bridge.quoteNativeChain(payload, options);
            totalCost += fees[i];
        }
    }
    
    /**
     * @dev Get minimal options for cost optimization
     * @param gasLimit Gas limit for destination execution (minimum ~100k)
     * @return options Encoded options for minimal cost
     */
    function getMinimalOptions(uint128 gasLimit) external pure returns (bytes memory options) {
        // LayerZero V2 options format: type(3) + gasLimit + value(0)
        // Type 3 = lzReceive with gas limit
        return abi.encodePacked(
            uint16(3),      // option type
            gasLimit,       // gas limit
            uint128(0)      // msg.value (0 for createProfile)
        );
    }
}