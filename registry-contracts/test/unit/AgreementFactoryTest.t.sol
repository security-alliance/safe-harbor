// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { ChainValidator } from "src/ChainValidator.sol";
import { AgreementFactory } from "src/AgreementFactory.sol";
import { Agreement } from "src/Agreement.sol";
import { AgreementDetails } from "src/types/AgreementTypes.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";
import { getMockAgreementDetails } from "test/utils/GetAgreementDetails.sol";

contract AgreementFactoryTest is Test {
    SafeHarborRegistry registry;
    ChainValidator chainValidator;
    AgreementFactory factory;
    HelperConfig helperConfig;
    DeploySafeHarbor deployer;

    address owner;
    address protocol;

    function setUp() public {
        protocol = address(0xAB);

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

        // Deploy the factory
        factory = new AgreementFactory();
    }

    function test_create() public {
        AgreementDetails memory agreementDetails = getMockAgreementDetails("0xAABB");

        vm.prank(protocol);
        address agreementAddress = factory.create(agreementDetails, address(registry), protocol);

        Agreement agreement = Agreement(agreementAddress);
        AgreementDetails memory storedDetails = agreement.getDetails();
        assertEq(keccak256(abi.encode(storedDetails)), keccak256(abi.encode(agreementDetails)));

        assertEq(agreement.owner(), protocol, "Agreement owner should be protocol");
    }

    function test_create_multipleAgreements() public {
        AgreementDetails memory details1 = getMockAgreementDetails("0xAABB");

        // Create first agreement
        vm.prank(protocol);
        address agreement1 = factory.create(details1, address(registry), protocol);

        // Create second agreement with different details
        AgreementDetails memory details2 = getMockAgreementDetails("0xCCDD");
        address protocol2 = address(0xCD);
        vm.prank(protocol2);
        address agreement2 = factory.create(details2, address(registry), protocol2);

        // Verify they're different contracts
        assertTrue(agreement1 != agreement2, "Agreements should be at different addresses");

        // Verify each has correct owner
        assertEq(Agreement(agreement1).owner(), protocol);
        assertEq(Agreement(agreement2).owner(), protocol2);
    }
}
