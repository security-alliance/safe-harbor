// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry {
    /// @notice admin address used to enable or disable factories.
    address public admin;

    /// @notice pending admin address used to accept admin rights.
    address public _pendingAdmin;

    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) public agreements;

    /// @notice A mapping which records the approved agreement factories.
    mapping(address factory => bool) public agreementFactories;

    /// ----- EVENTS -----

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(
        address indexed entity,
        address oldDetails,
        address newDetails
    );

    /// @notice An event that records when an address is newly enabled as a factory.
    event FactoryEnabled(address factory);

    /// @notice An event that records when an address is newly disabled as a factory.
    event FactoryDisabled(address factory);

    /// ----- ERRORS -----
    error OnlyAdmin();
    error OnlyPendingAdmin();
    error OnlyFactories();

    /// ----- MODIFIERS -----
    /// @notice Modifier to restrict access to admin-only functions.
    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier onlyPendingAdmin() {
        if (msg.sender != _pendingAdmin) revert OnlyPendingAdmin();
        _;
    }

    modifier onlyFactory() {
        if (!agreementFactories[msg.sender]) revert OnlyFactories();
        _;
    }

    /// ----- METHODS -----

    /// @notice Sets the admin address to the provided address.
    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice Officially adopt the agreement, or modify its terms if already adopted. Only callable by approved factories.
    /// @param details The new details of the agreement.
    function recordAdoption(
        address entity,
        address details
    ) external onlyFactory {
        address oldDetails = agreements[entity];
        agreements[entity] = details;
        emit SafeHarborAdoption(entity, oldDetails, details);
    }

    /// @notice Enables an address as a factory.
    /// @param factory The address to enable.
    function enableFactory(address factory) external onlyAdmin {
        agreementFactories[factory] = true;
        emit FactoryEnabled(factory);
    }

    /// @notice Disables an address as an factory.
    /// @param factory The address to disable.
    function disableFactory(address factory) external onlyAdmin {
        agreementFactories[factory] = false;
        emit FactoryDisabled(factory);
    }

    /// @notice Allows the admin to transfer admin rights to another address.
    /// @param newAdmin The address of the new admin.
    function transferAdminRights(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin address cannot be zero");
        _pendingAdmin = newAdmin;
    }

    /// @notice Allows the pending admin to accept admin rights.
    function acceptAdminRights() external onlyPendingAdmin {
        admin = _pendingAdmin;
        _pendingAdmin = address(0);
    }
}
