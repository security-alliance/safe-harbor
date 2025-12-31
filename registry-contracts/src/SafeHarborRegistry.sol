// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRegistry} from "src/interface/IRegistry.sol";
import {IChainValidator} from "src/interface/IChainValidator.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

string constant VERSION = "3.0.0";

/// @title The Safe Harbor Registry. See www.securityalliance.org for details.
// aderyn-ignore-next-line(centralization-risk)
contract SafeHarborRegistry is IRegistry, Ownable {
    // ----- ERRORS -----
    error SafeHarborRegistry__NoAgreement();
    error SafeHarborRegistry__ZeroAddress();

    // ----- STATE VARIABLES -----
    /// @notice A mapping which records the agreement details for a given governance/admin address.
    mapping(address entity => address details) private agreements;

    /// @notice The chain validator contract used to validate chain IDs.
    IChainValidator private chainValidator;

    // ----- EVENTS -----
    event SafeHarborAdoption(address indexed adopter, address agreementAddress);
    event ChainValidatorSet(address indexed newValidator);
    event LegacyDataMigrated(address indexed legacyRegistry, uint256 migratedCount);

    // ----- CONSTRUCTOR -----
    /// @notice Deploys the registry with optional migration from a legacy registry.
    /// @dev For fresh deployments, pass address(0) for _legacyRegistry and empty array for _adopters.
    ///      For migrations, pass the legacy registry address and array of known adopters.
    /// @param _initialOwner The owner of the registry.
    /// @param _chainValidator The address of the chain validator contract.
    /// @param _legacyRegistry The address of the legacy SafeHarborRegistryV2 contract (or address(0) for fresh deploy).
    /// @param _adopters Array of addresses that have adopted Safe Harbor in the legacy registry.
    constructor(
        address _initialOwner,
        address _chainValidator,
        address _legacyRegistry,
        address[] memory _adopters
    ) Ownable(_initialOwner) {
        if (_chainValidator == address(0)) {
            revert SafeHarborRegistry__ZeroAddress();
        }
        chainValidator = IChainValidator(_chainValidator);

        // Migrate data from legacy registry if provided
        if (_legacyRegistry != address(0) && _adopters.length > 0) {
            IRegistry legacyRegistry = IRegistry(_legacyRegistry);
            uint256 length = _adopters.length;
            uint256 migratedCount = 0;

            for (uint256 i = 0; i < length; i++) {
                address adopter = _adopters[i];
                // Query the legacy registry for this adopter's agreement
                try legacyRegistry.getAgreement(adopter) returns (address agreementAddress) {
                    if (agreementAddress != address(0)) {
                        agreements[adopter] = agreementAddress;
                        emit SafeHarborAdoption(adopter, agreementAddress);
                        migratedCount++;
                    }
                } catch {
                    // Skip adopters that don't have agreements or cause errors
                    continue;
                }
            }

            emit LegacyDataMigrated(_legacyRegistry, migratedCount);
        }
    }

    // ----- USER-FACING STATE-CHANGING FUNCTIONS -----

    /// @notice Function to update the chain validator contract.
    /// @param _newChainValidator The address of the new chain validator contract.
    // aderyn-ignore-next-line(centralization-risk)
    function setChainValidator(address _newChainValidator) external onlyOwner {
        if (_newChainValidator == address(0)) {
            revert SafeHarborRegistry__ZeroAddress();
        }
        emit ChainValidatorSet(_newChainValidator);
        chainValidator = IChainValidator(_newChainValidator);
    }

    /// @notice Function that records an adoption by msg.sender.
    /// @param _agreementAddress The address of the agreement to adopt.
    function adoptSafeHarbor(address _agreementAddress) external {
        address adopter = msg.sender;
        emit SafeHarborAdoption(adopter, _agreementAddress);
        agreements[adopter] = _agreementAddress;
    }

    // ----- USER-FACING READ-ONLY FUNCTIONS -----

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

    /// @notice Function that returns if a chain is valid.
    /// @param _caip2ChainId The CAIP-2 ID of the chain to check.
    /// @return bool True if the chain is valid, false otherwise.
    function isChainValid(string calldata _caip2ChainId) external view returns (bool) {
        return chainValidator.isChainValid(_caip2ChainId);
    }

    /// @notice Function that returns all currently valid chain IDs.
    /// @return string[] Array of all valid CAIP-2 chain IDs.
    function getValidChains() external view returns (string[] memory) {
        return chainValidator.getValidChains();
    }

    /// @notice Returns the current chain validator contract address.
    /// @return address The chain validator contract address.
    function getChainValidator() external view returns (address) {
        return address(chainValidator);
    }
}
