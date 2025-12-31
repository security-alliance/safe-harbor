// SPDX-License-Identifier: MIT
// aderyn-ignore-next-line(unspecific-solidity-pragma,push-zero-opcode)
pragma solidity ^0.8.20;

interface IRegistry {
    /// @notice Get the agreement address for the adopter. Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    /// @return address The agreement address.
    function getAgreement(address adopter) external view returns (address);

    /// @notice Check if a chain ID is valid in the registry.
    /// @param caip2ChainId The CAIP-2 ID of the chain to check.
    /// @return bool True if the chain is valid, false otherwise.
    function isChainValid(string calldata caip2ChainId) external view returns (bool);
}
