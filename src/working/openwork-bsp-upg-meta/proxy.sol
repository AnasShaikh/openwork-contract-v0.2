// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UUPSProxy
 * @notice A UUPS-compatible proxy that uses OpenZeppelin's ERC1967Proxy
 * @dev This proxy is compatible with any UUPS upgradeable contract that inherits from UUPSUpgradeable
 * 
 * Features:
 * - ERC1967 standard storage slots for implementation address
 * - Built-in upgrade mechanism via UUPS pattern
 * - Automatic initialization support
 * - Compatible with OpenZeppelin's upgrade tooling
 * 
 * Usage:
 * 1. Deploy your implementation contract (e.g., NativeAthena)
 * 2. Deploy this proxy with implementation address and initialization data
 * 3. The proxy will automatically delegate all calls to the implementation
 * 4. Upgrades are handled by calling upgradeTo/upgradeToAndCall on the implementation
 */
contract UUPSProxy is ERC1967Proxy {
    /**
     * @notice Constructor to initialize the UUPS proxy
     * @param implementation Address of the implementation contract
     * @param data Initialization data to be passed to the implementation's initialize function
     * 
     * @dev The data parameter should be the encoded call to the initialize function
     * Example for NativeAthena:
     * abi.encodeWithSignature("initialize(address,address,address)", owner, daoContract, bridge)
     */
    constructor(
        address implementation,
        bytes memory data
    ) ERC1967Proxy(implementation, data) {
        // The ERC1967Proxy constructor handles:
        // 1. Setting the implementation address in the correct storage slot
        // 2. Calling the implementation with the initialization data
        // 3. Ensuring the call succeeds or reverting
    }
    
    /**
     * @notice Receive function to handle plain ETH transfers
     * @dev This is required since the contract has a payable fallback
     */
    receive() external payable {}
    
    /**
     * @notice Get the current implementation address
     * @return impl The address of the current implementation contract
     * @dev This function is useful for verification and monitoring
     */
    function getImplementation() external view returns (address impl) {
        return _implementation();
    }
    
    /**
     * @notice Check if the contract supports UUPS upgrades
     * @return bool Always returns true as this is a UUPS proxy
     */
    function supportsUUPS() external pure returns (bool) {
        return true;
    }
}

/**
 * @title UUPSProxyFactory
 * @notice Factory contract to deploy UUPS proxies with deterministic addresses
 * @dev Optional factory for easier deployment and management of multiple proxies
 */
contract UUPSProxyFactory {
    event ProxyDeployed(
        address indexed proxy,
        address indexed implementation,
        bytes32 indexed salt,
        address deployer
    );
    
    /**
     * @notice Deploy a new UUPS proxy with CREATE2 for deterministic addresses
     * @param implementation Address of the implementation contract
     * @param data Initialization data for the implementation
     * @param salt Salt for CREATE2 deployment
     * @return proxy Address of the deployed proxy
     */
    function deployProxy(
        address implementation,
        bytes memory data,
        bytes32 salt
    ) external returns (address proxy) {
        bytes memory bytecode = abi.encodePacked(
            type(UUPSProxy).creationCode,
            abi.encode(implementation, data)
        );
        
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(proxy) {
                revert(0, 0)
            }
        }
        
        emit ProxyDeployed(proxy, implementation, salt, msg.sender);
    }
    
    /**
     * @notice Predict the address of a proxy before deployment
     * @param implementation Address of the implementation contract
     * @param data Initialization data for the implementation
     * @param salt Salt for CREATE2 deployment
     * @param deployer Address that will deploy the proxy
     * @return predicted The predicted address of the proxy
     */
    function predictProxyAddress(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address deployer
    ) external pure returns (address predicted) {
        bytes memory bytecode = abi.encodePacked(
            type(UUPSProxy).creationCode,
            abi.encode(implementation, data)
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployer,
                salt,
                keccak256(bytecode)
            )
        );
        
        return address(uint160(uint256(hash)));
    }
}

/**
 * @title DeploymentScript
 * @notice Example deployment script for the NativeAthena contract
 * @dev This shows how to properly deploy and initialize a UUPS proxy
 */
contract DeploymentExample {
    /**
     * @notice Example function showing how to deploy NativeAthena with UUPS proxy
     * @param implementation Address of the deployed NativeAthena implementation
     * @param owner Address that will own the contract
     * @param daoContract Address of the DAO contract
     * @param bridge Address of the bridge contract
     * @return proxy Address of the deployed proxy
     */
    function deployNativeAthena(
        address implementation,
        address owner,
        address daoContract,
        address bridge
    ) external returns (address proxy) {
        // Encode the initialization call
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            owner,
            daoContract,
            bridge
        );
        
        // Deploy the proxy
        proxy = address(new UUPSProxy(implementation, initData));
        
        return proxy;
    }
}

/*
DEPLOYMENT INSTRUCTIONS:

1. Deploy the implementation contract (NativeAthena):
   - Deploy NativeAthena.sol without calling initialize
   - Note the deployed address

2. Deploy the proxy:
   - Deploy UUPSProxy with:
     * implementation: address from step 1
     * data: encoded initialize call with your parameters

3. Interact with the proxy:
   - Use the proxy address for all interactions
   - The proxy will automatically delegate to the implementation
   - All state is stored in the proxy

4. Upgrading:
   - Deploy new implementation contract
   - Call upgradeToAndCall() on the proxy (via the current implementation)
   - Only the owner can authorize upgrades (via _authorizeUpgrade)

SECURITY NOTES:
- Always verify the implementation contract before deployment
- Ensure the initialize function can only be called once
- Test upgrades on testnet before mainnet deployment
- Keep the owner key secure as it controls upgrades
- Consider using a multisig or timelock for the owner role
*/