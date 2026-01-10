// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";
import { ICreateX } from "createx/ICreateX.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";

/// @title DeploymentIntegrationTest
/// @notice Tests that CREATE3 deployments produce the same addresses on mainnet and polygon
contract DeploymentIntegrationTest is Test {
    // CreateX is deployed at the same address on all chains
    address constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function test_create3Addresses_sameOnMainnetAndPolygon() public {
        // Fork mainnet and compute addresses
        vm.createSelectFork("mainnet");
        console.log("Forked Mainnet, chainId:", block.chainid);
        ICreateX createxMainnet = ICreateX(CREATEX);
        address chainValidatorProxyMainnet =
            createxMainnet.computeCreate3Address(keccak256("SafeHarbor.ChainValidator.proxy.v3"));
        address registryMainnet = createxMainnet.computeCreate3Address(keccak256("SafeHarbor.Registry.v3"));
        console.log("Mainnet ChainValidator Proxy:", chainValidatorProxyMainnet);
        console.log("Mainnet Registry:", registryMainnet);
        // Fork polygon and compute addresses
        vm.createSelectFork("polygon");
        console.log("\nForked Polygon, chainId:", block.chainid);
        ICreateX createxPolygon = ICreateX(CREATEX);
        address chainValidatorProxyPolygon =
            createxPolygon.computeCreate3Address(keccak256("SafeHarbor.ChainValidator.proxy.v3"));
        address registryPolygon = createxPolygon.computeCreate3Address(keccak256("SafeHarbor.Registry.v3"));
        console.log("Polygon ChainValidator Proxy:", chainValidatorProxyPolygon);
        console.log("Polygon Registry:", registryPolygon);
        // Verify addresses match across chains
        assertEq(
            chainValidatorProxyMainnet,
            chainValidatorProxyPolygon,
            "ChainValidator proxy address mismatch between chains"
        );
        assertEq(registryMainnet, registryPolygon, "Registry address mismatch between chains");
        console.log("\nSUCCESS: Addresses match across chains!");
    }

    function test_saltsMatchDeployScript() public {
        // Verify our test uses the same salts as the deploy script
        DeploySafeHarbor deployer = new DeploySafeHarbor();
        assertEq(
            deployer.CHAIN_VALIDATOR_IMPL_SALT(),
            keccak256("SafeHarbor.ChainValidator.impl.v3"),
            "ChainValidator impl salt mismatch"
        );
        assertEq(
            deployer.CHAIN_VALIDATOR_PROXY_SALT(),
            keccak256("SafeHarbor.ChainValidator.proxy.v3"),
            "ChainValidator proxy salt mismatch"
        );
        assertEq(deployer.REGISTRY_SALT(), keccak256("SafeHarbor.Registry.v3"), "Registry salt mismatch");
    }
}
