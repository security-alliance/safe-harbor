// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementFactoryV2.sol";
import "../../src/v2/AgreementV2.sol";
import "../../script/v2/AdoptSafeHarborV2.s.sol";
import {getMockAgreementDetails as getMockAgreementDetailsV2} from "../v2/mock.sol";
import {AgreementDetailsV2} from "../../src/v2/AgreementDetailsV2.sol";

contract AdoptSafeHarborV2Test is TestBase, DSTest {
    uint256 mockKey;
    address mockAddress;
    SafeHarborRegistryV2 registry;
    AgreementFactoryV2 factory;
    string json;

    function setUp() public {
        // Set up mock deployer
        mockKey = 0xA11;
        mockAddress = vm.addr(mockKey);

        // Deploy the SafeHarborRegistryV2
        address fallbackRegistry = address(0);
        registry = new SafeHarborRegistryV2(fallbackRegistry, mockAddress);

        // Set up valid chains in registry
        string[] memory validChains = new string[](2);
        validChains[0] = "eip155:1";
        validChains[1] = "eip155:2";

        vm.prank(mockAddress);
        registry.setValidChains(validChains);

        // Deploy the AgreementFactoryV2
        factory = new AgreementFactoryV2();

        // Read mock data
        json = vm.readFile("test/v2/mock.json");
    }

    function test_run() public {
        // Get mock agreement details
        AgreementDetailsV2 memory details = getMockAgreementDetailsV2(vm.toString(mockAddress));

        // Create agreement using factory
        vm.prank(mockAddress);
        address agreementAddr = factory.create(details, address(registry), mockAddress);

        // Adopt the agreement
        vm.prank(mockAddress);
        registry.adoptSafeHarbor(agreementAddr);

        // Verify the agreement was adopted
        address adoptedAddr = registry.getAgreement(mockAddress);
        assertEq(adoptedAddr, agreementAddr, "Agreement should be adopted");

        AgreementV2 agreement = AgreementV2(agreementAddr);
        AgreementDetailsV2 memory gotDetails = agreement.getDetails();

        console.logString("--------------------------GOT--------------------------");
        logAgreementDetailsV2(gotDetails);
        console.logString("--------------------------WANT--------------------------");
        logAgreementDetailsV2(details);

        // Compare the details
        assertEq(keccak256(abi.encode(details)), keccak256(abi.encode(gotDetails)), "Agreement details should match");

        // Verify owner is set correctly
        assertEq(agreement.owner(), mockAddress, "Agreement owner should be the adopter");

        // Verify version
        assertEq(agreement.version(), "1.1.0", "Agreement version should be correct");
    }

    function test_adoptWithCustomDetails() public {
        // Create custom agreement details
        AgreementDetailsV2 memory customDetails = getMockAgreementDetailsV2(vm.toString(mockAddress));
        customDetails.protocolName = "Custom Protocol";
        customDetails.agreementURI = "ipfs://customhash";

        // Create agreement using factory
        vm.prank(mockAddress);
        address agreementAddr = factory.create(customDetails, address(registry), mockAddress);

        // Adopt the agreement
        vm.prank(mockAddress);
        registry.adoptSafeHarbor(agreementAddr);

        // Verify adoption
        address adoptedAddr = registry.getAgreement(mockAddress);
        assertEq(adoptedAddr, agreementAddr, "Adopted agreement address should match");

        AgreementV2 agreement = AgreementV2(adoptedAddr);
        AgreementDetailsV2 memory details = agreement.getDetails();

        assertEq(details.protocolName, "Custom Protocol", "Protocol name should be custom");
        assertEq(details.agreementURI, "ipfs://customhash", "Agreement URI should be custom");
    }

    function test_factoryWithInvalidChain() public {
        // Create details with invalid chain
        AgreementDetailsV2 memory invalidDetails = getMockAgreementDetailsV2(vm.toString(mockAddress));
        invalidDetails.chains[0].caip2ChainId = "eip155:999"; // Invalid chain

        // Should fail when creating agreement with invalid chain
        vm.prank(mockAddress);
        vm.expectRevert(abi.encodeWithSelector(AgreementV2.InvalidChainId.selector, "eip155:999"));
        factory.create(invalidDetails, address(registry), mockAddress);
    }

    function test_multipleAdoptions() public {
        // Create first agreement
        AgreementDetailsV2 memory details1 = getMockAgreementDetailsV2(vm.toString(mockAddress));
        details1.protocolName = "Protocol 1";

        vm.prank(mockAddress);
        address agreement1 = factory.create(details1, address(registry), mockAddress);

        vm.prank(mockAddress);
        registry.adoptSafeHarbor(agreement1);

        // Verify first adoption
        assertEq(registry.getAgreement(mockAddress), agreement1);

        // Create second agreement
        AgreementDetailsV2 memory details2 = getMockAgreementDetailsV2(vm.toString(mockAddress));
        details2.protocolName = "Protocol 2";

        vm.prank(mockAddress);
        address agreement2 = factory.create(details2, address(registry), mockAddress);

        vm.prank(mockAddress);
        registry.adoptSafeHarbor(agreement2);

        // Verify second adoption replaced the first
        assertEq(registry.getAgreement(mockAddress), agreement2);

        AgreementV2 finalAgreement = AgreementV2(agreement2);
        AgreementDetailsV2 memory finalDetails = finalAgreement.getDetails();
        assertEq(finalDetails.protocolName, "Protocol 2");
    }

    // Helper function to log V2 agreement details
    function logAgreementDetailsV2(AgreementDetailsV2 memory details) internal view {
        console.logString("Protocol Name:");
        console.logString(details.protocolName);
        console.logString("Agreement URI:");
        console.logString(details.agreementURI);
        console.logString("Chains:");
        for (uint256 i = 0; i < details.chains.length; i++) {
            console.logString(string.concat("  Chain ", vm.toString(i), ":"));
            console.logString(string.concat("    CAIP-2 ID: ", details.chains[i].caip2ChainId));
            console.logString(string.concat("    Recovery Address: ", details.chains[i].assetRecoveryAddress));
            console.logString(string.concat("    Accounts: ", vm.toString(details.chains[i].accounts.length)));
        }
        console.logString("Bounty Terms:");
        console.logUint(details.bountyTerms.bountyPercentage);
        console.logUint(details.bountyTerms.bountyCapUSD);
        console.logBool(details.bountyTerms.retainable);
    }
}
