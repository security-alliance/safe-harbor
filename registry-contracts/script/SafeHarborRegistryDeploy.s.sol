// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Script} from "forge-std/Script.sol";
// import {SafeHarborRegistry} from "src/SafeHarborRegistry.sol";

// contract SafeHarborRegistryDeploy is Script {

//     // This is a create2 factory deployed by a one-time-use-account as described here:
//     // https://github.com/Arachnid/deterministic-deployment-proxy. As a result, this factory
//     // exists (or can exist) on any EVM compatible chain, and gives us a guaranteed way to deploy
//     // the registry to a deterministic address across all chains. This is used by default in foundry
//     // when we specify a salt in a contract creation.
//     address constant DETERMINISTIC_CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

//     // This could have been any value, but we choose zero.
//     bytes32 constant DETERMINISTIC_DEPLOY_SALT = bytes32(0);

//     function run() public {

//         require(
//             DETERMINISTIC_CREATE2_FACTORY.code.length != 0,
//             "Create2 factory not deployed yet, see https://github.com/Arachnid/deterministic-deployment-proxy."
//         );

//         require(
//             getExpectedAddress().code.length == 0,
//             "Registry already deployed, nothing left to do."
//         );

//         uint256 deployerPrivateKey = vm.envUint("REGISTRY_DEPLOYER_PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);
//         address deployedRegistry = address(new SafeHarborRegistry{salt : DETERMINISTIC_DEPLOY_SALT}());
//         vm.stopBroadcast();

//         require(
//             deployedRegistry == getExpectedAddress(),
//             "Deployed to unexpected address. Check that Foundry is using the correct create2 factory."
//         );
//     }

//     // Computes the address which the registry will be deployed to, assuming the correct create2 factory
//     // and salt are used. 
//     function getExpectedAddress() public pure returns (address) {
//         return address(uint160(uint(keccak256(abi.encodePacked(
//             bytes1(0xff),
//             DETERMINISTIC_CREATE2_FACTORY,
//             DETERMINISTIC_DEPLOY_SALT,
//             keccak256(type(SafeHarborRegistry).creationCode)
//         )))));
//     }
// }
