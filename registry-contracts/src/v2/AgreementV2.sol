// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../v1/AgreementV1.sol";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
contract AgreementV2 {
    /// @notice The details of the agreement.
    AgreementDetailsV1 private details;

    address public owner;

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    constructor(AgreementDetailsV1 memory _details, address _owner) {
        details = _details;
        owner = _owner;
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    /// @notice Function that returns the details of the agreement.
    /// @dev You need a view function, else it won't convert storage to memory automatically for the nested structs.
    /// @return AgreementDetailsV1 The details of the agreement.
    function getDetails() external view returns (AgreementDetailsV1 memory) {
        return details;
    }
}
