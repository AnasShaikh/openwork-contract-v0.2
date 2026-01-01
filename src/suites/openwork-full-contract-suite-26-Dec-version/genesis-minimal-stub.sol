// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title GenesisMinimalStub
 * @notice Minimal Genesis contract stub for callback compatibility
 * @dev Temporary solution - deploy full Genesis later and upgrade
 */
contract GenesisMinimalStub is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // Authorized contracts that can call updateUserClaimData
    mapping(address => bool) public authorizedContracts;

    // Track total claimed tokens per user
    mapping(address => uint256) public userTotalClaimedTokens;

    event ContractAuthorized(address indexed contractAddress, bool status);
    event UserClaimDataUpdated(address indexed user, uint256 claimedAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    function authorizeContract(address contractAddress, bool status) external onlyOwner {
        authorizedContracts[contractAddress] = status;
        emit ContractAuthorized(contractAddress, status);
    }

    function updateUserClaimData(address user, uint256 claimedAmount) external onlyAuthorized {
        userTotalClaimedTokens[user] += claimedAmount;
        emit UserClaimDataUpdated(user, claimedAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
