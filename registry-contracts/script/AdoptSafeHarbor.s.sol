// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {StdUtils} from "forge-std/StdUtils.sol";
import {ScriptBase} from "forge-std/Base.sol";
import "../src/SafeHarborRegistry.sol";

contract AdoptSafeHarbor is StdUtils, ScriptBase {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        Account memory proxyFactory = Account({
            accountAddress: 0xaB45c5A4B0c941a2F231C04C3f49182e1A254052,
            childContractScope: ChildContractScope.All,
            signature: new bytes(0)
        });
        Account memory safeFactory = Account({
            accountAddress: 0xaacFeEa03eb1561C4e67d661e40682Bd20E3541b,
            childContractScope: ChildContractScope.All,
            signature: new bytes(0)
        });
        Account memory conditionalTokens = Account({
            accountAddress: 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory ctfExchange = Account({
            accountAddress: 0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory negRiskAdapter = Account({
            accountAddress: 0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory negRiskOperator = Account({
            accountAddress: 0x71523d0f655B41E805Cec45b17163f528B59B820,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory negRiskWrappedCollateral = Account({
            accountAddress: 0x3A3BD7bb9528E159577F7C2e685CC81A765002E2,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory negRiskCtfExchange = Account({
            accountAddress: 0xC5d563A36AE78145C45a50134d48A1215220f80a,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory negRiskFeeModule = Account({
            accountAddress: 0x78769D50Be1763ed1CA0D5E878D93f05aabff29e,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory negRiskUmaCtfAdapter = Account({
            accountAddress: 0x2F5e3684cb1F318ec51b00Edba38d79Ac2c0aA9d,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory umaCtfAdapter = Account({
            accountAddress: 0x6A9D222616C90FcA5754cd1333cFD9b7fb6a4F74,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });
        Account memory feeModule = Account({
            accountAddress: 0x56C79347e95530c01A2FC76E732f9566dA16E113,
            childContractScope: ChildContractScope.None,
            signature: new bytes(0)
        });

        Chain memory chain = Chain({
            accounts: new Account[](12),
            assetRecoveryAddress: address(
                0x3dcE0a29139A851Da1dFCa56Af8e8a6440b4D952
            ),
            id: 137
        });
        chain.accounts[0] = proxyFactory;
        chain.accounts[1] = safeFactory;
        chain.accounts[2] = conditionalTokens;
        chain.accounts[3] = ctfExchange;
        chain.accounts[4] = negRiskAdapter;
        chain.accounts[5] = negRiskOperator;
        chain.accounts[6] = negRiskWrappedCollateral;
        chain.accounts[7] = negRiskCtfExchange;
        chain.accounts[8] = negRiskFeeModule;
        chain.accounts[9] = negRiskUmaCtfAdapter;
        chain.accounts[10] = umaCtfAdapter;
        chain.accounts[11] = feeModule;

        BountyTerms memory bountyTerms = BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 100,
            retainable: false,
            identity: IdentityRequirements.Anonymous,
            diligenceRequirements: "N/A"
        });

        Contact memory contact = Contact({
            name: "Mike Shrieve",
            contact: "mike@polymarket.com"
        });

        AgreementDetailsV1 memory mockDetails = AgreementDetailsV1({
            protocolName: "Polymarket",
            chains: new Chain[](1),
            contactDetails: new Contact[](1),
            bountyTerms: bountyTerms,
            agreementURI: "https://bafybeiakxvysdvsvupqcibkpifugzwcnllzt2udjk3l4yhcix7dqxxqyp4.ipfs.w3s.link/agreement.pdf"
        });
        mockDetails.chains[0] = chain;
        mockDetails.contactDetails[0] = contact;

        vm.startBroadcast(deployerPrivateKey);

        SafeHarborRegistry factory = SafeHarborRegistry(
            0x272b19056d9fC77C8BD0998f3845fbbeCC035FeD
        );

        factory.adoptSafeHarbor(mockDetails);

        vm.stopBroadcast();
    }
}
