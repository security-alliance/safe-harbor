// SPDX-License-Identifier: MIT
// aderyn-ignore-next-line(unspecific-solidity-pragma,push-zero-opcode)
pragma solidity ^0.8.24;

interface IChainValidator {
    /// @notice Check if a chain ID is valid.
    /// @param caip2ChainId The CAIP-2 ID of the chain to check.
    /// @return bool True if the chain is valid, false otherwise.
    function isChainValid(string calldata caip2ChainId) external view returns (bool);

    /// @notice Get all valid chain IDs.
    /// @return string[] Array of all valid CAIP-2 chain IDs.
    function getValidChains() external view returns (string[] memory);
}
