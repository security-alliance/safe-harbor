// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ChainValidator} from "src/ChainValidator.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeploySafeHarbor} from "script/Deploy.s.sol";

contract ChainValidatorTest is Test {
    address owner;

    ChainValidator chainValidator;
    HelperConfig helperConfig;
    DeploySafeHarbor deployer;

    function setUp() public {
        // Use HelperConfig and DeploySafeHarbor for deployment
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();

        // Initialize deployer with helperConfig
        deployer.initialize(helperConfig);

        // Get network config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getNetworkConfig();
        owner = networkConfig.owner;

        // Deploy ChainValidator using CREATE3
        chainValidator = ChainValidator(deployer.deployChainValidator());
    }

    // ----- CONSTRUCTOR TESTS -----

    function test_constructor() public {
        // Deploy a fresh ChainValidator with custom chains
        string[] memory initialChains = new string[](2);
        initialChains[0] = "eip155:1";
        initialChains[1] = "eip155:137";

        ChainValidator freshValidator = new ChainValidator(
            owner,
            initialChains
        );

        // Verify initial chains are valid
        assertTrue(freshValidator.isChainValid("eip155:1"));
        assertTrue(freshValidator.isChainValid("eip155:137"));
        assertFalse(freshValidator.isChainValid("eip155:999"));

        // Verify owner is set correctly
        assertEq(freshValidator.owner(), owner);
    }

    function test_constructor_emptyChains() public {
        // Deploy with no initial chains
        string[] memory emptyChains = new string[](0);
        ChainValidator emptyValidator = new ChainValidator(owner, emptyChains);

        // No chains should be valid
        assertFalse(emptyValidator.isChainValid("eip155:1"));
        string[] memory validChains = emptyValidator.getValidChains();
        assertEq(validChains.length, 0);
    }

    // ----- SET VALID CHAINS TESTS -----

    function test_setValidChains() public {
        string[] memory caip2ChainIds = new string[](2);
        caip2ChainIds[0] = "eip155:99999991";
        caip2ChainIds[1] = "eip155:99999992";

        // Should fail if not called by owner
        vm.expectRevert();
        chainValidator.setValidChains(caip2ChainIds);

        // Should succeed if called by owner
        vm.expectEmit();
        emit ChainValidator.ChainValiditySet(caip2ChainIds[0], true);
        vm.expectEmit();
        emit ChainValidator.ChainValiditySet(caip2ChainIds[1], true);
        vm.prank(owner);
        chainValidator.setValidChains(caip2ChainIds);

        // Verify chains are now valid
        assertTrue(chainValidator.isChainValid("eip155:1")); // Already valid from deployment
        assertTrue(chainValidator.isChainValid("eip155:99999991"));
        assertTrue(chainValidator.isChainValid("eip155:99999992"));
        assertFalse(chainValidator.isChainValid("eip155:88888888"));
    }

    function test_setValidChains_duplicateChain() public {
        string[] memory chains = new string[](1);
        chains[0] = "eip155:1"; // Already valid from deployment

        // Adding an already valid chain should still emit event but not duplicate in list
        vm.expectEmit();
        emit ChainValidator.ChainValiditySet("eip155:1", true);
        vm.prank(owner);
        chainValidator.setValidChains(chains);

        // List should not have duplicates (still 126 from HelperConfig)
        string[] memory validChains = chainValidator.getValidChains();
        assertEq(validChains.length, 126);
    }

    // ----- SET INVALID CHAINS TESTS -----

    function test_setInvalidChains() public {
        // First add some chains to remove
        string[] memory newChains = new string[](2);
        newChains[0] = "eip155:99999991";
        newChains[1] = "eip155:99999992";
        vm.prank(owner);
        chainValidator.setValidChains(newChains);

        // Verify they're valid
        assertTrue(chainValidator.isChainValid("eip155:99999991"));
        assertTrue(chainValidator.isChainValid("eip155:99999992"));

        string[] memory invalidChains = new string[](1);
        invalidChains[0] = "eip155:99999992";

        // Should fail if not called by owner
        vm.expectRevert();
        chainValidator.setInvalidChains(invalidChains);

        // Should succeed if called by owner
        vm.expectEmit();
        emit ChainValidator.ChainValiditySet("eip155:99999992", false);
        vm.prank(owner);
        chainValidator.setInvalidChains(invalidChains);

        // Verify one is still valid, one is not
        assertTrue(chainValidator.isChainValid("eip155:99999991"));
        assertFalse(chainValidator.isChainValid("eip155:99999992"));
    }

    function test_setInvalidChains_alreadyInvalid() public {
        string[] memory chains = new string[](1);
        chains[0] = "eip155:88888888"; // Never was valid

        // Removing an already invalid chain should still emit event
        vm.expectEmit();
        emit ChainValidator.ChainValiditySet("eip155:88888888", false);
        vm.prank(owner);
        chainValidator.setInvalidChains(chains);

        // Should still be invalid
        assertFalse(chainValidator.isChainValid("eip155:88888888"));
    }

    function test_setInvalidChains_removeFromMiddle() public {
        // Add multiple chains
        string[] memory newChains = new string[](3);
        newChains[0] = "eip155:99999991";
        newChains[1] = "eip155:99999992";
        newChains[2] = "eip155:99999993";
        vm.prank(owner);
        chainValidator.setValidChains(newChains);

        uint256 initialLength = chainValidator.getValidChains().length;

        // Remove the middle one
        string[] memory toRemove = new string[](1);
        toRemove[0] = "eip155:99999992";
        vm.prank(owner);
        chainValidator.setInvalidChains(toRemove);

        // List should be shorter by 1
        string[] memory validChains = chainValidator.getValidChains();
        assertEq(validChains.length, initialLength - 1);

        // Verify the correct chain was removed
        assertTrue(chainValidator.isChainValid("eip155:99999991"));
        assertFalse(chainValidator.isChainValid("eip155:99999992"));
        assertTrue(chainValidator.isChainValid("eip155:99999993"));
    }

    // ----- READ FUNCTIONS TESTS -----

    function test_isChainValid() public view {
        // Valid chain from HelperConfig
        assertTrue(chainValidator.isChainValid("eip155:1"));
        assertTrue(chainValidator.isChainValid("eip155:137"));

        // Invalid chain
        assertFalse(chainValidator.isChainValid("eip155:99999999"));
        assertFalse(chainValidator.isChainValid("invalid:chain"));
    }

    function test_getValidChains() public view {
        string[] memory validChains = chainValidator.getValidChains();

        // Should have the 126 chains from HelperConfig
        assertEq(validChains.length, 126);
        assertEq(validChains[0], "eip155:1");
    }

    // ----- OWNERSHIP TESTS -----

    function test_ownerCanTransferOwnership() public {
        address newOwner = address(0xbeef);

        vm.prank(owner);
        chainValidator.transferOwnership(newOwner);

        // New owner should be able to add chains
        string[] memory chains = new string[](1);
        chains[0] = "eip155:88888888";

        vm.prank(newOwner);
        chainValidator.setValidChains(chains);

        assertTrue(chainValidator.isChainValid("eip155:88888888"));
    }

    function test_nonOwnerCannotModifyChains() public {
        address nonOwner = address(0xdead);
        string[] memory chains = new string[](1);
        chains[0] = "eip155:88888888";

        vm.prank(nonOwner);
        vm.expectRevert();
        chainValidator.setValidChains(chains);

        vm.prank(nonOwner);
        vm.expectRevert();
        chainValidator.setInvalidChains(chains);
    }
}
