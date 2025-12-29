// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Agreement} from "src/Agreement.sol";
import {IRegistry} from "src/interface/IRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

string constant VERSION = "3.0.0";

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
// aderyn-ignore-next-line(centralization-risk)
contract SafeHarborRegistry is Ownable {
    // ----- STATE VARIABLES -----

    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) private agreements;

    /// @notice A mapping CAIP-2 IDs and if they are valid.
    mapping(string => bool) private validChains;

    /// @notice Array to keep track of all valid chain IDs
    string[] private validChainsList;

    /// @notice The fallback registry.
    IRegistry fallbackRegistry;

    // ----- EVENTS -----

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails);

    /// @notice An event that records when a chain is set as valid or invalid.
    event ChainValiditySet(string caip2ChainId, bool valid);

    // ----- ERRORS -----

    error NoAgreement();

    // ----- CONSTRUCTOR -----

    /// @notice Sets the factory and fallback registry addresses
    constructor(address _owner) Ownable(_owner) {}

    // ----- EXTERNAL FUNCTIONS -----
    function setFallbackRegistry(IRegistry _fallbackRegistry) external onlyOwner {
        fallbackRegistry = _fallbackRegistry;
    }

    function version() external pure returns (string memory) {
        return VERSION;
    }

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

    /// @notice Function that creates a new AgreementV2 contract and records it as an adoption by msg.sender.
    /// @param agreementAddress The address of the agreement to adopt.
    function adoptSafeHarbor(address agreementAddress) external {
        address adopter = msg.sender;

        address oldDetails = agreements[adopter];
        agreements[adopter] = agreementAddress;
        emit SafeHarborAdoption(adopter, oldDetails, agreementAddress);
    }

    /// @notice Get the agreement address for the adopter. Recursively queries fallback registries.
    /// @param adopter The adopter to query.
    /// @return address The agreement address.
    function getAgreement(address adopter) external view returns (address) {
        address agreement = agreements[adopter];

        if (agreement != address(0)) {
            return agreement;
        }

        if (address(fallbackRegistry) != address(0)) {
            return fallbackRegistry.getAgreement(adopter);
        }

        revert NoAgreement();
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

    // ----- INTERNAL FUNCTIONS -----

    /// @notice Internal function to remove a chain ID from the valid chains list.
    /// @param _caip2ChainId The CAIP-2 chain ID to remove.
    function _removeFromValidChainsList(string calldata _caip2ChainId) internal {
        for (uint256 i = 0; i < validChainsList.length; i++) {
            if (keccak256(bytes(validChainsList[i])) == keccak256(bytes(_caip2ChainId))) {
                // Replace with last element and pop
                validChainsList[i] = validChainsList[validChainsList.length - 1];
                validChainsList.pop();
                break;
            }
        }
    }
}
