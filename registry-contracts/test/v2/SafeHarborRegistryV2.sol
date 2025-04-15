// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";
import {AgreementV2} from "../../src/v2/AgreementV2.sol";
import "../../src/v2/AgreementDetailsV2.sol";
import "./mock.sol";

contract SafeHarborRegistryV2Test is TestBase, DSTest {
    address registryOwner;
    address owner;

    SafeHarborRegistryV2 registry;
    SafeHarborRegistryV2 registryV2;
    AgreementDetailsV2 details;
    AgreementV2 agreement;
    address agreementAddress;

    function setUp() public {
        registryOwner = address(0x2);
        owner = address(0x1);

        registry = new SafeHarborRegistryV2(address(0), registryOwner);
        registryV2 = new SafeHarborRegistryV2(address(registry), registryOwner);
        details = getMockAgreementDetails("0x0");

        agreement = new AgreementV2(details, owner);
        agreementAddress = address(agreement);
    }

    function test_addChains() public {
        string[] memory chainNames = new string[](2);
        chainNames[0] = "chain1";
        chainNames[1] = "chain2";

        // Should fail if not called by owner
        vm.expectRevert();
        registry.addChains(chainNames);

        // Should succeed if called by owner
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainAdded(chainNames[0]);
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainAdded(chainNames[1]);
        vm.prank(registryOwner);
        registry.addChains(chainNames);

        string[] memory chains = registry.getChains();
        assertEq(chains.length, 2);
        assertEq(chains[0], chainNames[0]);
        assertEq(chains[1], chainNames[1]);

        // Should fail if chain already exists
        vm.expectRevert();
        vm.prank(registryOwner);
        registry.addChains(chainNames);
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
