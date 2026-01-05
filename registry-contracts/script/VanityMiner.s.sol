// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { ICreateX } from "createx/ICreateX.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

/// @title VanityMiner
/// @notice Mines for CREATE3 salts that produce vanity addresses
contract VanityMiner is Script {
    // ----- MINING PARAMETERS (edit these) -----
    string public constant BASE_SALT = "SafeHarbor.ChainValidator.proxy";
    string public constant PREFIX = "5ea1";
    string public constant SUFFIX = "3";
    uint256 public constant START_NONCE = 0;
    uint256 public constant ITERATIONS = 1_000_000;

    // ----- STATE -----
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;
    bool private _initialized;

    // ----- INITIALIZATION -----

    /// @notice Initializes the miner with HelperConfig
    function initialize() public {
        if (!_initialized) {
            helperConfig = new HelperConfig();
            networkConfig = helperConfig.getNetworkConfig();
            _initialized = true;
        }
    }

    /// @notice Initializes with an existing HelperConfig
    function initialize(HelperConfig _helperConfig) public {
        if (!_initialized) {
            helperConfig = _helperConfig;
            networkConfig = helperConfig.getNetworkConfig();
            _initialized = true;
        }
    }

    // ----- MAIN ENTRY POINT -----

    function run() external {
        initialize();

        ICreateX createx = ICreateX(networkConfig.createx);

        console.log("Mining vanity address...");
        console.log("CreateX:", networkConfig.createx);
        console.log("Base salt:", BASE_SALT);
        console.log("Prefix:", PREFIX);
        console.log("Suffix:", SUFFIX);
        console.log("Start nonce:", START_NONCE);
        console.log("Iterations:", ITERATIONS);
        console.log("---");

        bytes memory prefixBytes = bytes(PREFIX);
        bytes memory suffixBytes = bytes(SUFFIX);

        for (uint256 i = START_NONCE; i < START_NONCE + ITERATIONS; i++) {
            bytes32 salt = keccak256(abi.encodePacked(BASE_SALT, ".", i));
            address computed = createx.computeCreate3Address(salt);

            if (_matchesPattern(computed, prefixBytes, suffixBytes)) {
                console.log("FOUND!");
                console.log("Nonce:", i);
                console.log("Salt string:", string(abi.encodePacked(BASE_SALT, ".", vm.toString(i))));
                console.log("Salt bytes32:", vm.toString(salt));
                console.log("Address:", computed);
                console.log("---");
            }

            // Progress update every 100k iterations
            if (i % 100_000 == 0 && i > START_NONCE) {
                console.log("Progress:", i - START_NONCE, "/", ITERATIONS);
            }
        }

        console.log("Mining complete.");
    }

    // ----- HELPER FUNCTIONS -----

    /// @notice Quick test to verify a known salt
    function verify(bytes32 salt) public {
        initialize();
        ICreateX createx = ICreateX(networkConfig.createx);
        address computed = createx.computeCreate3Address(salt);
        console.log("Salt:", vm.toString(salt));
        console.log("Address:", computed);
    }

    /// @notice Check if address matches the prefix and suffix pattern
    function _matchesPattern(
        address addr,
        bytes memory prefix,
        bytes memory suffix
    )
        internal
        pure
        returns (bool)
    {
        bytes memory addrStr = _addressToAscii(addr);

        // Check prefix
        if (prefix.length > 0) {
            for (uint256 i = 0; i < prefix.length; i++) {
                if (addrStr[i] != prefix[i]) {
                    return false;
                }
            }
        }

        // Check suffix
        if (suffix.length > 0) {
            uint256 addrLen = addrStr.length;
            uint256 suffixLen = suffix.length;
            for (uint256 i = 0; i < suffixLen; i++) {
                if (addrStr[addrLen - suffixLen + i] != suffix[i]) {
                    return false;
                }
            }
        }

        return true;
    }

    /// @notice Convert address to lowercase ASCII hex string (without 0x prefix)
    function _addressToAscii(address addr) internal pure returns (bytes memory) {
        bytes memory result = new bytes(40);
        bytes memory hexChars = "0123456789abcdef";
        uint160 value = uint160(addr);

        for (uint256 i = 40; i > 0; i--) {
            result[i - 1] = hexChars[value & 0xf];
            value >>= 4;
        }

        return result;
    }
}
