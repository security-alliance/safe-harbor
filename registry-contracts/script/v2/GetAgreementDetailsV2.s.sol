// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementV2.sol";
import {logAgreementDetails} from "../../test/v2/mock.sol";

contract GetAgreementDetailsV2 is ScriptBase {
    function run() public view {
        address agreementAddress = vm.envAddress("AGREEMENT_ADDRESS");
        AgreementV2 agreement = AgreementV2(agreementAddress);
        AgreementDetailsV2 memory details = agreement.getDetails();
        logAgreementDetails(details);
    }

    /// @notice CLI entry: forge script ... --sig 'run(address)' <agreementAddress>
    function run(address agreementAddress) public view {
        AgreementV2 agreement = AgreementV2(agreementAddress);
        AgreementDetailsV2 memory details = agreement.getDetails();
        logAgreementDetails(details);
    }
}
