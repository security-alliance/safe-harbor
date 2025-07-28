// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SafeHarborRegistryV2, IRegistry} from "../../src/v2/SafeHarborRegistryV2.sol";
import {AgreementFactoryV2} from "../../src/v2/AgreementFactoryV2.sol";

contract DeployRegistryV2 is Script {
    // This is a create2 factory deployed by a one-time-use-account as described here:
    // https://github.com/Arachnid/deterministic-deployment-proxy. As a result, this factory
    // exists (or can exist) on any EVM compatible chain, and gives us a guaranteed way to deploy
    // the registry to a deterministic address across all chains. This is used by default in foundry
    // when we specify a salt in a contract creation.
    address constant DETERMINISTIC_CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // This could have been any value, but we choose zero.
    bytes32 constant DETERMINISTIC_DEPLOY_SALT = bytes32(0);

    address constant EXPECTED_DEPLOYER_ADDRESS = 0x31d23affb90bCAfcAAe9f27903b151DCDC82569E;

    // This is the address of the fallback registry that has already been deployed.
    // Set this to the zero address if no fallback registry exists.
    address fallbackRegistry = getFallbackRegistryAddress();

    function run() public {
        require(
            DETERMINISTIC_CREATE2_FACTORY.code.length != 0,
            "Create2 factory not deployed yet, see https://github.com/Arachnid/deterministic-deployment-proxy."
        );

        if (fallbackRegistry == address(0)) {
            console.log("WARNING: Deploying SafeHarborRegistryV2 with no fallback registry.");
        } else {
            // Disable this check if you want to deploy the register with no fallback registry.
            require(fallbackRegistry.code.length > 0, "No contract exists at the fallback registry address.");
        }

        uint256 deployerPrivateKey = vm.envUint("REGISTRY_DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        if (deployerAddress != EXPECTED_DEPLOYER_ADDRESS) {
            console.log("WARNING: The deployer address does not match the expected address.");
            console.log("Expected deployer address:");
            console.logAddress(EXPECTED_DEPLOYER_ADDRESS);
            console.log("Actual deployer address:");
            console.logAddress(deployerAddress);
        }

        console.log("Deploying from");
        console.logAddress(deployerAddress);

        // Deploy the Registry
        address expectedRegistryAddress = getExpectedRegistryAddress(deployerAddress);
        if (expectedRegistryAddress.code.length == 0) {
            deployRegistry(deployerPrivateKey, fallbackRegistry, deployerAddress, expectedRegistryAddress);
        } else {
            console.log("Registry already deployed at:");
            console.logAddress(expectedRegistryAddress);
        }

        // Deploy the Factory
        address expectedFactoryAddress = getExpectedFactoryAddress();
        if (expectedFactoryAddress.code.length == 0) {
            deployFactory(deployerPrivateKey, expectedFactoryAddress);
        } else {
            console.log("Factory already deployed at:");
            console.logAddress(expectedFactoryAddress);
        }
    }

    function deployRegistry(
        uint256 deployerPrivateKey,
        address _fallbackRegistry,
        address _owner,
        address expectedAddress
    ) internal {
        vm.broadcast(deployerPrivateKey);
        SafeHarborRegistryV2 registry = new SafeHarborRegistryV2{salt: DETERMINISTIC_DEPLOY_SALT}(_owner);

        if (_fallbackRegistry != address(0)) {
            vm.broadcast(deployerPrivateKey);
            registry.setFallbackRegistry(IRegistry(_fallbackRegistry));
        }

        address deployedRegistryAddress = address(registry);

        require(
            deployedRegistryAddress == expectedAddress,
            "Deployed to unexpected address. Check that Foundry is using the correct create2 factory."
        );

        require(
            deployedRegistryAddress.code.length != 0,
            "Registry deployment failed. Check that Foundry is using the correct create2 factory."
        );

        console.log("SafeHarborRegistryV2 deployed to:");
        console.logAddress(deployedRegistryAddress);
    }

    function deployFactory(uint256 deployerPrivateKey, address expectedAddress) internal {
        vm.broadcast(deployerPrivateKey);
        AgreementFactoryV2 factory = new AgreementFactoryV2{salt: DETERMINISTIC_DEPLOY_SALT}();

        address deployedFactoryAddress = address(factory);

        require(
            deployedFactoryAddress == expectedAddress,
            "Factory deployed to unexpected address. Check that Foundry is using the correct create2 factory."
        );

        require(
            deployedFactoryAddress.code.length != 0,
            "Factory deployment failed. Check that Foundry is using the correct create2 factory."
        );

        console.log("AgreementFactoryV2 deployed to:");
        console.logAddress(deployedFactoryAddress);
    }

    function getFallbackRegistryAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        // Most chains use this address
        address standardFallback = 0x8f72fcf695523A6FC7DD97EafDd7A083c386b7b6;

        // Map chain IDs to their fallback registry addresses
        if (chainId == 1) return standardFallback; // Ethereum
        if (chainId == 137) return standardFallback; // Polygon
        if (chainId == 42161) return standardFallback; // Arbitrum
        if (chainId == 10) return standardFallback; // Optimism
        if (chainId == 8453) return standardFallback; // Base
        if (chainId == 43114) return standardFallback; // Avalanche C
        if (chainId == 1101) return standardFallback; // Polygon zkEVM
        if (chainId == 56) return standardFallback; // BSC
        if (chainId == 100) return standardFallback; // Gnosis
        if (chainId == 324) return 0x5f5eEc1a37F42883Df9DacdAb11985467F813877; // ZKsync

        // For any other chain, return zero address (no fallback registry)
        return address(0);
    }

    // Computes the address which the registry will be deployed to, assuming the correct create2 factory
    // and salt are used.
    function getExpectedRegistryAddress(address _owner) public pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            DETERMINISTIC_CREATE2_FACTORY,
                            DETERMINISTIC_DEPLOY_SALT,
                            keccak256(abi.encodePacked(type(SafeHarborRegistryV2).creationCode, abi.encode(_owner)))
                        )
                    )
                )
            )
        );
    }

    // Computes the address which the factory will be deployed to
    function getExpectedFactoryAddress() public pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            DETERMINISTIC_CREATE2_FACTORY,
                            DETERMINISTIC_DEPLOY_SALT,
                            keccak256(abi.encodePacked(type(AgreementFactoryV2).creationCode))
                        )
                    )
                )
            )
        );
    }
}
