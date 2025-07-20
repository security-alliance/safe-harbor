// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementFactoryV2.sol";
import {AgreementDetailsV2, Chain as V2Chain, Account as V2Account, Contact, BountyTerms, ChildContractScope, IdentityRequirements} from "../../src/v2/AgreementDetailsV2.sol";

contract AdoptSafeHarborV2 is ScriptBase {
    using stdJson for string;

    // Update these addresses to match your deployed contracts
    address constant REGISTRY_ADDRESS =
        0xc8C53c0dd6830e15AF3263D718203e1B534C8Abe;
    address constant FACTORY_ADDRESS =
        0x8b466A706FbF1381fAf24a196C1e86928972B228;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);
        AgreementFactoryV2 factory = AgreementFactoryV2(FACTORY_ADDRESS);

        string memory json = vm.readFile("agreementDetailsV2.json");

        adopt(deployerPrivateKey, deployer, registry, factory, json);
    }

    function adopt(
        uint256 deployerPrivateKey,
        address deployer,
        SafeHarborRegistryV2 registry,
        AgreementFactoryV2 factory,
        string memory json
    ) public {
        // Read and parse the JSON file
        bytes memory data = json.parseRaw(".");

        // Decode into the intermediary struct
        agreementDetailsV2JSON memory jsonDetails = abi.decode(
            data,
            (agreementDetailsV2JSON)
        );
        AgreementDetailsV2 memory details = mapAgreementDetails(jsonDetails);

        // Begin broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Create agreement using factory
        address agreementAddress = factory.create(
            details,
            address(registry),
            deployer
        );
        console.log("Created agreement at:");
        console.logAddress(agreementAddress);

        // Adopt the agreement in the registry
        registry.adoptSafeHarbor(agreementAddress);
        console.log("Successfully adopted Safe Harbor V2 agreement");

        // End broadcast
        vm.stopBroadcast();
    }

    // Helper function to map agreementDetailsV2JSON to AgreementDetailsV2
    function mapAgreementDetails(
        agreementDetailsV2JSON memory jsonDetails
    ) internal pure returns (AgreementDetailsV2 memory) {
        return
            AgreementDetailsV2({
                protocolName: jsonDetails.protocolName,
                contactDetails: mapContacts(jsonDetails.contact),
                chains: mapChains(jsonDetails.chains),
                bountyTerms: mapBountyTerms(jsonDetails.bountyTerms),
                agreementURI: jsonDetails.agreementURI
            });
    }

    // Define intermediary structs with fields in alphabetical order
    // and enums replaced with uint8 for decoding
    struct agreementDetailsV2JSON {
        string agreementURI;
        bountyTermsJSON bountyTerms;
        chainJSON[] chains;
        contactJSON[] contact;
        string protocolName;
    }

    struct bountyTermsJSON {
        uint256 aggregateBountyCapUSD; // New in V2
        uint256 bountyCapUSD;
        uint256 bountyPercentage;
        string diligenceRequirements;
        uint8 identity; // enum replaced with uint8
        bool retainable;
    }

    struct chainJSON {
        accountJSON[] accounts;
        string assetRecoveryAddress; // Changed to string in V2
        string caip2ChainId; // Changed from id to caip2ChainId in V2
    }

    struct accountJSON {
        string accountAddress; // Changed to string in V2
        uint8 childContractScope; // enum replaced with uint8
        // Note: signature field removed in V2
    }

    struct contactJSON {
        string contact;
        string name;
    }

    // Helper function to map contactJSON[] to Contact[]
    function mapContacts(
        contactJSON[] memory jsonContacts
    ) internal pure returns (Contact[] memory) {
        uint256 count = jsonContacts.length;
        Contact[] memory contacts = new Contact[](count);
        for (uint256 i = 0; i < count; i++) {
            contacts[i] = Contact({
                contact: jsonContacts[i].contact,
                name: jsonContacts[i].name
            });
        }
        return contacts;
    }

    // Helper function to map bountyTermsJSON to BountyTerms
    function mapBountyTerms(
        bountyTermsJSON memory jsonBountyTerms
    ) internal pure returns (BountyTerms memory) {
        return
            BountyTerms({
                bountyPercentage: jsonBountyTerms.bountyPercentage,
                bountyCapUSD: jsonBountyTerms.bountyCapUSD,
                retainable: jsonBountyTerms.retainable,
                identity: IdentityRequirements(jsonBountyTerms.identity),
                diligenceRequirements: jsonBountyTerms.diligenceRequirements,
                aggregateBountyCapUSD: jsonBountyTerms.aggregateBountyCapUSD // New in V2
            });
    }

    // Helper function to map chainJSON[] to V2Chain[]
    function mapChains(
        chainJSON[] memory jsonChains
    ) internal pure returns (V2Chain[] memory) {
        uint256 count = jsonChains.length;
        V2Chain[] memory chains = new V2Chain[](count);
        for (uint256 i = 0; i < count; i++) {
            chains[i] = V2Chain({
                accounts: mapAccounts(jsonChains[i].accounts),
                assetRecoveryAddress: jsonChains[i].assetRecoveryAddress, // Now a string
                caip2ChainId: jsonChains[i].caip2ChainId // Now using CAIP-2 format
            });
        }
        return chains;
    }

    // Helper function to map accountJSON[] to V2Account[]
    function mapAccounts(
        accountJSON[] memory jsonAccounts
    ) internal pure returns (V2Account[] memory) {
        uint256 count = jsonAccounts.length;
        V2Account[] memory accounts = new V2Account[](count);
        for (uint256 i = 0; i < count; i++) {
            accounts[i] = V2Account({
                accountAddress: jsonAccounts[i].accountAddress, // Now a string
                childContractScope: ChildContractScope(
                    jsonAccounts[i].childContractScope
                )
            });
            // Note: signature field removed in V2
        }
        return accounts;
    }
}
