// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";
import {AgreementV2} from "../../src/v2/AgreementV2.sol";
import "../mock.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    address owner;

    SafeHarborRegistryV2 registry;
    SafeHarborRegistryV2 registryV2;
    AgreementDetailsV1 details;
    AgreementV2 agreement;
    address agreementAddress;

    function setUp() public {
        owner = address(0x1);

        registry = new SafeHarborRegistryV2(address(0));
        registryV2 = new SafeHarborRegistryV2(address(registry));
        details = getMockAgreementDetails(address(100));

        agreement = new AgreementV2(details, owner);
        agreementAddress = address(agreement);
    }

    function test_adoptSafeHarbor() public {
        address entity = address(0xee);

        vm.expectEmit();
        emit SafeHarborRegistryV2.SafeHarborAdoption(entity, address(0), agreementAddress);
        vm.prank(entity);
        registry.adoptSafeHarbor(agreementAddress);
    }

    function test_getDetails() public {
        address entity = address(0xee);

        vm.prank(entity);
        registry.adoptSafeHarbor(agreementAddress);
        address _agreement = registry.getAgreement(entity);
        assertEq(agreementAddress, _agreement);
    }

    function test_getDetails_fallback() public {
        address entity = address(0xee);

        vm.prank(entity);
        registry.adoptSafeHarbor(agreementAddress);
        address _agreement = registryV2.getAgreement(entity);
        assertEq(agreementAddress, _agreement);
    }

    function test_getDetails_missing() public {
        address entity = address(0xee);

        vm.expectRevert(SafeHarborRegistryV2.NoAgreement.selector);
        address _agreement = registryV2.getAgreement(entity);
        assertEq(_agreement, address(0));
    }
}
