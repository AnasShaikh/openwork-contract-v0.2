// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RewardsCalculator {
    struct RewardBand {
        uint256 minValue;       // Minimum USD value for this band
        uint256 maxValue;       // Maximum USD value for this band
        uint256 rewardPerAction; // OW tokens per governance action (scaled by 1e18)
    }
    
    RewardBand[] public rewardBands;
    address public owner;
    
    event RewardBandUpdated(uint256 indexed bandIndex, uint256 minValue, uint256 maxValue, uint256 rewardPerAction);
    event RewardBandAdded(uint256 indexed bandIndex, uint256 minValue, uint256 maxValue, uint256 rewardPerAction);
    event RewardBandRemoved(uint256 indexed bandIndex);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(address _owner) {
        owner = _owner;
        _initializeRewardBands();
    }
    
    function _initializeRewardBands() private {
        // Initialize with the provided rewards table
        // All values are in wei (1e18) for precision
        
        rewardBands.push(RewardBand(0, 500 * 1e18, 100000 * 1e18));                    // $0 - $500: 100,000 OW
        rewardBands.push(RewardBand(500 * 1e18, 1000 * 1e18, 50000 * 1e18));          // $500 - $1,000: 50,000 OW
        rewardBands.push(RewardBand(1000 * 1e18, 2000 * 1e18, 25000 * 1e18));         // $1,000 - $2,000: 25,000 OW
        rewardBands.push(RewardBand(2000 * 1e18, 4000 * 1e18, 12500 * 1e18));         // $2,000 - $4,000: 12,500 OW
        rewardBands.push(RewardBand(4000 * 1e18, 8000 * 1e18, 6250 * 1e18));          // $4,000 - $8,000: 6,250 OW
        rewardBands.push(RewardBand(8000 * 1e18, 16000 * 1e18, 3125 * 1e18));         // $8,000 - $16,000: 3,125 OW
        rewardBands.push(RewardBand(16000 * 1e18, 32000 * 1e18, 1562 * 1e18));        // $16,000 - $32,000: 1,562 OW
        rewardBands.push(RewardBand(32000 * 1e18, 64000 * 1e18, 781 * 1e18));         // $32,000 - $64,000: 781 OW
        rewardBands.push(RewardBand(64000 * 1e18, 128000 * 1e18, 391 * 1e18));        // $64,000 - $128,000: 391 OW
        rewardBands.push(RewardBand(128000 * 1e18, 256000 * 1e18, 196 * 1e18));       // $128,000 - $256,000: 196 OW
        rewardBands.push(RewardBand(256000 * 1e18, 512000 * 1e18, 98 * 1e18));        // $256,000 - $512,000: 98 OW
        rewardBands.push(RewardBand(512000 * 1e18, 1024000 * 1e18, 49 * 1e18));       // $512,000 - $1.024M: 49 OW
        rewardBands.push(RewardBand(1024000 * 1e18, 2048000 * 1e18, 24 * 1e18));      // $1.024M - $2.048M: 24 OW
        rewardBands.push(RewardBand(2048000 * 1e18, 4096000 * 1e18, 12 * 1e18));      // $2.048M - $4.096M: 12 OW
        rewardBands.push(RewardBand(4096000 * 1e18, 8192000 * 1e18, 6 * 1e18));       // $4.096M - $8.192M: 6 OW
        rewardBands.push(RewardBand(8192000 * 1e18, 16384000 * 1e18, 3 * 1e18));      // $8.192M - $16.384M: 3 OW
        rewardBands.push(RewardBand(16384000 * 1e18, 32768000 * 1e18, 15 * 1e17));    // $16.384M - $32.768M: 1.5 OW
        rewardBands.push(RewardBand(32768000 * 1e18, 65536000 * 1e18, 75 * 1e16));    // $32.768M - $65.536M: 0.75 OW
        rewardBands.push(RewardBand(65536000 * 1e18, 131072000 * 1e18, 38 * 1e16));   // $65.536M - $131.072M: 0.38 OW
        rewardBands.push(RewardBand(131072000 * 1e18, 262144000 * 1e18, 19 * 1e16));  // $131.072M - $262.144M: 0.19 OW
    }
    
    function getCurrentRewardPerAction(uint256 totalPlatformValue) external view returns (uint256) {
        for (uint256 i = 0; i < rewardBands.length; i++) {
            if (totalPlatformValue >= rewardBands[i].minValue && totalPlatformValue <= rewardBands[i].maxValue) {
                return rewardBands[i].rewardPerAction;
            }
        }
        
        // If platform value exceeds all bands, return the lowest reward
        if (rewardBands.length > 0) {
            return rewardBands[rewardBands.length - 1].rewardPerAction;
        }
        
        return 0;
    }
    
    function calculateTotalRewards(uint256 governanceActions, uint256 totalPlatformValue) external view returns (uint256) {
        uint256 rewardPerAction = this.getCurrentRewardPerAction(totalPlatformValue);
        return governanceActions * rewardPerAction;
    }
    
    function getRewardBandCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minValue, uint256 maxValue, uint256 rewardPerAction) {
        require(index < rewardBands.length, "Band index out of range");
        RewardBand memory band = rewardBands[index];
        return (band.minValue, band.maxValue, band.rewardPerAction);
    }
    
    function getCurrentBandIndex(uint256 totalPlatformValue) external view returns (uint256) {
        for (uint256 i = 0; i < rewardBands.length; i++) {
            if (totalPlatformValue >= rewardBands[i].minValue && totalPlatformValue <= rewardBands[i].maxValue) {
                return i;
            }
        }
        // Return last band index if value exceeds all bands
        return rewardBands.length > 0 ? rewardBands.length - 1 : 0;
    }
    
    // Admin functions to modify reward bands
    function updateRewardBand(uint256 index, uint256 minValue, uint256 maxValue, uint256 rewardPerAction) external onlyOwner {
        require(index < rewardBands.length, "Band index out of range");
        require(minValue <= maxValue, "Invalid value range");
        
        rewardBands[index] = RewardBand(minValue, maxValue, rewardPerAction);
        emit RewardBandUpdated(index, minValue, maxValue, rewardPerAction);
    }
    
    function addRewardBand(uint256 minValue, uint256 maxValue, uint256 rewardPerAction) external onlyOwner {
        require(minValue <= maxValue, "Invalid value range");
        
        rewardBands.push(RewardBand(minValue, maxValue, rewardPerAction));
        emit RewardBandAdded(rewardBands.length - 1, minValue, maxValue, rewardPerAction);
    }
    
    function removeRewardBand(uint256 index) external onlyOwner {
        require(index < rewardBands.length, "Band index out of range");
        require(rewardBands.length > 1, "Cannot remove last band");
        
        // Move the last element to the deleted spot and remove the last element
        rewardBands[index] = rewardBands[rewardBands.length - 1];
        rewardBands.pop();
        
        emit RewardBandRemoved(index);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}