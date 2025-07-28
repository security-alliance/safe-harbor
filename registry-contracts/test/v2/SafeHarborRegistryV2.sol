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

    SafeHarborRegistryV2 fallbackRegistry;
    SafeHarborRegistryV2 registry;
    AgreementDetailsV2 details;
    AgreementV2 agreement;
    address agreementAddress;

    function setUp() public {
        registryOwner = address(0x2);
        owner = address(0x1);

        fallbackRegistry = new SafeHarborRegistryV2(address(0), registryOwner);
        registry = new SafeHarborRegistryV2(address(fallbackRegistry), registryOwner);

        string[] memory validChains = new string[](2);
        validChains[0] = "eip155:1";
        validChains[1] = "eip155:2";
        vm.prank(registryOwner);
        registry.setValidChains(validChains);

        details = getMockAgreementDetails("0xaabbccdd");

        agreement = new AgreementV2(details, address(registry), owner);
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
        assertTrue(registry.isChainValid("eip155:1"));
        assertTrue(registry.isChainValid("eip155:2"));
        assertTrue(registry.isChainValid("eip155:137"));
        assertTrue(!registry.isChainValid("eip155:999"));

        string[] memory validChains = registry.getValidChains();
        assertEq(validChains[0], "eip155:1");
        assertEq(validChains[1], "eip155:2");
        assertEq(validChains[2], "eip155:137");
        assertEq(validChains.length, 3);
    }

    function test_setInvalidChains() public {
        string[] memory invalidChains = new string[](2);
        invalidChains[0] = "eip155:137";
        invalidChains[1] = "eip155:2";

        // Should fail if not called by owner
        vm.expectRevert();
        registry.setInvalidChains(invalidChains);

        // Should succeed if called by owner
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet("eip155:137", false);
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet("eip155:2", false);
        vm.prank(registryOwner);
        registry.setInvalidChains(invalidChains);

        assertTrue(registry.isChainValid("eip155:1"));
        assertTrue(!registry.isChainValid("eip155:137"));
        assertTrue(!registry.isChainValid("eip155:2"));

        string[] memory remainingChains = registry.getValidChains();
        assertEq(remainingChains.length, 1);
        assertEq(remainingChains[0], "eip155:1");
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
        fallbackRegistry.adoptSafeHarbor(agreementAddress);
        address _agreement = registry.getAgreement(entity);
        assertEq(agreementAddress, _agreement);
    }

    function test_getDetails_missing() public {
        address entity = address(0xee);

        vm.expectRevert(SafeHarborRegistryV2.NoAgreement.selector);
        address _agreement = registry.getAgreement(entity);
        assertEq(_agreement, address(0));
    }
}
