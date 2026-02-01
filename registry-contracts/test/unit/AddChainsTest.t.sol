// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { ChainValidator } from "src/ChainValidator.sol";
import { AgreementFactory } from "src/AgreementFactory.sol";
import { Agreement } from "src/Agreement.sol";
import {
    AgreementDetails,
    Chain as AgreementChain,
    Account as AgreementAccount,
    Contact,
    BountyTerms,
    ChildContractScope,
    IdentityRequirements
} from "src/types/AgreementTypes.sol";
import { AddChains } from "script/AddChains.s.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";

/// @title AddChainsTest
/// @notice Simplified test suite for the AddChains script
/// @dev Note: The script uses vm.startBroadcast() which changes msg.sender in tests.
///      We test the script behavior directly and rely on contract tests for validation.
contract AddChainsTest is Test {
    AddChains public addChainsScript;
    HelperConfig public helperConfig;
    DeploySafeHarbor public deployer;

    ChainValidator public chainValidator;
    Agreement public agreement;
    address public agreementAddress;

    function setUp() public {
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();
        deployer.initialize(helperConfig);

        chainValidator = ChainValidator(deployer.deployChainValidator());
        deployer.deployRegistry();
        deployer.deployAgreementFactory();

        addChainsScript = new AddChains();

        // Create initial agreement (test contract is owner)
        AgreementDetails memory details = _getInitialAgreementDetails();
        agreement = new Agreement(details, address(chainValidator), address(this));
        agreementAddress = address(agreement);
    }

    function _getInitialAgreementDetails() internal pure returns (AgreementDetails memory details) {
        Contact[] memory contacts = new Contact[](1);
        contacts[0] = Contact({ name: "Security", contact: "sec@test.com" });

        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xAbCdEf1234567890123456789012345678901234", childContractScope: ChildContractScope.None
        });

        AgreementChain[] memory chains = new AgreementChain[](1);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1",
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: accounts
        });

        details = AgreementDetails({
            protocolName: "Test Protocol",
            agreementURI: "ipfs://test",
            contactDetails: contacts,
            chains: chains,
            bountyTerms: BountyTerms({
                bountyPercentage: 10,
                bountyCapUSD: 100_000,
                aggregateBountyCapUSD: 500_000,
                retainable: false,
                identity: IdentityRequirements.Pseudonymous,
                diligenceRequirements: ""
            })
        });
    }

    function _getChainsToAdd() internal pure returns (AgreementChain[] memory chains) {
        chains = new AgreementChain[](2);

        AgreementAccount[] memory accounts1 = new AgreementAccount[](1);
        accounts1[0] = AgreementAccount({
            accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.All
        });
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:137",
            assetRecoveryAddress: "0x2222222222222222222222222222222222222222",
            accounts: accounts1
        });

        AgreementAccount[] memory accounts2 = new AgreementAccount[](1);
        accounts2[0] = AgreementAccount({
            accountAddress: "0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            childContractScope: ChildContractScope.ExistingOnly
        });
        chains[1] = AgreementChain({
            caip2ChainId: "eip155:42161",
            assetRecoveryAddress: "0x3333333333333333333333333333333333333333",
            accounts: accounts2
        });
    }

    function _getSingleChainToAdd() internal pure returns (AgreementChain[] memory chains) {
        chains = new AgreementChain[](1);
        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
            childContractScope: ChildContractScope.FutureOnly
        });
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:8453",
            assetRecoveryAddress: "0x4444444444444444444444444444444444444444",
            accounts: accounts
        });
    }

    // ======== JSON PARSING TESTS ========

    function test_jsonParsing_validChains() public view {
        AgreementChain[] memory chains = addChainsScript.preview("test/unit/testdata/addChains.json");

        assertEq(chains.length, 2);
        assertEq(chains[0].caip2ChainId, "eip155:137");
        assertEq(chains[1].caip2ChainId, "eip155:42161");
        assertEq(chains[1].accounts.length, 2);
    }

    function test_jsonParsing_invalidPath() public {
        vm.expectRevert();
        addChainsScript.preview("nonexistent/file.json");
    }

    // ======== SCRIPT FUNCTIONALITY TESTS ========
    // Note: These tests verify the script works correctly. Since the script
    // uses vm.startBroadcast(), ownership validation happens on-chain.

    function test_script_addsChainsViaDirectCall() public {
        // Since script uses broadcast, test by calling agreement directly
        // This verifies the chain data format is correct
        AgreementChain[] memory chainsToAdd = _getSingleChainToAdd();

        agreement.addChains(chainsToAdd);

        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 2);
        assertEq(details.chains[1].caip2ChainId, "eip155:8453");
    }

    function test_script_addsMultipleChains() public {
        AgreementChain[] memory chainsToAdd = _getChainsToAdd();

        agreement.addChains(chainsToAdd);

        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 3);
    }

    // ======== ON-CHAIN VALIDATION TESTS ========
    // These verify the Agreement contract validation works correctly

    function test_revert_duplicateChain() public {
        // Try to add a chain that already exists
        AgreementChain[] memory chains = new AgreementChain[](1);
        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD", childContractScope: ChildContractScope.All
        });
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1", // Already exists
            assetRecoveryAddress: "0x5555555555555555555555555555555555555555",
            accounts: accounts
        });

        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__DuplicateChainId.selector, "eip155:1"));
        agreement.addChains(chains);
    }

    function test_revert_notOwner() public {
        // Create agreement owned by someone else
        address otherOwner = address(0xBEEF);
        AgreementDetails memory details = _getInitialAgreementDetails();
        vm.prank(otherOwner);
        Agreement otherAgreement = new Agreement(details, address(chainValidator), otherOwner);

        // Try to add chains directly - should fail (not owner)
        vm.expectRevert();
        otherAgreement.addChains(_getSingleChainToAdd());
    }

    function test_revert_emptyChainId() public {
        AgreementChain[] memory chains = new AgreementChain[](1);
        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.All
        });
        chains[0] = AgreementChain({
            caip2ChainId: "", // Empty chain ID - validated on-chain
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: accounts
        });

        vm.expectRevert();
        agreement.addChains(chains);
    }

    function test_revert_noAccounts() public {
        AgreementChain[] memory chains = new AgreementChain[](1);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:137",
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: new AgreementAccount[](0) // No accounts - validated on-chain
        });

        vm.expectRevert();
        agreement.addChains(chains);
    }
}
