// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IRegistry } from "src/interface/IRegistry.sol";

string constant VERSION = "3.0.0";

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
contract SafeHarborRegistry is IRegistry {
    // ----- ERRORS -----
    error SafeHarborRegistry__NoAgreement();

    // ----- STATE VARIABLES -----
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) private agreements;

    // ----- EVENTS -----
    event SafeHarborAdoption(address indexed adopter, address agreementAddress);
    event LegacyDataMigrated(address indexed legacyRegistry, uint256 migratedCount);

    // ----- CONSTRUCTOR -----
    /// @notice Deploys the registry with optional migration from a legacy registry.
    /// @dev For fresh deployments, pass address(0) for _legacyRegistry and empty array for _adopters.
    ///      For migrations, pass the legacy registry address and array of known adopters.
    /// @param _legacyRegistry The address of the legacy SafeHarborRegistryV2 contract (or address(0) for fresh deploy).
    /// @param _adopters Array of addresses that have adopted Safe Harbor in the legacy registry.
    constructor(address _legacyRegistry, address[] memory _adopters) {
        // Migrate data from legacy registry if provided
        if (_legacyRegistry == address(0) || _adopters.length <= 0) {
            return;
        }
        IRegistry legacyRegistry = IRegistry(_legacyRegistry);
        uint256 length = _adopters.length;
        uint256 migratedCount = 0;

        for (uint256 i = 0; i < length; i++) {
            address adopter = _adopters[i];
            // Query the legacy registry for this adopter's agreement
            try legacyRegistry.getAgreement(adopter) returns (address agreementAddress) {
                if (agreementAddress == address(0)) {
                    continue;
                }
                agreements[adopter] = agreementAddress;
                emit SafeHarborAdoption(adopter, agreementAddress);
                migratedCount++;
            } catch {
                // Skip adopters that don't have agreements or cause errors
                continue;
            }
        }

        emit LegacyDataMigrated(_legacyRegistry, migratedCount);
    }

    // ----- USER-FACING STATE-CHANGING FUNCTIONS -----

    /// @notice Function that records an adoption by msg.sender.
    /// @param _agreementAddress The address of the agreement to adopt.
    function adoptSafeHarbor(address _agreementAddress) external {
        address adopter = msg.sender;
        emit SafeHarborAdoption(adopter, _agreementAddress);
        agreements[adopter] = _agreementAddress;
    }

    // ----- USER-FACING READ-ONLY FUNCTIONS -----

    /// @notice Returns the version of the registry.
    /// @return string The version string.
    function version() external pure returns (string memory) {
        return VERSION;
    }

    /// @notice Get the agreement address for the adopter.
    /// @param _adopter The adopter to query.
    /// @return address The agreement address.
    function getAgreement(address _adopter) external view returns (address) {
        address agreement = agreements[_adopter];

        if (agreement != address(0)) {
            return agreement;
        }

        revert SafeHarborRegistry__NoAgreement();
    }
}
