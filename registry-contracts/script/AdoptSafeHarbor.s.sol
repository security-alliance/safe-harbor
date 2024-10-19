// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {stdJson} from "forge-std/StdJson.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../src/SafeHarborRegistry.sol";

contract AdoptSafeHarbor is ScriptBase {
    using stdJson for string;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        SafeHarborRegistry registry = SafeHarborRegistry(0x8f72fcf695523A6FC7DD97EafDd7A083c386b7b6);
        string memory json = vm.readFile("agreementDetails.json");

        adopt(deployerPrivateKey, registry, json);
    }

    function adopt(uint256 deployerPrivateKey, SafeHarborRegistry registry, string memory json) public {
        // Read and parse the JSON file
        bytes memory data = json.parseRaw(".");

        // Decode into the intermediary struct
        agreementDetailsV1JSON memory jsonDetails = abi.decode(data, (agreementDetailsV1JSON));
        AgreementDetailsV1 memory details = mapAgreementDetails(jsonDetails);

        // Begin broadcast
        vm.startBroadcast(deployerPrivateKey);

        registry.adoptSafeHarbor(details);

        // End broadcast
        vm.stopBroadcast();
    }

    // Helper function to map agreementDetailsV1JSON to AgreementDetailsV1
    function mapAgreementDetails(agreementDetailsV1JSON memory jsonDetails)
        internal
        pure
        returns (AgreementDetailsV1 memory)
    {
        return AgreementDetailsV1({
            protocolName: jsonDetails.protocolName,
            contactDetails: mapContacts(jsonDetails.contact),
            chains: mapChains(jsonDetails.chains),
            bountyTerms: mapBountyTerms(jsonDetails.bountyTerms),
            agreementURI: jsonDetails.agreementURI
        });
    }

    // Define intermediary structs with fields in alphabetical order
    // and enums replaced with uint8 for decoding
    struct agreementDetailsV1JSON {
        string agreementURI;
        bountyTermsJSON bountyTerms;
        chainJSON[] chains;
        contactJSON[] contact;
        string protocolName;
    }

    struct bountyTermsJSON {
        uint256 bountyCapUSD;
        uint256 bountyPercentage;
        string diligenceRequirements;
        uint8 identity; // enum replaced with uint8
        bool retainable;
    }

    struct chainJSON {
        accountJSON[] accounts;
        address assetRecoveryAddress;
        uint256 id;
    }

    struct accountJSON {
        address accountAddress;
        uint8 childContractScope; // enum replaced with uint8
        bytes signature;
    }

    struct contactJSON {
        string contact;
        string name;
    }

    // Helper function to map contactJSON[] to Contact[]
    function mapContacts(contactJSON[] memory jsonContacts) internal pure returns (Contact[] memory) {
        uint256 count = jsonContacts.length;
        Contact[] memory contacts = new Contact[](count);
        for (uint256 i = 0; i < count; i++) {
            contacts[i] = Contact({contact: jsonContacts[i].contact, name: jsonContacts[i].name});
        }
        return contacts;
    }

    // Helper function to map bountyTermsJSON to BountyTerms
    function mapBountyTerms(bountyTermsJSON memory jsonBountyTerms) internal pure returns (BountyTerms memory) {
        return BountyTerms({
            bountyPercentage: jsonBountyTerms.bountyPercentage,
            bountyCapUSD: jsonBountyTerms.bountyCapUSD,
            retainable: jsonBountyTerms.retainable,
            identity: IdentityRequirements(jsonBountyTerms.identity),
            diligenceRequirements: jsonBountyTerms.diligenceRequirements
        });
    }

    // Helper function to map chainJSON[] to Chain[]
    function mapChains(chainJSON[] memory jsonChains) internal pure returns (Chain[] memory) {
        uint256 count = jsonChains.length;
        Chain[] memory chains = new Chain[](count);
        for (uint256 i = 0; i < count; i++) {
            chains[i] = Chain({
                accounts: mapAccounts(jsonChains[i].accounts),
                assetRecoveryAddress: jsonChains[i].assetRecoveryAddress,
                id: jsonChains[i].id
            });
        }
        return chains;
    }

    // Helper function to map accountJSON[] to Account[]
    function mapAccounts(accountJSON[] memory jsonAccounts) internal pure returns (Account[] memory) {
        uint256 count = jsonAccounts.length;
        Account[] memory accounts = new Account[](count);
        for (uint256 i = 0; i < count; i++) {
            accounts[i] = Account({
                accountAddress: jsonAccounts[i].accountAddress,
                childContractScope: ChildContractScope(jsonAccounts[i].childContractScope),
                signature: jsonAccounts[i].signature
            });
        }
        return accounts;
    }
}
