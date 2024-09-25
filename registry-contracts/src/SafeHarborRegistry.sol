// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgreementV1.sol";

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry is AgreementValidatorV1 {
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) public agreements;

    /// @notice The fallback registry.
    SafeHarborRegistry fallbackRegistry;

    /// ----- EVENTS -----

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails);

    /// ----- ERRORS -----
    error NoAgreement();

    /// ----- METHODS -----
    /// @notice Sets the factory and fallback registry addresses
    constructor(address _fallbackRegistry) {
        fallbackRegistry = SafeHarborRegistry(_fallbackRegistry);
    }

    /// @notice Function that creates a new AgreementV1 contract and records it as an adoption by msg.sender.
    /// @param details The details of the agreement.
    function adoptSafeHarbor(AgreementDetailsV1 memory details) external {
        AgreementV1 agreementDetails = new AgreementV1(details);
        address agreementAddress = address(agreementDetails);
        address adopter = msg.sender;

        address oldDetails = agreements[adopter];
        agreements[adopter] = agreementAddress;
        emit SafeHarborAdoption(adopter, oldDetails, agreementAddress);
    }

    /// @notice Get the agreement address for the adopter.  Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    function getAgreement(address adopter) external view returns (address) {
        address agreement = agreements[adopter];

        if (agreement != address(0)) {
            return agreement;
        }

        if (address(fallbackRegistry) != address(0)) {
            return fallbackRegistry.getAgreement(adopter);
        }

        revert NoAgreement();
    }
}
