// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// LayerZero V2 interfaces (minimal for send/receive)
interface ILayerZeroEndpointV2 {
    function send(
        uint32 dstEid,
        address to,
        bytes calldata payload,
        bytes calldata options,
        address refundAddress
    ) external payable;
}

interface ILayerZeroReceiverV2 {
    function lzReceive(
        uint32 srcEid,
        address sender,
        bytes calldata payload,
        address executor,
        bytes calldata extraData
    ) external;
}

contract SimpleUUPS is Initializable, UUPSUpgradeable, OwnableUpgradeable, ILayerZeroReceiverV2 {
    string public data;
    ILayerZeroEndpointV2 public lzEndpoint;

    struct Option {
        address user;
        uint256 strikePrice;
        uint256 expiry;
        bool exercised;
    }

    Option[] public options;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _data, address _lzEndpoint) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        data = _data;
        lzEndpoint = ILayerZeroEndpointV2(_lzEndpoint);
    }

    // LayerZero send function
    function sendData(
        uint32 dstEid,
        address to,
        string calldata _data,
        bytes calldata lzOptions,
        address refundAddress
    ) external payable onlyOwner {
        bytes memory payload = abi.encode(_data);
        lzEndpoint.send{value: msg.value}(dstEid, to, payload, lzOptions, refundAddress);
    }

    // LayerZero receive function
    function lzReceive(
        uint32 /*srcEid*/,
        address /*sender*/,
        bytes calldata payload,
        address /*executor*/,
        bytes calldata /*extraData*/
    ) external override {
        require(msg.sender == address(lzEndpoint), "Only endpoint");
        string memory receivedData = abi.decode(payload, (string));
        data = receivedData;
    }

    // User can create a put option
    function createPutOption(uint256 strikePrice, uint256 expiry) external {
        require(expiry > block.timestamp, "Expiry must be in future");
        options.push(Option({
            user: msg.sender,
            strikePrice: strikePrice,
            expiry: expiry,
            exercised: false
        }));
    }

    // User can exercise their put option
    function exercisePutOption(uint256 optionId) external {
        Option storage opt = options[optionId];
        require(opt.user == msg.sender, "Not option owner");
        require(block.timestamp <= opt.expiry, "Option expired");
        require(!opt.exercised, "Already exercised");
        opt.exercised = true;
        // Add your logic for exercising the put option here (e.g., transfer assets)
    }

    function setData(string memory _data) public onlyOwner {
        data = _data;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}