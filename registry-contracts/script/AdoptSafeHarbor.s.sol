// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { AgreementFactory } from "src/AgreementFactory.sol";
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

/// @title AdoptSafeHarbor
/// @notice Script for adopting Safe Harbor via JSON configuration
/// @dev This script reads agreement details from a JSON file, creates an Agreement
///      contract via the AgreementFactory, and optionally registers it with the SafeHarborRegistry
contract AdoptSafeHarbor is Script {
    using stdJson for string;

    // ----- ERRORS -----
    error AdoptSafeHarbor__InvalidJsonPath(string path);
    error AdoptSafeHarbor__ProtocolNameEmpty();
    error AdoptSafeHarbor__AgreementUriEmpty();
    error AdoptSafeHarbor__NoChainsSpecified();
    error AdoptSafeHarbor__NoContactDetails();
    error AdoptSafeHarbor__ChainValidatorNotFound();
    error AdoptSafeHarbor__RegistryNotFound();
    error AdoptSafeHarbor__FactoryNotFound();
    error AdoptSafeHarbor__InvalidBountyPercentage(uint256 percentage);
    error AdoptSafeHarbor__DeploymentFailed();
    error AdoptSafeHarbor__AdoptionFailed();

    // ----- EVENTS -----
    event AgreementCreated(address indexed agreement, address indexed owner, bytes32 salt);
    event SafeHarborAdopted(address indexed adopter, address indexed agreement);

    // ----- STRUCTS -----
    struct AdoptionConfig {
        string jsonPath;
        address factory;
        address registry;
        address chainValidator;
        bool shouldAdoptToRegistry;
        address owner;
        bytes32 salt;
    }

    // ----- CONSTANTS -----
    uint256 private constant MAX_BOUNTY_PERCENTAGE = 100;
    string private constant DEFAULT_JSON_PATH = "examples/agreementDetails.json";

    // ======== MAIN ENTRY POINTS ========

    /// @notice Main entry point - uses environment variables for configuration
    /// @dev Uses vm.startBroadcast() for key management (pass --private-key via CLI)
    ///      Optional env vars: AGREEMENT_DETAILS_PATH (default: examples/agreementDetails.json)
    ///                         AGREEMENT_FACTORY
    ///                         REGISTRY_ADDRESS
    ///                         CHAIN_VALIDATOR_ADDRESS
    ///                         ADOPT_TO_REGISTRY (default: false)
    ///                         AGREEMENT_OWNER (default: msg.sender)
    ///                         AGREEMENT_SALT (default: keccak256 of protocol name + timestamp)
    function run() external {
        AdoptionConfig memory config = _loadConfigFromEnv();
        _executeAdoption(config);
    }

    /// @notice Execute adoption with explicit configuration
    /// @param config The adoption configuration
    function run(AdoptionConfig calldata config) external {
        _executeAdoption(config);
    }

    /// @notice Preview the agreement details from a file without deploying
    /// @param jsonPath Path to the JSON file containing agreement details
    function preview(string calldata jsonPath) external view returns (AgreementDetails memory details) {
        string memory json = _readJsonFile(jsonPath);
        details = _parseAgreementDetails(json);
        _logPreview(details);
    }

    /// @notice Execute adoption with pre-parsed agreement details (useful for programmatic usage)
    /// @param config The adoption configuration
    /// @param details The agreement details struct
    function run(AdoptionConfig calldata config, AgreementDetails calldata details) external {
        _executeAdoptionWithDetails(config, details);
    }

    // ======== INTERNAL EXECUTION FUNCTIONS ========

    /// @notice Execute the full adoption flow from JSON file
    /// @param config The adoption configuration
    function _executeAdoption(AdoptionConfig memory config) internal {
        // Read and parse JSON
        console.log("Reading agreement details from:", config.jsonPath);
        string memory json = _readJsonFile(config.jsonPath);
        AgreementDetails memory details = _parseAgreementDetails(json);

        _executeAdoptionWithDetails(config, details);
    }

    /// @notice Execute the full adoption flow with pre-parsed details
    /// @param config The adoption configuration
    /// @param details The pre-parsed agreement details
    function _executeAdoptionWithDetails(AdoptionConfig memory config, AgreementDetails memory details) internal {
        // Validate contract addresses
        _validateAddresses(config);

        // Validate agreement details
        _validateAgreementDetails(details);

        // Log the parsed details
        _logAgreementDetails(details);

        // Create agreement
        address agreementAddress = _createAgreement(config, details);

        // Optionally adopt to registry
        if (config.shouldAdoptToRegistry) {
            _adoptToRegistry(config, agreementAddress);
        }

        console.log("==============================================");
        console.log("Adoption complete!");
        console.log("Agreement address:", agreementAddress);
        if (config.shouldAdoptToRegistry) {
            console.log("Registered to:", config.registry);
        }
        console.log("==============================================");
    }

    /// @notice Create the agreement contract via the factory
    /// @param config The adoption configuration
    /// @param details The agreement details
    /// @return agreementAddress The address of the created agreement
    function _createAgreement(
        AdoptionConfig memory config,
        AgreementDetails memory details
    )
        internal
        returns (address agreementAddress)
    {
        AgreementFactory factory = AgreementFactory(config.factory);

        address owner = config.owner == address(0) ? msg.sender : config.owner;

        // Generate salt if not provided
        bytes32 salt = config.salt;
        if (salt == bytes32(0)) {
            salt = keccak256(abi.encodePacked(details.protocolName, block.timestamp));
        }

        // Compute expected address
        address deployer = msg.sender;
        address predictedAddress = factory.computeAddress(details, config.chainValidator, owner, salt, deployer);
        console.log("Predicted agreement address:", predictedAddress);

        agreementAddress = factory.create(details, config.chainValidator, owner, salt);

        if (agreementAddress == address(0)) {
            revert AdoptSafeHarbor__DeploymentFailed();
        }

        // Verify the deployed address matches prediction
        if (agreementAddress != predictedAddress) {
            console.log("WARNING: Deployed address differs from prediction!");
            console.log("  Predicted:", predictedAddress);
            console.log("  Actual:", agreementAddress);
        }

        emit AgreementCreated(agreementAddress, owner, salt);
        console.log("Agreement created at:", agreementAddress);
        console.log("  Owner:", owner);
        console.log("  Salt:", vm.toString(salt));

        return agreementAddress;
    }

    /// @notice Adopt the agreement to the SafeHarborRegistry
    /// @param config The adoption configuration
    /// @param agreementAddress The address of the agreement to adopt
    function _adoptToRegistry(AdoptionConfig memory config, address agreementAddress) internal {
        SafeHarborRegistry registry = SafeHarborRegistry(config.registry);
        address adopter = msg.sender;

        registry.adoptSafeHarbor(agreementAddress);

        emit SafeHarborAdopted(adopter, agreementAddress);
        console.log("Agreement adopted to registry:", config.registry);
        console.log("  Adopter:", adopter);
    }

    // ======== PARSING FUNCTIONS ========

    /// @notice Parse complete agreement details from JSON
    /// @param json The JSON string to parse
    /// @return details The parsed AgreementDetails struct
    function _parseAgreementDetails(string memory json) internal view returns (AgreementDetails memory details) {
        details.protocolName = json.readString(".protocolName");
        details.agreementURI = json.readString(".agreementURI");
        details.contactDetails = _parseContacts(json);
        details.chains = _parseChains(json);
        details.bountyTerms = _parseBountyTerms(json);
    }

    /// @notice Parse contact details array from JSON
    /// @param json The JSON string to parse
    /// @return contacts Array of Contact structs
    function _parseContacts(string memory json) internal view returns (Contact[] memory contacts) {
        uint256 count = _getArrayLength(json, ".contactDetails", ".name");

        contacts = new Contact[](count);
        for (uint256 i; i < count; ++i) {
            string memory indexStr = _uintToString(i);
            contacts[i] = Contact({
                name: json.readString(string.concat(".contactDetails[", indexStr, "].name")),
                contact: json.readString(string.concat(".contactDetails[", indexStr, "].contact"))
            });
        }
    }

    /// @notice Parse chain details array from JSON
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

    /// @notice Parse bounty terms from JSON
    /// @param json The JSON string to parse
    /// @return terms The parsed BountyTerms struct
    function _parseBountyTerms(string memory json) internal view returns (BountyTerms memory terms) {
        terms = BountyTerms({
            bountyPercentage: json.readUint(".bountyTerms.bountyPercentage"),
            bountyCapUSD: json.readUint(".bountyTerms.bountyCapUSD"),
            aggregateBountyCapUSD: json.readUint(".bountyTerms.aggregateBountyCapUSD"),
            retainable: json.readBool(".bountyTerms.retainable"),
            identity: IdentityRequirements(uint8(json.readUint(".bountyTerms.identity"))),
            diligenceRequirements: json.readString(".bountyTerms.diligenceRequirements")
        });
    }

    // ======== CONFIGURATION LOADING ========

    /// @notice Load configuration from environment variables
    /// @return config The populated AdoptionConfig struct
    function _loadConfigFromEnv() internal view returns (AdoptionConfig memory config) {
        config.jsonPath = vm.envOr("AGREEMENT_DETAILS_PATH", DEFAULT_JSON_PATH);
        config.factory = vm.envOr("AGREEMENT_FACTORY", address(0));
        config.registry = vm.envOr("REGISTRY_ADDRESS", address(0));
        config.chainValidator = vm.envOr("CHAIN_VALIDATOR_ADDRESS", address(0));
        config.shouldAdoptToRegistry = vm.envOr("ADOPT_TO_REGISTRY", false);
        config.owner = vm.envOr("AGREEMENT_OWNER", address(0));

        // Load salt if provided
        string memory saltStr = vm.envOr("AGREEMENT_SALT", string(""));
        if (bytes(saltStr).length > 0) {
            config.salt = keccak256(bytes(saltStr));
        }
    }

    // ======== VALIDATION FUNCTIONS ========

    /// @notice Validate that required contract addresses are set
    /// @param config The adoption configuration to validate
    function _validateAddresses(AdoptionConfig memory config) internal pure {
        if (config.chainValidator == address(0)) {
            revert AdoptSafeHarbor__ChainValidatorNotFound();
        }
        if (config.factory == address(0)) {
            revert AdoptSafeHarbor__FactoryNotFound();
        }
        if (config.shouldAdoptToRegistry && config.registry == address(0)) {
            revert AdoptSafeHarbor__RegistryNotFound();
        }
    }

    /// @notice Validate agreement details
    /// @param details The agreement details to validate
    function _validateAgreementDetails(AgreementDetails memory details) internal pure {
        if (bytes(details.protocolName).length == 0) {
            revert AdoptSafeHarbor__ProtocolNameEmpty();
        }
        if (bytes(details.agreementURI).length == 0) {
            revert AdoptSafeHarbor__AgreementUriEmpty();
        }
        if (details.chains.length == 0) {
            revert AdoptSafeHarbor__NoChainsSpecified();
        }
        if (details.contactDetails.length == 0) {
            revert AdoptSafeHarbor__NoContactDetails();
        }
        if (details.bountyTerms.bountyPercentage > MAX_BOUNTY_PERCENTAGE) {
            revert AdoptSafeHarbor__InvalidBountyPercentage(details.bountyTerms.bountyPercentage);
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
            revert AdoptSafeHarbor__InvalidJsonPath(path);
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

    /// @notice Log agreement details for preview
    /// @param details The agreement details to log
    function _logPreview(AgreementDetails memory details) internal pure {
        console.log("========== AGREEMENT PREVIEW ==========");
        _logAgreementDetails(details);
        console.log("=======================================");
        console.log("(This is a preview - no transaction will be executed)");
    }

    /// @notice Log agreement details to console
    /// @param details The agreement details to log
    function _logAgreementDetails(AgreementDetails memory details) internal pure {
        string[3] memory identityRequirements = ["Anonymous", "Pseudonymous", "Named"];
        string[4] memory childContractScopes = ["None", "ExistingOnly", "All", "FutureOnly"];

        console.log("Protocol Name:", details.protocolName);
        console.log("Agreement URI:", details.agreementURI);

        console.log("Contact Details (", details.contactDetails.length, "):");
        for (uint256 i; i < details.contactDetails.length; ++i) {
            console.log("  [", i, "] Name:", details.contactDetails[i].name);
            console.log("      Contact:", details.contactDetails[i].contact);
        }

        console.log("Chains (", details.chains.length, "):");
        for (uint256 i; i < details.chains.length; ++i) {
            AgreementChain memory chain = details.chains[i];
            console.log("  [", i, "] CAIP-2 ID:", chain.caip2ChainId);
            console.log("      Asset Recovery:", chain.assetRecoveryAddress);
            console.log("      Accounts (", chain.accounts.length, "):");
            for (uint256 j; j < chain.accounts.length; ++j) {
                AgreementAccount memory account = chain.accounts[j];
                console.log("        [", j, "] Address:", account.accountAddress);
                console.log("            Scope:", childContractScopes[uint256(account.childContractScope)]);
            }
        }

        console.log("Bounty Terms:");
        console.log("  Percentage:", details.bountyTerms.bountyPercentage, "%");
        console.log("  Cap USD: $", details.bountyTerms.bountyCapUSD);
        console.log("  Aggregate Cap USD: $", details.bountyTerms.aggregateBountyCapUSD);
        console.log("  Retainable:", details.bountyTerms.retainable ? "Yes" : "No");
        console.log("  Identity:", identityRequirements[uint256(details.bountyTerms.identity)]);
        console.log("  Diligence:", details.bountyTerms.diligenceRequirements);
    }
}
