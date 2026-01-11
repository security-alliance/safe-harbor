// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IChainValidator } from "src/interface/IChainValidator.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Chain Validator for Safe Harbor Registry
/// @notice Manages the list of valid chains for Safe Harbor agreements
// aderyn-ignore-next-line(centralization-risk,contract-locks-ether)
contract ChainValidator is IChainValidator, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // ----- CONSTANTS -----
    /// @notice Value indicating a chain is not valid (index + 1 = 0 means not present)
    uint256 private constant NOT_VALID = 0;

    // ----- STATE VARIABLES -----
    /// @notice Maps chain ID to its index + 1 in validChainsList (0 = not valid)
    mapping(string caip2 => uint256 indexPlusOne) private validChains;
    string[] private validChainsList;

    // ----- EVENTS -----
    event ChainValiditySet(string caip2ChainId, bool valid);

    // ----- CONSTRUCTOR -----
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ----- INITIALIZER -----
    /// @notice Initializes the contract with the owner and initial valid chains.
    /// @param _initialOwner The owner of the contract.
    /// @param _initialValidChains The initial list of valid CAIP-2 chain IDs.
    function initialize(address _initialOwner, string[] calldata _initialValidChains) external initializer {
        __Ownable_init(_initialOwner);
        uint256 length = _initialValidChains.length;
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i; i < length; i++) {
            if (validChains[_initialValidChains[i]] != NOT_VALID) {
                continue;
            }
            // Store index + 1 (current length + 1 before push)
            validChains[_initialValidChains[i]] = validChainsList.length + 1;
            validChainsList.push(_initialValidChains[i]);
            emit ChainValiditySet(_initialValidChains[i], true);
        }
    }

    // ----- UUPS -----
    /// @notice Authorizes an upgrade to a new implementation.
    /// @param newImplementation The address of the new implementation.
    // aderyn-ignore-next-line(centralization-risk,empty-block)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    // ----- USER-FACING STATE-CHANGING FUNCTIONS -----

    /// @notice Function that sets a list of chains as valid.
    /// @param _caip2ChainIds The CAIP-2 IDs of the chains to mark as valid.
    // aderyn-ignore-next-line(centralization-risk)
    function setValidChains(string[] calldata _caip2ChainIds) external onlyOwner {
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i; i < _caip2ChainIds.length; i++) {
            if (validChains[_caip2ChainIds[i]] == NOT_VALID) {
                // Store index + 1 (current length + 1 before push)
                validChains[_caip2ChainIds[i]] = validChainsList.length + 1;
                validChainsList.push(_caip2ChainIds[i]);
            }
            emit ChainValiditySet(_caip2ChainIds[i], true);
        }
    }

    /// @notice Function that marks a list of chains as invalid.
    /// @param _caip2ChainIds The CAIP-2 IDs of the chains to mark as invalid.
    // aderyn-ignore-next-line(centralization-risk)
    function setInvalidChains(string[] calldata _caip2ChainIds) external onlyOwner {
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i; i < _caip2ChainIds.length; i++) {
            uint256 indexPlusOne = validChains[_caip2ChainIds[i]];
            if (indexPlusOne != NOT_VALID) {
                _removeFromValidChainsList(indexPlusOne - 1);
                validChains[_caip2ChainIds[i]] = NOT_VALID;
            }
            emit ChainValiditySet(_caip2ChainIds[i], false);
        }
    }

    // ----- INTERNAL STATE-CHANGING FUNCTIONS -----

    /// @notice Internal function to remove a chain ID from the valid chains list using O(1) swap-and-pop.
    /// @param _index The index of the chain ID to remove.
    function _removeFromValidChainsList(uint256 _index) internal {
        uint256 lastIndex = validChainsList.length - 1;

        if (_index != lastIndex) {
            // Swap with last element
            string memory lastChainId = validChainsList[lastIndex];
            validChainsList[_index] = lastChainId;
            // Update the swapped element's index in the mapping
            validChains[lastChainId] = _index + 1;
        }

        validChainsList.pop();
    }

    // ----- USER-FACING READ-ONLY FUNCTIONS -----

    /// @notice Function that returns if a chain is valid.
    /// @param _caip2ChainId The CAIP-2 ID of the chain to check.
    /// @return bool True if the chain is valid, false otherwise.
    function isChainValid(string calldata _caip2ChainId) external view returns (bool) {
        return validChains[_caip2ChainId] != NOT_VALID;
    }

    /// @notice Function that returns all currently valid chain IDs.
    /// @return string[] Array of all valid CAIP-2 chain IDs.
    function getValidChains() external view returns (string[] memory) {
        return validChainsList;
    }
}
