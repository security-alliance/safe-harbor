// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";

contract DeployRegistryV2 is Script {
    // This is a create2 factory deployed by a one-time-use-account as described here:
    // https://github.com/Arachnid/deterministic-deployment-proxy. As a result, this factory
    // exists (or can exist) on any EVM compatible chain, and gives us a guaranteed way to deploy
    // the registry to a deterministic address across all chains. This is used by default in foundry
    // when we specify a salt in a contract creation.
    address constant DETERMINISTIC_CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // This could have been any value, but we choose zero.
    bytes32 constant DETERMINISTIC_DEPLOY_SALT = bytes32(0);

    // This is the address of the fallback registry that has already been deployed.
    // Set this to the zero address if no fallback registry exists.
    //? 0x8f72fcf695523A6FC7DD97EafDd7A083c386b7b6 // mainnet
    //? 0x5f5eEc1a37F42883Df9DacdAb11985467F813877 // zksync
    address fallbackRegistry = address(0);

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

        address registryAddress = getExpectedAddress(fallbackRegistry, deployerAddress);
        require(registryAddress.code.length == 0, "Registry already deployed, nothing left to do.");

        vm.startBroadcast(deployerPrivateKey);
        SafeHarborRegistryV2 registry =
            new SafeHarborRegistryV2{salt: DETERMINISTIC_DEPLOY_SALT}(fallbackRegistry, deployerAddress);
        vm.stopBroadcast();

        address deployedRegistryAddress = address(registry);

        require(
            deployedRegistryAddress == registryAddress,
            "Deployed to unexpected address. Check that Foundry is using the correct create2 factory."
        );

        require(
            deployedRegistryAddress.code.length != 0,
            "Registry deployment failed. Check that Foundry is using the correct create2 factory."
        );

        console.log("SafeHarborRegistryV2 deployed to:");
        console.logAddress(deployedRegistryAddress);
    }

    // Computes the address which the registry will be deployed to, assuming the correct create2 factory
    // and salt are used.
    function getExpectedAddress(address _fallbackRegistry, address _owner) public pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            DETERMINISTIC_CREATE2_FACTORY,
                            DETERMINISTIC_DEPLOY_SALT,
                            keccak256(
                                abi.encodePacked(
                                    type(SafeHarborRegistryV2).creationCode,
                                    abi.encode(_fallbackRegistry),
                                    abi.encode(_owner)
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}
