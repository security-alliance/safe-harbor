// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SafeHarborRegistry} from "../src/SafeHarborRegistry.sol";
import {AgreementV1Factory} from "../src/AgreementV1.sol";

contract SafeHarborRegistryDeploy is Script {
    // This is a create2 factory deployed by a one-time-use-account as described here:
    // https://github.com/Arachnid/deterministic-deployment-proxy. As a result, this factory
    // exists (or can exist) on any EVM compatible chain, and gives us a guaranteed way to deploy
    // the registry to a deterministic address across all chains. This is used by default in foundry
    // when we specify a salt in a contract creation.
    address constant DETERMINISTIC_CREATE2_FACTORY =
        0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // This could have been any value, but we choose zero.
    bytes32 constant DETERMINISTIC_DEPLOY_SALT = bytes32(0);

    function run() public {
        require(
            DETERMINISTIC_CREATE2_FACTORY.code.length != 0,
            "Create2 factory not deployed yet, see https://github.com/Arachnid/deterministic-deployment-proxy."
        );

        uint256 deployerPrivateKey = vm.envUint(
            "REGISTRY_DEPLOYER_PRIVATE_KEY"
        );
        address deployerAddress = vm.addr(deployerPrivateKey);

        address registryAddress = getExpectedAddress(deployerAddress);
        require(
            registryAddress.code.length == 0,
            "Registry already deployed, nothing left to do."
        );

        vm.startBroadcast(deployerPrivateKey);
        AgreementV1Factory factory = new AgreementV1Factory{
            salt: DETERMINISTIC_DEPLOY_SALT
        }(registryAddress);

        address deployedFactoryAddress = address(factory);
        SafeHarborRegistry registry = new SafeHarborRegistry{
            salt: DETERMINISTIC_DEPLOY_SALT
        }(deployedFactoryAddress, SafeHarborRegistry(address(0)));

        address deployedRegistryAddress = address(registry);

        require(
            deployedRegistryAddress == registryAddress,
            "Deployed to unexpected address. Check that Foundry is using the correct create2 factory."
        );

        vm.stopBroadcast();
    }

    // Computes the address which the registry will be deployed to, assuming the correct create2 factory
    // and salt are used.
    function getExpectedAddress(address admin) public pure returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                DETERMINISTIC_CREATE2_FACTORY,
                                DETERMINISTIC_DEPLOY_SALT,
                                keccak256(
                                    abi.encodePacked(
                                        type(SafeHarborRegistry).creationCode,
                                        abi.encode(admin)
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }
}
