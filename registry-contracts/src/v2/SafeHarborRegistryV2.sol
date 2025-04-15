// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgreementV2.sol" as V2;
import "../common/IRegistry.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

string constant _version = "1.1.0";

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistryV2 is Ownable {
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) private agreements;

    /// @notice A mapping of Safe Harbor ChainIDs to their respective chain names.  Counts up from 1.
    string[] public chains;

    /// @notice The fallback registry.
    IRegistry fallbackRegistry;

    /// ----- EVENTS -----

    /// @notice An event that records when an address either newly adopts the Safe Harbor, or alters its previous terms.
    event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails);

    /// @notice An event that records when a new chain is added to the registry.
    event ChainAdded(string chainName);

    /// ----- ERRORS -----
    error NoAgreement();
    error ChainAlreadyExists(string chainName);

    /// ----- METHODS -----
    /// @notice Sets the factory and fallback registry addresses
    constructor(address _fallbackRegistry, address _owner) Ownable(_owner) {
        fallbackRegistry = IRegistry(_fallbackRegistry);
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    /// @notice Function that adds a list of chain names to the registry.
    function addChains(string[] memory _chains) external onlyOwner {
        for (uint256 i = 0; i < _chains.length; i++) {
            for (uint256 j = 0; j < chains.length; j++) {
                if (keccak256(abi.encodePacked(_chains[i])) == keccak256(abi.encodePacked(chains[j]))) {
                    revert ChainAlreadyExists(_chains[i]);
                }
            }

            chains.push(_chains[i]);
            emit ChainAdded(_chains[i]);
        }
    }

    /// @notice Function that returns the list of chain names.
    function getChains() external view returns (string[] memory) {
        return chains;
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
}
