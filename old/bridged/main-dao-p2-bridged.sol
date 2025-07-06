// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

interface InativeDAO {
    function updateStakeData(
        address staker,
        uint256 amount,
        uint256 unlockTime,
        uint256 durationMinutes,
        bool isActive
    ) external;
}

interface IMainDAO {
    function stakes(address staker) external view returns (uint256 amount, uint256 unlockTime, uint256 durationMinutes);
    function addOrUpdateEarner(address earner, uint256 balance, uint256 governanceActions, uint256 cumulativeEarnings, uint256 platformTotal) external;
}

contract CrossChainBridge is OApp {
    IMainDAO public mainDAO;
    
    // Cross-chain receiver contract address (for backward compatibility)
    InativeDAO public nativeDAO;
    
    // LayerZero configuration for Native DAO communication
    uint32 public nativeDaoEid;
    bytes public layerZeroOptions;
    
    // Cross-chain execution tracking
    mapping(bytes32 => bool) public executedMessages;
    
    // Access control for multiple local contracts (LayerZero)
    mapping(uint32 => mapping(bytes32 => bool)) public authorizedLocalContracts;
    
    // Cross-chain events
    event CrossChainSendFailed(address indexed staker, string reason);
    event CrossChainSendSuccess(address indexed staker);
    event CrossChainMessageReceived(bytes32 indexed messageId, string indexed messageType, address indexed executor);
    event LocalContractDeauthorized(uint32 indexed eid, bytes32 indexed localContract);
    event MainDAOUpdated(address indexed newMainDAO);
    event NativeDAOUpdated(address indexed newNativeDAO);
    event LayerZeroOptionsUpdated(bytes newOptions);
    
    constructor(
        address _endpoint,
        address _owner,
        address _mainDAO
    ) 
        OApp(_endpoint, _owner)
        Ownable(_owner)
    {
        mainDAO = IMainDAO(_mainDAO);
        // Set default LayerZero options
        layerZeroOptions = hex"0003010011010000000000000000000000000000ea60";
    }
    
    // Set main DAO contract
    function setMainDAO(address _mainDAO) external onlyOwner {
        require(_mainDAO != address(0), "Invalid main DAO address");
        mainDAO = IMainDAO(_mainDAO);
        emit MainDAOUpdated(_mainDAO);
    }
    
    // Access control functions for multiple local contracts
    function removeAuthorizedLocal(uint32 _eid, bytes32 _localContract) external onlyOwner {
        authorizedLocalContracts[_eid][_localContract] = false;
        emit LocalContractDeauthorized(_eid, _localContract);
    }
    
    function isAuthorizedLocal(uint32 _eid, bytes32 _localContract) external view returns (bool) {
        return authorizedLocalContracts[_eid][_localContract];
    }
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        // Prevent replay attacks
        require(!executedMessages[_guid], "Message already executed");
        executedMessages[_guid] = true;
        
        // Verify sender is authorized
        require(authorizedLocalContracts[_origin.srcEid][_origin.sender], "Unauthorized local contract");
        
        string memory messageType = abi.decode(payload, (string));
        
        emit CrossChainMessageReceived(_guid, messageType, msg.sender);
        
        if (keccak256(bytes(messageType)) == keccak256(bytes("UPDATE_EARNER"))) {
            (, address earnerAddress, uint256 balance, uint256 governanceActions, uint256 cumulativeEarnings, uint256 platformTotal) = 
                abi.decode(payload, (string, address, uint256, uint256, uint256, uint256));
            mainDAO.addOrUpdateEarner(earnerAddress, balance, governanceActions, cumulativeEarnings, platformTotal);
        }
    }
    
    function setNativeDaoEid(uint32 _nativeDaoEid) external onlyOwner {
        nativeDaoEid = _nativeDaoEid;
    }
    
    function setLayerZeroOptions(bytes calldata _options) external onlyOwner {
        layerZeroOptions = _options;
        emit LayerZeroOptionsUpdated(_options);
    }
    
    // Set cross-chain receiver contract (for backward compatibility)
    function setNativeDAO(address _receiver) external onlyOwner {
        nativeDAO = InativeDAO(_receiver);
        emit NativeDAOUpdated(_receiver);
    }
    
    // Main function called by MainDAO to send stake updates
    function sendStakeUpdate(address staker, bool isActive) external {
        require(msg.sender == address(mainDAO), "Only MainDAO can call this");
        
        _sendStakeDataViaLayerZero(staker, isActive);
    }
    
    function _sendStakeDataViaLayerZero(address staker, bool isActive) internal {
        if (nativeDaoEid == 0) return;
        
        (uint256 amount, uint256 unlockTime, uint256 durationMinutes) = mainDAO.stakes(staker);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "UPDATE_STAKE_DATA",
            staker,
            amount,
            unlockTime,
            durationMinutes,
            isActive
        );
        
        try this._lzSendStakeUpdate{value: address(this).balance}(payload) {
            emit CrossChainSendSuccess(staker);
        } catch {
            // Fallback to direct call if LayerZero fails
            _sendStakeDataDirectCall(staker, isActive);
        }
    }
    
    function _lzSendStakeUpdate(bytes memory payload) external payable {
        require(msg.sender == address(this), "Internal function only");
        
        _lzSend(
            nativeDaoEid,
            payload,
            layerZeroOptions,
            MessagingFee(msg.value, 0),
            payable(address(this))
        );
    }
    
    function _sendStakeDataDirectCall(address staker, bool isActive) internal {
        if (address(nativeDAO) == address(0)) return;
        
        (uint256 amount, uint256 unlockTime, uint256 durationMinutes) = mainDAO.stakes(staker);
        
        try nativeDAO.updateStakeData(
            staker,
            amount,
            unlockTime,
            durationMinutes,
            isActive
        ) {
            emit CrossChainSendSuccess(staker);
        } catch Error(string memory reason) {
            emit CrossChainSendFailed(staker, reason);
        } catch {
            emit CrossChainSendFailed(staker, "Unknown error");
        }
    }
    
    // Quote function for gas estimation
    function quoteStakeUpdate(address staker) external view returns (uint256) {
        (uint256 amount, uint256 unlockTime, uint256 durationMinutes) = mainDAO.stakes(staker);
        bool isActive = amount > 0;
        
        bytes memory payload = abi.encode(
            "UPDATE_STAKE_DATA",
            staker,
            amount,
            unlockTime,
            durationMinutes,
            isActive
        );
        
        MessagingFee memory fee = _quote(nativeDaoEid, payload, layerZeroOptions, false);
        return fee.nativeFee;
    }
    
    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    // Allow contract to receive ETH for gas fees
    receive() external payable {}
}