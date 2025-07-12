// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";

struct ChainInfo {
    uint256 chainId;
    string name;
}

contract SetChains is Script {
    address constant REGISTRY_ADDRESS = 0xc8C53c0dd6830e15AF3263D718203e1B534C8Abe;

    function run() public {
        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);
        require(address(registry).code.length > 0, "No contract exists at the registry address.");

        uint256 deployerPrivateKey = vm.envUint("REGISTRY_DEPLOYER_PRIVATE_KEY");

        ChainInfo[] memory chains = new ChainInfo[](32);
        chains[0] = ChainInfo(1, "Ethereum");
        chains[1] = ChainInfo(56, "BSC");
        chains[2] = ChainInfo(42161, "Arbitrum");
        chains[3] = ChainInfo(137, "Polygon");
        chains[4] = ChainInfo(8453, "Base");
        chains[5] = ChainInfo(43114, "Avalanche");
        chains[6] = ChainInfo(10, "Optimism");
        chains[7] = ChainInfo(728126428, "Tron");
        chains[8] = ChainInfo(1284, "Moonbeam");
        chains[9] = ChainInfo(1285, "Moonriver");
        chains[10] = ChainInfo(252, "Fraxtal");
        chains[11] = ChainInfo(100, "Gnosis");
        chains[12] = ChainInfo(34443, "Mode");
        chains[13] = ChainInfo(1101, "Polygon ZkEVM");
        chains[14] = ChainInfo(146, "Sonic");
        chains[15] = ChainInfo(81457, "Blast");
        chains[16] = ChainInfo(288, "Boba");
        chains[17] = ChainInfo(42220, "Celo");
        chains[18] = ChainInfo(314, "Filecoin");
        chains[19] = ChainInfo(59144, "Linea");
        chains[20] = ChainInfo(169, "Manta Pacific");
        chains[21] = ChainInfo(5000, "Mantle");
        chains[22] = ChainInfo(690, "Berachain");
        chains[23] = ChainInfo(30, "Unichain");
        chains[24] = ChainInfo(534352, "Scroll");
        chains[25] = ChainInfo(1329, "Sei Network");
        chains[26] = ChainInfo(167000, "Taiko Alethia");
        chains[27] = ChainInfo(480, "World Chain");
        chains[28] = ChainInfo(324, "zkSync Mainnet");
        chains[29] = ChainInfo(7777777, "Zora");
        chains[30] = ChainInfo(204, "opBNB Mainnet");
        chains[31] = ChainInfo(1088, "Metis Andromeda Mainnet");

        uint256[] memory chainIds = new uint256[](chains.length);
        string[] memory chainNames = new string[](chains.length);

        for (uint256 i = 0; i < chains.length; i++) {
            chainIds[i] = chains[i].chainId;
            chainNames[i] = chains[i].name;
        }

        vm.broadcast(deployerPrivateKey);
        registry.setChains(chainIds, chainNames);
    }
}
