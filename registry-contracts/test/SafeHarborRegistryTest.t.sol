// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SafeHarborRegistry.sol";

event SafeHarborAdoption(
    address indexed entity,
    SafeHarborRegistry.AgreementDetails oldDetails,
    SafeHarborRegistry.AgreementDetails newDetails
);

contract SafeHarborRegistryTest is Test {
    SafeHarborRegistry registry;
    SafeHarborRegistry.AgreementDetails emptyDetails;
    SafeHarborRegistry.AgreementDetails exampleDetails;

    function setUp() public {
        registry = new SafeHarborRegistry();

        // Define example agreement details
        exampleDetails = SafeHarborRegistry.AgreementDetails({
            protocolName: "Test Protocol",
            scope: "Test Assets",
            contactDetails: "test@example.com",
            bountyTerms: "10% bounty",
            assetRecoveryAddress: address(0xdead),
            agreementURI: "ipfs://testhash"
        });
    }

    function testAdoptSafeHarbor() public {
        // Expect the SafeHarborAdoption event to be emitted with specific parameters
        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(
            address(this),
            emptyDetails,
            exampleDetails
        );
        registry.adoptSafeHarbor(exampleDetails);

        // Verify that the agreement details were correctly updated
        (
            string memory protocolName,
            string memory scope,
            string memory contactDetails,
            string memory bountyTerms,
            address assetRecoveryAddress,
            string memory agreementURI
        ) = registry.agreements(address(this));

        assertEq(protocolName, exampleDetails.protocolName);
        assertEq(scope, exampleDetails.scope);
        assertEq(contactDetails, exampleDetails.contactDetails);
        assertEq(bountyTerms, exampleDetails.bountyTerms);
        assertEq(assetRecoveryAddress, exampleDetails.assetRecoveryAddress);
        assertEq(agreementURI, exampleDetails.agreementURI);
    }

    function testAdoptAndUpdateSafeHarbor() public {
        registry.adoptSafeHarbor(exampleDetails);

        exampleDetails.scope = "Updated Assets";

        registry.adoptSafeHarbor(exampleDetails);

        (
            string memory protocolName,
            string memory scope,
            string memory contactDetails,
            string memory bountyTerms,
            address assetRecoveryAddress,
            string memory agreementURI
        ) = registry.agreements(address(this));

        assertEq(protocolName, exampleDetails.protocolName);
        assertEq(scope, exampleDetails.scope);
        assertEq(contactDetails, exampleDetails.contactDetails);
        assertEq(bountyTerms, exampleDetails.bountyTerms);
        assertEq(assetRecoveryAddress, exampleDetails.assetRecoveryAddress);
        assertEq(agreementURI, exampleDetails.agreementURI);
    }
}
