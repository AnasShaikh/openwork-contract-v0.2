// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GeneralProxy is ERC1967Proxy {
    constructor(
        address implementation,
        bytes memory initData
    ) ERC1967Proxy(implementation, initData) {}
}