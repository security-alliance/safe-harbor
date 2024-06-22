// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/SafeHarborRegistry.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    address admin;
    SafeHarborRegistry registry;

    function setUp() public {
        admin = address(0xaa);
        registry = new SafeHarborRegistry(admin);
    }

    function test_recordAdoption() public {
        address factory = address(0xff);
        address agreement = address(0xbb);

        vm.prank(admin);
        registry.enableFactory(factory);

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(
            tx.origin,
            address(0),
            agreement
        );
        vm.prank(factory);
        registry.recordAdoption(agreement);
        assertEq(registry.agreements(tx.origin), agreement);
    }

    function test_adoptSafeHarbor_disabledFactory() public {
        address factory = address(0xff);
        address agreement = address(0xbb);

        vm.prank(admin);
        registry.disableFactory(factory);

        vm.expectRevert("Only approved factories may adopt the Safe Harbor");
        vm.prank(factory);
        registry.recordAdoption(agreement);
    }

    function test_enableFactory() public {
        address factory = address(0xff);

        vm.prank(admin);
        vm.expectEmit();
        emit SafeHarborRegistry.FactoryEnabled(factory);
        registry.enableFactory(factory);

        assertTrue(registry.agreementFactories(factory));
    }

    function test_enableFactory_notAdmin() public {
        address factory = address(0xff);
        address fakeAdmin = address(0xcc);

        vm.expectRevert("Only the admin can perform this action");
        vm.prank(fakeAdmin);
        registry.enableFactory(factory);
    }

    function test_disableFactory() public {
        address factory = address(0xff);

        vm.expectEmit();
        emit SafeHarborRegistry.FactoryDisabled(factory);
        vm.prank(admin);
        registry.disableFactory(factory);

        assertTrue(!registry.agreementFactories(factory));
    }

    function test_disableFactory_notAdmin() public {
        address factory = address(0xff);
        address fakeAdmin = address(0xcc);

        vm.expectRevert("Only the admin can perform this action");
        vm.prank(fakeAdmin);
        registry.disableFactory(factory);
    }

    function test_transferAdminRights() public {
        address newAdmin = address(0xbb);

        vm.prank(admin);
        registry.transferAdminRights(newAdmin);
        assertEq(registry.admin(), newAdmin);
    }

    function test_transferAdminRights_notAdmin() public {
        address fakeAdmin = address(0xcc);
        address newAdmin = address(0xbb);

        vm.expectRevert("Only the admin can perform this action");
        vm.prank(fakeAdmin);
        registry.transferAdminRights(newAdmin);
    }
}
