// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TestBase} from "forge-std/Test.sol";
import "../src/SafeHarborRegistry.sol";
import "../src/Agreement_v1.sol";

contract SafeHarborRegistryTest is TestBase {
    function testSetUp() public {
        SafeHarborRegistry registry = new SafeHarborRegistry();
        AgreementV1Factory factory = new AgreementV1Factory(address(registry));

        registry.enableFactory(address(factory));

        AgreementDetailsV1 memory details = AgreementDetailsV1({
            protocolName: "Test Protocol",
            chains: new Chain[](1),
            contactDetails: new Contact[](1),
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

        details.chains[0] = Chain({
            accounts: new Account[](1),
            assetRecoveryAddress: address(this),
            chainID: 1
        });

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
