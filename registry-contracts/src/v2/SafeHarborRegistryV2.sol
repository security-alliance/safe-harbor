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

    /// @notice A mapping of chainIDs to their names.  Uses EVM chainIDs where possible, and adds custom IDs for non-EVM chains.
    mapping(uint256 => string) public chains;
    /// @notice A list of chain IDs that are enabled.
    uint256[] public chainIds;

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
    function setChains(uint256[] calldata _chainIds, string[] calldata _chainNames) external onlyOwner {
        require(_chainIds.length == _chainNames.length, "Input arrays must have same length");

        for (uint256 i = 0; i < _chainIds.length; i++) {
            uint256 chainId = _chainIds[i];
            if (bytes(chains[chainId]).length != 0) {
                revert ChainAlreadyExists(_chainNames[i]);
            }

            chains[chainId] = _chainNames[i];
            chainIds.push(chainId);
            emit ChainAdded(_chainNames[i]);
        }
    }

    /// @notice Returns all chain IDs and their names
    function getChains() external view returns (uint256[] memory ids, string[] memory names) {
        uint256 length = chainIds.length;
        names = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            names[i] = chains[chainIds[i]];
        }

        return (chainIds, names);
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
