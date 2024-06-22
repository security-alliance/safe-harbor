// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {AgreementV1Factory} from "../src/Agreement_v1.sol";

// This function generates an account signature for EOAs. For ERC-1271 contracts
// the method of signature generation may vary from contract to contract. Ensure
// that you always reset all signature fields to empty before hashing the agreement
// details.
contract GenerateAccountSignatureV1 is Script {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        string memory agreementFile = vm.envString("AGREEMENT_FILE");

        string memory json = vm.readFile(agreementFile);
        AgreementDetailsV1 memory details = abi.decode(
            vm.parseJson(json, "AgreementDetailsV1"),
            (AgreementDetailsV1)
        );

        // Empty signature field for hashing
        for (uint i = 0; i < details.chains.length; i++) {
            for (uint j = 0; j < details.chains[i].accounts.length; j++) {
                details.chains[i].accounts[j].signature = new bytes(0);
            }
        }

        // Generate the signature
        bytes32 hash = keccak256(abi.encode(details));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.log("Account Address:");
        console.logAddress(vm.addr(privateKey));
        console.log("Generated Signature:");
        console.logBytes(signature);
    }
}
