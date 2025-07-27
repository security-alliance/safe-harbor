// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementFactoryV2.sol";
import {
    AgreementDetailsV2,
    Chain as ChainV2,
    Account as AccountV2,
    Contact,
    BountyTerms,
    ChildContractScope,
    IdentityRequirements
} from "../../src/v2/AgreementDetailsV2.sol";

contract AdoptSafeHarborV2 is ScriptBase {
    using stdJson for string;

    // Update these addresses to match your deployed contracts
    address constant REGISTRY_ADDRESS = 0xB4aaAfD63b78971BB0D3561d0577133b965A1704;
    address constant FACTORY_ADDRESS = 0xB8bf65D4D3CBDE4A082B991794DEa97398cD9f76;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);
        AgreementFactoryV2 factory = AgreementFactoryV2(FACTORY_ADDRESS);

        string memory json = vm.readFile("agreementDetailsV2.json");

        adopt(deployerPrivateKey, registry, factory, json);
    }

    function adopt(
        uint256 deployerPrivateKey,
        SafeHarborRegistryV2 registry,
        AgreementFactoryV2 factory,
        string memory json
    ) public {
        address deployer = vm.addr(deployerPrivateKey);

        // Parses JSON
        bytes memory data = json.parseRaw(".");
        agreementDetailsV2JSON memory jsonDetails = abi.decode(data, (agreementDetailsV2JSON));
        AgreementDetailsV2 memory details = mapAgreementDetails(jsonDetails);

        vm.startBroadcast(deployerPrivateKey);

        // Create agreement using factory
        address agreementAddress = factory.create(details, address(registry), deployer);
        console.log("Created agreement at:");
        console.logAddress(agreementAddress);

        // Adopt the agreement in the registry
        registry.adoptSafeHarbor(agreementAddress);
        console.log("Successfully adopted Safe Harbor V2 agreement");

        vm.stopBroadcast();
    }

    // Helper function to map agreementDetailsV1JSON to AgreementDetailsV1
    function mapAgreementDetails(agreementDetailsV2JSON memory jsonDetails)
        internal
        pure
        returns (AgreementDetailsV2 memory)
    {
        return AgreementDetailsV2({
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
        uint256 aggregateBountyCapUSD;
        uint256 bountyCapUSD;
        uint256 bountyPercentage;
        string diligenceRequirements;
        uint8 identity; // enum replaced with uint8
        bool retainable;
    }

    struct chainJSON {
        accountJSON[] accounts;
        string assetRecoveryAddress;
        string caip2ChainId;
    }

    struct accountJSON {
        string accountAddress;
        uint8 childContractScope; // enum replaced with uint8
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
            diligenceRequirements: jsonBountyTerms.diligenceRequirements,
            aggregateBountyCapUSD: jsonBountyTerms.aggregateBountyCapUSD
        });
    }

    // Helper function to map chainJSON[] to Chain[]
    function mapChains(chainJSON[] memory jsonChains) internal pure returns (ChainV2[] memory) {
        uint256 count = jsonChains.length;
        ChainV2[] memory chains = new ChainV2[](count);
        for (uint256 i = 0; i < count; i++) {
            chains[i] = ChainV2({
                accounts: mapAccounts(jsonChains[i].accounts),
                assetRecoveryAddress: jsonChains[i].assetRecoveryAddress,
                caip2ChainId: jsonChains[i].caip2ChainId
            });
        }
        return chains;
    }

    // Helper function to map accountJSON[] to Account[]
    function mapAccounts(accountJSON[] memory jsonAccounts) internal pure returns (AccountV2[] memory) {
        uint256 count = jsonAccounts.length;
        AccountV2[] memory accounts = new AccountV2[](count);
        for (uint256 i = 0; i < count; i++) {
            accounts[i] = AccountV2({
                accountAddress: jsonAccounts[i].accountAddress,
                childContractScope: ChildContractScope(jsonAccounts[i].childContractScope)
            });
        }
        return accounts;
    }
}
