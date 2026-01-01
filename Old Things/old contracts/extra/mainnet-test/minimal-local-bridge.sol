// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OAppSender, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MinimalLocalBridge - Profile Messaging Only
 * @dev Stripped down LayerZero bridge for profile creation cost testing
 */
contract MinimalLocalBridge is OAppSender, OAppReceiver {
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;
    
    // Chain endpoint for native chain
    uint32 public nativeChainEid;
    
    // Events
    event ProfileMessageSent(address indexed user, string ipfsHash, address referrer, uint256 fee);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event NativeChainEidUpdated(uint32 newEid);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    constructor(
        address _endpoint,
        address _owner,
        uint32 _nativeChainEid
    ) OAppCore(_endpoint, _owner) Ownable(_owner) {
        nativeChainEid = _nativeChainEid;
    }
    
    // Override the conflicting oAppVersion function
    function oAppVersion() public pure override(OAppReceiver, OAppSender) returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }
    
    // Override to allow insufficient fee for testing
    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert("Insufficient native fee");
        return _nativeFee;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setAuthorizedContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }
    
    function setNativeChainEid(uint32 _nativeChainEid) external onlyOwner {
        nativeChainEid = _nativeChainEid;
        emit NativeChainEidUpdated(_nativeChainEid);
    }
    
    // ==================== PROFILE MESSAGING ====================
    
    /**
     * @dev Send createProfile message to native chain
     * @param _functionName Function identifier (should be "createProfile")
     * @param _payload Encoded profile data
     * @param _options LayerZero execution options
     */
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata _options
    ) external payable onlyAuthorized {
        require(keccak256(bytes(_functionName)) == keccak256("createProfile"), "Only profile creation supported");
        
        // Send via LayerZero
        _lzSend(
            nativeChainEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        // Decode payload for event emission
        (string memory funcName, address user, string memory ipfsHash, address referrer) = 
            abi.decode(_payload, (string, address, string, address));
        
        emit ProfileMessageSent(user, ipfsHash, referrer, msg.value);
    }
    
    /**
     * @dev Quote fee for sending profile to native chain
     * @param _payload Encoded profile data
     * @param _options LayerZero execution options
     * @return fee Required native token amount
     */
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata _options
    ) external view returns (uint256 fee) {
        MessagingFee memory messagingFee = _quote(nativeChainEid, _payload, _options, false);
        return messagingFee.nativeFee;
    }
    
    /**
     * @dev Batch quote for multiple profile creations
     * @param payloads Array of encoded profile data
     * @param options LayerZero execution options
     * @return fees Array of individual fees
     * @return totalFee Sum of all fees
     */
    function quoteBatchProfiles(
        bytes[] calldata payloads,
        bytes calldata options
    ) external view returns (uint256[] memory fees, uint256 totalFee) {
        fees = new uint256[](payloads.length);
        
        for (uint i = 0; i < payloads.length; i++) {
            MessagingFee memory messagingFee = _quote(nativeChainEid, payloads[i], options, false);
            fees[i] = messagingFee.nativeFee;
            totalFee += fees[i];
        }
    }
    
    // ==================== INCOMING MESSAGE HANDLING ====================
    
    /**
     * @dev Handle incoming LayerZero messages (minimal implementation)
     * @param _origin Message origin information
     * @param _payload Message payload
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /* _guid */,
        bytes calldata _payload,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) internal override {
        // For testing bridge, just emit event on received messages
        // In production, this would route to appropriate contracts
        emit MessageReceived(_origin.srcEid, _payload);
    }
    
    event MessageReceived(uint32 indexed sourceChain, bytes payload);
    
    // ==================== VIEW FUNCTIONS ====================
    
    function isAuthorizedContract(address _contract) external view returns (bool) {
        return authorizedContracts[_contract];
    }
    
    function getNativeChainEid() external view returns (uint32) {
        return nativeChainEid;
    }
    
    // ==================== UTILITY FUNCTIONS ====================
    
    /**
     * @dev Get minimal LayerZero options for cost optimization
     * @param gasLimit Gas limit for destination execution
     * @return options Encoded minimal options
     */
    function getMinimalOptions(uint128 gasLimit) external pure returns (bytes memory options) {
        return abi.encodePacked(
            uint16(3),      // option type (lzReceive with gas)
            gasLimit,       // gas limit
            uint128(0)      // msg.value (0 for profiles)
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