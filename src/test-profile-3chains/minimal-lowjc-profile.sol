// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MinimalLocalOpenWorkJobContract is OAppSender, ReentrancyGuard {
    
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
    }
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    
    // Chain endpoints for cross-chain communication
    uint32 public rewardsChainEid;    // Chain where RewardsContract is deployed
    uint32 public nativeChainEid;     // Chain where NativeOpenWorkJobContract is deployed
    
    // Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer);
    event CrossChainProfileCreated(address indexed user, string ipfsHash, address referrer, uint32[] dstEids);
    
    constructor(
        address _endpoint, 
        address _owner,
        uint32 _rewardsChainEid,
        uint32 _nativeChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        rewardsChainEid = _rewardsChainEid;
        nativeChainEid = _nativeChainEid;
    }
    
    // Override to change fee check from equivalency to < since batch fees are cumulative
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }
    
    /**
     * @notice Create profile locally and send cross-chain messages to both Rewards and Native contracts
     * @param _ipfsHash IPFS hash of the profile data
     * @param _referrerAddress Address of the referrer (can be address(0))
     * @param _rewardsOptions LayerZero options for rewards chain
     * @param _nativeOptions LayerZero options for native chain
     */
    function createProfile(
        string memory _ipfsHash,
        address _referrerAddress,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(!hasProfile[msg.sender], "Profile already exists");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        // Create profile locally first
        profiles[msg.sender] = Profile({
            userAddress: msg.sender,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress
        });
        hasProfile[msg.sender] = true;
        
        emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress);
        
        // Prepare cross-chain data
        uint32[] memory dstEids = new uint32[](2);
        bytes[] memory options = new bytes[](2);
        
        dstEids[0] = rewardsChainEid;
        dstEids[1] = nativeChainEid;
        options[0] = _rewardsOptions;
        options[1] = _nativeOptions;
        
        // Send to multiple chains using batch pattern from StringSender
        _sendProfileToMultipleChains(dstEids, msg.sender, _ipfsHash, _referrerAddress, options);
        
        emit CrossChainProfileCreated(msg.sender, _ipfsHash, _referrerAddress, dstEids);
    }
    
    /**
     * @notice Send profile creation to multiple chains (based on StringSender batch pattern)
     */
    function _sendProfileToMultipleChains(
        uint32[] memory _dstEids,
        address _user,
        string memory _ipfsHash,
        address _referrerAddress,
        bytes[] memory _options
    ) internal {
        require(_dstEids.length == _options.length, "Arrays length mismatch");
        require(_dstEids.length > 0, "No destinations provided");
        
        // Encode profile data as payload
        bytes memory payload = abi.encode(_user, _ipfsHash, _referrerAddress);
        
        // Calculate total fees upfront (fail-fast pattern)
        MessagingFee memory totalFee = _quoteMultiple(_dstEids, payload, _options);
        require(msg.value >= totalFee.nativeFee, "Insufficient fee provided");
        
        uint256 remainingValue = msg.value;
        
        // Send to all destination chains
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], payload, _options[i], false);
            
            remainingValue -= fee.nativeFee;
            require(remainingValue >= 0, "Insufficient fee for this destination");
            
            _lzSend(
                _dstEids[i],
                payload, 
                _options[i],
                fee,
                payable(msg.sender)
            );
        }
    }
    
    /**
     * @notice Internal function to calculate total fees for multiple destinations
     */
    function _quoteMultiple(
        uint32[] memory _dstEids,
        bytes memory _payload,
        bytes[] memory _options
    ) internal view returns (MessagingFee memory totalFee) {
        for (uint256 i = 0; i < _dstEids.length; i++) {
            MessagingFee memory fee = _quote(_dstEids[i], _payload, _options[i], false);
            totalFee.nativeFee += fee.nativeFee;
            totalFee.lzTokenFee += fee.lzTokenFee;
        }
    }
    
    /**
     * @notice Quote function for profile creation fees
     */
    function quoteCreateProfile(
        string calldata _ipfsHash,
        address _referrerAddress,
        bytes calldata _rewardsOptions,
        bytes calldata _nativeOptions
    ) external view returns (uint256 totalFee, uint256 rewardsFee, uint256 nativeFee) {
        bytes memory payload = abi.encode(msg.sender, _ipfsHash, _referrerAddress);
        
        MessagingFee memory msgFee1 = _quote(rewardsChainEid, payload, _rewardsOptions, false);
        MessagingFee memory msgFee2 = _quote(nativeChainEid, payload, _nativeOptions, false);
        
        rewardsFee = msgFee1.nativeFee;
        nativeFee = msgFee2.nativeFee;
        totalFee = rewardsFee + nativeFee;
    }
    
    /**
     * @notice Update chain endpoints (admin function)
     */
    function updateChainEndpoints(uint32 _rewardsChainEid, uint32 _nativeChainEid) external onlyOwner {
        rewardsChainEid = _rewardsChainEid;
        nativeChainEid = _nativeChainEid;
    }
    
    // View functions
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
}