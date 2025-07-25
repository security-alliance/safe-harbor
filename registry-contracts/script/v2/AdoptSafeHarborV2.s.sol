// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementFactoryV2.sol";
import {
    AgreementDetailsV2,
    Chain as V2Chain,
    Account as V2Account,
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
        // Parse the JSON file field by field
        AgreementDetailsV2 memory details = parseAgreementDetails(json);

        // Begin broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Create agreement using factory
        address agreementAddress = factory.create(details, address(registry), deployer);
        console.log("Created agreement at:");
        console.logAddress(agreementAddress);

        // Adopt the agreement in the registry
        registry.adoptSafeHarbor(agreementAddress);
        console.log("Successfully adopted Safe Harbor V2 agreement");

        // End broadcast
        vm.stopBroadcast();
    }

    // Parse the JSON file field by field using stdJson
    function parseAgreementDetails(string memory json) internal pure returns (AgreementDetailsV2 memory) {
        return AgreementDetailsV2({
            protocolName: json.readString(".protocolName"),
            contactDetails: parseContacts(json),
            chains: parseChains(json),
            bountyTerms: parseBountyTerms(json),
            agreementURI: json.readString(".agreementURI")
        });
    }

    // Parse contact details
    function parseContacts(string memory json) internal pure returns (Contact[] memory) {
        // Use a try-catch approach to determine array length
        uint256 contactCount = 0;
        bool continueLoop = true;

        while (continueLoop) {
            try vm.parseJsonString(json, string.concat(".contact[", vm.toString(contactCount), "].name")) returns (
                string memory
            ) {
                contactCount++;
            } catch {
                continueLoop = false;
            }
        }

        Contact[] memory contacts = new Contact[](contactCount);
        for (uint256 i = 0; i < contactCount; i++) {
            string memory indexPath = string.concat(".contact[", vm.toString(i), "]");
            contacts[i] = Contact({
                name: json.readString(string.concat(indexPath, ".name")),
                contact: json.readString(string.concat(indexPath, ".contact"))
            });
        }
        return contacts;
    }

    // Parse bounty terms
    function parseBountyTerms(string memory json) internal pure returns (BountyTerms memory) {
        return BountyTerms({
            bountyPercentage: json.readUint(".bountyTerms.bountyPercentage"),
            bountyCapUSD: json.readUint(".bountyTerms.bountyCapUSD"),
            retainable: json.readBool(".bountyTerms.retainable"),
            identity: IdentityRequirements(json.readUint(".bountyTerms.identity")),
            diligenceRequirements: json.readString(".bountyTerms.diligenceRequirements"),
            aggregateBountyCapUSD: json.readUint(".bountyTerms.aggregateBountyCapUSD")
        });
    }

    // Parse chains
    function parseChains(string memory json) internal pure returns (V2Chain[] memory) {
        // Use a try-catch approach to determine array length
        uint256 chainCount = 0;
        bool continueLoop = true;

        while (continueLoop) {
            try vm.parseJsonString(json, string.concat(".chains[", vm.toString(chainCount), "].caip2ChainId")) returns (
                string memory
            ) {
                chainCount++;
            } catch {
                continueLoop = false;
            }
        }

        V2Chain[] memory chains = new V2Chain[](chainCount);
        for (uint256 i = 0; i < chainCount; i++) {
            string memory chainPath = string.concat(".chains[", vm.toString(i), "]");
            chains[i] = V2Chain({
                accounts: parseAccountsForChainIndex(json, i),
                assetRecoveryAddress: json.readString(string.concat(chainPath, ".assetRecoveryAddress")),
                caip2ChainId: json.readString(string.concat(chainPath, ".caip2ChainId"))
            });
        }
        return chains;
    }

    // Parse accounts for a specific chain by index
    function parseAccountsForChainIndex(string memory json, uint256 chainIndex)
        internal
        pure
        returns (V2Account[] memory)
    {
        string memory accountsPath = string.concat(".chains[", vm.toString(chainIndex), "].accounts");

        // Use a try-catch approach to determine array length
        uint256 accountCount = 0;
        bool continueLoop = true;

        while (continueLoop) {
            try vm.parseJsonString(
                json, string.concat(accountsPath, "[", vm.toString(accountCount), "].accountAddress")
            ) returns (string memory) {
                accountCount++;
            } catch {
                continueLoop = false;
            }
        }

        V2Account[] memory accounts = new V2Account[](accountCount);
        for (uint256 i = 0; i < accountCount; i++) {
            string memory accountPath = string.concat(accountsPath, "[", vm.toString(i), "]");
            accounts[i] = V2Account({
                accountAddress: json.readString(string.concat(accountPath, ".accountAddress")),
                childContractScope: ChildContractScope(json.readUint(string.concat(accountPath, ".childContractScope")))
            });
        }
        return accounts;
    }
}
