// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/v1/SafeHarborRegistry.sol";
import "../mock.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    SafeHarborRegistry registry;
    SafeHarborRegistry registryV2;
    AgreementDetailsV1 details;

    function setUp() public {
        registry = new SafeHarborRegistry(address(0));
        registryV2 = new SafeHarborRegistry(address(registry));
        details = getMockAgreementDetails(address(100));
    }

    function test_adoptSafeHarbor() public {
        address newDetails = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;
        address entity = address(0xee);

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(entity, address(0), newDetails);
        vm.prank(entity);
        registry.adoptSafeHarbor(details);
    }

    function test_getDetails() public {
        address entity = address(0xee);

        vm.prank(entity);
        registry.adoptSafeHarbor(details);
        AgreementV1 agreement = AgreementV1(registry.getAgreement(entity));
        AgreementDetailsV1 memory gotDetails = agreement.getDetails();
        assertEq(registry.hash(details), registry.hash(gotDetails));
    }

    function test_getDetails_fallback() public {
        address entity = address(0xee);

        vm.prank(entity);
        registry.adoptSafeHarbor(details);
        AgreementV1 agreement = AgreementV1(registryV2.getAgreement(entity));
        AgreementDetailsV1 memory gotDetails = agreement.getDetails();
        assertEq(registry.hash(details), registry.hash(gotDetails));
    }

    function test_getDetails_missing() public {
        address entity = address(0xee);

        vm.expectRevert(SafeHarborRegistry.NoAgreement.selector);
        address agreement = registryV2.getAgreement(entity);
        assertEq(agreement, address(0));
    }
}
