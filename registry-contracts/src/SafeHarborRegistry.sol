// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry {
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) public agreements;

    /// @notice The factory address which is approved to submit agreements.
    address factory;

    /// @notice The fallback registry.
    SafeHarborRegistry fallbackRegistry;

    /// ----- EVENTS -----

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails);

    /// ----- ERRORS -----
    error OnlyFactories();
    error NoDetails();

    /// ----- MODIFIERS -----
    /// @notice Modifier to restrict access to admin-only functions.
    modifier onlyFactory() {
        if (msg.sender != factory) revert OnlyFactories();
        _;
    }

    /// ----- METHODS -----

    /// @notice Sets the factory and fallback registry addresses
    constructor(address _factory, SafeHarborRegistry _fallbackRegistry) {
        factory = _factory;
        fallbackRegistry = _fallbackRegistry;
    }

    /// @notice Officially adopt the agreement, or modify its terms if already adopted. Only callable by approved factories.
    /// @param details The new details of the agreement.
    function recordAdoption(address entity, address details) external onlyFactory {
        address oldDetails = agreements[entity];
        agreements[entity] = details;
        emit SafeHarborAdoption(entity, oldDetails, details);
    }

    /// @notice Get the details of an agreement.  Recursively queries fallback registries.
    /// @param entity The entity to query.
    function getDetails(address entity) external view returns (address) {
        address details = agreements[entity];

        if (details != address(0)) {
            return details;
        }

        if (fallbackRegistry != SafeHarborRegistry(address(0))) {
            return fallbackRegistry.getDetails(entity);
        }

        revert NoDetails();
    }
}
