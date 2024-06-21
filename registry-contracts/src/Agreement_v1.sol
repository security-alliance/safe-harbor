// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./SafeHarborRegistry.sol";

// Smart contract that contains the terms that will be deployed by a protocol
// when they adopt the agreement with the protocol's selected AgreementDetails
contract AgreementV1 {
    AgreementDetailsV1 public details;

    constructor(AgreementDetailsV1 memory _details) {
        details = _details;
    }
}

// The contract that has been approved by the safe harbor registry to record new adoptions.
contract AgreementV1Factory {
    SafeHarborRegistry public registry;

    constructor(address registryAddress) {
        registry = SafeHarborRegistry(registryAddress);
    }

    function adoptSafeHarbor(AgreementDetailsV1 memory details) external {
        AgreementV1 agreementDetails = new AgreementV1(details);
        registry.recordAdoption(address(agreementDetails));
    }
}

struct AgreementDetailsV1 {
    // The name of the protocol adopting the agreement.
    string protocolName;
    Chain[] chains;
    // The contact details (required for pre-notifying).
    Contact[] contactDetails;
    // The terms of the agreement.
    BountyTerms bountyTerms;
    // Indication whether the agreement should be automatically upgraded to future versions approved by SEAL.
    bool automaticallyUpgrade;
    // IPFS hash of the actual agreement document, which confirms all terms.
    string agreementURI;
}

struct Chain {
    Account[] accounts;
    address assetRecoveryAddress;
    uint chainID;
}

struct Account {
    // The address of the account (EOA or smart contract).
    address accountAddress;
    // Whether smart contracts deployed by this account are in scope.
    bool includeChildContracts;
    // Whether smart contracts deployed by this account after the agreement is adopted are in scope.
    bool includeNewChildContracts;
    //
    // signature of (Account.signature = 0)
    // For contracts - add support for https://eips.ethereum.org/EIPS/eip-1271
}

struct Contact {
    // The name of the contact.
    string name;
    // The role of the contact.
    string role;
    // The contact details (IE email, phone, telegram).
    string contact;
}

enum IdentityRequirement {
    Anonymous,
    Pseudonymous,
    Named
}

struct BountyTerms {
    // Percentage of the recovered funds a Whitehat receives as their bounty (0-100).
    uint bountyPercentage;
    // The maximum bounty in USD.
    uint bountyCapUSD;
    // Indicates if the Whitehat can retain their bounty.
    bool retainable;
    // Identity requirements for Whitehats eligible under the agreement.
    IdentityRequirement identityRequirement;
    // Description of what KYC, sanctions, diligence, or other verification will be performed on Whitehats to determine their eligibility to receive the bounty.
    string diligenceRequirements;
}
