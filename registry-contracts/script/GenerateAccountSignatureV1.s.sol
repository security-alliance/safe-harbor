// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {ScriptBase} from "forge-std/Base.sol";
import {
    AgreementDetailsV1,
    Chain,
    Contact,
    Account,
    BountyTerms,
    ChildContractScope,
    IdentityRequirements
} from "../src/AgreementV1.sol";

import {AgreementValidatorV1} from "../src/AgreementValidatorV1.sol";

// This function generates an account signature for EOAs. For ERC-1271 contracts
// the method of signature generation may vary from contract to contract. Ensure
// that you always reset all signature fields to empty before hashing the agreement
// details.
contract GenerateAccountSignatureV1 is ScriptBase {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        address signerAddress = vm.addr(signerPrivateKey);
        AgreementDetailsV1 memory details = getAgreementDetails();

        // Empty signature field for hashing
        ChildContractScope signerScope;
        bool signerPresent;
        for (uint256 i = 0; i < details.chains.length; i++) {
            for (uint256 j = 0; j < details.chains[i].accounts.length; j++) {
                details.chains[i].accounts[j].signature = new bytes(0);

                Account memory acc = details.chains[i].accounts[j];
                if (acc.accountAddress == signerAddress) {
                    signerScope = acc.childContractScope;
                    signerPresent = true;
                }
            }
        }

        if (!signerPresent) {
            console.log("Signer not found in agreement details");
            revert();
        }

        // Generate the signature
        AgreementValidatorV1 validator = new AgreementValidatorV1();
        bytes32 digest = validator.encode(validator.DOMAIN_SEPARATOR(), details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Assert that the signature is valid
        Account memory account =
            Account({accountAddress: signerAddress, childContractScope: signerScope, signature: signature});
        assert(validator.validateAccount(details, account));

        console.log("Account Address:");
        console.logAddress(vm.addr(signerPrivateKey));
        console.log("Generated Signature:");
        console.logBytes(signature);
    }

    function getAgreementDetails() internal pure returns (AgreementDetailsV1 memory details) {
        Account memory account = Account({
            accountAddress: address(0xa40F732195D3165359478FC35f040442e3f9b127),
            childContractScope: ChildContractScope.All,
            signature: new bytes(0)
        });

        Chain memory chain = Chain({
            accounts: new Account[](1),
            assetRecoveryAddress: address(0xa30F2797Bf542ECe99290cf4E4C6546cc349B9A1),
            id: 1
        });
        chain.accounts[0] = account;

        Contact memory contact = Contact({name: "Test Name", contact: "test@mail.com"});

        BountyTerms memory bountyTerms = BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 100,
            retainable: true,
            identity: IdentityRequirements.Anonymous,
            diligenceRequirements: "none"
        });

        details = AgreementDetailsV1({
            protocolName: "testProtocol",
            chains: new Chain[](1),
            contactDetails: new Contact[](1),
            bountyTerms: bountyTerms,
            agreementURI: "ipfs://testHash"
        });
        details.chains[0] = chain;
        details.contactDetails[0] = contact;

        return details;
    }
}
