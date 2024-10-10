// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {stdJson} from "forge-std/StdJson.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../src/SafeHarborRegistry.sol";

contract AdoptSafeHarbor is ScriptBase {
    using stdJson for string;

    // Define intermediary structs with fields in alphabetical order
    // and enums replaced with uint8 for decoding
    struct AgreementDetailsV1Json {
        string agreementURI;
        BountyTermsJson bountyTerms;
        ChainJson[] chains;
        ContactJson[] contactDetails;
        string protocolName;
    }

    struct BountyTermsJson {
        uint256 bountyCapUSD;
        uint256 bountyPercentage;
        string diligenceRequirements;
        uint8 identity; // enum replaced with uint8
        bool retainable;
    }

    struct ChainJson {
        AccountJson[] accounts;
        address assetRecoveryAddress;
        uint256 id;
    }

    struct AccountJson {
        address accountAddress;
        uint8 childContractScope; // enum replaced with uint8
        bytes signature;
    }

    struct ContactJson {
        string contact;
        string name;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Read and parse the JSON file
        string memory json = vm.readFile("agreementDetails.json");
        bytes memory data = json.parseRaw(".");

        // Decode into the intermediary struct
        AgreementDetailsV1Json memory jsonDetails = abi.decode(
            data,
            (AgreementDetailsV1Json)
        );

        // Map intermediary structs to original structs
        // Map ContactJson[] to Contact[]
        uint256 contactCount = jsonDetails.contactDetails.length;
        Contact[] memory contactDetails = new Contact[](contactCount);
        for (uint256 i = 0; i < contactCount; i++) {
            ContactJson memory cj = jsonDetails.contactDetails[i];
            contactDetails[i] = Contact({name: cj.name, contact: cj.contact});
        }

        // Map BountyTermsJson to BountyTerms
        BountyTerms memory bountyTerms = BountyTerms({
            bountyPercentage: jsonDetails.bountyTerms.bountyPercentage,
            bountyCapUSD: jsonDetails.bountyTerms.bountyCapUSD,
            retainable: jsonDetails.bountyTerms.retainable,
            identity: IdentityRequirements(jsonDetails.bountyTerms.identity),
            diligenceRequirements: jsonDetails.bountyTerms.diligenceRequirements
        });

        // Map ChainJson[] to Chain[]
        uint256 chainCount = jsonDetails.chains.length;
        Chain[] memory chains = new Chain[](chainCount);
        for (uint256 i = 0; i < chainCount; i++) {
            ChainJson memory cj = jsonDetails.chains[i];

            // Map AccountJson[] to Account[]
            uint256 accountCount = cj.accounts.length;
            Account[] memory accounts = new Account[](accountCount);
            for (uint256 j = 0; j < accountCount; j++) {
                AccountJson memory aj = cj.accounts[j];
                accounts[j] = Account({
                    accountAddress: aj.accountAddress,
                    childContractScope: ChildContractScope(
                        aj.childContractScope
                    ),
                    signature: aj.signature
                });
            }

            chains[i] = Chain({
                accounts: accounts,
                assetRecoveryAddress: cj.assetRecoveryAddress,
                id: cj.id
            });
        }

        // Construct the AgreementDetailsV1 struct
        AgreementDetailsV1 memory details = AgreementDetailsV1({
            protocolName: jsonDetails.protocolName,
            contactDetails: contactDetails,
            chains: chains,
            bountyTerms: bountyTerms,
            agreementURI: jsonDetails.agreementURI
        });

        // Begin broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Instantiate the SafeHarborRegistry contract
        SafeHarborRegistry factory = SafeHarborRegistry(
            0x272b19056d9fC77C8BD0998f3845fbbeCC035FeD
        );

        // Call the adoptSafeHarbor function with the details
        factory.adoptSafeHarbor(details);

        // End broadcast
        vm.stopBroadcast();
    }
}
