// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    /// @notice Get the agreement address for the adopter. Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    /// @return address The agreement address.
    function getAgreement(address adopter) external view returns (address);
}
