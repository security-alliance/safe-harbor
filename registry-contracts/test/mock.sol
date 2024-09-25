// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/AgreementV1.sol";

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
