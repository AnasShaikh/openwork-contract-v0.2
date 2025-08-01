// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IMailbox {
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId);
    
    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external view returns (uint256 fee);
}

interface IAthenaClient {
    function handleFinalizeDisputeWithVotes(
        string memory disputeId, 
        bool winningSide, 
        uint256 votesFor, 
        uint256 votesAgainst,
        address[] memory voters,
        address[] memory claimAddresses,
        uint256[] memory votingPowers,
        bool[] memory voteDirections
    ) external;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

contract HyperlaneBridge is Ownable {
    
    IMailbox public immutable mailbox;
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;
    
    // Contract addresses for routing incoming messages
    address public athenaClientContract;
    address public lowjcContract;
    
    // Chain domains - Hyperlane domain IDs
    uint32 public nativeChainDomain;
    uint32 public mainChainDomain;        // Main/Rewards chain (single)
    uint32 public thisLocalChainDomain;   // This local chain's domain
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstDomain, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceDomain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainDomainUpdated(string indexed chainType, uint32 newDomain);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeExecuted(address indexed targetProxy, address indexed newImplementation, uint32 indexed sourceDomain);
    event ThisLocalChainDomainUpdated(uint32 oldDomain, uint32 newDomain);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    modifier onlyMailbox() {
        require(msg.sender == address(mailbox), "Only mailbox can call");
        _;
    }
    
    constructor(
        address _mailbox,
        address _owner,
        uint32 _nativeChainDomain,
        uint32 _mainChainDomain,
        uint32 _thisLocalChainDomain
    ) Ownable(_owner) {
        mailbox = IMailbox(_mailbox);
        nativeChainDomain = _nativeChainDomain;
        mainChainDomain = _mainChainDomain;
        thisLocalChainDomain = _thisLocalChainDomain;
    }
    
    // ==================== HYPERLANE MESSAGE HANDLING ====================
    
    /**
     * @dev Handle incoming messages from Hyperlane
     * This is the function that Hyperlane calls when delivering a message
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external onlyMailbox {
        // Extract function name from message
        (string memory functionName) = abi.decode(_message, (string));

        // --- 1) UPGRADE HANDLING ---
        if (keccak256(bytes(functionName)) == keccak256("upgradeFromDAO")) {
            require(_origin == mainChainDomain, "Upgrade commands only from main chain");
            (, address targetProxy, address newImplementation) =
                abi.decode(_message, (string, address, address));
            require(targetProxy != address(0), "Invalid target proxy address");
            require(newImplementation != address(0), "Invalid implementation address");
            IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
            emit UpgradeExecuted(targetProxy, newImplementation, _origin);
        }

        // --- 2) ATHENA CLIENT MESSAGES ---
        else if (keccak256(bytes(functionName)) == keccak256("finalizeDisputeWithVotes")) {
            (, string memory disputeId, bool winningSide, uint256 votesFor, uint256 votesAgainst,
             address[] memory voters, address[] memory claimAddresses, 
             uint256[] memory votingPowers, bool[] memory voteDirections) =
                abi.decode(_message, (string, string, bool, uint256, uint256, address[], address[], uint256[], bool[]));
            
            IAthenaClient(athenaClientContract).handleFinalizeDisputeWithVotes(
                disputeId, winningSide, votesFor, votesAgainst,
                voters, claimAddresses, votingPowers, voteDirections
            );
        }

        // --- 3) unknown function → revert ---
        else {
            revert("Unknown function call");
        }

        emit CrossChainMessageReceived(functionName, _origin, _message);
    }
    
    // ==================== BRIDGE FUNCTIONS ====================
    
    function sendToNativeChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        mailbox.dispatch{value: msg.value}(
            nativeChainDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, nativeChainDomain, _payload);
    }
    
    function sendToMainChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        mailbox.dispatch{value: msg.value}(
            mainChainDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, mainChainDomain, _payload);
    }
    
    function sendToTwoChains(
        string memory _functionName,
        bytes memory _mainChainPayload,
        bytes memory _nativePayload,
        bytes calldata /* _mainChainOptions */,
        bytes calldata /* _nativeOptions */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        // Calculate fees upfront
        uint256 mainChainFee = mailbox.quoteDispatch(mainChainDomain, recipientAddress, _mainChainPayload);
        uint256 nativeFee = mailbox.quoteDispatch(nativeChainDomain, recipientAddress, _nativePayload);
        uint256 totalFee = mainChainFee + nativeFee;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to main chain
        mailbox.dispatch{value: mainChainFee}(
            mainChainDomain,
            recipientAddress,
            _mainChainPayload
        );
        
        // Send to native chain
        mailbox.dispatch{value: nativeFee}(
            nativeChainDomain,
            recipientAddress,
            _nativePayload
        );
        
        emit CrossChainMessageSent(_functionName, mainChainDomain, _mainChainPayload);
        emit CrossChainMessageSent(_functionName, nativeChainDomain, _nativePayload);
    }
    
