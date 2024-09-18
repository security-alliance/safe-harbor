// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SafeHarborRegistry.sol";
import "./SignatureValidator.sol";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
contract AgreementV1 {
    /// @notice The details of the agreement.
    AgreementDetailsV1 private details;

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    constructor(AgreementDetailsV1 memory _details) {
        details = _details;
    }

    /// @notice Function that returns the version of the agreement.
    function version() external pure returns (string memory) {
        return "1.0.0";
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
    /// @notice https://eips.ethereum.org/EIPS/eip-712
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    /// @notice The SafeHarborRegistry contract.
    SafeHarborRegistry public registry;

    /// ----- eip-712 TYPEHASHES
    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant AGREEMENTDETAILS_TYPEHASH = keccak256(
        "AgreementDetailsV1(string protocolName,string contactDetails,Chain[] chains,BountyTerms bountyTerms,string agreementURI)"
    );

    bytes32 constant CHAIN_TYPEHASH = keccak256("Chain(address assetRecoveryAddress,Account[] accounts,uint id)");

    bytes32 constant ACCOUNT_TYPEHASH =
        keccak256("Account(address accountAddress,ChildContractScope childContractScope,bytes signature)");

    bytes32 constant BOUNTYTERMS_TYPEHASH =
        keccak256("BountyTerms(uint bountyPercentage,uint bountyCapUSD,IdentityVerification verification)");

    bytes32 DOMAIN_SEPARATOR;

    /// @notice Constructor that sets the SafeHarborRegistry address.
    /// @param registryAddress The address of the SafeHarborRegistry contract.
    constructor(address registryAddress) {
        registry = SafeHarborRegistry(registryAddress);
        DOMAIN_SEPARATOR =
            hash(EIP712Domain({name: "Ether Mail", version: "1.0.0", chainId: 1, verifyingContract: address(this)}));
    }

    /// @notice Function that returns the version of the agreement factory.
    function version() external pure returns (string memory) {
        return "1.0.0";
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
        bytes32 digest = hash(details);

        // Verify that the account's accountAddress signed the hashed details.
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
    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function hash(AgreementDetailsV1 memory details) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AGREEMENTDETAILS_TYPEHASH,
                keccak256(bytes(details.protocolName)),
                keccak256(bytes(details.contactDetails)),
                hash(details.chains),
                hash(details.bountyTerms),
                keccak256(bytes(details.agreementURI))
            )
        );
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
            return keccak256("None");
        } else if (childContractScope == ChildContractScope.ExistingOnly) {
            return keccak256("ExistingOnly");
        } else if (childContractScope == ChildContractScope.All) {
            return keccak256("All");
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
                hash(bountyTerms.verification)
            )
        );
    }

    function hash(IdentityVerification verification) internal pure returns (bytes32) {
        if (verification == IdentityVerification.Retainable) {
            return keccak256("Retainable");
        } else if (verification == IdentityVerification.Immunefi) {
            return keccak256("Immunefi");
        } else if (verification == IdentityVerification.Bugcrowd) {
            return keccak256("Bugcrowd");
        } else if (verification == IdentityVerification.Hackerone) {
            return keccak256("Hackerone");
        } else {
            revert("Invalid verification service");
        }
    }
}

/// @notice Struct that contains the details of the agreement.
struct AgreementDetailsV1 {
    // The name of the protocol adopting the agreement.
    string protocolName;
    // The contact details (required for pre-notifying).
    string contactDetails;
    // The scope and recovery address by chain.
    Chain[] chains;
    // The terms of the agreement.
    BountyTerms bountyTerms;
    // IPFS hash of the actual agreement document, which confirms all terms.
    string agreementURI;
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

/// @notice Whitehat identity verification methods. If Retainable, the Whitehat's
// identity is not verified. If set to a verification service, the Whitehat's
// identity is verified by that service. The provided services are those selected by SEAL.
enum IdentityVerification {
    Retainable,
    Immunefi,
    Bugcrowd,
    Hackerone
}

/// @notice Struct that contains the terms of the bounty for the agreement.
struct BountyTerms {
    // Percentage of the recovered funds a Whitehat receives as their bounty (0-100).
    uint256 bountyPercentage;
    // The maximum bounty in USD.
    uint256 bountyCapUSD;
    // The method by which the Whitehat's identity is verified. If Retainable,
    // the Whitehat's identity is not verified. If set to a verification service,
    // the Whitehat's identity is verified by that service.
    IdentityVerification verification;
}
