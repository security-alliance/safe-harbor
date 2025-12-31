// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Hashes a string using inline assembly for gas efficiency
function _hashString(string memory str) pure returns (bytes32 result) {
    assembly {
        result := keccak256(add(str, 0x20), mload(str))
    }
}
