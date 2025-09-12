// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Sample USDT Contract
 * @dev ERC-20 compatible stablecoin contract with additional features
 * @notice This is a sample implementation for educational purposes
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract SampleUSDT is IERC20 {
    string public name = "Sample Tether USD";
    string public symbol = "USDT";
    uint8 public decimals = 6; // USDT uses 6 decimals
    uint256 private _totalSupply;
    
    address public owner;
    bool public paused = false;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public blacklisted;
    
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Pause();
    event Unpause();
    event Blacklist(address indexed account);
    event Unblacklist(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Account is blacklisted");
        _;
    }
    
    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        _totalSupply = _initialSupply * 10**decimals;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    // ERC-20 Functions
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) 
        public 
        override 
        whenNotPaused 
        notBlacklisted(msg.sender) 
        notBlacklisted(recipient) 
        returns (bool) 
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address tokenOwner, address spender) 
        public 
        view 
        override 
        returns (uint256) 
    {
        return _allowances[tokenOwner][spender];
    }
    
    function approve(address spender, uint256 amount) 
        public 
        override 
        whenNotPaused 
        notBlacklisted(msg.sender) 
        returns (bool) 
    {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) 
        public 
        override 
        whenNotPaused 
        notBlacklisted(sender) 
        notBlacklisted(recipient) 
        returns (bool) 
    {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    // Internal functions
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        require(_balances[sender] >= amount, "Transfer amount exceeds balance");
        
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        require(tokenOwner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }
    
    // Owner functions
    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Mint to zero address");
        
        _totalSupply += amount;
        _balances[to] += amount;
        
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }
    
    function burn(uint256 amount) public onlyOwner {
        require(_balances[msg.sender] >= amount, "Burn amount exceeds balance");
        
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        
        emit Burn(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function pause() public onlyOwner {
        paused = true;
        emit Pause();
    }
    
    function unpause() public onlyOwner {
        paused = false;
        emit Unpause();
    }
    
    function addToBlacklist(address account) public onlyOwner {
        blacklisted[account] = true;
        emit Blacklist(account);
    }
    
    function removeFromBlacklist(address account) public onlyOwner {
        blacklisted[account] = false;
        emit Unblacklist(account);
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // Emergency function to destroy blacklisted funds
    function destroyBlackFunds(address blacklistedUser) public onlyOwner {
        require(blacklisted[blacklistedUser], "Account is not blacklisted");
        uint256 dirtyFunds = _balances[blacklistedUser];
        _balances[blacklistedUser] = 0;
        _totalSupply -= dirtyFunds;
        emit Transfer(blacklistedUser, address(0), dirtyFunds);
    }
    
    // View functions
    function isPaused() public view returns (bool) {
        return paused;
    }
    
    function isBlacklisted(address account) public view returns (bool) {
        return blacklisted[account];
    }
}