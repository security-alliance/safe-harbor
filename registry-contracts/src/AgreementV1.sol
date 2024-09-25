// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SafeHarborRegistry.sol";
import "./SignatureValidator.sol";

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
    /// @return The details of the agreement.
    function getDetails() external view returns (AgreementDetailsV1 memory) {
        return details;
    }
}

/// @notice Factory contract that creates new AgreementV1 contracts and records their adoption in the SafeHarborRegistry.
contract AgreementV1Factory is SignatureValidator {
    SafeHarborRegistry public registry;

    /// @notice https://eips.ethereum.org/EIPS/eip-712
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    /// ----- eip-712 TYPEHASHES
    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant AGREEMENTDETAILS_TYPEHASH = keccak256(
        "AgreementDetailsV1(string protocolName,string contactDetails,Chain[] chains,BountyTerms bountyTerms,string agreementURI)"
    );

    bytes32 constant CONTACT_TYPEHASH = keccak256("Contact(string name,string contact)");

    bytes32 constant CHAIN_TYPEHASH = keccak256("Chain(address assetRecoveryAddress,Account[] accounts,uint id)");

    bytes32 constant ACCOUNT_TYPEHASH =
        keccak256("Account(address accountAddress,ChildContractScope childContractScope,bytes signature)");

    bytes32 constant BOUNTYTERMS_TYPEHASH =
        keccak256("BountyTerms(uint bountyPercentage,uint bountyCapUSD,IdentityVerification verification)");

    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    /// @notice Constructor that sets the SafeHarborRegistry address.
    /// @param registryAddress The address of the SafeHarborRegistry contract.
    constructor(address registryAddress) {
        registry = SafeHarborRegistry(registryAddress);
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    /// @notice Function that creates a new AgreementV1 contract and records its adoption in the SafeHarborRegistry.
    /// @param details The details of the agreement.
    function adoptSafeHarbor(AgreementDetailsV1 memory details) external {
        AgreementV1 agreementDetails = new AgreementV1(details);
        registry.recordAdoption(msg.sender, address(agreementDetails));
    }

    /// @notice Function that validates an account's signature for the agreement.
    /// @param details The details of the agreement.
    /// @param account The account to validate.
    function validateAccount(AgreementDetailsV1 memory details, Account memory account) public view returns (bool) {
        // Hash the details with eip-712.
        bytes32 digest = encode(DOMAIN_SEPERATOR(), details);

        return isSignatureValid(account.accountAddress, digest, account.signature);
    }

    /// @notice Function that validates an account's signature for the agreement using an agreement address.
    /// @param agreementAddress The address of the deployed AgreementV1 contract.
    /// @param account The account to validate.
    function validateAccountByAddress(address agreementAddress, Account memory account) external view returns (bool) {
        AgreementV1 agreement = AgreementV1(agreementAddress);
        AgreementDetailsV1 memory details = agreement.getDetails();

        return validateAccount(details, account);
    }

    /// ----- EIP-712 METHODS -----
    function DOMAIN_SEPERATOR() public view returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return hash(
            EIP712Domain({
                name: "Safe Harbor",
                version: _version,
                chainId: block.chainid,
                verifyingContract: address(this)
            })
        );
    }

    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                hash(eip712Domain.name),
                hash(eip712Domain.version),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function encode(bytes32 domainSeperator, AgreementDetailsV1 memory details) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeperator, hash(details)));
    }

    function hash(AgreementDetailsV1 memory details) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AGREEMENTDETAILS_TYPEHASH,
                hash(details.protocolName),
                hash(details.contactDetails),
                hash(details.chains),
                hash(details.bountyTerms),
                hash(details.agreementURI)
            )
        );
    }

    function hash(Contact[] memory contacts) internal pure returns (bytes32) {
        // Array values are encoded as the keccak256 of the concatenation of the encoded values.
        // https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata
        bytes memory encoded;
        for (uint256 i = 0; i < contacts.length; i++) {
            encoded = abi.encodePacked(encoded, hash(contacts[i]));
        }

        return keccak256(encoded);
    }

    function hash(Contact memory contact) internal pure returns (bytes32) {
        return keccak256(abi.encode(CONTACT_TYPEHASH, hash(contact.name), hash(contact.contact)));
    }

    function hash(Chain[] memory chains) internal pure returns (bytes32) {
        // Array values are encoded as the keccak256 of the concatenation of the encoded values.
        // https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata
        bytes memory encoded;
        for (uint256 i = 0; i < chains.length; i++) {
            encoded = abi.encodePacked(encoded, hash(chains[i]));
        }

        return keccak256(encoded);
    }

    function hash(Chain memory chain) internal pure returns (bytes32) {
        return keccak256(abi.encode(CHAIN_TYPEHASH, chain.assetRecoveryAddress, hash(chain.accounts), chain.id));
    }

    function hash(Account[] memory accounts) internal pure returns (bytes32) {
        // Array values are encoded as the keccak256 of the concatenation of the encoded values.
        // https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata
        bytes memory encoded;
        for (uint256 i = 0; i < accounts.length; i++) {
            encoded = abi.encodePacked(encoded, hash(accounts[i]));
        }

        return keccak256(encoded);
    }

    function hash(Account memory account) internal pure returns (bytes32) {
        // Account signatures are not included in the hash, avoiding circular dependancies.
        return keccak256(abi.encode(ACCOUNT_TYPEHASH, account.accountAddress, hash(account.childContractScope)));
    }

    function hash(ChildContractScope childContractScope) internal pure returns (bytes32) {
        if (childContractScope == ChildContractScope.None) {
            return hash("None");
        } else if (childContractScope == ChildContractScope.ExistingOnly) {
            return hash("ExistingOnly");
        } else if (childContractScope == ChildContractScope.All) {
            return hash("All");
        } else {
            revert("Invalid child contract scope");
        }
    }

    function hash(BountyTerms memory bountyTerms) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                BOUNTYTERMS_TYPEHASH,
                bountyTerms.bountyPercentage,
                bountyTerms.bountyCapUSD,
                bountyTerms.retainable,
                hash(bountyTerms.identity),
                hash(bountyTerms.diligenceRequirements)
            )
        );
    }

    function hash(IdentityRequirements identity) internal pure returns (bytes32) {
        if (identity == IdentityRequirements.Anonymous) {
            return hash("Anonymous");
        } else if (identity == IdentityRequirements.Pseudonymous) {
            return hash("Pseudonymous");
        } else if (identity == IdentityRequirements.Named) {
            return hash("Named");
        } else {
            revert("Invalid identity");
        }
    }

    function hash(string memory str) internal pure returns (bytes32) {
        return keccak256(bytes(str));
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
