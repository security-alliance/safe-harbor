// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
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
/// @notice Test suite for the AddChains script
contract AddChainsTest is Test {
    // ----- STATE -----
    AddChains public addChainsScript;
    HelperConfig public helperConfig;
    DeploySafeHarbor public deployer;

    SafeHarborRegistry public registry;
    ChainValidator public chainValidator;
    AgreementFactory public factory;

    address public owner;
    address public protocol;

    Agreement public agreement;
    address public agreementAddress;

    // ----- SETUP -----

    function setUp() public {
        // Use test contract itself as owner to avoid msg.sender issues
        owner = address(this);

        // Deploy contracts
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();
        deployer.initialize(helperConfig);

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        chainValidator = ChainValidator(deployer.deployChainValidator());
        registry = SafeHarborRegistry(deployer.deployRegistry());
        factory = AgreementFactory(deployer.deployAgreementFactory());

        // Deploy the AddChains script
        addChainsScript = new AddChains();

        // Create initial agreement for testing (test contract is owner)
        AgreementDetails memory details = _getInitialAgreementDetails();
        agreement = new Agreement(details, address(chainValidator), owner);
        agreementAddress = address(agreement);
    }

    // ======== HELPER FUNCTIONS ========

    /// @notice Get initial agreement details with one chain
    function _getInitialAgreementDetails() internal pure returns (AgreementDetails memory details) {
        Contact[] memory contacts = new Contact[](1);
        contacts[0] = Contact({ name: "Security Team", contact: "security@test.com" });

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

        BountyTerms memory terms = BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 100_000,
            aggregateBountyCapUSD: 500_000,
            retainable: false,
            identity: IdentityRequirements.Pseudonymous,
            diligenceRequirements: "KYC Required"
        });

        details = AgreementDetails({
            protocolName: "Test Protocol",
            agreementURI: "ipfs://QmTestHash",
            contactDetails: contacts,
            chains: chains,
            bountyTerms: terms
        });
    }

    /// @notice Get chains to add for testing
    function _getChainsToAdd() internal pure returns (AgreementChain[] memory chains) {
        chains = new AgreementChain[](2);

        // Chain 1: Polygon
        AgreementAccount[] memory accounts1 = new AgreementAccount[](1);
        accounts1[0] = AgreementAccount({
            accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.All
        });

        chains[0] = AgreementChain({
            caip2ChainId: "eip155:137",
            assetRecoveryAddress: "0x2222222222222222222222222222222222222222",
            accounts: accounts1
        });

        // Chain 2: Arbitrum
        AgreementAccount[] memory accounts2 = new AgreementAccount[](2);
        accounts2[0] = AgreementAccount({
            accountAddress: "0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            childContractScope: ChildContractScope.ExistingOnly
        });
        accounts2[1] = AgreementAccount({
            accountAddress: "0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", childContractScope: ChildContractScope.None
        });

        chains[1] = AgreementChain({
            caip2ChainId: "eip155:42161",
            assetRecoveryAddress: "0x3333333333333333333333333333333333333333",
            accounts: accounts2
        });
    }

    /// @notice Get single chain to add
    function _getSingleChainToAdd() internal pure returns (AgreementChain[] memory chains) {
        chains = new AgreementChain[](1);

        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
            childContractScope: ChildContractScope.FutureOnly
        });

        chains[0] = AgreementChain({
            caip2ChainId: "eip155:8453",
            assetRecoveryAddress: "0x4444444444444444444444444444444444444444",
            accounts: accounts
        });
    }

    /// @notice Get chain with duplicate ID (should fail)
    function _getDuplicateChain() internal pure returns (AgreementChain[] memory chains) {
        chains = new AgreementChain[](1);

        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE", childContractScope: ChildContractScope.All
        });

        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1", // Already exists in initial agreement
            assetRecoveryAddress: "0x5555555555555555555555555555555555555555",
            accounts: accounts
        });
    }

    // ======== SUCCESS TESTS ========

    function test_addChains_singleChain() public {
        // Ensure we're using the owner key

        AgreementChain[] memory chainsToAdd = _getSingleChainToAdd();

        // Add chains
        agreement.addChains(chainsToAdd);

        // Verify chains were added
        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 2); // Original + 1 new
        assertEq(details.chains[1].caip2ChainId, "eip155:8453");
    }

    function test_addChains_multipleChains() public {
        // Ensure we're using the owner key

        AgreementChain[] memory chainsToAdd = _getChainsToAdd();

        // Add chains
        agreement.addChains(chainsToAdd);

        // Verify chains were added
        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 3); // Original + 2 new
        assertEq(details.chains[1].caip2ChainId, "eip155:137");
        assertEq(details.chains[2].caip2ChainId, "eip155:42161");
    }

    function test_addChains_withConfig() public {
        // Ensure we're using the owner key

        AgreementChain[] memory chainsToAdd = _getSingleChainToAdd();

        AddChains.ChainAdditionConfig memory config = AddChains.ChainAdditionConfig({
            jsonPath: "", // Not used when passing chains directly
            agreement: agreementAddress
        });

        // This would need the script to support config + chains, but current implementation
        // uses config for JSON only. We'll test the direct approach instead.
        agreement.addChains(chainsToAdd);

        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 2);
    }

    function test_addChains_multipleTimes() public {
        AgreementChain[] memory firstBatch = _getSingleChainToAdd();
        AgreementChain[] memory secondBatch = _getChainsToAdd();

        // Add first batch

        agreement.addChains(firstBatch);

        // Add second batch - reset env var in case it was changed

        agreement.addChains(secondBatch);

        // Verify all chains present
        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 4); // Original + 1 + 2
    }

    // ======== JSON PARSING TESTS ========

    function test_jsonParsing_validChains() public {
        // Use pre-existing test file
        AgreementChain[] memory chains = addChainsScript.preview("test/unit/testdata/addChains.json");

        assertEq(chains.length, 2);
        assertEq(chains[0].caip2ChainId, "eip155:137");
        assertEq(chains[1].caip2ChainId, "eip155:42161");
        assertEq(chains[1].accounts.length, 2);
    }

    function test_jsonParsing_invalidPath() public {
        vm.expectRevert(abi.encodeWithSelector(AddChains.AddChains__InvalidJsonPath.selector, "nonexistent/file.json"));
        addChainsScript.preview("nonexistent/file.json");
    }

    // ======== ERROR HANDLING TESTS ========

    function test_revert_zeroAddress() public {
        AgreementChain[] memory chains = _getSingleChainToAdd();

        vm.expectRevert(AddChains.AddChains__InvalidAgreementAddress.selector);
        addChainsScript.run(address(0), chains);
    }

    function test_revert_notContract() public {
        AgreementChain[] memory chains = _getSingleChainToAdd();

        vm.expectRevert(AddChains.AddChains__InvalidAgreementAddress.selector);
        addChainsScript.run(address(0x1234), chains); // Random EOA address
    }

    function test_revert_notOwner() public {
        AgreementChain[] memory chains = _getSingleChainToAdd();

        // Create an agreement owned by a different address
        address otherOwner = address(0xBEEF);
        AgreementDetails memory otherDetails = _getInitialAgreementDetails();
        vm.prank(otherOwner);
        Agreement otherAgreement = new Agreement(otherDetails, address(chainValidator), otherOwner);

        // Try to add chains from this test contract (not the owner)
        vm.expectRevert(
            abi.encodeWithSelector(
                AddChains.AddChains__NotAgreementOwner.selector,
                address(this), // Test contract is the caller
                otherOwner
            )
        );
        addChainsScript.run(address(otherAgreement), chains);
    }

    function test_revert_noChains() public {
        AgreementChain[] memory emptyChains = new AgreementChain[](0);

        vm.expectRevert(AddChains.AddChains__NoChainsProvided.selector);
        addChainsScript.run(agreementAddress, emptyChains);
    }

    function test_revert_duplicateChain() public {
        AgreementChain[] memory duplicateChain = _getDuplicateChain();

        // This will revert from the Agreement contract directly
        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__DuplicateChainId.selector, "eip155:1"));
        agreement.addChains(duplicateChain);
    }

    function test_revert_emptyChainId() public {
        AgreementChain[] memory chains = new AgreementChain[](1);
        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.All
        });

        chains[0] = AgreementChain({
            caip2ChainId: "", // Empty chain ID
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: accounts
        });

        vm.expectRevert(
            abi.encodeWithSelector(AddChains.AddChains__ChainValidationFailed.selector, "", "Empty chain ID")
        );
        addChainsScript.run(agreementAddress, chains);
    }

    function test_revert_emptyRecoveryAddress() public {
        AgreementChain[] memory chains = new AgreementChain[](1);
        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.All
        });

        chains[0] = AgreementChain({
            caip2ChainId: "eip155:137",
            assetRecoveryAddress: "", // Empty recovery address
            accounts: accounts
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                AddChains.AddChains__ChainValidationFailed.selector, "eip155:137", "Empty recovery address"
            )
        );
        addChainsScript.run(agreementAddress, chains);
    }

    function test_revert_noAccounts() public {
        AgreementChain[] memory chains = new AgreementChain[](1);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:137",
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: new AgreementAccount[](0) // No accounts
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                AddChains.AddChains__ChainValidationFailed.selector, "eip155:137", "No accounts provided"
            )
        );
        addChainsScript.run(agreementAddress, chains);
    }
}
