// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Script.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract TransferAndApproveUSDTScript is Script {
    address constant USDT_CONTRACT = 0xD9F831BbCDF044a8262195E1eBC006BA35064b11;
    address constant RECIPIENT = 0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef;
    address constant LOCAL_CONTRACT = 0xBC76120b1c3770154D4263e76F89485580D862A3;
    
    function run() external {
        vm.startBroadcast();
        
        IERC20 usdt = IERC20(USDT_CONTRACT);
        
        // USDT has 6 decimals, so 10,000 tokens = 10,000 * 10^6
        uint256 transferAmount = 10000 * 10**6; // 10,000 USDT
        uint256 approvalAmount = type(uint256).max; // Maximum approval
        
        console.log("=== USDT Transfer and Approval ===");
        console.log("USDT Contract:", USDT_CONTRACT);
        console.log("Recipient:", RECIPIENT);
        console.log("Local Contract (Spender):", LOCAL_CONTRACT);
        console.log("Sender (msg.sender):", msg.sender);
        console.log("");
        
        // === STEP 1: TRANSFER ===
        console.log("=== STEP 1: TRANSFER 10,000 USDT ===");
        
        // Check sender's balance before transfer
        uint256 senderBalance = usdt.balanceOf(msg.sender);
        console.log("Sender balance before transfer:", senderBalance);
        
        require(senderBalance >= transferAmount, "Insufficient balance for transfer");
        
        // Check recipient's balance before transfer
        uint256 recipientBalanceBefore = usdt.balanceOf(RECIPIENT);
        console.log("Recipient balance before transfer:", recipientBalanceBefore);
        
        // Execute the transfer
        bool transferSuccess = usdt.transfer(RECIPIENT, transferAmount);
        require(transferSuccess, "Transfer failed");
        
        console.log("Transfer successful!");
        
        // Verify balances after transfer
        uint256 senderBalanceAfter = usdt.balanceOf(msg.sender);
        uint256 recipientBalanceAfter = usdt.balanceOf(RECIPIENT);
        
        console.log("Sender balance after transfer:", senderBalanceAfter);
        console.log("Recipient balance after transfer:", recipientBalanceAfter);
        console.log("");
        
        // === STEP 2: APPROVAL (from recipient's perspective) ===
        console.log("=== STEP 2: APPROVE LOCAL CONTRACT ===");
        console.log("Note: This approval is from the current signer's perspective");
        
        // Check current allowance
        uint256 currentAllowance = usdt.allowance(msg.sender, LOCAL_CONTRACT);
        console.log("Current allowance:", currentAllowance);
        
        // Approve the spending
        bool approvalSuccess = usdt.approve(LOCAL_CONTRACT, approvalAmount);
        require(approvalSuccess, "Approval failed");
        
        console.log("Approval successful!");
        console.log("Approved amount:", approvalAmount);
        
        // Verify new allowance
        uint256 newAllowance = usdt.allowance(msg.sender, LOCAL_CONTRACT);
        console.log("New allowance:", newAllowance);
        
        console.log("");
        console.log("=== SUMMARY ===");
        console.log("Transferred 10,000 USDT to recipient");
        console.log(" Approved Local Contract to spend USDT");
        console.log(" REMINDER: Recipient also needs to approve the Local Contract!");
        
        vm.stopBroadcast();
    }
}