// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "wormhole-solidity-sdk/interfaces/IERC20.sol";

/**
 * @title MinimalTest
 * @notice Test just the USDC transfer without any Wormhole/CCTP complexity
 */
contract MinimalTest {
    address public immutable USDC;
    
    event TestTransfer(address from, address to, uint256 amount);
    
    constructor(address _usdc) {
        USDC = _usdc;
    }
    
    function testUSDCTransfer(uint256 amount) external {
        // Just try the transferFrom that's failing
        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        emit TestTransfer(msg.sender, address(this), amount);
    }
    
    function checkAllowance(address owner) external view returns (uint256) {
        return IERC20(USDC).allowance(owner, address(this));
    }
    
    function checkBalance(address account) external view returns (uint256) {
        return IERC20(USDC).balanceOf(account);
    }
}