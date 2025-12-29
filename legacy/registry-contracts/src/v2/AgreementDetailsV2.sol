// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Struct that contains the details of the agreement.
struct AgreementDetailsV2 {
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
    string assetRecoveryAddress;
    // The accounts in scope for the agreement.
    Account[] accounts;
    // The CAIP-2 chain ID. Please refer to the CAIP-2 standard for more details.
    // https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md
    string caip2ChainId;
}

/// @notice Struct that contains the details of an account in an agreement.
struct Account {
    // The address of the account (EOA or smart contract).
    string accountAddress;
    // The scope of child contracts included in the agreement.
    ChildContractScope childContractScope;
}

/// @notice Enum that defines the inclusion of child contracts in an agreement.
enum ChildContractScope {
    // No child contracts are included.
    None,
    // Only child contracts that were created before the time of this agreement are included.
    ExistingOnly,
    // All child contracts, both existing and new, are included.
    All,
    // Only child contracts that were created after the time of this agreement are included.
    FutureOnly
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
    // Optional. Caps the total USD value of bounties paid across all whitehats for a single exploit.
    // If set to 0, no aggregate cap applies and each whitehat may receive up to bountyCapUSD individually.
    uint256 aggregateBountyCapUSD;
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
