// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../script/SafeHarborRegistryDeploy.s.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    // Set up the environment before each test
    function setUp() public {
        string memory fakePrivateKey = "0xf0931a501a9b5fd5183d01f35526e5bc64d05d9d25d4005a8b1600ed6cd8d795";
        vm.setEnv("REGISTRY_DEPLOYER_PRIVATE_KEY", fakePrivateKey);
    }

    function testRun() public {
        SafeHarborRegistryDeploy script = new SafeHarborRegistryDeploy();
        script.run();
    }
}
