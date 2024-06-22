// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry {
    /// @notice admin address used to enable or disable factories.
    address public admin;

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

    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) public agreements;

    /// @notice A mapping which records the approved agreement factories.
    mapping(address factory => bool) public agreementFactories;

    /// @notice Sets the admin address to the provided address.
    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice Officially adopt the agreement, or modify its terms if already adopted. Only callable by approved factories.
    /// @param details The new details of the agreement.
    function recordAdoption(address details) external {
        require(
            agreementFactories[msg.sender],
            "Only approved factories may adopt the Safe Harbor"
        );

        address entity = tx.origin;
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

    /// @notice Modifier to restrict access to admin-only functions.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    /// @notice Allows the admin to transfer admin rights to another address.
    /// @param newAdmin The address of the new admin.
    function transferAdminRights(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin address cannot be zero");
        admin = newAdmin;
    }
}
