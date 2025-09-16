// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {AgreementV2} from "../../src/v2/AgreementV2.sol";
import {AdoptSafeHarborV2} from "./AdoptSafeHarborV2.s.sol";
import {Chain as ChainV2} from "../../src/v2/AgreementDetailsV2.sol";

contract AddChainsV2 is Script {
    using stdJson for string;

    // Path to the JSON input file (can be overridden with --ffi and env if needed)
    string constant INPUT_JSON_PATH = "addChainsV2.json";

    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory json = vm.readFile(INPUT_JSON_PATH);

        // Read the agreement address from JSON
        address agreementAddress = json.readAddress(".agreementAddress");
        require(agreementAddress != address(0), "agreementAddress missing or zero");

        AgreementV2 agreement = AgreementV2(agreementAddress);
        require(address(agreement).code.length > 0, "No contract at agreementAddress");

        AdoptSafeHarborV2 parser = new AdoptSafeHarborV2();
        ChainV2[] memory chains = parser.parseChains(json);
        console.log("Adding", chains.length, "chains to", agreementAddress);

        vm.startBroadcast(pk);
        agreement.addChains(chains);
        vm.stopBroadcast();

        console.log("Added chains successfully");
    }
}
