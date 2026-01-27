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
        DeploySafeHarbor deployer = new DeploySafeHarbor();
        address expectedDeployer = deployer.DEPLOYER();

        // Compute the guarded salts that CreateX will use
        // For salts with first 20 bytes = msg.sender and byte 20 = 0x00:
        // guardedSalt = keccak256(abi.encodePacked(msg.sender, salt))
        bytes32 guardedProxySalt = _computeGuardedSalt(expectedDeployer, deployer.CHAIN_VALIDATOR_PROXY_SALT());
        bytes32 guardedRegistrySalt = _computeGuardedSalt(expectedDeployer, deployer.REGISTRY_SALT());

        // Fork mainnet and compute addresses
        vm.createSelectFork("mainnet");
        console.log("Forked Mainnet, chainId:", block.chainid);
        ICreateX createxMainnet = ICreateX(CREATEX);
        address chainValidatorProxyMainnet = createxMainnet.computeCreate3Address(guardedProxySalt, CREATEX);
        address registryMainnet = createxMainnet.computeCreate3Address(guardedRegistrySalt, CREATEX);
        console.log("Mainnet ChainValidator Proxy:", chainValidatorProxyMainnet);
        console.log("Mainnet Registry:", registryMainnet);

        // Fork polygon and compute addresses
        vm.createSelectFork("polygon");
        console.log("\nForked Polygon, chainId:", block.chainid);
        ICreateX createxPolygon = ICreateX(CREATEX);
        address chainValidatorProxyPolygon = createxPolygon.computeCreate3Address(guardedProxySalt, CREATEX);
        address registryPolygon = createxPolygon.computeCreate3Address(guardedRegistrySalt, CREATEX);
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

    function test_saltGuardPreventsOtherDeployers() public {
        DeploySafeHarbor deployer = new DeploySafeHarbor();
        address expectedDeployer = deployer.DEPLOYER();
        address maliciousDeployer = address(0xdead);

        // Compute guarded salts for legitimate deployer
        bytes32 legitimateGuardedSalt = _computeGuardedSalt(expectedDeployer, deployer.REGISTRY_SALT());

        // Compute guarded salts for malicious deployer (different msg.sender)
        bytes32 maliciousGuardedSalt = _computeGuardedSalt(maliciousDeployer, deployer.REGISTRY_SALT());

        vm.createSelectFork("mainnet");
        ICreateX createx = ICreateX(CREATEX);

        address legitimateAddress = createx.computeCreate3Address(legitimateGuardedSalt, CREATEX);
        address maliciousAddress = createx.computeCreate3Address(maliciousGuardedSalt, CREATEX);

        // Addresses should be different - salt guard works!
        assertTrue(legitimateAddress != maliciousAddress, "Salt guard should prevent address collision");
        console.log("Legitimate deployer address:", legitimateAddress);
        console.log("Malicious deployer address:", maliciousAddress);
        console.log("SUCCESS: Salt guard prevents other deployers from using our address!");
    }

    /// @dev Computes the guarded salt that CreateX uses for permissioned deploys
    /// When first 20 bytes = msg.sender and byte 20 = 0x00, CreateX computes:
    /// guardedSalt = keccak256(abi.encodePacked(bytes32(uint256(uint160(msg.sender))), salt))
    function _computeGuardedSalt(address sender, bytes32 salt) internal pure returns (bytes32) {
        bytes32 a = bytes32(uint256(uint160(sender)));
        bytes32 b = salt;
        // This matches CreateX's _efficientHash function
        return keccak256(abi.encodePacked(a, b));
    }
}
