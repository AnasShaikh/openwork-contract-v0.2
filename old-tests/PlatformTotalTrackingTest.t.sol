// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/rewards-tracking-contract.sol";
import "../src/maindao.sol";

// Minimal mock for testing
contract MinimalMockERC20 {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

contract CorePlatformTotalTest is Test {
    RewardsTrackingContract public rewardsContract;
    maindao public mainDAO;
    MinimalMockERC20 public mockToken;
    
    address public owner = address(this);
    address public jobGiver = address(0x1);
    address public freelancer = address(0x2);
    
    function setUp() public {
        mockToken = new MinimalMockERC20();
        mainDAO = new maindao(address(mockToken));
        rewardsContract = new RewardsTrackingContract(owner);
        
        // Only set MainDAO in rewards contract (no authorization needed for this)
        rewardsContract.setMainDAO(address(mainDAO));
    }
    
    function testRewardsContractPlatformTotal() public {
        // Test that rewards contract can track platform total
        assertEq(rewardsContract.currentTotalPlatformPayments(), 0);
        
        console.log("Initial platform total in rewards contract:", rewardsContract.currentTotalPlatformPayments());
        console.log("Test passed: Rewards contract platform total tracking");
    }
    
    function testMainDAOPlatformTotal() public {
        // Test MainDAO platform total tracking
        assertEq(mainDAO.totalPlatformPayments(), 0);
        assertEq(mainDAO.getTotalPlatformPayments(), 0);
        
        console.log("Initial platform total in MainDAO:", mainDAO.totalPlatformPayments());
        console.log("Test passed: MainDAO platform total tracking");
    }
    
    function testRewardsContractOwnerFunctions() public {
        // Test owner-only functions in rewards contract
        
        // Update user tokens (owner function)
        rewardsContract.updateUserTotalOWTokens(jobGiver, 1000 * 1e18);
        assertEq(rewardsContract.getUserTotalOWTokens(jobGiver), 1000 * 1e18);
        
        // Update user earnings (owner function)
        rewardsContract.updateUserCumulativeEarnings(jobGiver, 500 * 1e6);
        assertEq(rewardsContract.getUserCumulativeEarnings(jobGiver), 500 * 1e6);
        
        console.log("Test passed: Rewards contract owner functions");
    }
    
    function testTokenCalculations() public {
        // Test the token calculation logic
        
        // Test basic calculation for first band (0-500)
        uint256 tokens = rewardsContract.calculateTokensForRange(0, 100 * 1e6);
        uint256 expected = 100 * 1e6 * 100000 * 1e18 / 1e6; // 100 USDT * 100,000 OW per USDT
        assertEq(tokens, expected);
        
        console.log("Tokens for 100 USDT:", tokens);
        console.log("Expected tokens:", expected);
        console.log("Test passed: Token calculations");
    }
    
    function testRewardBandsStructure() public {
        // Test that reward bands are properly initialized
        uint256 bandCount = rewardsContract.getRewardBandsCount();
        assertGt(bandCount, 0);
        
        // Test first band
        (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) = rewardsContract.getRewardBand(0);
        assertEq(minAmount, 0);
        assertEq(maxAmount, 500 * 1e6);
        assertEq(owPerDollar, 100000 * 1e18);
        
        console.log("Total reward bands:", bandCount);
        console.log("First band - Min:", minAmount);
        console.log("First band - Max:", maxAmount);
        console.log("First band - Rate:", owPerDollar);
        console.log("Test passed: Reward bands structure");
    }
    
    function testCalculateTokensForAmount() public {
        // Test the public function for calculating tokens
        
        // For a user with no previous earnings, calculate tokens for 200 USDT
        uint256 tokens = rewardsContract.calculateTokensForAmount(jobGiver, 200 * 1e6);
        
        // Should be 200 * 100,000 = 20,000,000 tokens
        uint256 expected = 200 * 1e6 * 100000 * 1e18 / 1e6;
        assertEq(tokens, expected);
        
        console.log("Tokens for 200 USDT (new user):", tokens);
        console.log("Test passed: Calculate tokens for amount");
    }
    
    function testPlatformTotalGettersOnly() public {
        // Just test that all the getter functions work
        
        // Rewards contract getters
        uint256 rewardsTotal = rewardsContract.currentTotalPlatformPayments();
        assertEq(rewardsTotal, 0);
        
        // MainDAO getters
        uint256 mainDAOTotal1 = mainDAO.totalPlatformPayments();
        uint256 mainDAOTotal2 = mainDAO.getTotalPlatformPayments();
        assertEq(mainDAOTotal1, 0);
        assertEq(mainDAOTotal2, 0);
        assertEq(mainDAOTotal1, mainDAOTotal2);
        
        console.log("All platform total getters return 0 initially");
        console.log("Test passed: Platform total getters");
    }
}