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

interface IRewardsContract {
    function handleSyncClaimableRewards(address user, uint256 claimableAmount, uint32 sourceDomain) external;
}

interface IMainDAO {
    function handleSyncVotingPower(address user, uint256 totalRewards, uint32 sourceDomain) external;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

contract HyperlaneMainChainBridge is Ownable {
    
    IMailbox public immutable mailbox;
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;
    
    // Contract addresses for routing incoming messages
    address public mainDaoContract;
    address public rewardsContract;
    
    // Chain domains - this bridge handles multiple destination chains
    uint32 public nativeChainDomain;      // Chain where Native contracts are deployed
    uint32 public athenaClientChainDomain; // Chain where AthenaClient is deployed
    uint32 public lowjcChainDomain;       // Chain where LOWJC is deployed
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstDomain, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceDomain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainDomainUpdated(string indexed chainType, uint32 newDomain);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeCommandSent(uint32 indexed targetChain, address indexed targetProxy, address indexed newImplementation);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    modifier onlyMailbox() {
        require(msg.sender == address(mailbox), "Only mailbox can call");
        _;
    }
    
    modifier onlyMainDAO() {
        require(msg.sender == mainDaoContract, "Only Main DAO can call this function");
        _;
    }
    
    constructor(
        address _mailbox,
        address _owner,
        uint32 _nativeChainDomain,
        uint32 _athenaClientChainDomain,
        uint32 _lowjcChainDomain
    ) Ownable(_owner) {
        mailbox = IMailbox(_mailbox);
        nativeChainDomain = _nativeChainDomain;
        athenaClientChainDomain = _athenaClientChainDomain;
        lowjcChainDomain = _lowjcChainDomain;
    }
    
    // ==================== UPGRADE FUNCTIONALITY ====================
    
    function sendUpgradeCommand(
        uint32 _dstChainDomain,
        address targetProxy,
        address newImplementation,
        bytes calldata /* _options */
    ) external payable onlyMainDAO {
        // encode the call for the receiving side
        bytes memory payload = abi.encode("upgradeFromDAO", targetProxy, newImplementation);
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));

        mailbox.dispatch{value: msg.value}(
            _dstChainDomain,
            recipientAddress,
            payload
        );

