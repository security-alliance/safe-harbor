// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { ICreateX } from "createx/ICreateX.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { ChainValidator } from "src/ChainValidator.sol";
import { AgreementFactory } from "src/AgreementFactory.sol";

/// @title DeploySafeHarbor
/// @notice Deployment script for Safe Harbor Registry using CREATE3 for deterministic addresses
contract DeploySafeHarbor is Script {
    // ----- CONSTANTS -----
    // Deployer address encoded in salts for permissioned deploy protection.
    // Only this address can deploy to the predetermined CREATE3 addresses.
    address public constant DEPLOYER = 0xD9b8653Ab0bBa82C397b350F7319bA0c76d9F26a;

    // Salt identifiers (last 11 bytes of the guarded salt)
    bytes11 private constant CHAIN_VALIDATOR_IMPL_SALT_ID = bytes11(keccak256("SafeHarbor.ChainValidator.impl.v3"));
    bytes11 private constant CHAIN_VALIDATOR_PROXY_SALT_ID = bytes11(keccak256("SafeHarbor.ChainValidator.proxy.v3"));
    bytes11 private constant REGISTRY_SALT_ID = bytes11(keccak256("SafeHarbor.Registry.v3"));
    bytes11 private constant AGREEMENT_FACTORY_SALT_ID = bytes11(keccak256("SafeHarbor.AgreementFactory.v3"));

    // Guarded salts: deployer (20 bytes) + 0x00 (1 byte, same address across chains) + salt ID (11 bytes)
    // This ensures only DEPLOYER can deploy to these CREATE3 addresses
    bytes32 public constant CHAIN_VALIDATOR_IMPL_SALT =
        bytes32(abi.encodePacked(DEPLOYER, bytes1(0x00), CHAIN_VALIDATOR_IMPL_SALT_ID));
    bytes32 public constant CHAIN_VALIDATOR_PROXY_SALT =
        bytes32(abi.encodePacked(DEPLOYER, bytes1(0x00), CHAIN_VALIDATOR_PROXY_SALT_ID));
    bytes32 public constant REGISTRY_SALT = bytes32(abi.encodePacked(DEPLOYER, bytes1(0x00), REGISTRY_SALT_ID));
    bytes32 public constant AGREEMENT_FACTORY_SALT =
        bytes32(abi.encodePacked(DEPLOYER, bytes1(0x00), AGREEMENT_FACTORY_SALT_ID));

    // ----- STATE -----
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;
    bool private _initialized;

    // ----- DEPLOYED ADDRESSES -----
    address public chainValidatorImpl;
    address public chainValidator; // proxy address
    address public registry;
    address public agreementFactory;

    // ----- INITIALIZATION -----

    /// @notice Initializes the deployer with HelperConfig
    /// @dev Must be called before deployChainValidator or deployRegistry
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

        console.log("Deploying Safe Harbor Registry...");
        console.log("Chain ID:", block.chainid);
        console.log("ChainValidator Owner:", networkConfig.owner);
        console.log("CreateX:", networkConfig.createx);
        console.log("Legacy Registry:", networkConfig.legacyRegistry);

        vm.startBroadcast();

        // Deploy ChainValidator
        chainValidator = deployChainValidator();
        console.log("ChainValidator deployed at:", chainValidator);

        // Deploy SafeHarborRegistry
        registry = deployRegistry();
        console.log("SafeHarborRegistry deployed at:", registry);

        // Deploy AgreementFactory
        agreementFactory = deployAgreementFactory();
        console.log("AgreementFactory deployed at:", agreementFactory);

        vm.stopBroadcast();
    }

    // ----- DEPLOYMENT FUNCTIONS -----

    /// @notice Deploys the ChainValidator implementation and proxy using CREATE3
    /// @return proxy The address of the deployed proxy
    function deployChainValidator() public returns (address proxy) {
        ICreateX createx = ICreateX(networkConfig.createx);

        // Get valid chains from helper config
        string[] memory validChains = helperConfig.getValidChains();

        // 1. Deploy implementation
        bytes memory implInitCode = abi.encodePacked(type(ChainValidator).creationCode);
        chainValidatorImpl = createx.deployCreate3(CHAIN_VALIDATOR_IMPL_SALT, implInitCode);
        console.log("ChainValidator implementation deployed at:", chainValidatorImpl);

        // 2. Encode the initialize call for the proxy
        bytes memory initData = abi.encodeCall(ChainValidator.initialize, (networkConfig.owner, validChains));

        // 3. Deploy ERC1967Proxy pointing to implementation
        bytes memory proxyInitCode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(chainValidatorImpl, initData));
        proxy = createx.deployCreate3(CHAIN_VALIDATOR_PROXY_SALT, proxyInitCode);

        // Store proxy address
        chainValidator = proxy;

        return proxy;
    }

    /// @notice Deploys the SafeHarborRegistry contract using CREATE3
    function deployRegistry() public returns (address) {
        ICreateX createx = ICreateX(networkConfig.createx);

        // Encode constructor arguments (legacyRegistry, adopters)
        bytes memory initCode = abi.encodePacked(
            type(SafeHarborRegistry).creationCode, abi.encode(networkConfig.legacyRegistry, networkConfig.adopters)
        );

        // Deploy using CREATE3
        address deployed = createx.deployCreate3(REGISTRY_SALT, initCode);

        return deployed;
    }

    /// @notice Deploys the AgreementFactory contract using CREATE3
    function deployAgreementFactory() public returns (address) {
        ICreateX createx = ICreateX(networkConfig.createx);

        // Encode creation bytecode (no constructor arguments)
        bytes memory initCode = abi.encodePacked(type(AgreementFactory).creationCode);

        // Deploy using CREATE3
        address deployed = createx.deployCreate3(AGREEMENT_FACTORY_SALT, initCode);

        // Store in state variable
        agreementFactory = deployed;

        return deployed;
    }

    // ----- HELPER FUNCTIONS -----

    /// @notice Computes the expected addresses for the deployed contracts
    function computeExpectedAddresses()
        public
        view
        returns (
            address expectedValidatorImpl,
            address expectedValidatorProxy,
            address expectedRegistry,
            address expectedFactory
        )
    {
        ICreateX createx = ICreateX(networkConfig.createx);
        expectedValidatorImpl = createx.computeCreate3Address(CHAIN_VALIDATOR_IMPL_SALT);
        expectedValidatorProxy = createx.computeCreate3Address(CHAIN_VALIDATOR_PROXY_SALT);
        expectedRegistry = createx.computeCreate3Address(REGISTRY_SALT);
        expectedFactory = createx.computeCreate3Address(AGREEMENT_FACTORY_SALT);
    }
}
