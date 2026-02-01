// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { Agreement } from "src/Agreement.sol";
import {
    AgreementDetails,
    Chain as AgreementChain,
    Account as AgreementAccount,
    Contact,
    BountyTerms,
    ChildContractScope,
    IdentityRequirements
} from "src/types/AgreementTypes.sol";

/// @title GetAgreementDetails
/// @notice Script for retrieving and displaying Safe Harbor agreement details
/// @dev Fetches agreement details from an Agreement contract and logs them in a readable format.
///      Can be used via environment variable or direct address parameter.
contract GetAgreementDetails is Script {
    // ----- ENTRY POINTS -----

    /// @notice Execute with explicit agreement address
    /// @param agreementAddress The address of the Agreement contract to query
    function run(address agreementAddress) external view {
        _execute(agreementAddress);
    }

    // ----- INTERNAL FUNCTIONS -----

    /// @notice Internal execution logic shared by all entry points
    /// @param agreementAddress The address of the Agreement contract to query
    function _execute(address agreementAddress) internal view {
        _validateAddress(agreementAddress);
        AgreementDetails memory details = _fetchDetails(agreementAddress);
        _logAgreementDetails(details);
    }

    /// @notice Fetches agreement details from the contract
    /// @param agreementAddress The address of the Agreement contract
    /// @return details The complete agreement details
    function _fetchDetails(address agreementAddress) internal view returns (AgreementDetails memory details) {
        Agreement agreement = Agreement(agreementAddress);
        details = agreement.getDetails();
    }

    /// @notice Validates that the provided address is non-zero
    /// @param agreementAddress The address to validate
    function _validateAddress(address agreementAddress) internal pure {
        if (agreementAddress == address(0)) {
            revert("GetAgreementDetails: Agreement address cannot be zero");
        }
    }

    /// @notice Logs all agreement details in a formatted, readable manner
    /// @param details The agreement details to log
    function _logAgreementDetails(AgreementDetails memory details) internal pure {
        _logHeader("SAFE HARBOR AGREEMENT DETAILS");

        _logSection("PROTOCOL INFORMATION");
        console.log("  Protocol Name:", details.protocolName);
        console.log("  Agreement URI:", details.agreementURI);

        _logContactDetails(details.contactDetails);
        _logChainDetails(details.chains);
        _logBountyTerms(details.bountyTerms);

        _logFooter();
    }

    /// @notice Logs contact details section
    /// @param contacts Array of contact information
    function _logContactDetails(Contact[] memory contacts) internal pure {
        _logSection("CONTACT DETAILS");
        console.log("  Total Contacts:", contacts.length);

        for (uint256 i; i < contacts.length; ++i) {
            console.log(string.concat("  [", _uintToString(i), "]"));
            console.log("    Name:   ", contacts[i].name);
            console.log("    Contact:", contacts[i].contact);
        }
    }

    /// @notice Logs chain details section
    /// @param chains Array of chain information
    function _logChainDetails(AgreementChain[] memory chains) internal pure {
        _logSection("CHAIN SCOPE");
        console.log("  Total Chains:", chains.length);

        for (uint256 i; i < chains.length; ++i) {
            AgreementChain memory chain = chains[i];
            console.log(string.concat("  [", _uintToString(i), "] ", chain.caip2ChainId));
            console.log("    Asset Recovery Address:", chain.assetRecoveryAddress);
            console.log("    Accounts in Scope:", chain.accounts.length);

            for (uint256 j; j < chain.accounts.length; ++j) {
                AgreementAccount memory account = chain.accounts[j];
                console.log(
                    string.concat(
                        "      [", _uintToString(j), "] ", account.accountAddress, " (", _childScopeToString(account.childContractScope), ")"
                    )
                );
            }
        }
    }

    /// @notice Logs bounty terms section
    /// @param terms The bounty terms to log
    function _logBountyTerms(BountyTerms memory terms) internal pure {
        _logSection("BOUNTY TERMS");
        console.log("  Bounty Percentage:        ", terms.bountyPercentage, "%");
        console.log("  Bounty Cap (USD):         $", _formatUint(terms.bountyCapUSD));
        console.log("  Aggregate Bounty Cap:     $", _formatUint(terms.aggregateBountyCapUSD));
        console.log("  Retainable:               ", terms.retainable ? "Yes" : "No");
        console.log("  Identity Requirements:    ", _identityToString(terms.identity));
        console.log("  Diligence Requirements:   ", terms.diligenceRequirements);
    }

    // ----- UTILITY FUNCTIONS -----

    /// @notice Converts ChildContractScope enum to string representation
    function _childScopeToString(ChildContractScope scope) internal pure returns (string memory) {
        if (scope == ChildContractScope.None) return "None";
        if (scope == ChildContractScope.ExistingOnly) return "ExistingOnly";
        if (scope == ChildContractScope.All) return "All";
        if (scope == ChildContractScope.FutureOnly) return "FutureOnly";
        return "Unknown";
    }

    /// @notice Converts IdentityRequirements enum to string representation
    function _identityToString(IdentityRequirements identity) internal pure returns (string memory) {
        if (identity == IdentityRequirements.Anonymous) return "Anonymous";
        if (identity == IdentityRequirements.Pseudonymous) return "Pseudonymous";
        if (identity == IdentityRequirements.Named) return "Named";
        return "Unknown";
    }

    /// @notice Converts uint256 to string
    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            ++digits;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            --digits;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    /// @notice Formats a uint256 value
    function _formatUint(uint256 value) internal pure returns (string memory) {
        return _uintToString(value);
    }

    // ----- LOGGING FORMATTING -----

    function _logHeader(string memory title) internal pure {
        console.log("");
        console.log("===================================================================");
        console.log("  ", title);
        console.log("===================================================================");
    }

    function _logSection(string memory title) internal pure {
        console.log("");
        console.log(string.concat("  ", title));
        console.log("  -----------------------------------------------------------------");
    }

    function _logFooter() internal pure {
        console.log("");
        console.log("===================================================================");
        console.log("");
    }
}
