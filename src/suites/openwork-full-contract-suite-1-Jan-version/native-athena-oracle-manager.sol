// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Interface for Native Athena to check voting eligibility
interface INativeAthena {
    function canVote(address account) external view returns (bool);
    function minOracleMembers() external view returns (uint256);
    function updateOracleActiveStatus(string memory oracleName) external;
}

// Interface for OpenworkGenesis storage contract
interface IOpenworkGenesis {
    struct Oracle {
        string name;
        address[] members;
        string shortDescription;
        string hashOfDetails;
        address[] skillVerifiedAddresses;
    }
    
    // Oracle setters
    function setOracle(string memory name, address[] memory members, string memory shortDescription, string memory hashOfDetails, address[] memory skillVerifiedAddresses) external;
    function addOracleMember(string memory oracleName, address member) external;
    function removeOracleMember(string memory oracleName, address memberToRemove) external;
    
    // Oracle getters
    function getOracle(string memory oracleName) external view returns (Oracle memory);
}

contract NativeAthenaOracleManager is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // Contract references
    IOpenworkGenesis public genesis;
    INativeAthena public nativeAthena;

    // Access control
    mapping(address => bool) public authorizedCallers;

    // Governance/Admin pattern
    mapping(address => bool) public admins;
    address public mainDAO;

    // Storage gap for upgrade safety
    uint256[50] private __gap;

    // Events
    event GenesisUpdated(address indexed oldGenesis, address indexed newGenesis);
    event NativeAthenaUpdated(address indexed oldAthena, address indexed newAthena);
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event OracleCreated(string indexed oracleName, uint256 memberCount);
    event OracleMemberAdded(string indexed oracleName, address indexed member);
    event OracleMemberRemoved(string indexed oracleName, address indexed member);
    event OracleRemoved(string indexed oracleName);
    event AdminUpdated(address indexed admin, bool status);
    event MainDAOUpdated(address indexed oldDAO, address indexed newDAO);
    
    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner,
        address _genesis,
        address _nativeAthena
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        genesis = IOpenworkGenesis(_genesis);
        nativeAthena = INativeAthena(_nativeAthena);
        admins[_owner] = true;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(admins[_msgSender()], "Admin");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setGenesis(address _genesis) external onlyOwner {
        address oldGenesis = address(genesis);
        genesis = IOpenworkGenesis(_genesis);
        emit GenesisUpdated(oldGenesis, _genesis);
    }
    
    function setNativeAthena(address _nativeAthena) external onlyOwner {
        address oldAthena = address(nativeAthena);
        nativeAthena = INativeAthena(_nativeAthena);
        emit NativeAthenaUpdated(oldAthena, _nativeAthena);
    }
    
    function setAuthorizedCaller(address _caller, bool _authorized) external onlyOwner {
        authorizedCallers[_caller] = _authorized;
        emit AuthorizedCallerUpdated(_caller, _authorized);
    }

    function setAdmin(address _admin, bool _status) external {
        require(msg.sender == owner() || msg.sender == mainDAO, "Unauthorized");
        admins[_admin] = _status;
        emit AdminUpdated(_admin, _status);
    }

    function setMainDAO(address _mainDAO) external onlyOwner {
        address oldDAO = mainDAO;
        mainDAO = _mainDAO;
        emit MainDAOUpdated(oldDAO, _mainDAO);
    }
    
    // ==================== ORACLE MANAGEMENT FUNCTIONS ====================
    
    function addOrUpdateOracle(
        string[] memory _names,
        address[][] memory _members,
        string[] memory _shortDescriptions,
        string[] memory _hashOfDetails,
        address[][] memory _skillVerifiedAddresses
    ) external onlyAuthorized {
        require(_names.length == _members.length && 
                _names.length == _shortDescriptions.length &&
                _names.length == _hashOfDetails.length &&
                _names.length == _skillVerifiedAddresses.length, 
                "Array lengths must match");
        
        for (uint256 i = 0; i < _names.length; i++) {
            genesis.setOracle(_names[i], _members[i], _shortDescriptions[i], _hashOfDetails[i], _skillVerifiedAddresses[i]);
            emit OracleCreated(_names[i], _members[i].length);
        }
    }
    
    function addSingleOracle(
        string memory _name,
        address[] memory _members,
        string memory _shortDescription,
        string memory _hashOfDetails,
        address[] memory _skillVerifiedAddresses
    ) external onlyAuthorized {
        require(bytes(_name).length > 0, "Oracle name cannot be empty");
        // MODIFIED: Allow empty member arrays OR require minimum members
        require(_members.length == 0 || _members.length >= nativeAthena.minOracleMembers(), "Not enough members for oracle");
        
        // Verify all members meet voting requirements (only if members are provided)
        for (uint256 i = 0; i < _members.length; i++) {
            require(nativeAthena.canVote(_members[i]), "Member does not meet minimum stake/earned tokens requirement");
        }
        
        genesis.setOracle(_name, _members, _shortDescription, _hashOfDetails, _skillVerifiedAddresses);
        emit OracleCreated(_name, _members.length);
    }

    function addMembers(address[] memory _members, string memory _oracleName) external onlyAuthorized {
        // Check oracle exists in genesis
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        
        for (uint256 i = 0; i < _members.length; i++) {
            require(nativeAthena.canVote(_members[i]), "Member does not meet minimum stake/earned tokens requirement");
            genesis.addOracleMember(_oracleName, _members[i]);
            emit OracleMemberAdded(_oracleName, _members[i]);
        }
        
        // NEW: Auto-update oracle active status after adding members
        nativeAthena.updateOracleActiveStatus(_oracleName);
    }
    
    function removeMemberFromOracle(string memory _oracleName, address _memberToRemove) external onlyAuthorized {
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        require(bytes(oracle.name).length > 0, "Oracle not found");
        
        genesis.removeOracleMember(_oracleName, _memberToRemove);
        emit OracleMemberRemoved(_oracleName, _memberToRemove);
        
        // NEW: Auto-update oracle active status after removing member
        nativeAthena.updateOracleActiveStatus(_oracleName);
    }

    function removeOracle(string[] memory _oracleNames) external onlyAuthorized {
        for (uint256 i = 0; i < _oracleNames.length; i++) {
            // Set empty oracle to effectively remove it
            address[] memory emptyMembers = new address[](0);
            address[] memory emptySkillVerified = new address[](0);
            genesis.setOracle(_oracleNames[i], emptyMembers, "", "", emptySkillVerified);
            emit OracleRemoved(_oracleNames[i]);
        }
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getOracle(string memory _oracleName) external view returns (
        string memory name,
        address[] memory members,
        string memory shortDescription,
        string memory hashOfDetails,
        address[] memory skillVerifiedAddresses
    ) {
        IOpenworkGenesis.Oracle memory oracle = genesis.getOracle(_oracleName);
        return (
            oracle.name,
            oracle.members,
            oracle.shortDescription,
            oracle.hashOfDetails,
            oracle.skillVerifiedAddresses
        );
    }
}
