// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../src/SafeHarborRegistry.sol";
import "../src/Agreement_v1.sol";

contract SafeHarborRegistryTest is Test {
    function testSetUp() public {
        SafeHarborRegistry registry = new SafeHarborRegistry();
        AgreementV1Factory factory = new AgreementV1Factory(address(registry));

        registry.enableFactory(address(factory));

        AgreementDetailsV1 memory details = AgreementDetailsV1({
            protocolName: "Test Protocol",
            // For complex array types, each element should be constructed explicitly in its own statement.
            chains: new Chain[](1), // Specify the size of the array
            contactDetails: new Contact[](1), // An empty array is fine if no initial elements
            bountyTerms: BountyTerms({
                bountyPercentage: 10,
                bountyCapUSD: 100,
                retainable: false,
                identityRequirement: IdentityRequirement.Named,
                diligenceRequirements: "joe mama"
            }),
            automaticallyUpgrade: false,
            agreementURI: "ipfs://QmX7"
        });

        // Properly initialize elements of the array `chains`
        details.chains[0] = Chain({
            accounts: new Account[](1), // Specify the size of the array
            assetRecoveryAddress: address(this),
            chainID: 1
        });

        // Initialize the `accounts` array within the `Chain`
        details.chains[0].accounts[0] = Account({
            accountAddress: address(this),
            includeChildContracts: false,
            includeNewChildContracts: false
        });

        details.contactDetails[0] = Contact({
            name: "Big mama",
            role: "head mama",
            contact: "raven"
        });

        factory.adoptSafeHarbor(details);
    }
}
