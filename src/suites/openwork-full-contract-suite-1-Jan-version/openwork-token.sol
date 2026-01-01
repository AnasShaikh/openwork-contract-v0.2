// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingToken
 * @dev ERC-20 token with voting capabilities compatible with OpenZeppelin Governor
 * 
 * Features:
 * - Standard ERC-20 functionality
 * - ERC20Permit for gasless approvals
 * - ERC20Votes for governance voting (checkpoints, delegation)
 * - Ownable for administrative functions
 */
contract VotingToken is ERC20, ERC20Permit, ERC20Votes, Ownable {

    // Initial supply of tokens (adjust as needed)
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens

    // Governance-only minting
    address public mainDAO;

    // Events
    event MainDAOUpdated(address indexed oldDAO, address indexed newDAO);

    /**
     * @dev Constructor that sets up the token with initial parameters
     * CRITICAL: Tokens auto-transferred to designated addresses for legal compliance
     * @param initialOwner Address that will own the contract (governance control only)
     * @param mainRewardsContract Address that receives 750M (600M earned + 150M team locked)
     * @param daoAddress Address for DAO (250M free tokens = preseed + treasury + team free)
     */
    constructor(
        address initialOwner,
        address mainRewardsContract,
        address daoAddress
    )
        ERC20("OpenWorkToken", "OWORK")
        ERC20Permit("OpenWorkToken")
        Ownable(initialOwner)
    {
        require(mainRewardsContract != address(0), "Invalid main rewards address");
        require(daoAddress != address(0), "Invalid DAO address");

        // Token Distribution (1B total):
        // 75% (750M) → Main Rewards (600M earned + 150M team locked, governance-unlocked)
        _mint(mainRewardsContract, 750_000_000 * 10**18);

        // 25% (250M) → DAO Treasury (preseed + treasury + team free, controlled by DAO)
        _mint(daoAddress, 250_000_000 * 10**18);

        // LEGAL COMPLIANCE: Owner wallet receives ZERO tokens
    }
    
    /**
     * @dev Mint new tokens (only mainDAO can call this)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == mainDAO, "Only DAO");
        _mint(to, amount);
    }

    /**
     * @dev Set the main DAO address (only owner can call this)
     * @param _mainDAO Address of the main DAO contract
     */
    function setMainDAO(address _mainDAO) external onlyOwner {
        require(_mainDAO != address(0), "Invalid DAO address");
        address oldDAO = mainDAO;
        mainDAO = _mainDAO;
        emit MainDAOUpdated(oldDAO, _mainDAO);
    }
    
    /**
     * @dev Burn tokens from caller's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
    
    /**
     * @dev Burn tokens from specified account (requires allowance)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) public {
        _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
    }
    
    // The following functions are overrides required by Solidity due to multiple inheritance
    
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }
    
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
