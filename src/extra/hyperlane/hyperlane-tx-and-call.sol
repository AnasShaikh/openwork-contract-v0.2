// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Minimal interfaces
interface IHyperlaneWarpRoute {
    function transferRemote(uint32 _destinationDomain, bytes32 _recipient, uint256 _amount) external payable returns (bytes32);
    function quoteGasPayment(uint32 _destinationDomain) external view returns (uint256);
}

interface IInterchainAccountRouter {
    function getRemoteInterchainAccount(uint32 destination, address owner) external view returns (address);
    function callRemote(uint32 destination, CallLib.Call[] calldata calls) external payable returns (bytes32);
    function quoteGasPayment(uint32 destination) external view returns (uint256);
}

library CallLib {
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }
}

contract MinimalTransferAndCallDemo is Ownable {
    
    IERC20 public usdcToken;
    IHyperlaneWarpRoute public warpRoute;
    IInterchainAccountRouter public icaRouter;
    
    // Simple job tracking
    mapping(string => uint256) public escrowedJobs;
    
    // Events
    event JobEscrowed(string jobId, uint256 amount, uint32 destinationChain);
    event JobReleased(string jobId, address recipient, uint256 amount);
    
    constructor(
        address _usdc,
        address _warpRoute, 
        address _icaRouter
    ) Ownable(msg.sender) {
        usdcToken = IERC20(_usdc);
        warpRoute = IHyperlaneWarpRoute(_warpRoute);
        icaRouter = IInterchainAccountRouter(_icaRouter);
    }
    
    // Demo: Escrow funds on destination chain
    function escrowOnDestination(
        string memory jobId,
        uint256 amount,
        uint32 destinationChain,
        address destinationContract
    ) external payable {
        // Transfer USDC from user
        usdcToken.transferFrom(msg.sender, address(this), amount);
        
        // Get ICA address on destination
        address ica = icaRouter.getRemoteInterchainAccount(destinationChain, address(this));
        
        // Quote fees
        uint256 warpFee = warpRoute.quoteGasPayment(destinationChain);
        uint256 icaFee = icaRouter.quoteGasPayment(destinationChain);
        require(msg.value >= warpFee + icaFee, "Insufficient gas");
        
        // Step 1: Send USDC to ICA
        usdcToken.approve(address(warpRoute), amount);
        warpRoute.transferRemote{value: warpFee}(
            destinationChain,
            bytes32(uint256(uint160(ica))),
            amount
        );
        
        // Step 2: Call destination contract to setup escrow
        CallLib.Call[] memory calls = new CallLib.Call[](2);
        calls[0] = CallLib.Call({
            to: address(usdcToken),
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", destinationContract, amount)
        });
        calls[1] = CallLib.Call({
            to: destinationContract,
            value: 0,
            data: abi.encodeWithSignature("receiveEscrow(string,uint256)", jobId, amount)
        });
        
        icaRouter.callRemote{value: icaFee}(destinationChain, calls);
        
        emit JobEscrowed(jobId, amount, destinationChain);
    }
    
    // Demo: Receive escrow from other chains
    function receiveEscrow(string memory jobId, uint256 amount) external {
        // Transfer from ICA to this contract
        usdcToken.transferFrom(msg.sender, address(this), amount);
        escrowedJobs[jobId] = amount;
    }
    
    // Demo: Release escrowed funds
    function releaseEscrow(string memory jobId, address recipient) external onlyOwner {
        uint256 amount = escrowedJobs[jobId];
        require(amount > 0, "No escrow found");
        
        escrowedJobs[jobId] = 0;
        usdcToken.transfer(recipient, amount);
        
        emit JobReleased(jobId, recipient, amount);
    }
    
    // View functions
    function getEscrow(string memory jobId) external view returns (uint256) {
        return escrowedJobs[jobId];
    }
    
    function getICA(uint32 destinationChain) external view returns (address) {
        return icaRouter.getRemoteInterchainAccount(destinationChain, address(this));
    }
    
    function quoteFees(uint32 destinationChain) external view returns (uint256 warpFee, uint256 icaFee, uint256 total) {
        warpFee = warpRoute.quoteGasPayment(destinationChain);
        icaFee = icaRouter.quoteGasPayment(destinationChain);
        total = warpFee + icaFee;
    }
}