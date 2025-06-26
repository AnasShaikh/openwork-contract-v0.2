// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/maindao.sol";
import "../src/rewards-calc-maindao.sol";

// Mock ERC20 for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract RewardsClaimingTest is Test {
    maindao public dao;
    RewardsCalculator public rewardsCalc;
    MockERC20 public token;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token = new MockERC20();
        rewardsCalc = new RewardsCalculator(address(this));
        dao = new maindao(address(token), address(rewardsCalc));
        
        // Give DAO tokens for rewards
        token.mint(address(dao), 10000000 * 1e18);
        
        // Setup users as earners
        dao.addOrUpdateEarner(alice, 500 * 1e18, 0, 0, 100 * 1e18);
        dao.addOrUpdateEarner(bob, 300 * 1e18, 0, 0, 100 * 1e18);
    }

    function testClaimRewardsBasic() public {
        // Alice performs 3 governance actions in first band ($100 platform value)
        dao.addOrUpdateEarner(alice, 500 * 1e18, 3, 0, 100 * 1e18);
        
        // Should get 3 * 100,000 = 300,000 OW tokens
        uint256 expectedReward = 3 * 100000 * 1e18;
        assertEq(dao.getClaimableRewards(alice), expectedReward);
        
        uint256 balanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        dao.claimRewards();
        
        assertEq(token.balanceOf(alice), balanceBefore + expectedReward);
        assertEq(dao.claimedRewards(alice), expectedReward);
        assertEq(dao.getClaimableRewards(alice), 0);
    }

    function testClaimRewardsAfterPlatformGrowth() public {
        // Alice has 2 actions, platform grows from $100 to $750 (first to second band)
        dao.addOrUpdateEarner(alice, 500 * 1e18, 2, 0, 750 * 1e18);
        
        // Should get 2 * 50,000 = 100,000 OW tokens (second band rate)
        uint256 expectedReward = 2 * 50000 * 1e18;
        assertEq(dao.getClaimableRewards(alice), expectedReward);
        
        vm.prank(alice);
        dao.claimRewards();
        
        assertEq(dao.claimedRewards(alice), expectedReward);
    }

    function testIncrementalClaiming() public {
        // Alice starts with 2 actions
        dao.addOrUpdateEarner(alice, 500 * 1e18, 2, 0, 100 * 1e18);
        
        // Claims first batch
        vm.prank(alice);
        dao.claimRewards();
        
        uint256 firstClaim = 2 * 100000 * 1e18;
        assertEq(dao.claimedRewards(alice), firstClaim);
        
        // Alice performs 2 more actions (total 4)
        dao.addOrUpdateEarner(alice, 500 * 1e18, 4, 0, 100 * 1e18);
        
        // Should be able to claim for 2 additional actions
        uint256 additionalClaimable = 2 * 100000 * 1e18;
        assertEq(dao.getClaimableRewards(alice), additionalClaimable);
        
        vm.prank(alice);
        dao.claimRewards();
        
        assertEq(dao.claimedRewards(alice), 4 * 100000 * 1e18);
    }

    function testGetUserRewardInfo() public {
        dao.addOrUpdateEarner(alice, 500 * 1e18, 5, 0, 100 * 1e18);
        
        (uint256 actions, uint256 totalRewards, uint256 claimed, uint256 claimable, uint256 currentRate) = 
            dao.getUserRewardInfo(alice);
        
        assertEq(actions, 5);
        assertEq(totalRewards, 5 * 100000 * 1e18);
        assertEq(claimed, 0);
        assertEq(claimable, 5 * 100000 * 1e18);
        assertEq(currentRate, 100000 * 1e18);
    }

    function testErrorConditions() public {
        // Non-earner trying to claim
        address stranger = makeAddr("stranger");
        vm.expectRevert("User is not an earner");
        vm.prank(stranger);
        dao.claimRewards();
        
        // Earner with no actions
        vm.expectRevert("No governance actions performed");
        vm.prank(alice);
        dao.claimRewards();
        
        // Double claiming
        dao.addOrUpdateEarner(bob, 300 * 1e18, 1, 0, 100 * 1e18);
        vm.prank(bob);
        dao.claimRewards();
        
        vm.expectRevert("No rewards to claim");
        vm.prank(bob);
        dao.claimRewards();
    }

    function testRewardsAcrossBands() public {
        // Test rewards in first band
        assertEq(dao.getCurrentRewardPerAction(), 100000 * 1e18);
        
        // Move to second band by updating earner with higher platform total
        dao.addOrUpdateEarner(alice, 500 * 1e18, 1, 0, 750 * 1e18);
        assertEq(dao.getCurrentRewardPerAction(), 50000 * 1e18);
        
        // Move to third band by updating earner with even higher platform total
        dao.addOrUpdateEarner(alice, 500 * 1e18, 3, 0, 1500 * 1e18);
        assertEq(dao.getCurrentRewardPerAction(), 25000 * 1e18);
        
        // Alice should get rewards for 3 actions at third band rate
        assertEq(dao.getClaimableRewards(alice), 3 * 25000 * 1e18);
    }
}