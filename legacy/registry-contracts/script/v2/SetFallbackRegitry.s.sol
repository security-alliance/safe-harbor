// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {SafeHarborRegistryV2, IRegistry} from "../../src/v2/SafeHarborRegistryV2.sol";

contract SetFallbackRegistry is Script {
    // Update these addresses to match your deployed contracts
    address constant REGISTRY_ADDRESS = 0x1eaCD100B0546E433fbf4d773109cAD482c34686;
    address constant FALLBACK_REGISTRY_ADDRESS = 0x8f72fcf695523A6FC7DD97EafDd7A083c386b7b6;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("REGISTRY_DEPLOYER_PRIVATE_KEY");

        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);

        vm.broadcast(deployerPrivateKey);
        registry.setFallbackRegistry(IRegistry(FALLBACK_REGISTRY_ADDRESS));
    }
}
