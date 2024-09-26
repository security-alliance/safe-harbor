// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SignatureValidator.sol";
import "./AgreementV1.sol";

/// @notice Validator contract that validates safe harbor agreements.
contract AgreementValidatorV1 is SignatureValidator {
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

    /// @notice Constructor sets the domain separator.
    constructor() {
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    /// @notice Function that validates an account's signature for the agreement.
    /// @param details The details of the agreement.
    /// @param account The account to validate.
    function validateAccount(AgreementDetailsV1 memory details, Account memory account) public view returns (bool) {
        // Hash the details with eip-712.
        bytes32 digest = encode(DOMAIN_SEPARATOR(), details);

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
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
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
