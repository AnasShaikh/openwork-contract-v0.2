// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MinimalFundLockTest {
    using SafeERC20 for IERC20;
    
    IERC20 public usdtToken;
    
    // Dummy storage for testing gas costs
    mapping(string => uint256) public jobLockedAmounts;
    
    event USDTEscrowed(string indexed jobId, address indexed jobGiver, uint256 amount);
    
    constructor(address _usdtToken) {
        usdtToken = IERC20(_usdtToken);
    }
    
    // Complex postJob function mimicking the native contract for gas testing
    function postJobComplex(
        string memory _jobDetailHash, 
        string[] memory _descriptions, 
        uint256[] memory _amounts
    ) external {
        // Mimic complex validation logic without restrictions for testing
        uint256 calculatedTotal = 0;
        for (uint i = 0; i < _amounts.length; i++) {
            calculatedTotal += _amounts[i];
        }
        
        // Generate dummy job ID with complex string operations
        string memory jobId = string(abi.encodePacked("eth-", _jobDetailHash, "-", block.timestamp));
        
        // Store milestone data in complex structures (mimics job creation)
        for (uint i = 0; i < _descriptions.length; i++) {
            string memory milestoneKey = string(abi.encodePacked(jobId, "-milestone-", i));
            jobLockedAmounts[milestoneKey] = _amounts[i];
        }
        
        // Store main job data
        jobLockedAmounts[jobId] = calculatedTotal;
        
        // Multiple storage operations
        jobLockedAmounts[string(abi.encodePacked(jobId, "-status"))] = 1; // Open status
        jobLockedAmounts[string(abi.encodePacked(jobId, "-milestone-count"))] = _descriptions.length;
        jobLockedAmounts[string(abi.encodePacked(jobId, "-creator"))] = uint256(uint160(msg.sender));
        
        // Emit events similar to the original contract
        emit USDTEscrowed(jobId, msg.sender, calculatedTotal);
        emit JobPosted(jobId, msg.sender, _jobDetailHash);
        emit JobStatusChanged(jobId, 1); // Open status
    }
    
    // Additional events to match original contract complexity
    event JobPosted(string indexed jobId, address indexed jobGiver, string jobDetailHash);
    event JobStatusChanged(string indexed jobId, uint256 newStatus);
    
    // Function to check locked amount (for testing)
    function getLockedAmount(string memory jobId) external view returns (uint256) {
        return jobLockedAmounts[jobId];
    }
    
    // Emergency withdraw function
    function emergencyWithdraw() external {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No USDT balance");
        usdtToken.safeTransfer(msg.sender, balance);
    }
}