    function sendToSpecificChain(
        string memory _functionName,
        uint32 _dstDomain,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        mailbox.dispatch{value: msg.value}(
            _dstDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, _dstDomain, _payload);
    }
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(nativeChainDomain, recipientAddress, _payload);
    }
    
    function quoteMainChain(
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(mainChainDomain, recipientAddress, _payload);
    }
    
    function quoteTwoChains(
        bytes calldata _mainChainPayload,
        bytes calldata _nativePayload,
        bytes calldata /* _mainChainOptions */,
        bytes calldata /* _nativeOptions */
    ) external view returns (uint256 totalFee, uint256 mainChainFee, uint256 nativeFee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        mainChainFee = mailbox.quoteDispatch(mainChainDomain, recipientAddress, _mainChainPayload);
        nativeFee = mailbox.quoteDispatch(nativeChainDomain, recipientAddress, _nativePayload);
        totalFee = mainChainFee + nativeFee;
    }
    
    function quoteSpecificChain(
        uint32 _dstDomain,
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(_dstDomain, recipientAddress, _payload);
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }
    
    function setAthenaClientContract(address _athenaClient) external onlyOwner {
        athenaClientContract = _athenaClient;
        emit ContractAddressSet("athenaClient", _athenaClient);
    }
    
    function setLowjcContract(address _lowjc) external onlyOwner {
        lowjcContract = _lowjc;
        emit ContractAddressSet("lowjc", _lowjc);
    }
    
    function updateNativeChainDomain(uint32 _nativeChainDomain) external onlyOwner {
        nativeChainDomain = _nativeChainDomain;
        emit ChainDomainUpdated("native", _nativeChainDomain);
    }
    
    function updateMainChainDomain(uint32 _mainChainDomain) external onlyOwner {
        mainChainDomain = _mainChainDomain;
        emit ChainDomainUpdated("main", _mainChainDomain);
    }
    
    function updateThisLocalChainDomain(uint32 _thisLocalChainDomain) external onlyOwner {
        uint32 oldDomain = thisLocalChainDomain;
        thisLocalChainDomain = _thisLocalChainDomain;
        emit ThisLocalChainDomainUpdated(oldDomain, _thisLocalChainDomain);
    }
    
    function updateChainDomains(uint32 _nativeChainDomain, uint32 _mainChainDomain, uint32 _thisLocalChainDomain) external onlyOwner {
        nativeChainDomain = _nativeChainDomain;
        mainChainDomain = _mainChainDomain;
        thisLocalChainDomain = _thisLocalChainDomain;
        emit ChainDomainUpdated("native", _nativeChainDomain);
        emit ChainDomainUpdated("main", _mainChainDomain);
        emit ThisLocalChainDomainUpdated(thisLocalChainDomain, _thisLocalChainDomain);
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getMailbox() external view returns (address) {
        return address(mailbox);
    }
    
    function getLocalDomain() external view returns (uint32) {
        return thisLocalChainDomain;
    }
}