// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { ChainValidator } from "src/ChainValidator.sol";
import { Agreement } from "src/Agreement.sol";
import { AgreementDetails } from "src/types/AgreementTypes.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";
import { getMockAgreementDetails } from "test/utils/GetAgreementDetails.sol";

contract SafeHarborRegistryTest is Test {
    address owner;

    SafeHarborRegistry registry;
    ChainValidator chainValidator;
    HelperConfig helperConfig;
    DeploySafeHarbor deployer;

    Agreement agreement;
    address agreementAddress;

    function setUp() public {
        // Use HelperConfig and DeploySafeHarbor for deployment
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();

        // Initialize deployer with helperConfig
        deployer.initialize(helperConfig);

        // Get network config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        owner = networkConfig.owner;

        // Deploy ChainValidator using CREATE3
        chainValidator = ChainValidator(deployer.deployChainValidator());

        // Deploy SafeHarborRegistry using CREATE3
        registry = SafeHarborRegistry(deployer.deployRegistry());

        // Create a test agreement
        AgreementDetails memory details = getMockAgreementDetails("0xaabbccdd");
        vm.prank(owner);
        agreement = new Agreement(details, address(registry), owner);
        agreementAddress = address(agreement);
    }

    // ----- CHAIN VALIDATOR TESTS -----
    // Note: Chain validation is now delegated to ChainValidator contract

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

        // Verify chains are valid via registry (which delegates to chainValidator)
        assertTrue(registry.isChainValid("eip155:1")); // Already valid from deployment
        assertTrue(registry.isChainValid("eip155:99999991"));
        assertTrue(registry.isChainValid("eip155:99999992"));
        assertFalse(registry.isChainValid("eip155:88888888"));
    }

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

        assertTrue(chainValidator.isChainValid("eip155:99999991"));
        assertFalse(chainValidator.isChainValid("eip155:99999992"));
    }

    function test_getValidChains() public view {
        string[] memory validChains = registry.getValidChains();
        // Should have the 126 chains from HelperConfig
        assertEq(validChains.length, 126);
        assertEq(validChains[0], "eip155:1");
    }

    // ----- CHAIN VALIDATOR SETTER TEST -----

    function test_setChainValidator() public {
        // Deploy a new chain validator
        string[] memory newValidChains = new string[](1);
        newValidChains[0] = "eip155:12345";
        ChainValidator newValidator = new ChainValidator(owner, newValidChains);

        // Should fail if not called by owner
        vm.expectRevert();
        registry.setChainValidator(address(newValidator));

        // Should fail with zero address
        vm.prank(owner);
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__ZeroAddress.selector);
        registry.setChainValidator(address(0));

        // Should succeed if called by owner
        vm.expectEmit();
        emit SafeHarborRegistry.ChainValidatorSet(address(newValidator));
        vm.prank(owner);
        registry.setChainValidator(address(newValidator));

        // Verify the new validator is used
        assertEq(registry.getChainValidator(), address(newValidator));
        assertTrue(registry.isChainValid("eip155:12345"));
        assertFalse(registry.isChainValid("eip155:1")); // Old chain no longer valid
    }

    // ----- ADOPTION TESTS -----

    function test_adoptSafeHarbor() public {
        address entity = address(0xee);

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(entity, agreementAddress);
        vm.prank(entity);
        registry.adoptSafeHarbor(agreementAddress);
    }

    function test_getAgreement() public {
        address entity = address(0xee);

        vm.prank(entity);
        registry.adoptSafeHarbor(agreementAddress);
        address _agreement = registry.getAgreement(entity);
        assertEq(agreementAddress, _agreement);
    }

    function test_getAgreement_missing() public {
        address entity = address(0xee);

        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__NoAgreement.selector);
        registry.getAgreement(entity);
    }

    function test_version() public view {
        assertEq(registry.version(), "3.0.0");
    }

    // ----- CONSTRUCTOR TESTS -----

    function test_constructor_zeroChainValidator() public {
        address[] memory adopters = new address[](0);
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__ZeroAddress.selector);
        new SafeHarborRegistry(owner, address(0), address(0), adopters);
    }

    function test_constructor_withMigration() public {
        // Setup: Create a "legacy" registry with an adopter
        address legacyAdopter = address(0xbeef);

        // Deploy a mock legacy registry (we'll use SafeHarborRegistry as a stand-in)
        string[] memory legacyChains = new string[](1);
        legacyChains[0] = "eip155:1";
        ChainValidator legacyValidator = new ChainValidator(owner, legacyChains);
        address[] memory emptyAdopters = new address[](0);
        SafeHarborRegistry legacyRegistry =
            new SafeHarborRegistry(owner, address(legacyValidator), address(0), emptyAdopters);

        // Have the legacy adopter adopt
        vm.prank(legacyAdopter);
        legacyRegistry.adoptSafeHarbor(agreementAddress);

        // Now deploy a new registry with migration
        address[] memory adoptersToMigrate = new address[](1);
        adoptersToMigrate[0] = legacyAdopter;

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(legacyAdopter, agreementAddress);
        vm.expectEmit();
        emit SafeHarborRegistry.LegacyDataMigrated(address(legacyRegistry), 1);

        SafeHarborRegistry newRegistry =
            new SafeHarborRegistry(owner, address(chainValidator), address(legacyRegistry), adoptersToMigrate);

        // Verify the adopter was migrated
        assertEq(newRegistry.getAgreement(legacyAdopter), agreementAddress);
    }

    function test_constructor_withMigration_adopterNotFound() public {
        // Setup: Create a "legacy" registry WITHOUT any adopters
        string[] memory legacyChains = new string[](1);
        legacyChains[0] = "eip155:1";
        ChainValidator legacyValidator = new ChainValidator(owner, legacyChains);
        address[] memory emptyAdopters = new address[](0);
        SafeHarborRegistry legacyRegistry =
            new SafeHarborRegistry(owner, address(legacyValidator), address(0), emptyAdopters);

        // Try to migrate an adopter that doesn't exist in the legacy registry
        // This should trigger the catch block (getAgreement reverts with NoAgreement)
        address nonExistentAdopter = address(0xdead);
        address[] memory adoptersToMigrate = new address[](1);
        adoptersToMigrate[0] = nonExistentAdopter;

        // Should still emit LegacyDataMigrated but with count 0 (the adopter was skipped)
        vm.expectEmit();
        emit SafeHarborRegistry.LegacyDataMigrated(address(legacyRegistry), 0);

        SafeHarborRegistry newRegistry =
            new SafeHarborRegistry(owner, address(chainValidator), address(legacyRegistry), adoptersToMigrate);

        // The non-existent adopter should NOT have been migrated
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__NoAgreement.selector);
        newRegistry.getAgreement(nonExistentAdopter);
    }

    function test_constructor_withMigration_mixedAdopters() public {
        // Setup: Create a "legacy" registry with one adopter
        address validAdopter = address(0xbeef);
        address invalidAdopter = address(0xdead);

        string[] memory legacyChains = new string[](1);
        legacyChains[0] = "eip155:1";
        ChainValidator legacyValidator = new ChainValidator(owner, legacyChains);
        address[] memory emptyAdopters = new address[](0);
        SafeHarborRegistry legacyRegistry =
            new SafeHarborRegistry(owner, address(legacyValidator), address(0), emptyAdopters);

        // Have only one adopter adopt
        vm.prank(validAdopter);
        legacyRegistry.adoptSafeHarbor(agreementAddress);

        // Try to migrate both valid and invalid adopters
        address[] memory adoptersToMigrate = new address[](2);
        adoptersToMigrate[0] = validAdopter;
        adoptersToMigrate[1] = invalidAdopter; // This one will be skipped

        // Should emit events for valid adopter and final migration count of 1
        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(validAdopter, agreementAddress);
        vm.expectEmit();
        emit SafeHarborRegistry.LegacyDataMigrated(address(legacyRegistry), 1);

        SafeHarborRegistry newRegistry =
            new SafeHarborRegistry(owner, address(chainValidator), address(legacyRegistry), adoptersToMigrate);

        // Valid adopter should be migrated
        assertEq(newRegistry.getAgreement(validAdopter), agreementAddress);

        // Invalid adopter should NOT be migrated
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__NoAgreement.selector);
        newRegistry.getAgreement(invalidAdopter);
    }
}
