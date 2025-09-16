// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";

contract SetChains is Script {
    address constant REGISTRY_ADDRESS = 0x1eaCD100B0546E433fbf4d773109cAD482c34686;

    function run() public {
        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);
        require(address(registry).code.length > 0, "No contract exists at the registry address.");

        uint256 deployerPrivateKey = vm.envUint("REGISTRY_DEPLOYER_PRIVATE_KEY");

        // CAIP-2 chain IDs for various chains
        string[] memory caip2ChainIds = new string[](51);
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
        caip2ChainIds[32] = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"; // Solana Mainnet
        caip2ChainIds[33] = "stellar:pubnet"; // Stellar Mainnet
        caip2ChainIds[34] = "bip122:000000000019d6689c085ae165831e93"; // Bitcoin Mainnet
        caip2ChainIds[35] = "eip155:999"; // HyperEVM
        caip2ChainIds[36] = "eip155:25"; // Cronos
        caip2ChainIds[37] = "eip155:1116"; // CORE
        caip2ChainIds[38] = "eip155:747474"; // Katana
        caip2ChainIds[39] = "eip155:369"; // Pulsechain
        caip2ChainIds[40] = "eip155:30"; // Rootstock
        caip2ChainIds[41] = "eip155:81457"; // Blast
        caip2ChainIds[42] = "eip155:2222"; // Kava
        caip2ChainIds[43] = "eip155:8217"; // Kaia
        caip2ChainIds[44] = "eip155:200901"; // Bitlayer
        caip2ChainIds[45] = "eip155:60808"; // Bob
        caip2ChainIds[46] = "eip155:98866"; // Plume
        caip2ChainIds[47] = "eip155:43111"; // Hemi
        caip2ChainIds[48] = "eip155:14"; // Flare
        caip2ChainIds[49] = "eip155:1868"; // Soneium
        caip2ChainIds[50] = "eip155:295"; // Hedera

        vm.broadcast(deployerPrivateKey);
        registry.setValidChains(caip2ChainIds);
    }
}
