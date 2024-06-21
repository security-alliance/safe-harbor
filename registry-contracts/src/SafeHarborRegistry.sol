// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry {
    address public agreementDeployer;
    address public admin;

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(
        address indexed entity,
        address oldDetails,
        address newDetails
    );

    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) public agreements;
    /// @notice A mapping which records the approved agreement deployers.
    mapping(address entity => address deployer) public agreementDeployers;

    /// @notice Sets the admin address to the contract deployer.
    constructor() {
        admin = msg.sender;
    }

    /// @notice Modifier to restrict access to admin-only functions.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    /// @notice Officially adopt the agreement, or modify its terms if already adopted.
    /// @param entity The address of the entity adopting the agreement.
    /// @param details The new details of the agreement.
    function recordAdoption(address entity, address details) external {
        require(
            agreementDeployers[entity] == msg.sender,
            "Only approved deployers may adopt the Safe Harbor"
        );

        address oldDetails = agreements[entity];
        agreements[entity] = details;
        emit SafeHarborAdoption(entity, oldDetails, details);
    }

    /// @notice Sets an address as an approved deployer.
    /// @param deployer The address to approve.
    function approveDeployer(
        address entity,
        address deployer
    ) external onlyAdmin {
        agreementDeployers[entity] = deployer;
    }

    /// @notice Allows the admin to transfer admin rights to another address.
    /// @param newAdmin The address of the new admin.
    function transferAdminRights(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin address cannot be zero");
        admin = newAdmin;
    }
}
