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
import "./DeployRegistryV2.s.sol";
import {logAgreementDetails} from "../../test/v2/mock.sol";

contract AdoptSafeHarborV2 is ScriptBase {
    using stdJson for string;

    // Update these addresses to match your deployed contracts
    address constant REGISTRY_ADDRESS = 0x1eaCD100B0546E433fbf4d773109cAD482c34686;
    address constant FACTORY_ADDRESS = 0x98D1594Ba4f2115f75392ac92A7e3C8A81C67Fed;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address owner = vm.envOr("AGREEMENT_OWNER", vm.addr(deployerPrivateKey));
        bool shouldAdoptToRegistry = vm.envOr("ADOPT_TO_REGISTRY", false);

        SafeHarborRegistryV2 registry = SafeHarborRegistryV2(REGISTRY_ADDRESS);
        AgreementFactoryV2 factory = AgreementFactoryV2(FACTORY_ADDRESS);

        string memory json = vm.readFile("agreementDetailsV2.json");

        adopt(deployerPrivateKey, registry, factory, json, owner, shouldAdoptToRegistry);
    }

    function adopt(
        uint256 deployerPrivateKey,
        SafeHarborRegistryV2 registry,
        AgreementFactoryV2 factory,
        string memory json,
        address owner,
        bool shouldAdoptToRegistry
    ) public {
        AgreementDetailsV2 memory details = parseAgreementDetails(json);
        logAgreementDetails(details);

        vm.startBroadcast(deployerPrivateKey);

        address agreementAddress = factory.create(details, address(registry), owner);
        console.log("Created agreement at:");
        console.logAddress(agreementAddress);

        if (shouldAdoptToRegistry) {
            registry.adoptSafeHarbor(agreementAddress);
        }

        vm.stopBroadcast();
    }

    // Helper function to parse the complete agreement details
    function parseAgreementDetails(string memory json) internal view returns (AgreementDetailsV2 memory) {
        return AgreementDetailsV2({
            protocolName: json.readString(".protocolName"),
            contactDetails: parseContacts(json),
            chains: parseChains(json),
            bountyTerms: parseBountyTerms(json),
            agreementURI: json.readString(".agreementURI")
        });
    }

    // Helper function to parse contacts array
    function parseContacts(string memory json) internal view returns (Contact[] memory) {
        uint256 contactCount = getArrayLength(json, ".contact", ".name");

        Contact[] memory contacts = new Contact[](contactCount);
        for (uint256 i = 0; i < contactCount; i++) {
            contacts[i] = Contact({
                name: json.readString(string.concat(".contact[", vm.toString(i), "].name")),
                contact: json.readString(string.concat(".contact[", vm.toString(i), "].contact"))
            });
        }
        return contacts;
    }

    // Helper function to parse bounty terms
    function parseBountyTerms(string memory json) internal pure returns (BountyTerms memory) {
        return BountyTerms({
            bountyPercentage: json.readUint(".bountyTerms.bountyPercentage"),
            bountyCapUSD: json.readUint(".bountyTerms.bountyCapUSD"),
            retainable: json.readBool(".bountyTerms.retainable"),
            identity: IdentityRequirements(uint8(json.readUint(".bountyTerms.identity"))),
            diligenceRequirements: json.readString(".bountyTerms.diligenceRequirements"),
            aggregateBountyCapUSD: json.readUint(".bountyTerms.aggregateBountyCapUSD")
        });
    }

    // Helper function to parse chains array
    function parseChains(string memory json) public view returns (ChainV2[] memory) {
        uint256 chainCount = getArrayLength(json, ".chains", ".id");

        ChainV2[] memory chains = new ChainV2[](chainCount);
        for (uint256 i = 0; i < chainCount; i++) {
            string memory chainIndex = vm.toString(i);
            chains[i] = ChainV2({
                caip2ChainId: json.readString(string.concat(".chains[", chainIndex, "].id")),
                assetRecoveryAddress: json.readString(string.concat(".chains[", chainIndex, "].assetRecoveryAddress")),
                accounts: parseAccounts(json, chainIndex)
            });
        }
        return chains;
    }

    // Helper function to parse accounts for a specific chain
    function parseAccounts(string memory json, string memory chainIndex) internal view returns (AccountV2[] memory) {
        uint256 accountCount =
            getArrayLength(json, string.concat(".chains[", chainIndex, "].accounts"), ".accountAddress");

        AccountV2[] memory accounts = new AccountV2[](accountCount);
        for (uint256 j = 0; j < accountCount; j++) {
            string memory accountIndex = vm.toString(j);
            accounts[j] = AccountV2({
                accountAddress: json.readString(
                    string.concat(".chains[", chainIndex, "].accounts[", accountIndex, "].accountAddress")
                ),
                childContractScope: ChildContractScope(
                    uint8(
                        json.readUint(
                            string.concat(".chains[", chainIndex, "].accounts[", accountIndex, "].childContractScope")
                        )
                    )
                )
            });
        }
        return accounts;
    }

    // Helper function to determine array length by checking if indices exist
    function getArrayLength(string memory json, string memory arrayPath, string memory testField)
        internal
        view
        returns (uint256)
    {
        uint256 count = 0;
        while (true) {
            string memory fullPath = string.concat(arrayPath, "[", vm.toString(count), "]", testField);
            if (!vm.keyExists(json, fullPath)) {
                break;
            }
            count++;
        }
        return count;
    }
}
