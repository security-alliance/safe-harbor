// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SignatureValidator.sol";
import "./AgreementV1.sol";
import "./EIP712.sol";

/// @notice Validator contract that validates safe harbor agreements.
contract AgreementValidatorV1 is SignatureValidator, EIP712("Safe Harbor", _version) {
    /// ----- eip-712 TYPEHASHES
    /// GENERATED WITH `forge eip712 registry-contracts/src/AgreementV1.sol`
    bytes private constant agreementDetailsTypeHashStr =
        "AgreementDetailsV1(string protocolName,Contact[] contactDetails,Chain[] chains,BountyTerms bountyTerms,string agreementURI)Account(address accountAddress,uint8 childContractScope,bytes signature)BountyTerms(uint256 bountyPercentage,uint256 bountyCapUSD,bool retainable,uint8 identity,string diligenceRequirements)Chain(address assetRecoveryAddress,Account[] accounts,uint256 id)Contact(string name,string contact)";
    bytes private constant contactTypeHashStr = "Contact(string name,string contact)";
    bytes private constant chainTypeHashStr =
        "Chain(address assetRecoveryAddress,Account[] accounts,uint256 id)Account(address accountAddress,uint8 childContractScope,bytes signature)";
    bytes private constant accountTypeHashStr =
        "Account(address accountAddress,uint8 childContractScope,bytes signature)";
    bytes private constant bountyTermsTypeHashStr =
        "BountyTerms(uint256 bountyPercentage,uint256 bountyCapUSD,bool retainable,uint8 identity,string diligenceRequirements)";

    bytes32 private constant AGREEMENTDETAILS_TYPEHASH = keccak256(agreementDetailsTypeHashStr);
    bytes32 private constant CONTACT_TYPEHASH = keccak256(contactTypeHashStr);
    bytes32 private constant CHAIN_TYPEHASH = keccak256(chainTypeHashStr);
    bytes32 private constant ACCOUNT_TYPEHASH = keccak256(accountTypeHashStr);
    bytes32 private constant BOUNTYTERMS_TYPEHASH = keccak256(bountyTermsTypeHashStr);

    /// @notice Function that validates an account's signature for the agreement.
    /// @param details The details of the agreement.
    /// @param account The account to validate.
    function validateAccount(AgreementDetailsV1 memory details, Account memory account) public view returns (bool) {
        // Hash the details with eip-712.
        bytes32 digest = getTypedDataHash(details);
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
    function getTypedDataHash(AgreementDetailsV1 memory details) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), hash(details)));
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
        bytes32 empty = keccak256(new bytes(0));
        return keccak256(abi.encode(ACCOUNT_TYPEHASH, account.accountAddress, account.childContractScope, empty));
    }

    // function hash(ChildContractScope childContractScope) internal pure returns (bytes32) {
    //     if (childContractScope == ChildContractScope.None) {
    //         return hash("None");
    //     } else if (childContractScope == ChildContractScope.ExistingOnly) {
    //         return hash("ExistingOnly");
    //     } else if (childContractScope == ChildContractScope.All) {
    //         return hash("All");
    //     } else {
    //         revert("Invalid child contract scope");
    //     }
    // }

    function hash(BountyTerms memory bountyTerms) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                BOUNTYTERMS_TYPEHASH,
                bountyTerms.bountyPercentage,
                bountyTerms.bountyCapUSD,
                bountyTerms.retainable,
                bountyTerms.identity,
                hash(bountyTerms.diligenceRequirements)
            )
        );
    }

    // function hash(IdentityRequirements identity) internal pure returns (bytes32) {
    //     if (identity == IdentityRequirements.Anonymous) {
    //         return hash("Anonymous");
    //     } else if (identity == IdentityRequirements.Pseudonymous) {
    //         return hash("Pseudonymous");
    //     } else if (identity == IdentityRequirements.Named) {
    //         return hash("Named");
    //     } else {
    //         revert("Invalid identity");
    //     }
    // }

    function hash(string memory str) internal pure returns (bytes32) {
        return keccak256(bytes(str));
    }
}
