// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Agreement } from "src/Agreement.sol";
import { Chain as AgreementChain, Account as AgreementAccount, ChildContractScope } from "src/types/AgreementTypes.sol";

/// @title AddChains
/// @notice Script for adding chains to an existing Agreement contract
/// @dev Reads chain details from JSON and calls addChains on the Agreement contract.
///      Validation happens on-chain via the Agreement contract.
contract AddChains is Script {
    using stdJson for string;

    string private constant DEFAULT_JSON_PATH = "examples/addChains.json";

    struct ChainAdditionConfig {
        string jsonPath;
        address agreement;
    }

    /// @notice Main entry point - uses environment variables
    function run() external {
        ChainAdditionConfig memory config = _loadConfigFromEnv();
        _executeChainAddition(config);
    }

    /// @notice Execute with explicit configuration
    function run(ChainAdditionConfig calldata config) external {
        _executeChainAddition(config);
    }

    /// @notice Execute with pre-parsed chains
    function run(address agreementAddress, AgreementChain[] calldata chains) external {
        _executeChainAdditionWithChains(agreementAddress, chains);
    }

    /// @notice Preview the chains to be added without executing
    function preview(string calldata jsonPath) external view returns (AgreementChain[] memory chains) {
        string memory json = vm.readFile(jsonPath);
        chains = _parseChains(json);
        _logChains(chains);
    }

    function _executeChainAddition(ChainAdditionConfig memory config) internal {
        string memory json = vm.readFile(config.jsonPath);

        address agreementAddress =
            config.agreement == address(0) ? json.readAddress(".agreementAddress") : config.agreement;

        AgreementChain[] memory chains = _parseChains(json);
        _executeChainAdditionWithChains(agreementAddress, chains);
    }

    function _executeChainAdditionWithChains(address agreementAddress, AgreementChain[] memory chains) internal {
        console.log("Adding", chains.length, "chains to agreement:", agreementAddress);
        _logChains(chains);

        Agreement agreement = Agreement(agreementAddress);

        vm.startBroadcast();
        agreement.addChains(chains);
        vm.stopBroadcast();

        console.log("Chains added successfully!");
    }

    function _parseChains(string memory json) internal view returns (AgreementChain[] memory chains) {
        uint256 count = _getArrayLength(json, ".chains", ".caip2ChainId");
        chains = new AgreementChain[](count);

        for (uint256 i; i < count; ++i) {
            string memory basePath = string.concat(".chains[", _uintToString(i), "]");
            chains[i] = AgreementChain({
                caip2ChainId: json.readString(string.concat(basePath, ".caip2ChainId")),
                assetRecoveryAddress: json.readString(string.concat(basePath, ".assetRecoveryAddress")),
                accounts: _parseAccounts(json, _uintToString(i))
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

    function _loadConfigFromEnv() internal view returns (ChainAdditionConfig memory config) {
        config.jsonPath = vm.envOr("ADD_CHAINS_JSON_PATH", DEFAULT_JSON_PATH);
        string memory agreementStr = vm.envOr("AGREEMENT_ADDRESS", string(""));
        if (bytes(agreementStr).length > 0) {
            config.agreement = vm.parseAddress(agreementStr);
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

    function _logChains(AgreementChain[] memory chains) internal pure {
        console.log("Chains to add (", chains.length, "):");
        for (uint256 i; i < chains.length; ++i) {
            console.log("  [", i, "]", chains[i].caip2ChainId);
        }
    }
}
