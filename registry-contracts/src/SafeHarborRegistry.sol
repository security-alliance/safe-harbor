// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry {
    address public agreementDeployer;

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(
        address indexed entity,
        address oldDetails,
        address newDetails
    );

    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) public agreements;
    /// @notice A mapping which records the approved agreement deployers.
    mapping(address deployer => bool approved) public agreementDeployers;

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
    function recordAdoption(AgreementDetailsV1 memory details) external {
        require(
            agreementDeployers[msg.sender],
            "Only approved deployers may adopt the Safe Harbor"
        );

        address memory oldDetails = agreements[entity];
        agreements[entity] = details;
        emit SafeHarborAdoption(entity, oldDetails, details);
    }

    function getAgreementDetails(address entity) (detailsAddress address, version string) {
        // if you have the entity's details in your agreements mapping, return the details address.
        // otherwise, 
    }

    /// @notice Sets an address as an approved deployer.
    /// @param deployer The address to approve.
    function approveDeployer(address deployer) external onlyAdmin {
        agreementDeployers[deployer] = true;
    }

    /// @notice Allows the admin to transfer admin rights to another address.
    /// @param newAdmin The address of the new admin.
    function transferAdminRights(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin address cannot be zero");
        admin = newAdmin;
    }
}
