// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry {

    /// @notice Agreement details struct.
    struct AgreementDetails {
        // The name of the protocol adopting the agreement.
        string protocolName;
        // The assets in scope of the agreement.
        string scope;
        // The contact details (required for pre-notifying).
        string contactDetails;
        // The bounty terms (e.g. percentage bounty, cap, if payable immediately).
        string bountyTerms;
        // Address where recovered funds should be sent.
        address assetRecoveryAddress;
        // IPFS hash of the actual agreement document, which confirms all terms.
        string agreementURI;
    }

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(address indexed entity, AgreementDetails oldDetails, AgreementDetails newDetails);

    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => AgreementDetails details) public agreements;

    /// @notice Officially adopt the agreement, or modify its terms if already adopted.
    /// @param details The new details of the agreement.
    function adoptSafeHarbor(AgreementDetails calldata details) external {
        AgreementDetails memory oldDetails = agreements[msg.sender];
        agreements[msg.sender] = details;
        emit SafeHarborAdoption(msg.sender, oldDetails, details);
    }
}
