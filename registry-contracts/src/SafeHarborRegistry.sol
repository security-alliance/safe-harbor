// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IRegistry } from "src/interface/IRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { _hashString } from "src/utils/Utils.sol";

string constant VERSION = "3.0.0";

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
// aderyn-ignore-next-line(centralization-risk)
contract SafeHarborRegistry is IRegistry, Ownable {
    // ----- ERRORS -----
    error SafeHarborRegistry__NoAgreement();

    // ----- STATE VARIABLES -----
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) private agreements;
    mapping(string caip2 => bool valid) private validChains;
    string[] private validChainsList;

    // ----- EVENTS -----
    event SafeHarborAdoption(address indexed adopter, address agreementAddress);
    event ChainValiditySet(string caip2ChainId, bool valid);

    // ----- CONSTRUCTOR & INITIALIZER -----
    /// @notice Sets the factory and fallback registry addresses
    constructor(address _initialOwner) Ownable(_initialOwner) { }

    // aderyn-ignore-next-line(centralization-risk)
    function initialize() external onlyOwner { }

    // ----- USER-FACING STATE-CHANGING FUNCTIONS -----

    /// @notice Function that sets a list of chains as valid in the registry.
    /// @param _caip2ChainIds The CAIP-2 IDs of the chains to mark as valid.
    function setValidChains(string[] calldata _caip2ChainIds) external onlyOwner {
        for (uint256 i = 0; i < _caip2ChainIds.length; i++) {
            if (!validChains[_caip2ChainIds[i]]) {
                validChains[_caip2ChainIds[i]] = true;
                validChainsList.push(_caip2ChainIds[i]);
            }
            emit ChainValiditySet(_caip2ChainIds[i], true);
        }
    }

    /// @notice Function that marks a list of chains as invalid in the registry.
    /// @param _caip2ChainIds The CAIP-2 IDs of the chains to mark as invalid.
    function setInvalidChains(string[] calldata _caip2ChainIds) external onlyOwner {
        for (uint256 i = 0; i < _caip2ChainIds.length; i++) {
            if (validChains[_caip2ChainIds[i]]) {
                validChains[_caip2ChainIds[i]] = false;
                _removeFromValidChainsList(_caip2ChainIds[i]);
            }
            emit ChainValiditySet(_caip2ChainIds[i], false);
        }
    }

    /// @notice Function that records an adoption by msg.sender.
    /// @param _agreementAddress The address of the agreement to adopt.
    function adoptSafeHarbor(address _agreementAddress) external {
        address adopter = msg.sender;
        emit SafeHarborAdoption(adopter, _agreementAddress);
        agreements[adopter] = _agreementAddress;
    }

    // ----- INTERNAL STATE-CHANGING FUNCTIONS -----
    /// @notice Internal function to remove a chain ID from the valid chains list.
    /// @param _caip2ChainId The CAIP-2 chain ID to remove.
    function _removeFromValidChainsList(string calldata _caip2ChainId) internal {
        bytes32 targetHash = _hashString(_caip2ChainId);
        for (uint256 i = 0; i < validChainsList.length; i++) {
            if (_hashString(validChainsList[i]) == targetHash) {
                // Replace with last element and pop
                validChainsList[i] = validChainsList[validChainsList.length - 1];
                validChainsList.pop();
                break;
            }
        }
    }

    // ----- USER-FACING READ-ONLY FUNCTIONS -----
    function version() external pure returns (string memory) {
        return VERSION;
    }

    /// @notice Get the agreement address for the adopter. Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    /// @return address The agreement address.
    function getAgreement(address adopter) external view returns (address) {
        address agreement = agreements[adopter];

        if (agreement != address(0)) {
            return agreement;
        }

        revert SafeHarborRegistry__NoAgreement();
    }

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

    // ----- INTERNAL READ-ONLY FUNCTIONS -----
}
