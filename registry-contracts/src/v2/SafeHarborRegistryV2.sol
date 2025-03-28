// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../common/Registry.sol";
import "../v1/AgreementValidatorV1.sol";
import "./AgreementV2.sol" as V2;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistryV2 is AgreementValidatorV1 {
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) private agreements;

    /// @notice The fallback registry.
    IRegistry fallbackRegistry;

    /// ----- EVENTS -----

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails);

    /// ----- ERRORS -----
    error NoAgreement();

    /// ----- METHODS -----
    /// @notice Sets the factory and fallback registry addresses
    constructor(address _fallbackRegistry) {
        fallbackRegistry = IRegistry(_fallbackRegistry);
    }

    function version() external pure returns (string memory) {
        return "1.1.0";
    }

    /// @notice Function that creates a new AgreementV2 contract and records it as an adoption by msg.sender.
    /// @param agreementAddress The address of the agreement to adopt.
    function adoptSafeHarbor(address agreementAddress) external {
        address adopter = msg.sender;

        address oldDetails = agreements[adopter];
        agreements[adopter] = agreementAddress;
        emit SafeHarborAdoption(adopter, oldDetails, agreementAddress);
    }

    /// @notice Get the agreement address for the adopter. Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    /// @return address The agreement address.
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
