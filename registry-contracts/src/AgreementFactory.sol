// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Agreement } from "src/Agreement.sol";
import { AgreementDetails } from "src/types/AgreementTypes.sol";

/// @title Factory for creating Agreement contracts
contract AgreementFactory {
    // ----- EXTERNAL FUNCTIONS -----

    /// @notice Creates an Agreement contract.
    /// @param details The agreement details
    /// @param registry The Safe Harbor Registry address
    /// @param owner The owner of the agreement
    function create(
        AgreementDetails memory details,
        address registry,
        address owner
    )
        external
        returns (address agreementAddress)
    {
        Agreement agreement = new Agreement(details, registry, owner);
        agreementAddress = address(agreement);
        return agreementAddress;
    }
}
