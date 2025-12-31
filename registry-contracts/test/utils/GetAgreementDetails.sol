// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    AgreementDetails,
    Account,
    ChildContractScope,
    Chain,
    Contact,
    BountyTerms,
    IdentityRequirements
} from "src/types/AgreementTypes.sol";
import { console } from "forge-std/console.sol";

function getMockAgreementDetails(string memory accountAddress) pure returns (AgreementDetails memory mockDetails) {
    Account memory account = Account({ accountAddress: accountAddress, childContractScope: ChildContractScope.All });

    Chain memory chain = Chain({
        accounts: new Account[](1),
        assetRecoveryAddress: "0x0000000000000000000000000000000000000022",
        caip2ChainId: "eip155:1"
    });
    chain.accounts[0] = account;

    Contact memory contact = Contact({ name: "Test Name V2", contact: "test@mail.com" });

    BountyTerms memory bountyTerms = BountyTerms({
        bountyPercentage: 10,
        bountyCapUSD: 100,
        retainable: false,
        identity: IdentityRequirements.Anonymous,
        diligenceRequirements: "none",
        aggregateBountyCapUSD: 1000
    });

    mockDetails = AgreementDetails({
        protocolName: "testProtocolV2",
        chains: new Chain[](1),
        contactDetails: new Contact[](1),
        bountyTerms: bountyTerms,
        agreementURI: "ipfs://testHash"
    });
    mockDetails.chains[0] = chain;
    mockDetails.contactDetails[0] = contact;

    return mockDetails;
}

function logAgreementDetails(AgreementDetails memory details) pure {
    string[3] memory identityRequirements = ["Anonymous", "Pseudonymous", "Named"];
    string[4] memory childContractScopes = ["None", "ExistingOnly", "All", "FutureOnly"];

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
        console.log("  Chain ID:", details.chains[i].caip2ChainId);
        console.log("  Asset Recovery Address:", details.chains[i].assetRecoveryAddress);
        console.log("  Number of Accounts in Scope:", toString(details.chains[i].accounts.length));

        // Print Account Details
        for (uint256 j = 0; j < details.chains[i].accounts.length; j++) {
            console.log("    Account Address:", details.chains[i].accounts[j].accountAddress);
            console.log(
                "    Child Contract Scope:",
                childContractScopes[uint256(details.chains[i].accounts[j].childContractScope)]
            );
        }
    }

    // Print Bounty Terms
    console.log("Bounty Percentage:", toString(uint256(details.bountyTerms.bountyPercentage)));
    console.log("Bounty Cap USD:", toString(details.bountyTerms.bountyCapUSD));
    console.log("Aggregate Bounty Cap USD:", toString(details.bountyTerms.aggregateBountyCapUSD));
    console.log("Is Retainable:", details.bountyTerms.retainable ? "Yes" : "No");
    console.log("Identity Requirement:", identityRequirements[uint256(details.bountyTerms.identity)]);
    console.log("Diligence Requirements:", details.bountyTerms.diligenceRequirements);
}

function toString(uint256 value) pure returns (string memory) {
    if (value == 0) {
        return "0";
    }

    uint256 temp = value;
    uint256 digits;

    while (temp != 0) {
        digits++;
        temp /= 10;
    }

    bytes memory buffer = new bytes(digits);

    while (value != 0) {
        digits--;
        buffer[digits] = bytes1(uint8(48 + (value % 10)));
        value /= 10;
    }

    return string(buffer);
}
