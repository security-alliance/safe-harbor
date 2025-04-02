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
    mapping(uint256 => string) public chains;
    mapping(string => uint256) public chainIDs;

    /// @notice The total number of registered chains.
    uint256 public chainCount;

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
        chainCount = 0;
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    /// @notice Function that adds a list of chain names to the registry.
    function addChains(string[] memory chainNames) external onlyOwner {
        for (uint256 i = 0; i < chainNames.length; i++) {
            string memory chainName = chainNames[i];
            if (chainIDs[chainName] != 0) {
                revert ChainAlreadyExists(chainName);
            }

            chains[chainCount] = chainName;
            chainIDs[chainName] = chainCount + 1;
            emit ChainAdded(chainName);
            chainCount++;
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
}
