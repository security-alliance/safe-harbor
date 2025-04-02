// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    /// @notice Get the agreement address for the adopter. Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    /// @return address The agreement address.
    function getAgreement(address adopter) external view returns (address);
    function version() external pure returns (string memory);
    function chains(uint256 id) external pure returns (string memory);
    function chainIDs(string memory chainName) external pure returns (uint256);
}
