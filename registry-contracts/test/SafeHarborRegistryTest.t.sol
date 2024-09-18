// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/SafeHarborRegistry.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    address factory;
    SafeHarborRegistry registry;
    SafeHarborRegistry registryV2;

    function setUp() public {
        factory = address(0xff);
        registry = new SafeHarborRegistry(factory, SafeHarborRegistry(address(0)));
        registryV2 = new SafeHarborRegistry(factory, registry);
    }

    function test_recordAdoption() public {
        address agreement = address(0xbb);
        address entity = address(0xee);

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(entity, address(0), agreement);
        vm.prank(factory);
        registry.recordAdoption(entity, agreement);
        assertEq(registry.agreements(entity), agreement);
    }

    function test_recordAdoption_fakefactory() public {
        address fakeFactory = address(0x11);
        address agreement = address(0xbb);
        address entity = address(0xee);

        vm.expectRevert(SafeHarborRegistry.OnlyFactories.selector);
        vm.prank(fakeFactory);
        registry.recordAdoption(entity, agreement);
    }

    function test_getDetails() public {
        address agreement = address(0xbb);
        address entity = address(0xee);

        vm.prank(factory);
        registry.recordAdoption(entity, agreement);
        assertEq(registry.getDetails(entity), agreement);
    }

    function test_getDetails_fallback() public {
        address agreement = address(0xbb);
        address entity = address(0xee);

        vm.prank(factory);
        registry.recordAdoption(entity, agreement);
        assertEq(registryV2.getDetails(entity), agreement);
    }
}
