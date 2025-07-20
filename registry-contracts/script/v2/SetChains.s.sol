// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";

contract SetChains is Script {
    address constant REGISTRY_ADDRESS = 0xc8C53c0dd6830e15AF3263D718203e1B534C8Abe;

    function run() public {
        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);
        require(address(registry).code.length > 0, "No contract exists at the registry address.");

        uint256 deployerPrivateKey = vm.envUint("REGISTRY_DEPLOYER_PRIVATE_KEY");

        // CAIP-2 chain IDs for various chains
        string[] memory caip2ChainIds = new string[](32);
        caip2ChainIds[0] = "eip155:1"; // Ethereum
        caip2ChainIds[1] = "eip155:56"; // BSC
        caip2ChainIds[2] = "eip155:42161"; // Arbitrum
        caip2ChainIds[3] = "eip155:137"; // Polygon
        caip2ChainIds[4] = "eip155:8453"; // Base
        caip2ChainIds[5] = "eip155:43114"; // Avalanche
        caip2ChainIds[6] = "eip155:10"; // Optimism
        caip2ChainIds[7] = "tron:mainnet"; // Tron (mainnet)
        caip2ChainIds[8] = "eip155:1284"; // Moonbeam
        caip2ChainIds[9] = "eip155:1285"; // Moonriver
        caip2ChainIds[10] = "eip155:252"; // Fraxtal
        caip2ChainIds[11] = "eip155:100"; // Gnosis
        caip2ChainIds[12] = "eip155:34443"; // Mode
        caip2ChainIds[13] = "eip155:1101"; // Polygon ZkEVM
        caip2ChainIds[14] = "eip155:146"; // Sonic
        caip2ChainIds[15] = "eip155:81457"; // Blast
        caip2ChainIds[16] = "eip155:288"; // Boba
        caip2ChainIds[17] = "eip155:42220"; // Celo
        caip2ChainIds[18] = "eip155:314"; // Filecoin
        caip2ChainIds[19] = "eip155:59144"; // Linea
        caip2ChainIds[20] = "eip155:169"; // Manta Pacific
        caip2ChainIds[21] = "eip155:5000"; // Mantle
        caip2ChainIds[22] = "eip155:690"; // Berachain
        caip2ChainIds[23] = "eip155:30"; // Unichain
        caip2ChainIds[24] = "eip155:534352"; // Scroll
        caip2ChainIds[25] = "eip155:1329"; // Sei Network
        caip2ChainIds[26] = "eip155:167000"; // Taiko Alethia
        caip2ChainIds[27] = "eip155:480"; // World Chain
        caip2ChainIds[28] = "eip155:324"; // zkSync Mainnet
        caip2ChainIds[29] = "eip155:7777777"; // Zora
        caip2ChainIds[30] = "eip155:204"; // opBNB Mainnet
        caip2ChainIds[31] = "eip155:1088"; // Metis Andromeda Mainnet

        vm.broadcast(deployerPrivateKey);
        registry.setValidChains(caip2ChainIds);
    }
}
