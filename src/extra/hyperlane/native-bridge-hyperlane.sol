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

interface INativeDAO {
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external;
}

interface INativeAthena {
    function handleRaiseDispute(string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) external;
    function handleSubmitSkillVerification(address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) external;
    function handleAskAthena(address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) external;
}

interface INativeOpenWorkJobContract {
    function createProfile(address user, string memory ipfsHash, address referrer) external;
    function postJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external;
    function applyToJob(address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) external;
    function startJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external;
    function submitWork(address applicant, string memory jobId, string memory submissionHash) external;
    function releasePayment(address jobGiver, string memory jobId, uint256 amount) external;
    function lockNextMilestone(address caller, string memory jobId, uint256 lockedAmount) external;
    function releasePaymentAndLockNext(address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) external;
    function rate(address rater, string memory jobId, address userToRate, uint256 rating) external;
    function addPortfolio(address user, string memory portfolioHash) external;
    function incrementGovernanceAction(address user) external;
    function handleUpdateUserClaimData(address user, uint256 claimedTokens) external;
}

interface IUpgradeable {
    function upgradeFromDAO(address newImplementation) external;
}

contract HyperlaneNativeBridge is Ownable {
    
    IMailbox public immutable mailbox;
    
    // Authorized contracts that can use the bridge
    mapping(address => bool) public authorizedContracts;
    
    // Contract addresses for routing incoming messages
    address public nativeDaoContract;
    address public nativeAthenaContract;
    address public nativeOpenWorkJobContract;
    
    // NEW: Multiple Local Chains Support
    mapping(uint32 => bool) public authorizedLocalChains;
    uint32[] public localChainDomains;
    
    // Chain domains - Hyperlane domain IDs
    uint32 public mainChainDomain;        // Main/Rewards chain (single)
    
    // NEW: Recipient address management for cross-chain messages
    mapping(uint32 => address) public chainRecipients;
    
    // Events
    event CrossChainMessageSent(string indexed functionName, uint32 dstDomain, bytes payload);
    event CrossChainMessageReceived(string indexed functionName, uint32 indexed sourceDomain, bytes data);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ChainDomainUpdated(string indexed chainType, uint32 newDomain);
    event ContractAddressSet(string indexed contractType, address contractAddress);
    event UpgradeExecuted(address indexed targetProxy, address indexed newImplementation, uint32 indexed sourceDomain);
    event LocalChainAdded(uint32 indexed localChainDomain);
    event LocalChainRemoved(uint32 indexed localChainDomain);
    event RecipientAddressSet(uint32 indexed chainDomain, address indexed recipientAddress);
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to use bridge");
        _;
    }
    
    modifier onlyMailbox() {
        require(msg.sender == address(mailbox), "Only mailbox can call");
        _;
    }
    
    modifier onlyMainChain() {
        require(msg.sender == address(this), "Only main chain can call this function");
        _;
    }
    
    constructor(
        address _mailbox,
        address _owner,
        uint32 _mainChainDomain
    ) Ownable(_owner) {
        mailbox = IMailbox(_mailbox);
        mainChainDomain = _mainChainDomain;
    }
    
    // ==================== LOCAL CHAIN MANAGEMENT ====================
    
    function addLocalChain(uint32 _localChainDomain) external onlyOwner {
        require(!authorizedLocalChains[_localChainDomain], "Local chain already authorized");
        authorizedLocalChains[_localChainDomain] = true;
        localChainDomains.push(_localChainDomain);
        emit LocalChainAdded(_localChainDomain);
    }
    
    function removeLocalChain(uint32 _localChainDomain) external onlyOwner {
        require(authorizedLocalChains[_localChainDomain], "Local chain not authorized");
        authorizedLocalChains[_localChainDomain] = false;
        
        // Remove from array
        for (uint256 i = 0; i < localChainDomains.length; i++) {
            if (localChainDomains[i] == _localChainDomain) {
                localChainDomains[i] = localChainDomains[localChainDomains.length - 1];
                localChainDomains.pop();
                break;
            }
        }
        emit LocalChainRemoved(_localChainDomain);
    }
    
    function getLocalChains() external view returns (uint32[] memory) {
        return localChainDomains;
    }
    
    // ==================== JOB ID PARSING UTILITY ====================
    
    function extractDomainFromJobId(string memory jobId) internal pure returns (uint32) {
        bytes memory jobIdBytes = bytes(jobId);
        uint256 dashIndex = 0;
        
        // Find the dash position
        for (uint256 i = 0; i < jobIdBytes.length; i++) {
            if (jobIdBytes[i] == '-') {
                dashIndex = i;
                break;
            }
        }
        
        require(dashIndex > 0, "Invalid job ID format");
        
        // Extract domain part (before dash)
        uint32 domain = 0;
        for (uint256 i = 0; i < dashIndex; i++) {
            require(jobIdBytes[i] >= '0' && jobIdBytes[i] <= '9', "Invalid domain in job ID");
            domain = domain * 10 + uint32(uint8(jobIdBytes[i]) - 48);
        }
        
        return domain;
    }
    
    // ==================== UPGRADE FUNCTIONALITY ====================
    
    function handleUpgradeContract(address targetProxy, address newImplementation) external onlyMainChain {
        require(targetProxy != address(0), "Invalid target proxy address");
        require(newImplementation != address(0), "Invalid implementation address");
        
        // Execute the upgrade
        IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
        
        emit UpgradeExecuted(targetProxy, newImplementation, mainChainDomain);
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
        if (keccak256(bytes(functionName)) == keccak256("upgradeFromDAO")) {
            require(_origin == mainChainDomain, "Upgrade commands only from main chain");
            (, address targetProxy, address newImplementation) = 
                abi.decode(_message, (string, address, address));
            require(targetProxy != address(0), "Invalid target proxy address");
            require(newImplementation != address(0), "Invalid implementation address");
            IUpgradeable(targetProxy).upgradeFromDAO(newImplementation);
            emit UpgradeExecuted(targetProxy, newImplementation, _origin);
        }

        // ==================== NATIVE DAO MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("updateStakeData"))) {
            require(nativeDaoContract != address(0), "Native DAO contract not set");
            (, address staker, uint256 amount, uint256 unlockTime, uint256 durationMinutes, bool isActive) = abi.decode(_message, (string, address, uint256, uint256, uint256, bool));
            INativeDAO(nativeDaoContract).updateStakeData(staker, amount, unlockTime, durationMinutes, isActive);
        }

        // ==================== NATIVE ATHENA MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("raiseDispute"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, string memory jobId, string memory disputeHash, string memory oracleName, uint256 fee, address disputeRaiser) = abi.decode(_message, (string, string, string, string, uint256, address));
            INativeAthena(nativeAthenaContract).handleRaiseDispute(jobId, disputeHash, oracleName, fee, disputeRaiser);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitSkillVerification"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, address applicant, string memory applicationHash, uint256 feeAmount, string memory targetOracleName) = abi.decode(_message, (string, address, string, uint256, string));
            INativeAthena(nativeAthenaContract).handleSubmitSkillVerification(applicant, applicationHash, feeAmount, targetOracleName);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("askAthena"))) {
            require(nativeAthenaContract != address(0), "Native Athena contract not set");
            (, address applicant, string memory description, string memory hash, string memory targetOracle, string memory fees) = abi.decode(_message, (string, address, string, string, string, string));
            INativeAthena(nativeAthenaContract).handleAskAthena(applicant, description, hash, targetOracle, fees);
        }
        
        // ==================== NATIVE OPENWORK JOB CONTRACT MESSAGES ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("createProfile"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user, string memory ipfsHash, address referrer) = abi.decode(_message, (string, address, string, address));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).createProfile(user, ipfsHash, referrer);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("postJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(_message, (string, string, address, string, string[], uint256[]));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).postJob(jobId, jobGiver, jobDetailHash, descriptions, amounts);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("applyToJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address applicant, string memory jobId, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts) = abi.decode(_message, (string, address, string, string, string[], uint256[]));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).applyToJob(applicant, jobId, applicationHash, descriptions, amounts);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("startJob"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) = abi.decode(_message, (string, address, string, uint256, bool));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).startJob(jobGiver, jobId, applicationId, useApplicantMilestones);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("submitWork"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address applicant, string memory jobId, string memory submissionHash) = abi.decode(_message, (string, address, string, string));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).submitWork(applicant, jobId, submissionHash);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePayment"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 amount) = abi.decode(_message, (string, address, string, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).releasePayment(jobGiver, jobId, amount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("lockNextMilestone"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address caller, string memory jobId, uint256 lockedAmount) = abi.decode(_message, (string, address, string, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).lockNextMilestone(caller, jobId, lockedAmount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("releasePaymentAndLockNext"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address jobGiver, string memory jobId, uint256 releasedAmount, uint256 lockedAmount) = abi.decode(_message, (string, address, string, uint256, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).releasePaymentAndLockNext(jobGiver, jobId, releasedAmount, lockedAmount);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("rate"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address rater, string memory jobId, address userToRate, uint256 rating) = abi.decode(_message, (string, address, string, address, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).rate(rater, jobId, userToRate, rating);
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("addPortfolio"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user, string memory portfolioHash) = abi.decode(_message, (string, address, string));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).addPortfolio(user, portfolioHash);
        }
        // ==================== GOVERNANCE ACTION HANDLING ====================
        else if (keccak256(bytes(functionName)) == keccak256(bytes("incrementGovernanceAction"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user) = abi.decode(_message, (string, address));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).incrementGovernanceAction(user);
        }
        else if (keccak256(bytes(functionName)) == keccak256(bytes("updateUserClaimData"))) {
            require(nativeOpenWorkJobContract != address(0), "Native OpenWork Job contract not set");
            (, address user, uint256 claimedAmount) = abi.decode(_message, (string, address, uint256));
            INativeOpenWorkJobContract(nativeOpenWorkJobContract).handleUpdateUserClaimData(user, claimedAmount);
        }
        
        // ==================== UNKNOWN FUNCTION ====================
        else {
            revert("Unknown function call");
        }
                    
        emit CrossChainMessageReceived(functionName, _origin, _message);
    }
    
    // ==================== BRIDGE FUNCTIONS ====================
    
    function sendToMainChain(
        string memory _functionName,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        address recipient = chainRecipients[mainChainDomain];
        require(recipient != address(0), "Main chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        
        mailbox.dispatch{value: msg.value}(
            mainChainDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, mainChainDomain, _payload);
    }
    
    function sendToLocalChain(
        string memory _disputeId,
        string memory _functionName,
        bytes memory _payload,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        uint32 targetDomain = extractDomainFromJobId(_disputeId);
        require(authorizedLocalChains[targetDomain], "Local chain not authorized");
        
        address recipient = chainRecipients[targetDomain];
        require(recipient != address(0), "Local chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        
        mailbox.dispatch{value: msg.value}(
            targetDomain,
            recipientAddress,
            _payload
        );
        
        emit CrossChainMessageSent(_functionName, targetDomain, _payload);
    }

    function sendSyncRewardsData(
        address user,
        uint256 claimableAmount,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes memory payload = abi.encode(
            "syncClaimableRewards",
            user,
            claimableAmount
        );
        
        address recipient = chainRecipients[mainChainDomain];
        require(recipient != address(0), "Main chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        
        mailbox.dispatch{value: msg.value}(
            mainChainDomain,
            recipientAddress,
            payload
        );
        
        emit CrossChainMessageSent("syncClaimableRewards", mainChainDomain, payload);
    }

    function sendSyncVotingPower(
        address user,
        uint256 totalRewards,
        bytes calldata /* _options */
    ) external payable onlyAuthorized {
        bytes memory payload = abi.encode(
            "syncVotingPower",
            user,
            totalRewards
        );
        
        address recipient = chainRecipients[mainChainDomain];
        require(recipient != address(0), "Main chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        
        mailbox.dispatch{value: msg.value}(
            mainChainDomain,
            recipientAddress,
            payload
        );
        
        emit CrossChainMessageSent("syncVotingPower", mainChainDomain, payload);
    }
    
    // ==================== QUOTE FUNCTIONS ====================

    function quoteSyncVotingPower(
        address user,
        uint256 totalRewards,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode(
            "syncVotingPower",
            user,
            totalRewards
        );
        address recipient = chainRecipients[mainChainDomain];
        require(recipient != address(0), "Main chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        return mailbox.quoteDispatch(mainChainDomain, recipientAddress, payload);
    }

    function quoteSyncRewardsData(
        address user,
        uint256 claimableAmount,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        bytes memory payload = abi.encode(
            "syncClaimableRewards",
            user,
            claimableAmount
        );
        address recipient = chainRecipients[mainChainDomain];
        require(recipient != address(0), "Main chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        return mailbox.quoteDispatch(mainChainDomain, recipientAddress, payload);
    }

    function quoteLocalChain(
        string memory _disputeId,
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        uint32 targetDomain = extractDomainFromJobId(_disputeId);
        require(authorizedLocalChains[targetDomain], "Local chain not authorized");
        
        address recipient = chainRecipients[targetDomain];
        require(recipient != address(0), "Local chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        return mailbox.quoteDispatch(targetDomain, recipientAddress, _payload);
    }

    function quoteMainChain(
        bytes calldata _payload,
        bytes calldata /* _options */
    ) external view returns (uint256 fee) {
        address recipient = chainRecipients[mainChainDomain];
        require(recipient != address(0), "Main chain recipient not set");
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        return mailbox.quoteDispatch(mainChainDomain, recipientAddress, _payload);
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
        address recipient1 = chainRecipients[_dstDomain1];
        address recipient2 = chainRecipients[_dstDomain2];
        address recipient3 = chainRecipients[_dstDomain3];
        require(recipient1 != address(0), "Chain 1 recipient not set");
        require(recipient2 != address(0), "Chain 2 recipient not set");
        require(recipient3 != address(0), "Chain 3 recipient not set");
        
        bytes32 recipientAddress1 = bytes32(uint256(uint160(recipient1)));
        bytes32 recipientAddress2 = bytes32(uint256(uint160(recipient2)));
        bytes32 recipientAddress3 = bytes32(uint256(uint160(recipient3)));
        
        fee1 = mailbox.quoteDispatch(_dstDomain1, recipientAddress1, _payload1);
        fee2 = mailbox.quoteDispatch(_dstDomain2, recipientAddress2, _payload2);
        fee3 = mailbox.quoteDispatch(_dstDomain3, recipientAddress3, _payload3);
        totalFee = fee1 + fee2 + fee3;
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function authorizeContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }
    
    function setNativeDaoContract(address _nativeDao) external onlyOwner {
        nativeDaoContract = _nativeDao;
        emit ContractAddressSet("nativeDao", _nativeDao);
    }
    
    function setNativeAthenaContract(address _nativeAthena) external onlyOwner {
        nativeAthenaContract = _nativeAthena;
        emit ContractAddressSet("nativeAthena", _nativeAthena);
    }
    
    function setNativeOpenWorkJobContract(address _nativeOpenWorkJob) external onlyOwner {
        nativeOpenWorkJobContract = _nativeOpenWorkJob;
        emit ContractAddressSet("nativeOpenWorkJob", _nativeOpenWorkJob);
    }
    
    // NEW: Recipient address management functions
    function setRecipientForChain(uint32 _chainDomain, address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");
        chainRecipients[_chainDomain] = _recipient;
        emit RecipientAddressSet(_chainDomain, _recipient);
    }
    
    function setRecipientsForChains(uint32[] calldata _chainDomains, address[] calldata _recipients) external onlyOwner {
        require(_chainDomains.length == _recipients.length, "Array length mismatch");
        
        for (uint256 i = 0; i < _chainDomains.length; i++) {
            require(_recipients[i] != address(0), "Invalid recipient address");
            chainRecipients[_chainDomains[i]] = _recipients[i];
            emit RecipientAddressSet(_chainDomains[i], _recipients[i]);
        }
    }
    
    function updateMainChainDomain(uint32 _mainChainDomain) external onlyOwner {
        mainChainDomain = _mainChainDomain;
        emit ChainDomainUpdated("main", _mainChainDomain);
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
    
    function getRecipientForChain(uint32 _chainDomain) external view returns (address) {
        return chainRecipients[_chainDomain];
    }
}