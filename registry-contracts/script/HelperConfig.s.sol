// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script, console2 } from "forge-std/Script.sol";
import { SafeHarborRegistryV2 } from "test/mocks/LegacyRegistryV2.sol";
import { CreateX } from "test/mocks/MockCreateX.sol";

/// @title HelperConfig for Safe Harbor Registry Deployments
/// @notice Provides deployment configuration for different networks
contract HelperConfig is Script {
    // ----- ERRORS -----
    error HelperConfig__InvalidChainId();

    // ----- STRUCTS -----
    struct NetworkConfig {
        address owner;
        address legacyRegistry;
        address createx;
        address[] adopters;
    }

    // ----- CONSTANTS -----
    address public constant CREATEX_ADDRESS = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
    uint256 public constant LOCAL_CHAIN_ID = 31_337;
    address public constant DEFAULT_ANVIL_OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant DEFAULT_LEGACY_REGISTRY = 0x1eaCD100B0546E433fbf4d773109cAD482c34686;

    // ----- ADDRESS CONSTANTS -----
    address public constant SEAL_MAINNET_OWNER = 0xD9b8653Ab0bBa82C397b350F7319bA0c76d9F26a;
    address public constant OPS_COVEFI_ETH = 0x71BDC5F3AbA49538C76d58Bc2ab4E3A1118dAe4c;
    address public constant AAVE = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
    address public constant IDLE_FINANCE = 0xFb3bD022D5DAcF95eE28a6B07825D4Ff9C5b3814;
    address public constant ENS = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7;
    address public constant RHEO = 0x462B545e8BBb6f9E5860928748Bfe9eCC712c3a7;
    address public constant ENSURO = 0x261af6C5A12e268Bb919548c694fC75486B0EBBe;

    // ----- STATE -----
    NetworkConfig public activeNetworkConfig;
    address private deployedCreateX;
    address private deployedLegacyRegistry;

    // ----- CONSTRUCTOR -----
    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 10) {
            activeNetworkConfig = getOptimismConfig();
        } else if (block.chainid == 137) {
            activeNetworkConfig = getPolygonConfig();
        } else if (block.chainid == 42_161) {
            activeNetworkConfig = getArbitrumConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseConfig();
        } else if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    // ----- NETWORK CONFIG -----

    /// @notice Gets the network config for the current chain
    function getNetworkConfig() public returns (NetworkConfig memory) {
        // Return cached config, deploying CreateX for local if needed
        console2.log("Getting network config for chain ID:", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID && activeNetworkConfig.createx == address(0)) {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
        return activeNetworkConfig;
    }

    // ----- MAINNET CONFIGS -----

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        address[] memory adopters = new address[](5);
        adopters[0] = RHEO;
        adopters[1] = OPS_COVEFI_ETH;
        adopters[2] = AAVE;
        adopters[3] = IDLE_FINANCE;
        adopters[4] = ENS;
        return NetworkConfig({
            owner: SEAL_MAINNET_OWNER,
            legacyRegistry: DEFAULT_LEGACY_REGISTRY,
            createx: CREATEX_ADDRESS,
            adopters: adopters
        });
    }

    function getOptimismConfig() public pure returns (NetworkConfig memory) {
        address[] memory adopters = new address[](0);
        return NetworkConfig({
            owner: address(0), // TODO: Set optimism owner
            legacyRegistry: address(0),
            createx: CREATEX_ADDRESS,
            adopters: adopters
        });
    }

    function getPolygonConfig() public pure returns (NetworkConfig memory) {
        address[] memory adopters = new address[](1);
        adopters[0] = ENSURO;
        address currentOwner = 0x31d23affb90bCAfcAAe9f27903b151DCDC82569E; // THIS IS AN EOA!!! This should be a
        // multisig
        return NetworkConfig({
            owner: currentOwner, legacyRegistry: DEFAULT_LEGACY_REGISTRY, createx: CREATEX_ADDRESS, adopters: adopters
        });
    }

    function getArbitrumConfig() public pure returns (NetworkConfig memory) {
        address[] memory adopters = new address[](0);
        return NetworkConfig({
            owner: address(0), // TODO: Set arbitrum owner
            legacyRegistry: address(0),
            createx: CREATEX_ADDRESS,
            adopters: adopters
        });
    }

    function getBaseConfig() public pure returns (NetworkConfig memory) {
        address[] memory adopters = new address[](0);
        return NetworkConfig({
            owner: address(0), // TODO: Set base owner
            legacyRegistry: address(0),
            createx: CREATEX_ADDRESS,
            adopters: adopters
        });
    }

    // ----- TESTNET CONFIGS -----

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        address[] memory adopters = new address[](0);
        return NetworkConfig({
            owner: address(0), // TODO: Set sepolia owner
            legacyRegistry: address(0),
            createx: CREATEX_ADDRESS,
            adopters: adopters
        });
    }

    // ----- LOCAL CONFIG -----

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // If already deployed, return cached config
        address[] memory adopters = new address[](0);
        if (deployedCreateX != address(0) && deployedLegacyRegistry != address(0)) {
            return NetworkConfig({
                owner: DEFAULT_ANVIL_OWNER,
                legacyRegistry: deployedLegacyRegistry,
                createx: deployedCreateX,
                adopters: adopters
            });
        }

        // Deploy CreateX locally if not yet deployed
        if (deployedCreateX == address(0)) {
            // Note: block.number must be >= 32 for CreateX to work (it does block.number - 32)
            if (block.number < 100) {
                vm.roll(100);
            }
            // Deploy MockCreateX (copy of CreateX with compatible pragma)
            CreateX createx = new CreateX();
            deployedCreateX = address(createx);
        }

        // Deploy LegacyRegistry locally if not yet deployed
        if (deployedLegacyRegistry == address(0)) {
            SafeHarborRegistryV2 legacyRegistry = new SafeHarborRegistryV2(DEFAULT_ANVIL_OWNER);
            deployedLegacyRegistry = address(legacyRegistry);
        }

        return NetworkConfig({
            owner: DEFAULT_ANVIL_OWNER,
            legacyRegistry: deployedLegacyRegistry,
            createx: deployedCreateX,
            adopters: adopters
        });
    }

    // ----- HELPERS -----

    /// @notice Returns true if running on a local chain (anvil)
    function isLocalChain() public view returns (bool) {
        return block.chainid == LOCAL_CHAIN_ID;
    }

    // ----- VALID CHAINS -----
    // Returns the list of valid CAIP-2 chain IDs for Safe Harbor agreements
    // This list is the same for all deployments

    function getValidChains() public pure returns (string[] memory) {
        string[] memory chains = new string[](126);
        chains[0] = "eip155:1";
        chains[1] = "eip155:56";
        chains[2] = "eip155:42161";
        chains[3] = "eip155:137";
        chains[4] = "eip155:8453";
        chains[5] = "eip155:43114";
        chains[6] = "eip155:10";
        chains[7] = "tron:mainnet";
        chains[8] = "eip155:1284";
        chains[9] = "eip155:1285";
        chains[10] = "eip155:252";
        chains[11] = "eip155:100";
        chains[12] = "eip155:34443";
        chains[13] = "eip155:1101";
        chains[14] = "eip155:146";
        chains[15] = "eip155:81457";
        chains[16] = "eip155:288";
        chains[17] = "eip155:42220";
        chains[18] = "eip155:314";
        chains[19] = "eip155:59144";
        chains[20] = "eip155:169";
        chains[21] = "eip155:5000";
        chains[22] = "eip155:690";
        chains[23] = "eip155:30";
        chains[24] = "eip155:534352";
        chains[25] = "eip155:1329";
        chains[26] = "eip155:167000";
        chains[27] = "eip155:480";
        chains[28] = "eip155:324";
        chains[29] = "eip155:7777777";
        chains[30] = "eip155:204";
        chains[31] = "eip155:1088";
        chains[32] = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp";
        chains[33] = "stellar:pubnet";
        chains[34] = "bip122:000000000019d6689c085ae165831e93";
        chains[35] = "eip155:999";
        chains[36] = "eip155:25";
        chains[37] = "eip155:1116";
        chains[38] = "eip155:747474";
        chains[39] = "eip155:369";
        chains[40] = "eip155:2222";
        chains[41] = "eip155:8217";
        chains[42] = "eip155:200901";
        chains[43] = "eip155:60808";
        chains[44] = "eip155:98866";
        chains[45] = "eip155:43111";
        chains[46] = "eip155:14";
        chains[47] = "eip155:1868";
        chains[48] = "eip155:295";
        chains[49] = "eip155:9745";
        chains[50] = "tron:27Lqcw";
        chains[51] = "sui:mainnet";
        chains[52] = "eip155:57073";
        chains[53] = "eip155:80094";
        chains[54] = "starknet:SN_MAIN";
        chains[55] = "eip155:3073";
        chains[56] = "eip155:143";
        chains[57] = "stacks:1";
        chains[58] = "eip155:130";
        chains[59] = "eip155:747";
        chains[60] = "eip155:42793";
        chains[61] = "xrpl:0";
        chains[62] = "algorand:wGHE2Pwdvd7S12BL5FaOP20EGYesN73k";
        chains[63] = "eip155:173";
        chains[64] = "eip155:5064014";
        chains[65] = "eip155:2345";
        chains[66] = "tezos:NetXdQprcVkpaWU";
        chains[67] = "eip155:2741";
        chains[68] = "eip155:1729";
        chains[69] = "eip155:2020";
        chains[70] = "eip155:3637";
        chains[71] = "waves:087";
        chains[72] = "eip155:13371";
        chains[73] = "eip155:5464";
        chains[74] = "iota:mainnet";
        chains[75] = "eip155:388";
        chains[76] = "eip155:50104";
        chains[77] = "eip155:1514";
        chains[78] = "eip155:1923";
        chains[79] = "conflux:cfx";
        chains[80] = "eip155:1135";
        chains[81] = "eip155:250";
        chains[82] = "eip155:88888";
        chains[83] = "eip155:4689";
        chains[84] = "eip155:6900";
        chains[85] = "eip155:33139";
        chains[86] = "eip155:40";
        chains[87] = "eip155:1625";
        chains[88] = "eip155:1313161554";
        chains[89] = "eip155:888";
        chains[90] = "eip155:239";
        chains[91] = "eip155:5031";
        chains[92] = "eip155:96";
        chains[93] = "eip155:7000";
        chains[94] = "eip155:432204";
        chains[95] = "eip155:2410";
        chains[96] = "eip155:8822";
        chains[97] = "eip155:31612";
        chains[98] = "eip155:16661";
        chains[99] = "eip155:10088";
        chains[100] = "eip155:9999999";
        chains[101] = "vechain:b1ac3413d346d43539627e6be7ec1b4a";
        chains[102] = "eip155:177";
        chains[103] = "eip155:8008";
        chains[104] = "eip155:592";
        chains[105] = "bip122:12a765e31ffd4059bada1e25190f6e98";
        chains[106] = "eip155:757";
        chains[107] = "eip155:66";
        chains[108] = "eip155:48900";
        chains[109] = "eip155:4337";
        chains[110] = "eip155:53935";
        chains[111] = "eip155:3338";
        chains[112] = "eip155:321";
        chains[113] = "eip155:777777";
        chains[114] = "eip155:6001";
        chains[115] = "eip155:71402";
        chains[116] = "eip155:277";
        chains[117] = "eip155:21000000";
        chains[118] = "eip155:20";
        chains[119] = "eip155:10000";
        chains[120] = "eip155:18888";
        chains[121] = "eip155:964";
        chains[122] = "eip155:1890";
        chains[123] = "eip155:148";
        chains[124] = "eip155:42170";
        chains[125] = "bip122:fdbe99b90c90bae7505796461471d89a";
        return chains;
    }
}
