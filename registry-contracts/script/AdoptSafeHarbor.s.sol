// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { AgreementFactory } from "src/AgreementFactory.sol";
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
/// @dev Reads agreement details from JSON, creates Agreement via factory,
///      optionally registers with SafeHarborRegistry. Validation happens on-chain.
contract AdoptSafeHarbor is Script {
    using stdJson for string;

    string private constant DEFAULT_JSON_PATH = "examples/agreementDetails.json";

    struct AdoptionConfig {
        string jsonPath;
        address factory;
        address registry;
        address chainValidator;
        bool shouldAdoptToRegistry;
        address owner;
        bytes32 salt;
    }

    /// @notice Main entry point - uses environment variables
    function run() external {
        AdoptionConfig memory config = _loadConfigFromEnv();
        _executeAdoption(config);
    }

    /// @notice Execute adoption with explicit configuration
    function run(AdoptionConfig calldata config) external {
        _executeAdoption(config);
    }

    /// @notice Preview the agreement details from a file without deploying
    function preview(string calldata jsonPath) external view returns (AgreementDetails memory details) {
        string memory json = vm.readFile(jsonPath);
        details = _parseAgreementDetails(json);
        _logPreview(details);
    }

    /// @notice Execute adoption with pre-parsed agreement details
    function run(AdoptionConfig calldata config, AgreementDetails calldata details) external {
        _executeAdoptionWithDetails(config, details);
    }

    function _executeAdoption(AdoptionConfig memory config) internal {
        string memory json = vm.readFile(config.jsonPath);
        AgreementDetails memory details = _parseAgreementDetails(json);
        _executeAdoptionWithDetails(config, details);
    }

    function _executeAdoptionWithDetails(AdoptionConfig memory config, AgreementDetails memory details) internal {
        console.log("Creating agreement for:", details.protocolName);

        address agreementAddress = _createAgreement(config, details);

        if (config.shouldAdoptToRegistry) {
            SafeHarborRegistry registry = SafeHarborRegistry(config.registry);
            vm.startBroadcast();
            registry.adoptSafeHarbor(agreementAddress);
            vm.stopBroadcast();
            console.log("Registered to Safe Harbor Registry");
        }

        console.log("Agreement created at:", agreementAddress);
    }

    function _createAgreement(
        AdoptionConfig memory config,
        AgreementDetails memory details
    )
        internal
        returns (address agreementAddress)
    {
        AgreementFactory factory = AgreementFactory(config.factory);
        address owner = config.owner == address(0) ? msg.sender : config.owner;

        vm.startBroadcast();
        agreementAddress = factory.create(details, config.chainValidator, owner, config.salt);
        vm.stopBroadcast();

        return agreementAddress;
    }

    function _parseAgreementDetails(string memory json) internal view returns (AgreementDetails memory details) {
        details.protocolName = json.readString(".protocolName");
        details.agreementURI = json.readString(".agreementURI");
        details.contactDetails = _parseContacts(json);
        details.chains = _parseChains(json);
        details.bountyTerms = _parseBountyTerms(json);
    }

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

    function _parseBountyTerms(string memory json) internal pure returns (BountyTerms memory terms) {
        terms = BountyTerms({
            bountyPercentage: json.readUint(".bountyTerms.bountyPercentage"),
            bountyCapUSD: json.readUint(".bountyTerms.bountyCapUSD"),
            aggregateBountyCapUSD: json.readUint(".bountyTerms.aggregateBountyCapUSD"),
            retainable: json.readBool(".bountyTerms.retainable"),
            identity: IdentityRequirements(uint8(json.readUint(".bountyTerms.identity"))),
            diligenceRequirements: json.readString(".bountyTerms.diligenceRequirements")
        });
    }

    function _loadConfigFromEnv() internal view returns (AdoptionConfig memory config) {
        config.jsonPath = vm.envOr("AGREEMENT_DETAILS_PATH", DEFAULT_JSON_PATH);
        config.factory = vm.envOr("AGREEMENT_FACTORY", address(0));
        config.registry = vm.envOr("REGISTRY_ADDRESS", address(0));
        config.chainValidator = vm.envOr("CHAIN_VALIDATOR_ADDRESS", address(0));
        config.shouldAdoptToRegistry = vm.envOr("ADOPT_TO_REGISTRY", false);
        config.owner = vm.envOr("AGREEMENT_OWNER", address(0));
        string memory saltStr = vm.envOr("AGREEMENT_SALT", string(""));
        if (bytes(saltStr).length > 0) {
            config.salt = keccak256(bytes(saltStr));
        }
    }

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
            if (!vm.keyExistsJson(json, path)) break;
            ++count;
        }
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
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

    function _logPreview(AgreementDetails memory details) internal pure {
        console.log("========== AGREEMENT PREVIEW ==========");
        console.log("Protocol:", details.protocolName);
        console.log("Chains:", details.chains.length);
        console.log("=======================================");
    }
}
