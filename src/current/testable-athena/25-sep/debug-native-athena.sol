// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DebugNativeAthena is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    
    // CCTP Integration for receiving fees
    IERC20 public usdcToken;
    uint256 public accumulatedFees;
    
    event FeePaymentProcessed(string indexed disputeId, address indexed recipient, uint256 amount);
    event DebugLog(string message, uint256 value);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _owner, 
        address _usdcToken
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        usdcToken = IERC20(_usdcToken);
        accumulatedFees = 0;
    }
    
    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender(), "Unauthorized upgrade");
    }
    
    function setAccumulatedFees(uint256 _amount) external onlyOwner {
        accumulatedFees = _amount;
    }
    
    /**
     * @notice Test fee payment distribution only
     */
    function testFeePayment(
        string memory _disputeId,
        address[] memory _recipients,
        address[] memory _claimAddresses,
        uint256[] memory _votingPowers,
        bool[] memory _voteDirections,
        bool _winningSide,
        uint256 _totalFees
    ) external {
        emit DebugLog("Starting testFeePayment", _totalFees);
        
        require(_recipients.length == _claimAddresses.length, "Array length mismatch");
        require(_totalFees <= accumulatedFees, "Insufficient accumulated fees");
        
        emit DebugLog("Passed basic checks", _recipients.length);
        
        // Calculate total winning voting power
        uint256 totalWinningVotingPower = 0;
        for (uint256 i = 0; i < _recipients.length; i++) {
            if (_voteDirections[i] == _winningSide) {
                totalWinningVotingPower += _votingPowers[i];
            }
        }
        
        emit DebugLog("Total winning voting power", totalWinningVotingPower);
        
        // Distribute fees to winning voters
        if (totalWinningVotingPower > 0) {
            for (uint256 i = 0; i < _recipients.length; i++) {
                if (_voteDirections[i] == _winningSide) {
                    uint256 voterShare = (_votingPowers[i] * _totalFees) / totalWinningVotingPower;
                    
                    emit DebugLog("Calculated voter share", voterShare);
                    
                    if (voterShare > 0) {
                        usdcToken.safeTransfer(_claimAddresses[i], voterShare);
                        emit FeePaymentProcessed(_disputeId, _claimAddresses[i], voterShare);
                    }
                }
            }
        }
        
        // Update accumulated fees after distribution
        accumulatedFees -= _totalFees;
        
        emit DebugLog("Completed fee distribution", accumulatedFees);
    }
}