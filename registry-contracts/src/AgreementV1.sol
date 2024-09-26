// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

string constant _version = "1.0.0";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
contract AgreementV1 {
    /// @notice The details of the agreement.
    AgreementDetailsV1 private details;

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    constructor(AgreementDetailsV1 memory _details) {
        details = _details;
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    /// @notice Function that returns the details of the agreement.
    /// @dev You need a view function, else it won't convert storage to memory automatically for the nested structs.
    /// @return AgreementDetailsV1 The details of the agreement.
    function getDetails() external view returns (AgreementDetailsV1 memory) {
        return details;
    }
}

/// @notice Struct that contains the details of the agreement.
struct AgreementDetailsV1 {
    // The name of the protocol adopting the agreement.
    string protocolName;
    // The contact details (required for pre-notifying).
    Contact[] contactDetails;
    // The scope and recovery address by chain.
    Chain[] chains;
    // The terms of the agreement.
    BountyTerms bountyTerms;
    // IPFS hash of the actual agreement document, which confirms all terms.
    string agreementURI;
}

/// @notice Struct that contains the contact details of the agreement.
struct Contact {
    string name;
    // This person's contact details (email, phone, telegram handle, etc.)
    string contact;
}

/// @notice Struct that contains the details of an agreement by chain.
struct Chain {
    // The address to which recovered assets will be sent.
    address assetRecoveryAddress;
    // The accounts in scope for the agreement.
    Account[] accounts;
    // The chain ID.
    uint256 id;
}

/// @notice Struct that contains the details of an account in an agreement.
struct Account {
    // The address of the account (EOA or smart contract).
    address accountAddress;
    // The scope of child contracts included in the agreement.
    ChildContractScope childContractScope;
    // The signature of the account. Optionally used to verify that this account has accepted this agreement.
    // Instructions for generating this signature may be found in the [README](../README.md).
    bytes signature;
}

/// @notice Enum that defines the inclusion of child contracts in an agreement.
enum ChildContractScope {
    // No child contracts are included.
    None,
    // Only child contracts that exist at the time of this agreement are included.
    ExistingOnly,
    // All child contracts, both existing and new, are included.
    All
}

/// @notice Whitehat identity verification requirements.
enum IdentityRequirements {
    // The whitehat will be subject to no KYC requirements.
    Anonymous,
    // The whitehat must provide a pseudonym.
    Pseudonymous,
    // The whitehat must confirm their legal name.
    Named
}

/// @notice Struct that contains the terms of the bounty for the agreement.
struct BountyTerms {
    // Percentage of the recovered funds a Whitehat receives as their bounty (0-100).
    uint256 bountyPercentage;
    // The maximum bounty in USD.
    uint256 bountyCapUSD;
    // Whether the whitehat can retain their bounty or must return all funds to
    // the asset recovery address.
    bool retainable;
    // The identity verification requirements on the whitehat.
    IdentityRequirements identity;
    // The diligence requirements placed on eligible whitehats. Only applicable for Named whitehats.
    string diligenceRequirements;
}
