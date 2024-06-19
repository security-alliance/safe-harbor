// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./SafeHarborRegistry.sol";

contract AgreementV1 {
    AgreementDetailsV1 public details;

    constructor(AgreementDetailsV1 memory _details) {
        details = _details;
    }
}

contract AgreementDetailDeployerV1 {
    SafeHarborRegistry public registry;

    constructor(address registryAddress) {
        registry = SafeHarborRegistry(registryAddress);
    }

    function adoptSafeHarbor(AgreementDetailsV1 memory details) external {
        AgreementV1 agreementDetails = new AgreementV1(details);
        registry.recordAdoption(msg.sender, address(agreementDetails));
    }
}

struct AgreementDetailsV1 {
    // The name of the protocol adopting the agreement.
    string protocolName;
    // The contracts in scope of the agreement.
    Contract[] scope;
    // The contact details (required for pre-notifying).
    Contact[] contactDetails;
    // The bounty terms.
    BountyTerms bountyTerms;
    // Indication whether the agreement should be automatically upgraded to future versions approved by SEAL.
    bool automaticallyUpgrade;
    // Address where recovered funds should be sent.
    address assetRecoveryAddress;
    // IPFS hash of the actual agreement document, which confirms all terms.
    string agreementURI;
}

struct Contract {
    // The address of the contract.
    address contractAddress;
    // The chain IDs on which the contract is deployed.
    uint[] chainIDs;
    // Whether smart contracts deployed by this address are in scope.
    bool includeChildContracts;
    // Whether smart contracts deployed by this address after the agreement is adopted are in scope.
    bool includeNewChildContracts;
}

struct Contact {
    // The name of the contact.
    string name;
    // The email of the contact.
    string email;
    // The phone number of the contact.
    string phone;
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
