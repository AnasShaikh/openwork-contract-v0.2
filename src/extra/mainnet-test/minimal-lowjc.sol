// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IMinimalLayerZeroBridge {
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable;
    
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee);
}

/**
 * @title MinimalLOWJC - Profile Creation Only
 * @dev Stripped down version for LayerZero cost testing
 */
contract MinimalLocalOpenWorkJobContract is 
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    struct Profile {
        address userAddress;
        string ipfsHash;
        address referrerAddress;
        uint256 createdAt;
    }
    
    // State variables
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    uint256 public totalProfilesCreated;
    
    IMinimalLayerZeroBridge public bridge;
    uint32 public chainId;
    
    // Events
    event ProfileCreated(address indexed user, string ipfsHash, address referrer, uint256 timestamp);
    event BridgeSet(address indexed bridge);
    event ProfileCostQuoted(address indexed user, uint256 quotedFee);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner, 
        uint32 _chainId,
        address _bridge
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        chainId = _chainId;
        bridge = IMinimalLayerZeroBridge(_bridge);
        totalProfilesCreated = 0;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender(), "Unauthorized upgrade");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Bridge address cannot be zero");
        bridge = IMinimalLayerZeroBridge(_bridge);
        emit BridgeSet(_bridge);
    }
    
    // ==================== PROFILE MANAGEMENT ====================
    
    /**
     * @dev Create profile and send to native chain
     * @param _ipfsHash IPFS hash of profile data
     * @param _referrerAddress Referrer address (can be address(0))
     * @param _nativeOptions LayerZero options for native chain message
     */
    function createProfile(
        string memory _ipfsHash, 
        address _referrerAddress,
        bytes calldata _nativeOptions
    ) external payable nonReentrant {
        require(!hasProfile[msg.sender], "Profile already exists");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        
        // Create profile locally
        profiles[msg.sender] = Profile({
            userAddress: msg.sender,
            ipfsHash: _ipfsHash,
            referrerAddress: _referrerAddress,
            createdAt: block.timestamp
        });
        hasProfile[msg.sender] = true;
        totalProfilesCreated++;
        
        // Send to native chain via LayerZero
        bytes memory nativePayload = abi.encode("createProfile", msg.sender, _ipfsHash, _referrerAddress);
        bridge.sendToNativeChain{value: msg.value}("createProfile", nativePayload, _nativeOptions);
        
        emit ProfileCreated(msg.sender, _ipfsHash, _referrerAddress, block.timestamp);
    }
    
    /**
     * @dev Quote cost for createProfile cross-chain message
     * @param _ipfsHash IPFS hash of profile data
     * @param _referrerAddress Referrer address
     * @param _nativeOptions LayerZero options
     * @return fee Required ETH for the cross-chain message
     */
    function quoteCreateProfile(
        string memory _ipfsHash,
        address _referrerAddress,
        bytes calldata _nativeOptions
    ) external view returns (uint256 fee) {
        bytes memory nativePayload = abi.encode("createProfile", msg.sender, _ipfsHash, _referrerAddress);
        fee = bridge.quoteNativeChain(nativePayload, _nativeOptions);
        return fee;
    }
    
    /**
     * @dev Quote and emit event for gas estimation
     */
    function quoteAndEmitCreateProfile(
        string memory _ipfsHash,
        address _referrerAddress,
        bytes calldata _nativeOptions
    ) external {
        bytes memory nativePayload = abi.encode("createProfile", msg.sender, _ipfsHash, _referrerAddress);
        uint256 fee = bridge.quoteNativeChain(nativePayload, _nativeOptions);
        
        emit ProfileCostQuoted(msg.sender, fee);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getProfile(address _user) public view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }
    
    function getTotalProfilesCreated() external view returns (uint256) {
        return totalProfilesCreated;
    }
    
    function getChainId() external view returns (uint32) {
        return chainId;
    }
    
    function getBridgeAddress() external view returns (address) {
        return address(bridge);
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    /**
     * @dev Get minimal LayerZero options for cost optimization
     * @param gasLimit Gas limit for destination chain execution
     * @return options Encoded minimal options
     */
    function getMinimalOptions(uint128 gasLimit) external pure returns (bytes memory options) {
        // LayerZero V2 options: type(3) + gasLimit + value(0)
        return abi.encodePacked(
            uint16(3),      // option type (lzReceive with gas)
            gasLimit,       // gas limit for destination
            uint128(0)      // msg.value (0 for profile creation)
        );
    }
    
    /**
     * @dev Emergency withdrawal of ETH
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}