// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/SafeHarborRegistry.sol";
import "../src/Agreement_v1.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    SafeHarborRegistry registry;
    AgreementV1Factory factory;
    AgreementDetailsV1 details;

    function setUp() public {
        registry = new SafeHarborRegistry();
        factory = new AgreementV1Factory(address(registry));

        details = AgreementDetailsV1({
            protocolName: "testProtocol",
            chains: new Chain[](1),
            contactDetails: new Contact[](1),
            bountyTerms: BountyTerms({
                bountyPercentage: 10,
                bountyCapUSD: 100,
                retainable: false,
                identityRequirement: IdentityRequirement.Named,
                diligenceRequirements: "testDiligenceRequirements"
            }),
            automaticallyUpgrade: false,
            agreementURI: "ipfs://testHash"
        });

        details.chains[0] = Chain({
            accounts: new Account[](1),
            assetRecoveryAddress: address(0x1),
            chainID: 1
        });

        details.chains[0].accounts[0] = Account({
            accountAddress: address(0x2),
            includeChildContracts: false,
            includeNewChildContracts: false
        });

        details.contactDetails[0] = Contact({
            name: "testName",
            role: "testRole",
            contact: "testContact"
        });
    }

    function test_adoptSafeHarbor() public {
        vm.expectEmit();
        emit SafeHarborRegistry.FactoryEnabled(address(factory));
        registry.enableFactory(address(factory));

        vm.expectEmit();

        emit SafeHarborRegistry.SafeHarborAdoption(
            address(tx.origin),
            address(0),
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac)
        );
        factory.adoptSafeHarbor(details);
        assertEq(
            registry.agreements(address(tx.origin)),
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac)
        );

        // Make sure the agreement was recorded correctly
        AgreementV1 agreement = AgreementV1(
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac)
        );

        (
            string memory protocolName,
            // Chain[] memory chains,
            // Contact[] memory contactDetails,
            BountyTerms memory bountyTerms,
            bool automaticallyUpgrade,
            string memory agreementURI
        ) = agreement.details();

        console.log("protocolName", protocolName);
        console.log(
            "bountyTerms.bountyPercentage",
            bountyTerms.bountyPercentage
        );
        console.log("bountyTerms.bountyCapUSD", bountyTerms.bountyCapUSD);
        console.log("bountyTerms.retainable", bountyTerms.retainable);
        console.log(
            "bountyTerms.diligenceRequirements",
            bountyTerms.diligenceRequirements
        );
        console.log("automaticallyUpgrade", automaticallyUpgrade);
        console.log("agreementURI", agreementURI);

        // get chain info
        Chain[] memory chains;
        uint256 numChains = agreement.getChainsCount();
        for (uint256 i = 0; i < numChains; i++) {
            Chain memory chain = agreement.getChain(i);
            console.log(
                "chain.assetRecoveryAddress",
                chain.assetRecoveryAddress
            );
            console.log("chain.chainID", chain.chainID);

            // get account info
            Account[] memory accounts = chain.accounts;
            uint256 numAccounts = accounts.length;
            for (uint256 j = 0; j < numAccounts; j++) {
                Account memory account = accounts[j];
                console.log("account.accountAddress", account.accountAddress);
                console.log(
                    "account.includeChildContracts",
                    account.includeChildContracts
                );
                console.log(
                    "account.includeNewChildContracts",
                    account.includeNewChildContracts
                );
            }
        }

        // get contact info
        Contact[] memory contactDetails;
        uint256 numContacts = agreement.getContactsCount();
        for (uint256 i = 0; i < numContacts; i++) {
            Contact memory contact = agreement.getContact(i);
            console.log("contact.name", contact.name);
            console.log("contact.role", contact.role);
            console.log("contact.contact", contact.contact);
        }
    }
}
