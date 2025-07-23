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

        // Set valid chains in registry
        string[] memory validChains = new string[](2);
        validChains[0] = "eip155:1";
        validChains[1] = "eip155:2";
        vm.prank(registryOwner);
        registryV2.setValidChains(validChains);

        details = getMockAgreementDetails("0x0");

        agreement = new AgreementV2(details, address(registryV2), owner);
        agreementAddress = address(agreement);
    }

    function test_setValidChains() public {
        string[] memory caip2ChainIds = new string[](2);
        caip2ChainIds[0] = "eip155:1";
        caip2ChainIds[1] = "eip155:137";

        // Should fail if not called by owner
        vm.expectRevert();
        registryV2.setValidChains(caip2ChainIds);

        // Should succeed if called by owner
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet(caip2ChainIds[0], true);
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet(caip2ChainIds[1], true);
        vm.prank(registryOwner);
        registryV2.setValidChains(caip2ChainIds);

        // Verify chains are valid
        assertTrue(registryV2.isChainValid(caip2ChainIds[0]));
        assertTrue(registryV2.isChainValid(caip2ChainIds[1]));
        assertTrue(!registryV2.isChainValid("eip155:999")); // Non-existent chain
    }

    function test_getValidChains() public {
        // Initially should have 2 chains from setUp (eip155:1, eip155:2)
        string[] memory initialChains = registryV2.getValidChains();
        assertEq(initialChains.length, 2);
        assertEq(registryV2.getValidChains().length, 2);

        // Add some new chains
        string[] memory chains = new string[](2);
        chains[0] = "eip155:137";
        chains[1] = "eip155:42161";

        vm.prank(registryOwner);
        registryV2.setValidChains(chains);

        // Verify they're tracked (should now have 4 total)
        string[] memory validChains = registryV2.getValidChains();
        assertEq(validChains.length, 4);
        assertEq(registryV2.getValidChains().length, 4);

        // Verify the chains are in the list (order may vary)
        bool foundEth = false;
        bool foundBase = false;
        bool foundPolygon = false;
        bool foundArbitrum = false;

        for (uint256 i = 0; i < validChains.length; i++) {
            if (keccak256(bytes(validChains[i])) == keccak256(bytes("eip155:1"))) {
                foundEth = true;
            } else if (keccak256(bytes(validChains[i])) == keccak256(bytes("eip155:2"))) {
                foundBase = true;
            } else if (keccak256(bytes(validChains[i])) == keccak256(bytes("eip155:137"))) {
                foundPolygon = true;
            } else if (keccak256(bytes(validChains[i])) == keccak256(bytes("eip155:42161"))) {
                foundArbitrum = true;
            }
        }

        assertTrue(foundEth, "Should find Ethereum");
        assertTrue(foundBase, "Should find Base");
        assertTrue(foundPolygon, "Should find Polygon");
        assertTrue(foundArbitrum, "Should find Arbitrum");
    }

    function test_setInvalidChains() public {
        // Registry starts with 2 chains (eip155:1, eip155:2), add one more
        string[] memory chains = new string[](1);
        chains[0] = "eip155:137";

        vm.prank(registryOwner);
        registryV2.setValidChains(chains);

        assertEq(registryV2.getValidChains().length, 3);

        // Now mark some as invalid
        string[] memory invalidChains = new string[](2);
        invalidChains[0] = "eip155:137";
        invalidChains[1] = "eip155:2";

        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet("eip155:137", false);
        vm.expectEmit();
        emit SafeHarborRegistryV2.ChainValiditySet("eip155:2", false);

        vm.prank(registryOwner);
        registryV2.setInvalidChains(invalidChains);

        // Verify validity status
        assertTrue(registryV2.isChainValid("eip155:1"));
        assertTrue(!registryV2.isChainValid("eip155:137"));
        assertTrue(!registryV2.isChainValid("eip155:2"));

        // Verify they're removed from the list (should have 1 left)
        string[] memory remainingChains = registryV2.getValidChains();
        assertEq(remainingChains.length, 1);
        assertEq(registryV2.getValidChains().length, 1);
        assertEq(remainingChains[0], "eip155:1");
    }

    function test_setValidChainsNoDuplicates() public {
        // Registry starts with 2 chains (eip155:1, eip155:2) from setUp
        assertEq(registryV2.getValidChains().length, 2);

        // Add overlapping and new chains
        string[] memory chains = new string[](3);
        chains[0] = "eip155:1"; // duplicate with setUp
        chains[1] = "eip155:42161"; // new
        chains[2] = "eip155:137"; // new

        vm.prank(registryOwner);
        registryV2.setValidChains(chains);

        // Should only have 4 unique chains total (2 from setUp + 2 new)
        assertEq(registryV2.getValidChains().length, 4);

        string[] memory validChains = registryV2.getValidChains();
        assertEq(validChains.length, 4);
    }

    function test_setInvalidNonexistentChains() public {
        // Registry starts with 2 chains from setUp
        assertEq(registryV2.getValidChains().length, 2);

        // Try to invalidate chains that were never valid
        string[] memory invalidChains = new string[](2);
        invalidChains[0] = "eip155:999";
        invalidChains[1] = "eip155:1000";

        vm.prank(registryOwner);
        registryV2.setInvalidChains(invalidChains);

        // Should still have the original 2 chains
        assertEq(registryV2.getValidChains().length, 2);
        assertTrue(!registryV2.isChainValid("eip155:999"));
        assertTrue(!registryV2.isChainValid("eip155:1000"));
    }

    function test_mixedValidInvalidOperations() public {
        // Registry starts with 2 chains, add 2 more
        string[] memory chains = new string[](2);
        chains[0] = "eip155:137";
        chains[1] = "eip155:10";

        vm.prank(registryOwner);
        registryV2.setValidChains(chains);
        assertEq(registryV2.getValidChains().length, 4);

        // Remove some
        string[] memory invalidChains = new string[](2);
        invalidChains[0] = "eip155:137";
        invalidChains[1] = "eip155:10";

        vm.prank(registryOwner);
        registryV2.setInvalidChains(invalidChains);
        assertEq(registryV2.getValidChains().length, 2);

        // Add more (including one that was removed)
        string[] memory moreChains = new string[](3);
        moreChains[0] = "eip155:137"; // re-adding
        moreChains[1] = "eip155:56"; // new
        moreChains[2] = "eip155:43114"; // new

        vm.prank(registryOwner);
        registryV2.setValidChains(moreChains);
        assertEq(registryV2.getValidChains().length, 5);

        // Verify final state
        assertTrue(registryV2.isChainValid("eip155:1"));
        assertTrue(registryV2.isChainValid("eip155:2"));
        assertTrue(registryV2.isChainValid("eip155:137"));
        assertTrue(registryV2.isChainValid("eip155:56"));
        assertTrue(registryV2.isChainValid("eip155:43114"));
        assertTrue(!registryV2.isChainValid("eip155:10"));
    }

    function test_adoptSafeHarbor() public {
        address entity = address(0xee);

        vm.expectEmit();
        emit SafeHarborRegistryV2.SafeHarborAdoption(entity, address(0), agreementAddress);
        vm.prank(entity);
        registryV2.adoptSafeHarbor(agreementAddress);
    }

    function test_getDetails() public {
        address entity = address(0xee);

        vm.prank(entity);
        registryV2.adoptSafeHarbor(agreementAddress);
        address _agreement = registryV2.getAgreement(entity);
        assertEq(agreementAddress, _agreement);
    }

    function test_getDetails_fallback() public {
        address entity = address(0xee);

        vm.prank(entity);
        registryV2.adoptSafeHarbor(agreementAddress);
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
