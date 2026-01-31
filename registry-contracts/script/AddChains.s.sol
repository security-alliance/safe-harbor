// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Agreement } from "src/Agreement.sol";
import {
    AgreementDetails,
    Chain as AgreementChain,
    Account as AgreementAccount,
    Contact,
    BountyTerms,
    ChildContractScope,
    IdentityRequirements
} from "src/types/AgreementTypes.sol";

/// @title AddChains
/// @notice Script for adding chains to an existing Agreement contract
/// @dev This script reads chain details from a JSON file or accepts them directly,
///      validates the agreement and chains, then calls addChains on the Agreement contract
contract AddChains is Script {
    using stdJson for string;

    // ----- ERRORS -----
    error AddChains__InvalidAgreementAddress();
    error AddChains__NotAgreementOwner(address caller, address actualOwner);
    error AddChains__NoChainsProvided();
    error AddChains__InvalidJsonPath(string path);
    error AddChains__ChainValidationFailed(string caip2ChainId, string reason);

    // ----- EVENTS -----
    event ChainsAdded(address indexed agreement, uint256 chainCount);
    event ChainAdditionFailed(address indexed agreement, string caip2ChainId, string reason);

    // ----- STRUCTS -----
    struct ChainAdditionConfig {
        string jsonPath;
        address agreement;
    }

    // ----- CONSTANTS -----
    string private constant DEFAULT_JSON_PATH = "examples/addChains.json";

    // ======== MAIN ENTRY POINTS ========

    /// @notice Main entry point - uses environment variables for configuration
    /// @dev Uses vm.startBroadcast() for key management (pass --private-key via CLI)
    ///      Optional env vars: ADD_CHAINS_JSON_PATH (default: examples/addChains.json)
    ///                         AGREEMENT_ADDRESS
    function run() external {
        ChainAdditionConfig memory config = _loadConfigFromEnv();
        _executeChainAddition(config);
    }

    /// @notice Execute chain addition with explicit configuration
    /// @param config The chain addition configuration containing JSON path and agreement address
    function run(ChainAdditionConfig calldata config) external {
        _executeChainAddition(config);
    }

    /// @notice Execute chain addition with pre-parsed chains
    /// @param agreementAddress The address of the Agreement contract
    /// @param chains Array of chains to add
    function run(address agreementAddress, AgreementChain[] calldata chains) external {
        _executeChainAdditionWithChains(agreementAddress, chains);
    }

    /// @notice Preview the chains to be added without executing
    /// @param jsonPath Path to the JSON file containing chain details
    function preview(string calldata jsonPath) external view returns (AgreementChain[] memory chains) {
        string memory json = _readJsonFile(jsonPath);
        chains = _parseChains(json);
        _logPreview(chains);
    }

    // ======== INTERNAL EXECUTION FUNCTIONS ========

    /// @notice Execute the chain addition flow from JSON file
    /// @param config The chain addition configuration
    function _executeChainAddition(ChainAdditionConfig memory config) internal {
        // Read and parse JSON
        console.log("Reading chain details from:", config.jsonPath);
        string memory json = _readJsonFile(config.jsonPath);

        // Get agreement address from JSON if not provided in config
        address agreementAddress = config.agreement == address(0) 
            ? json.readAddress(".agreementAddress") 
            : config.agreement;

        AgreementChain[] memory chains = _parseChains(json);
        _executeChainAdditionWithChains(agreementAddress, chains);
    }

    /// @notice Execute chain addition with pre-parsed chains
    /// @param agreementAddress The address of the Agreement contract
    /// @param chains Array of chains to add
    function _executeChainAdditionWithChains(
        address agreementAddress,
        AgreementChain[] memory chains
    )
        internal
    {
        // Validate inputs
        _validateAgreement(agreementAddress);
        _validateChains(chains);

        Agreement agreement = Agreement(agreementAddress);

        // Validate ownership
        address owner = agreement.owner();
        address caller = msg.sender;

        if (caller != owner) {
            revert AddChains__NotAgreementOwner(caller, owner);
        }

        // Log chains to be added
        _logChains(chains);

        // Execute addition
        agreement.addChains(chains);

        emit ChainsAdded(agreementAddress, chains.length);

        console.log("==============================================");
        console.log("Chains added successfully!");
        console.log("Agreement:", agreementAddress);
        console.log("Chains added:", chains.length);
        console.log("==============================================");
    }

    // ======== PARSING FUNCTIONS ========

    /// @notice Parse chains array from JSON
    /// @param json The JSON string to parse
    /// @return chains Array of AgreementChain structs
    function _parseChains(string memory json) internal view returns (AgreementChain[] memory chains) {
        uint256 count = _getArrayLength(json, ".chains", ".caip2ChainId");

        chains = new AgreementChain[](count);
        for (uint256 i; i < count; ++i) {
            string memory indexStr = _uintToString(i);
            string memory basePath = string.concat(".chains[", indexStr, "]");

            chains[i] = AgreementChain({
                caip2ChainId: json.readString(string.concat(basePath, ".caip2ChainId")),
                assetRecoveryAddress: json.readString(string.concat(basePath, ".assetRecoveryAddress")),
                accounts: _parseAccounts(json, indexStr)
            });
        }
    }

    /// @notice Parse account details for a specific chain from JSON
    /// @param json The JSON string to parse
    /// @param chainIndex The index of the chain in the JSON array
    /// @return accounts Array of AgreementAccount structs
    function _parseAccounts(
        string memory json,
        string memory chainIndex
    )
        internal
        view
        returns (AgreementAccount[] memory accounts)
    {
        string memory basePath = string.concat(".chains[", chainIndex, "].accounts");
        uint256 count = _getArrayLength(json, basePath, ".accountAddress");

        accounts = new AgreementAccount[](count);
        for (uint256 i; i < count; ++i) {
            string memory indexStr = _uintToString(i);
            accounts[i] = AgreementAccount({
                accountAddress: json.readString(string.concat(basePath, "[", indexStr, "].accountAddress")),
                childContractScope: ChildContractScope(
                    uint8(json.readUint(string.concat(basePath, "[", indexStr, "].childContractScope")))
                )
            });
        }
    }

    // ======== CONFIGURATION LOADING ========

    /// @notice Load configuration from environment variables
    /// @return config The populated ChainAdditionConfig struct
    function _loadConfigFromEnv() internal view returns (ChainAdditionConfig memory config) {
        config.jsonPath = vm.envOr("ADD_CHAINS_JSON_PATH", DEFAULT_JSON_PATH);
        
        // Try to load agreement address from env (optional)
        string memory agreementStr = vm.envOr("AGREEMENT_ADDRESS", string(""));
        if (bytes(agreementStr).length > 0) {
            config.agreement = vm.parseAddress(agreementStr);
        }
    }

    // ======== VALIDATION FUNCTIONS ========

    /// @notice Validate that the agreement address is a valid contract
    /// @param agreementAddress The address to validate
    function _validateAgreement(address agreementAddress) internal view {
        if (agreementAddress == address(0)) {
            revert AddChains__InvalidAgreementAddress();
        }
        if (agreementAddress.code.length == 0) {
            revert AddChains__InvalidAgreementAddress();
        }
    }

    /// @notice Validate chain details
    /// @param chains The chains to validate
    function _validateChains(AgreementChain[] memory chains) internal pure {
        if (chains.length == 0) {
            revert AddChains__NoChainsProvided();
        }

        for (uint256 i; i < chains.length; ++i) {
            if (bytes(chains[i].caip2ChainId).length == 0) {
                revert AddChains__ChainValidationFailed(chains[i].caip2ChainId, "Empty chain ID");
            }
            if (bytes(chains[i].assetRecoveryAddress).length == 0) {
                revert AddChains__ChainValidationFailed(chains[i].caip2ChainId, "Empty recovery address");
            }
            if (chains[i].accounts.length == 0) {
                revert AddChains__ChainValidationFailed(chains[i].caip2ChainId, "No accounts provided");
            }
        }
    }

    // ======== UTILITY FUNCTIONS ========

    /// @notice Read JSON file from disk
    /// @param path The file path
    /// @return json The file contents as a string
    function _readJsonFile(string memory path) internal view returns (string memory json) {
        try vm.readFile(path) returns (string memory content) {
            return content;
        } catch {
            revert AddChains__InvalidJsonPath(path);
        }
    }

    /// @notice Get the length of an array in JSON by checking element existence
    /// @param json The JSON string
    /// @param arrayPath The base path to the array
    /// @param testField A field that should exist in each element
    /// @return count The number of elements in the array
    function _getArrayLength(
        string memory json,
        string memory arrayPath,
        string memory testField
    )
        internal
        view
        returns (uint256 count)
    {
        while (true) {
            string memory path = string.concat(arrayPath, "[", _uintToString(count), "]", testField);
            if (!vm.keyExists(json, path)) {
                break;
            }
            ++count;
        }
    }

    /// @notice Convert uint256 to string
    /// @param value The value to convert
    /// @return string The string representation
    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            ++digits;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            --digits;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    // ======== LOGGING FUNCTIONS ========

    /// @notice Log chains for preview
    /// @param chains The chains to log
    function _logPreview(AgreementChain[] memory chains) internal pure {
        console.log("========== CHAIN ADDITION PREVIEW ==========");
        _logChains(chains);
        console.log("============================================");
        console.log("(This is a preview - no transaction will be executed)");
    }

    /// @notice Log chains to console
    /// @param chains The chains to log
    function _logChains(AgreementChain[] memory chains) internal pure {
        string[4] memory childContractScopes = ["None", "ExistingOnly", "All", "FutureOnly"];

        console.log("Chains to add (", chains.length, "):");
        for (uint256 i; i < chains.length; ++i) {
            AgreementChain memory chain = chains[i];
            console.log("  [", i, "] CAIP-2 ID:", chain.caip2ChainId);
            console.log("      Asset Recovery:", chain.assetRecoveryAddress);
            console.log("      Accounts (", chain.accounts.length, "):");
            for (uint256 j; j < chain.accounts.length; ++j) {
                AgreementAccount memory account = chain.accounts[j];
                console.log("        [", j, "] Address:", account.accountAddress);
                console.log(
                    "            Scope:", childContractScopes[uint256(account.childContractScope)]
                );
            }
        }
    }
}
