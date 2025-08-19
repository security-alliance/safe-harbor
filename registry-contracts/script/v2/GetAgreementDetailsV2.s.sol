// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementV2.sol";
import {logAgreementDetails} from "../../test/v2/mock.sol";

contract GetAgreementDetailsV2 is ScriptBase {
    address constant REGISTRY_ADDRESS = 0x1eaCD100B0546E433fbf4d773109cAD482c34686;

    function run() public view {
        address owner = vm.envAddress("AGREEMENT_OWNER");

        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);

        address agreementAddress = registry.getAgreement(owner);
        require(agreementAddress != address(0), "No agreement found for owner");

        console.log("Agreement address for owner:");
        console.logAddress(agreementAddress);

        AgreementV2 agreement = AgreementV2(agreementAddress);
        AgreementDetailsV2 memory details = agreement.getDetails();
        logAgreementDetails(details);
    }
}
