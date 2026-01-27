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
        agreement = new Agreement(details, address(chainValidator), owner);
        agreementAddress = address(agreement);
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

    function test_constructor_fresh() public {
        // Deploy a fresh registry with no legacy migration
        address[] memory adopters = new address[](0);
        SafeHarborRegistry freshRegistry = new SafeHarborRegistry(address(0), adopters);

        // Should work and have no adopters
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__NoAgreement.selector);
        freshRegistry.getAgreement(address(0xbeef));
    }

    function test_constructor_withMigration() public {
        // Setup: Create a "legacy" registry with an adopter
        address legacyAdopter = address(0xbeef);

        // Deploy a mock legacy registry
        address[] memory emptyAdopters = new address[](0);
        SafeHarborRegistry legacyRegistry = new SafeHarborRegistry(address(0), emptyAdopters);

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

        SafeHarborRegistry newRegistry = new SafeHarborRegistry(address(legacyRegistry), adoptersToMigrate);

        // Verify the adopter was migrated
        assertEq(newRegistry.getAgreement(legacyAdopter), agreementAddress);
    }

    function test_constructor_withMigration_adopterNotFound() public {
        // Setup: Create a "legacy" registry WITHOUT any adopters
        address[] memory emptyAdopters = new address[](0);
        SafeHarborRegistry legacyRegistry = new SafeHarborRegistry(address(0), emptyAdopters);

        // Try to migrate an adopter that doesn't exist in the legacy registry
        // This should trigger the catch block (getAgreement reverts with NoAgreement)
        address nonExistentAdopter = address(0xdead);
        address[] memory adoptersToMigrate = new address[](1);
        adoptersToMigrate[0] = nonExistentAdopter;

        // Should still emit LegacyDataMigrated but with count 0 (the adopter was skipped)
        vm.expectEmit();
        emit SafeHarborRegistry.LegacyDataMigrated(address(legacyRegistry), 0);

        SafeHarborRegistry newRegistry = new SafeHarborRegistry(address(legacyRegistry), adoptersToMigrate);

        // The non-existent adopter should NOT have been migrated
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__NoAgreement.selector);
        newRegistry.getAgreement(nonExistentAdopter);
    }

    function test_constructor_withMigration_mixedAdopters() public {
        // Setup: Create a "legacy" registry with one adopter
        address validAdopter = address(0xbeef);
        address invalidAdopter = address(0xdead);

        address[] memory emptyAdopters = new address[](0);
        SafeHarborRegistry legacyRegistry = new SafeHarborRegistry(address(0), emptyAdopters);

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

        SafeHarborRegistry newRegistry = new SafeHarborRegistry(address(legacyRegistry), adoptersToMigrate);

        // Valid adopter should be migrated
        assertEq(newRegistry.getAgreement(validAdopter), agreementAddress);

        // Invalid adopter should NOT be migrated
        vm.expectRevert(SafeHarborRegistry.SafeHarborRegistry__NoAgreement.selector);
        newRegistry.getAgreement(invalidAdopter);
    }
}
