// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import "../src/v1/AgreementV1.sol";

function getMockAgreementDetails(address accountAddress) pure returns (AgreementDetailsV1 memory mockDetails) {
    Account memory account =
        Account({accountAddress: accountAddress, childContractScope: ChildContractScope.All, signature: new bytes(0)});

    Chain memory chain = Chain({accounts: new Account[](1), assetRecoveryAddress: address(0x11), id: 1});
    chain.accounts[0] = account;

    Contact memory contact = Contact({name: "Test Name", contact: "test@mail.com"});

    BountyTerms memory bountyTerms = BountyTerms({
        bountyPercentage: 10,
        bountyCapUSD: 100,
        retainable: true,
        identity: IdentityRequirements.Anonymous,
        diligenceRequirements: "none"
    });

    mockDetails = AgreementDetailsV1({
        protocolName: "testProtocol",
        chains: new Chain[](1),
        contactDetails: new Contact[](1),
        bountyTerms: bountyTerms,
        agreementURI: "ipfs://testHash"
    });
    mockDetails.chains[0] = chain;
    mockDetails.contactDetails[0] = contact;

    return mockDetails;
}

function logAgreementDetails(AgreementDetailsV1 memory details) view {
    console.log("Agreement Details:");
    console.log("Protocol Name:", details.protocolName);
    console.log("Agreement URI:", details.agreementURI);

    // Print Contact Details
    console.log("Contact Details:");
    for (uint256 i = 0; i < details.contactDetails.length; i++) {
        console.log("Contact Name:", details.contactDetails[i].name);
        console.log("Contact Information:", details.contactDetails[i].contact);
    }

    // Print Chain Details
    console.log("Chain Details:");
    for (uint256 i = 0; i < details.chains.length; i++) {
        console.log("  Chain ID:", details.chains[i].id);
        console.log("  Asset Recovery Address:", details.chains[i].assetRecoveryAddress);
        console.log("  Number of Accounts in Scope:", details.chains[i].accounts.length);

        // Print Account Details
        for (uint256 j = 0; j < details.chains[i].accounts.length; j++) {
            console.log("    Account Address:", details.chains[i].accounts[j].accountAddress);
            console.log("    Child Contract Scope:", uint256(details.chains[i].accounts[j].childContractScope));
            console.log("    Signature: ", string(details.chains[i].accounts[j].signature));
        }
    }

    // Print Bounty Terms
    console.log("Bounty Percentage:", details.bountyTerms.bountyPercentage);
    console.log("Bounty Cap USD:", details.bountyTerms.bountyCapUSD);
    console.log("Is Retainable:", details.bountyTerms.retainable);
    console.log("Identity Requirement:", uint256(details.bountyTerms.identity));
    console.log("Diligence Requirements:", details.bountyTerms.diligenceRequirements);
}