        emit UpgradeCommandSent(_dstChainDomain, targetProxy, newImplementation);
    }
    
    function quoteUpgradeCommand(
        uint32 targetChainDomain,
        address targetProxy,
        address newImplementation
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode("upgradeContract", targetProxy, newImplementation);
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(targetChainDomain, recipientAddress, payload);
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
        (string memory functionName) = abi.decode(_message, (string));
        
        // ==================== UPGRADE HANDLING ====================
        if (keccak256(bytes(functionName)) == keccak256(bytes("upgradeContract"))) {
            // This should never be called on main chain bridge
            // Upgrade commands are sent FROM here, not TO here
            revert("Upgrade commands should originate from Main DAO, not be received");
        }
        
        // ==================== REWARDS CONTRACT MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("syncClaimableRewards"))) {
            require(rewardsContract != address(0), "Rewards contract not set");
            (, address user, uint256 claimableAmount) = abi.decode(_message, (string, address, uint256));
            IRewardsContract(rewardsContract).handleSyncClaimableRewards(user, claimableAmount, _origin);
        }

        else if (keccak256(bytes(functionName)) == keccak256(bytes("syncVotingPower"))) {
            require(mainDaoContract != address(0), "Main DAO contract not set");
            (, address user, uint256 totalRewards) = abi.decode(_message, (string, address, uint256));
            IMainDAO(mainDaoContract).handleSyncVotingPower(user, totalRewards, _origin);
        }
        
        // ==================== UNKNOWN FUNCTION ====================
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
    
    function sendToAthenaClientChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        mailbox.dispatch{value: msg.value}(
            athenaClientChainDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, athenaClientChainDomain, _payload);
    }
    
    function sendToLowjcChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        mailbox.dispatch{value: msg.value}(
            lowjcChainDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, lowjcChainDomain, _payload);
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
    
    function sendToTwoChains(
        string memory _functionName,
        uint32 _dstDomain1,
        uint32 _dstDomain2,
        bytes memory _payload1,
        bytes memory _payload2,
        bytes calldata /* _options1 */,
        bytes calldata /* _options2 */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        // Calculate total fees upfront
        uint256 fee1 = mailbox.quoteDispatch(_dstDomain1, recipientAddress, _payload1);
        uint256 fee2 = mailbox.quoteDispatch(_dstDomain2, recipientAddress, _payload2);
        uint256 totalFee = fee1 + fee2;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to first chain
        mailbox.dispatch{value: fee1}(
            _dstDomain1,
            recipientAddress,
            _payload1
        );
        
        // Send to second chain
        mailbox.dispatch{value: fee2}(
            _dstDomain2,
            recipientAddress,
            _payload2
        );
        
        emit CrossChainMessageSent(_functionName, _dstDomain1, _payload1);
        emit CrossChainMessageSent(_functionName, _dstDomain2, _payload2);
    }
    
    function sendToThreeChains(
        string memory _functionName,
        uint32 _dstDomain1,
        uint32 _dstDomain2,
        uint32 _dstDomain3,
        bytes memory _payload1,
        bytes memory _payload2,
        bytes memory _payload3,
        bytes calldata /* _options1 */,
        bytes calldata /* _options2 */,
        bytes calldata /* _options3 */
    ) external payable onlyAuthorized {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        // Calculate total fees upfront
        uint256 fee1 = mailbox.quoteDispatch(_dstDomain1, recipientAddress, _payload1);
        uint256 fee2 = mailbox.quoteDispatch(_dstDomain2, recipientAddress, _payload2);
        uint256 fee3 = mailbox.quoteDispatch(_dstDomain3, recipientAddress, _payload3);
        uint256 totalFee = fee1 + fee2 + fee3;
        
        require(msg.value >= totalFee, "Insufficient fee provided");
        
        // Send to all three chains
        mailbox.dispatch{value: fee1}(_dstDomain1, recipientAddress, _payload1);
        mailbox.dispatch{value: fee2}(_dstDomain2, recipientAddress, _payload2);
        mailbox.dispatch{value: fee3}(_dstDomain3, recipientAddress, _payload3);
        
        emit CrossChainMessageSent(_functionName, _dstDomain1, _payload1);
        emit CrossChainMessageSent(_functionName, _dstDomain2, _payload2);
        emit CrossChainMessageSent(_functionName, _dstDomain3, _payload3);
    }
    
    // ==================== QUOTE FUNCTIONS ====================
    
    function quoteNativeChain(
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(nativeChainDomain, recipientAddress, _payload);
    }
    
    function quoteAthenaClientChain(
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(athenaClientChainDomain, recipientAddress, _payload);
    }
    
    function quoteLowjcChain(
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(lowjcChainDomain, recipientAddress, _payload);
    }
    
    function quoteSpecificChain(
        uint32 _dstDomain,
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        return mailbox.quoteDispatch(_dstDomain, recipientAddress, _payload);
    }
    
    function quoteTwoChains(
        uint32 _dstDomain1,
        uint32 _dstDomain2,
        bytes calldata _payload1,
        bytes calldata _payload2,
        bytes calldata /* _options1 */,
        bytes calldata /* _options2 */
    ) external view returns (uint256 totalFee, uint256 fee1, uint256 fee2) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        fee1 = mailbox.quoteDispatch(_dstDomain1, recipientAddress, _payload1);
        fee2 = mailbox.quoteDispatch(_dstDomain2, recipientAddress, _payload2);
        totalFee = fee1 + fee2;
    }
    
    function quoteThreeChains(
        uint32 _dstDomain1,
        uint32 _dstDomain2,
        uint32 _dstDomain3,
        bytes calldata _payload1,
        bytes calldata _payload2,
        bytes calldata _payload3,
        bytes calldata /* _options1 */,
        bytes calldata /* _options2 */,
        bytes calldata /* _options3 */
    ) external view returns (uint256 totalFee, uint256 fee1, uint256 fee2, uint256 fee3) {
        bytes32 recipientAddress = bytes32(uint256(uint160(address(this))));
        
        fee1 = mailbox.quoteDispatch(_dstDomain1, recipientAddress, _payload1);
        fee2 = mailbox.quoteDispatch(_dstDomain2, recipientAddress, _payload2);
        fee3 = mailbox.quoteDispatch(_dstDomain3, recipientAddress, _payload3);
        totalFee = fee1 + fee2 + fee3;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }
    
    function setMainDaoContract(address _mainDao) external onlyOwner {
        require(_mainDao != address(0), "Invalid main DAO address");
        mainDaoContract = _mainDao;
        emit ContractAddressSet("mainDao", _mainDao);
    }
    
    function setRewardsContract(address _rewards) external onlyOwner {
        rewardsContract = _rewards;
        emit ContractAddressSet("rewards", _rewards);
    }
    
    function updateNativeChainDomain(uint32 _nativeChainDomain) external onlyOwner {
        nativeChainDomain = _nativeChainDomain;
        emit ChainDomainUpdated("native", _nativeChainDomain);
    }
    
    function updateAthenaClientChainDomain(uint32 _athenaClientChainDomain) external onlyOwner {
        athenaClientChainDomain = _athenaClientChainDomain;
        emit ChainDomainUpdated("athenaClient", _athenaClientChainDomain);
    }
    
    function updateLowjcChainDomain(uint32 _lowjcChainDomain) external onlyOwner {
        lowjcChainDomain = _lowjcChainDomain;
        emit ChainDomainUpdated("lowjc", _lowjcChainDomain);
    }
    
    function updateChainDomains(uint32 _nativeChainDomain, uint32 _athenaClientChainDomain, uint32 _lowjcChainDomain) external onlyOwner {
        nativeChainDomain = _nativeChainDomain;
        athenaClientChainDomain = _athenaClientChainDomain;
        lowjcChainDomain = _lowjcChainDomain;
        emit ChainDomainUpdated("native", _nativeChainDomain);
        emit ChainDomainUpdated("athenaClient", _athenaClientChainDomain);
        emit ChainDomainUpdated("lowjc", _lowjcChainDomain);
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
}