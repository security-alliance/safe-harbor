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
import { AdoptSafeHarbor } from "script/AdoptSafeHarbor.s.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";

/// @title AdoptSafeHarborTest
/// @notice Simplified test suite for the AdoptSafeHarbor script
/// @dev Tests JSON parsing and script flow. Validation happens on-chain.
contract AdoptSafeHarborTest is Test {
    AdoptSafeHarbor public adoptionScript;
    HelperConfig public helperConfig;
    DeploySafeHarbor public deployer;

    SafeHarborRegistry public registry;
    ChainValidator public chainValidator;
    AgreementFactory public factory;

    function setUp() public {
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();
        deployer.initialize(helperConfig);

        chainValidator = ChainValidator(deployer.deployChainValidator());
        registry = SafeHarborRegistry(deployer.deployRegistry());
        factory = AgreementFactory(deployer.deployAgreementFactory());

        adoptionScript = new AdoptSafeHarbor();
    }

    function _getValidAgreementDetails() internal pure returns (AgreementDetails memory details) {
        Contact[] memory contacts = new Contact[](1);
        contacts[0] = Contact({ name: "Security", contact: "sec@test.com" });

        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] = AgreementAccount({
            accountAddress: "0xAbCdEf1234567890123456789012345678901234",
            childContractScope: ChildContractScope.None
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

    function _getDefaultConfig() internal view returns (AdoptSafeHarbor.AdoptionConfig memory) {
        return AdoptSafeHarbor.AdoptionConfig({
            jsonPath: "",
            factory: address(factory),
            registry: address(registry),
            chainValidator: address(chainValidator),
            shouldAdoptToRegistry: false,
            owner: address(0), // Use msg.sender
            salt: bytes32(0)
        });
    }

    // ======== JSON PARSING TESTS ========

    function test_jsonParsing_validAgreement() public view {
        AgreementDetails memory details = adoptionScript.preview("test/unit/testdata/agreement.json");

        assertEq(details.protocolName, "Env Test");
        assertEq(details.agreementURI, "ipfs://test");
        assertEq(details.contactDetails.length, 1);
        assertEq(details.chains.length, 1);
        assertEq(details.chains[0].caip2ChainId, "eip155:1");
    }

    function test_jsonParsing_invalidJsonPath() public {
        vm.expectRevert();
        adoptionScript.preview("nonexistent/file.json");
    }

    // ======== AGREEMENT CREATION TESTS ========
    // Note: These test via direct factory calls since script uses broadcast

    function test_createAgreement_only() public {
        AgreementDetails memory details = _getValidAgreementDetails();

        address agreementAddress = factory.create(details, address(chainValidator), address(this), bytes32(0));

        Agreement agreement = Agreement(agreementAddress);
        AgreementDetails memory stored = agreement.getDetails();
        assertEq(stored.protocolName, "Test Protocol");
    }

    function test_createAgreement_withCustomOwner() public {
        address customOwner = address(0x1234);
        AgreementDetails memory details = _getValidAgreementDetails();

        address agreementAddress = factory.create(details, address(chainValidator), customOwner, bytes32(0));

        Agreement agreement = Agreement(agreementAddress);
        assertEq(agreement.owner(), customOwner);
    }

    function test_createAgreement_withCustomSalt() public {
        bytes32 customSalt = keccak256("custom");
        AgreementDetails memory details = _getValidAgreementDetails();

        address predicted = factory.computeAddress(details, address(chainValidator), address(this), customSalt, address(this));
        address actual = factory.create(details, address(chainValidator), address(this), customSalt);

        assertEq(predicted, actual);
    }

    function test_createAndAdoptAgreement() public {
        AgreementDetails memory details = _getValidAgreementDetails();

        // Create agreement
        address agreementAddress = factory.create(details, address(chainValidator), address(this), bytes32(0));

        // Adopt to registry
        registry.adoptSafeHarbor(agreementAddress);

        // Verify registration
        address registered = registry.getAgreement(address(this));
        assertEq(registered, agreementAddress);
    }

    // ======== ON-CHAIN VALIDATION TESTS ========

    function test_revert_invalidBountyPercentage() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.bountyTerms.bountyPercentage = 101;

        vm.expectRevert();
        factory.create(details, address(chainValidator), address(this), bytes32(0));
    }

    function test_revert_emptyChainId() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.chains[0].caip2ChainId = "";

        vm.expectRevert();
        factory.create(details, address(chainValidator), address(this), bytes32(0));
    }

    function test_revert_noAccounts() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.chains[0].accounts = new AgreementAccount[](0);

        vm.expectRevert();
        factory.create(details, address(chainValidator), address(this), bytes32(0));
    }

    // ======== ENVIRONMENT VARIABLE TESTS ========

    function test_runWithEnvironmentVariables() public {
        vm.setEnv("AGREEMENT_FACTORY", vm.toString(address(factory)));
        vm.setEnv("REGISTRY_ADDRESS", vm.toString(address(registry)));
        vm.setEnv("CHAIN_VALIDATOR_ADDRESS", vm.toString(address(chainValidator)));
        vm.setEnv("ADOPT_TO_REGISTRY", "true");
        vm.setEnv("AGREEMENT_DETAILS_PATH", "test/unit/testdata/agreement.json");

        // Preview to verify JSON parsing works
        AgreementDetails memory details = adoptionScript.preview("test/unit/testdata/agreement.json");
        assertEq(details.protocolName, "Env Test");

        // Create and adopt directly
        address agreementAddress = factory.create(details, address(chainValidator), address(this), bytes32(0));
        registry.adoptSafeHarbor(agreementAddress);

        address registered = registry.getAgreement(address(this));
        assertTrue(registered != address(0));
    }
}
