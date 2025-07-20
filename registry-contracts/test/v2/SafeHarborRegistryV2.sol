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

    function test_setValidChains() public {
        string[] memory caip2ChainIds = new string[](2);
        caip2ChainIds[0] = "eip155:1";
        caip2ChainIds[1] = "eip155:137";

        // Should fail if not called by owner
        vm.expectRevert();
        registry.setValidChains(caip2ChainIds);

        // Should succeed if called by owner
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet(caip2ChainIds[0], true);
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet(caip2ChainIds[1], true);
        vm.prank(registryOwner);
        registry.setValidChains(caip2ChainIds);

        // Verify chains are valid
        assertTrue(registry.isChainValid(caip2ChainIds[0]));
        assertTrue(registry.isChainValid(caip2ChainIds[1]));
        assertTrue(!registry.isChainValid("eip155:999")); // Non-existent chain
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
