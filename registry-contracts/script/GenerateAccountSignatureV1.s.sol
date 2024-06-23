// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {ScriptBase} from "forge-std/Base.sol";
import {AgreementDetailsV1, Chain, Account, Contact, BountyTerms, IdentityRequirement, ChildContractScope} from "../src/AgreementV1.sol";

// This function generates an account signature for EOAs. For ERC-1271 contracts
// the method of signature generation may vary from contract to contract. Ensure
// that you always reset all signature fields to empty before hashing the agreement
// details.
contract GenerateAccountSignatureV1 is ScriptBase {
    function run() external view {
        uint256 signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        AgreementDetailsV1 memory details = getAgreementDetails();

        // Empty signature field for hashing
        for (uint i = 0; i < details.chains.length; i++) {
            for (uint j = 0; j < details.chains[i].accounts.length; j++) {
                details.chains[i].accounts[j].signature = new bytes(0);
            }
        }

        // Generate the signature
        bytes32 hash = keccak256(abi.encode(details));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.log("Account Address:");
        console.logAddress(vm.addr(signerPrivateKey));
        console.log("Generated Signature:");
        console.logBytes(signature);
    }

    function getAgreementDetails()
        internal
        pure
        returns (AgreementDetailsV1 memory details)
    {
        Account memory account = Account({
            accountAddress: address(0xeaA33ea82591611Ac749b875aBD80a465219ab40),
            childContractScope: ChildContractScope.ExistingOnly,
            signature: new bytes(0)
        });

        Chain memory chain = Chain({
            accounts: new Account[](1),
            assetRecoveryAddress: address(
                0xa30F2797Bf542ECe99290cf4E4C6546cc349B9A1
            ),
            chainID: 1
        });
        chain.accounts[0] = account;

        Contact memory contact = Contact({
            name: "testName",
            role: "testRole",
            contact: "testContact"
        });

        BountyTerms memory bountyTerms = BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 100,
            retainable: false,
            identityRequirement: IdentityRequirement.Named,
            diligenceRequirements: "testDiligenceRequirements"
        });

        details = AgreementDetailsV1({
            protocolName: "testProtocol",
            chains: new Chain[](1),
            contactDetails: new Contact[](1),
            bountyTerms: bountyTerms,
            automaticallyUpgrade: false,
            agreementURI: "ipfs://testHash"
        });
        details.chains[0] = chain;
        details.contactDetails[0] = contact;

        return details;
    }
}
