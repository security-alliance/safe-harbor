// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IChainValidator } from "src/interface/IChainValidator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { _hashString } from "src/utils/Utils.sol";

/// @title Chain Validator for Safe Harbor Registry
/// @notice Manages the list of valid chains for Safe Harbor agreements
// aderyn-ignore-next-line(centralization-risk)
contract ChainValidator is IChainValidator, Ownable {
    // ----- STATE VARIABLES -----
    mapping(string caip2 => bool valid) private validChains;
    string[] private validChainsList;

    // ----- EVENTS -----
    event ChainValiditySet(string caip2ChainId, bool valid);

    // ----- CONSTRUCTOR -----
    constructor(address _initialOwner) Ownable(_initialOwner) { }

    // ----- USER-FACING STATE-CHANGING FUNCTIONS -----

    /// @notice Function that sets a list of chains as valid.
    /// @param _caip2ChainIds The CAIP-2 IDs of the chains to mark as valid.
    // aderyn-ignore-next-line(centralization-risk)
    function setValidChains(string[] calldata _caip2ChainIds) external onlyOwner {
        uint256 length = _caip2ChainIds.length;
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < length; i++) {
            if (!validChains[_caip2ChainIds[i]]) {
                validChains[_caip2ChainIds[i]] = true;
                validChainsList.push(_caip2ChainIds[i]);
            }
            emit ChainValiditySet(_caip2ChainIds[i], true);
        }
    }

    /// @notice Function that marks a list of chains as invalid.
    /// @param _caip2ChainIds The CAIP-2 IDs of the chains to mark as invalid.
    // aderyn-ignore-next-line(centralization-risk)
    function setInvalidChains(string[] calldata _caip2ChainIds) external onlyOwner {
        uint256 length = _caip2ChainIds.length;
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < length; i++) {
            if (validChains[_caip2ChainIds[i]]) {
                validChains[_caip2ChainIds[i]] = false;
                _removeFromValidChainsList(_caip2ChainIds[i]);
            }
            emit ChainValiditySet(_caip2ChainIds[i], false);
        }
    }

    // ----- INTERNAL STATE-CHANGING FUNCTIONS -----

    /// @notice Internal function to remove a chain ID from the valid chains list.
    /// @param _caip2ChainId The CAIP-2 chain ID to remove.
    function _removeFromValidChainsList(string calldata _caip2ChainId) internal {
        bytes32 targetHash = _hashString(_caip2ChainId);
        uint256 length = validChainsList.length;
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < length; i++) {
            if (_hashString(validChainsList[i]) == targetHash) {
                // Replace with last element and pop
                validChainsList[i] = validChainsList[length - 1];
                validChainsList.pop();
                break;
            }
        }
    }

    // ----- USER-FACING READ-ONLY FUNCTIONS -----

    /// @notice Function that returns if a chain is valid.
    /// @param _caip2ChainId The CAIP-2 ID of the chain to check.
    /// @return bool True if the chain is valid, false otherwise.
    function isChainValid(string calldata _caip2ChainId) external view returns (bool) {
        return validChains[_caip2ChainId];
    }

    /// @notice Function that returns all currently valid chain IDs.
    /// @return string[] Array of all valid CAIP-2 chain IDs.
    function getValidChains() external view returns (string[] memory) {
        return validChainsList;
    }
}
