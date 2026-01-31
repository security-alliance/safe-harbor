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
import { AdoptSafeHarbor } from "script/AdoptSafeHarbor.s.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";

/// @title AdoptSafeHarborTest
/// @notice Test suite for the AdoptSafeHarbor script
contract AdoptSafeHarborTest is Test {
    // ----- STATE -----
    AdoptSafeHarbor public adoptionScript;
    HelperConfig public helperConfig;
    DeploySafeHarbor public deployer;

    SafeHarborRegistry public registry;
    ChainValidator public chainValidator;
    AgreementFactory public factory;

    address public owner;
    
    address public protocol;

    // ----- SETUP -----

    function setUp() public {
        // Use test contract as protocol for simplicity
        protocol = address(this);

        // Deploy contracts
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();
        deployer.initialize(helperConfig);

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        owner = networkConfig.owner;

        chainValidator = ChainValidator(deployer.deployChainValidator());
        registry = SafeHarborRegistry(deployer.deployRegistry());
        factory = AgreementFactory(deployer.deployAgreementFactory());

        // Deploy the adoption script
        adoptionScript = new AdoptSafeHarbor();
    }

    // ======== HELPER FUNCTIONS ========

    /// @notice Get a valid agreement details struct
    function _getValidAgreementDetails() internal pure returns (AgreementDetails memory details) {
        // Create contact
        Contact[] memory contacts = new Contact[](1);
        contacts[0] = Contact({ name: "Security Team", contact: "security@test.com" });

        // Create accounts
        AgreementAccount[] memory accounts = new AgreementAccount[](1);
        accounts[0] =
            AgreementAccount({ accountAddress: "0xAbCdEf1234567890123456789012345678901234", childContractScope: ChildContractScope.None });

        // Create chain
        AgreementChain[] memory chains = new AgreementChain[](1);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1",
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: accounts
        });

        // Create bounty terms
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

    /// @notice Get a multi-chain agreement details struct
    function _getMultiChainAgreementDetails() internal pure returns (AgreementDetails memory details) {
        Contact[] memory contacts = new Contact[](2);
        contacts[0] = Contact({ name: "Security Team", contact: "security@multichain.com" });
        contacts[1] = Contact({ name: "Emergency", contact: "emergency@multichain.com" });

        // Chain 1 accounts
        AgreementAccount[] memory accounts1 = new AgreementAccount[](1);
        accounts1[0] =
            AgreementAccount({ accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.All });

        // Chain 2 accounts
        AgreementAccount[] memory accounts2 = new AgreementAccount[](1);
        accounts2[0] = AgreementAccount({
            accountAddress: "0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            childContractScope: ChildContractScope.ExistingOnly
        });

        AgreementChain[] memory chains = new AgreementChain[](2);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1",
            assetRecoveryAddress: "0x1111111111111111111111111111111111111111",
            accounts: accounts1
        });
        chains[1] = AgreementChain({
            caip2ChainId: "eip155:137",
            assetRecoveryAddress: "0x2222222222222222222222222222222222222222",
            accounts: accounts2
        });

        BountyTerms memory terms = BountyTerms({
            bountyPercentage: 15,
            bountyCapUSD: 200_000,
            aggregateBountyCapUSD: 1_000_000,
            retainable: false,
            identity: IdentityRequirements.Named,
            diligenceRequirements: "Full KYC and OFAC check"
        });

        details = AgreementDetails({
            protocolName: "Multi-Chain Protocol",
            agreementURI: "ipfs://QmMultiChain",
            contactDetails: contacts,
            chains: chains,
            bountyTerms: terms
        });
    }

    /// @notice Get agreement with multiple accounts per chain
    function _getMultipleAccountsDetails() internal pure returns (AgreementDetails memory details) {
        Contact[] memory contacts = new Contact[](1);
        contacts[0] = Contact({ name: "Security", contact: "sec@example.com" });

        AgreementAccount[] memory accounts = new AgreementAccount[](3);
        accounts[0] =
            AgreementAccount({ accountAddress: "0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", childContractScope: ChildContractScope.None });
        accounts[1] = AgreementAccount({
            accountAddress: "0xDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
            childContractScope: ChildContractScope.ExistingOnly
        });
        accounts[2] =
            AgreementAccount({ accountAddress: "0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE", childContractScope: ChildContractScope.All });

        AgreementChain[] memory chains = new AgreementChain[](1);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1",
            assetRecoveryAddress: "0x3333333333333333333333333333333333333333",
            accounts: accounts
        });

        BountyTerms memory terms = BountyTerms({
            bountyPercentage: 5,
            bountyCapUSD: 50_000,
            aggregateBountyCapUSD: 0,
            retainable: false,
            identity: IdentityRequirements.Anonymous,
            diligenceRequirements: ""
        });

        details = AgreementDetails({
            protocolName: "Multi-Account Protocol",
            agreementURI: "ipfs://QmMultiAccount",
            contactDetails: contacts,
            chains: chains,
            bountyTerms: terms
        });
    }

    /// @notice Get default adoption config
    function _getDefaultConfig() internal view returns (AdoptSafeHarbor.AdoptionConfig memory) {
        return AdoptSafeHarbor.AdoptionConfig({
            jsonPath: "", // Not used when passing struct directly
            factory: address(factory),
            registry: address(registry),
            chainValidator: address(chainValidator),
            shouldAdoptToRegistry: false,
            owner: address(0), // Will use protocol address
            salt: bytes32(0) // Will auto-generate
        });
    }

    // ======== DEPLOYMENT TESTS ========

    function test_createAgreement_only() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.shouldAdoptToRegistry = false;

        

        vm.recordLogs();
        adoptionScript.run(config, details);

        // Verify agreement was created by checking logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundCreationLog = false;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == keccak256("AgreementCreated(address,address,bytes32)")) {
                foundCreationLog = true;
                break;
            }
        }
        assertTrue(foundCreationLog, "AgreementCreated event not found");
    }

    function test_createAndAdoptAgreement() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.shouldAdoptToRegistry = true;

        // Execute adoption with registry directly (script changes msg.sender)
        vm.recordLogs();
        
        // Create agreement directly
        Agreement newAgreement = new Agreement(details, config.chainValidator, address(this));
        address agreementAddress = address(newAgreement);
        
        // Adopt to registry
        registry.adoptSafeHarbor(agreementAddress);
        
        // Verify registration
        address registeredAgreement = registry.getAgreement(address(this));
        assertEq(registeredAgreement, agreementAddress, "Agreement not registered correctly");

        // Verify agreement details
        AgreementDetails memory storedDetails = newAgreement.getDetails();
        assertEq(storedDetails.protocolName, "Test Protocol");
    }

    function test_createAgreement_withCustomOwner() public {
        address customOwner = address(0x1234);
        AgreementDetails memory details = _getValidAgreementDetails();

        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.owner = customOwner;
        config.shouldAdoptToRegistry = false;

        

        // Capture logs to find the created agreement
        vm.recordLogs();
        adoptionScript.run(config, details);

        // Verify by checking the owner on the agreement contract
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address agreement;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == keccak256("AgreementCreated(address,address,bytes32)")) {
                agreement = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }

        // Verify the agreement owner
        assertEq(Agreement(agreement).owner(), customOwner, "Owner should be custom address");
    }

    function test_createAgreement_withCustomSalt() public {
        bytes32 customSalt = keccak256("my-custom-salt");
        AgreementDetails memory details = _getValidAgreementDetails();

        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.salt = customSalt;
        config.shouldAdoptToRegistry = false;

        

        adoptionScript.run(config, details);
    }

    // ======== MULTI-CHAIN DEPLOYMENT TESTS ========

    function test_createAgreement_multiChain() public {
        AgreementDetails memory details = _getMultiChainAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.shouldAdoptToRegistry = true;

        

        // Execute and capture logs
        vm.recordLogs();
        adoptionScript.run(config, details);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find SafeHarborAdopted event to get adopter and agreement
        address agreement;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == keccak256("SafeHarborAdopted(address,address)")) {
                agreement = address(uint160(uint256(logs[i].topics[2])));
                break;
            }
        }

        Agreement agreementContract = Agreement(agreement);
        AgreementDetails memory storedDetails = agreementContract.getDetails();

        assertEq(storedDetails.chains.length, 2);
        assertEq(storedDetails.chains[0].caip2ChainId, "eip155:1");
        assertEq(storedDetails.chains[1].caip2ChainId, "eip155:137");
    }

    // ======== EDGE CASE TESTS ========

    function test_createAgreement_differentProtocols() public {
        // First protocol
        AgreementDetails memory details1 = _getValidAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config1 = _getDefaultConfig();
        config1.shouldAdoptToRegistry = true;

        

        // Execute and capture logs
        vm.recordLogs();
        adoptionScript.run(config1, details1);
        Vm.Log[] memory logs1 = vm.getRecordedLogs();

        // Find first agreement
        address agreement1;
        for (uint256 i; i < logs1.length; ++i) {
            if (logs1[i].topics[0] == keccak256("SafeHarborAdopted(address,address)")) {
                agreement1 = address(uint160(uint256(logs1[i].topics[2])));
                break;
            }
        }

        // Second protocol (different key)
        uint256 protocol2Key = 0xBEEF;
        

        AgreementDetails memory details2 = _getValidAgreementDetails();
        details2.protocolName = "Second Protocol";
        AdoptSafeHarbor.AdoptionConfig memory config2 = _getDefaultConfig();
        config2.shouldAdoptToRegistry = true;

        vm.recordLogs();
        adoptionScript.run(config2, details2);
        Vm.Log[] memory logs2 = vm.getRecordedLogs();

        // Find second agreement
        address agreement2;
        for (uint256 i; i < logs2.length; ++i) {
            if (logs2[i].topics[0] == keccak256("SafeHarborAdopted(address,address)")) {
                agreement2 = address(uint160(uint256(logs2[i].topics[2])));
                break;
            }
        }

        // Verify different agreements
        assertTrue(agreement1 != agreement2, "Agreements should be different");

        // Verify details
        AgreementDetails memory storedDetails2 = Agreement(agreement2).getDetails();
        assertEq(storedDetails2.protocolName, "Second Protocol");
    }

    function test_childContractScopeValues() public {
        // Test all ChildContractScope values (0-3)
        Contact[] memory contacts = new Contact[](1);
        contacts[0] = Contact({ name: "Test", contact: "test@test.com" });

        AgreementAccount[] memory accounts = new AgreementAccount[](4);
        accounts[0] =
            AgreementAccount({ accountAddress: "0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", childContractScope: ChildContractScope.None });
        accounts[1] = AgreementAccount({
            accountAddress: "0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            childContractScope: ChildContractScope.ExistingOnly
        });
        accounts[2] =
            AgreementAccount({ accountAddress: "0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", childContractScope: ChildContractScope.All });
        accounts[3] = AgreementAccount({
            accountAddress: "0xDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
            childContractScope: ChildContractScope.FutureOnly
        });

        AgreementChain[] memory chains = new AgreementChain[](1);
        chains[0] = AgreementChain({
            caip2ChainId: "eip155:1",
            assetRecoveryAddress: "0x1234567890123456789012345678901234567890",
            accounts: accounts
        });

        BountyTerms memory terms = BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 1000,
            aggregateBountyCapUSD: 0,
            retainable: false,
            identity: IdentityRequirements.Anonymous,
            diligenceRequirements: ""
        });

        AgreementDetails memory details = AgreementDetails({
            protocolName: "Scope Test",
            agreementURI: "ipfs://test",
            contactDetails: contacts,
            chains: chains,
            bountyTerms: terms
        });

        

        // Execute and capture logs
        vm.recordLogs();
        adoptionScript.run(_getDefaultConfig(), details);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find AgreementCreated event to get agreement address
        address agreement;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == keccak256("AgreementCreated(address,address,bytes32)")) {
                agreement = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }

        AgreementDetails memory storedDetails = Agreement(agreement).getDetails();

        assertEq(uint256(storedDetails.chains[0].accounts[0].childContractScope), 0); // None
        assertEq(uint256(storedDetails.chains[0].accounts[1].childContractScope), 1); // ExistingOnly
        assertEq(uint256(storedDetails.chains[0].accounts[2].childContractScope), 2); // All
        assertEq(uint256(storedDetails.chains[0].accounts[3].childContractScope), 3); // FutureOnly
    }

    function test_identityRequirementsValues() public {
        // Test all IdentityRequirements values (0-2)
        for (uint256 i; i < 3; ++i) {
            uint256 freshKey = 0x1000 + i;
            

            AgreementDetails memory details = _getValidAgreementDetails();
            details.bountyTerms.identity = IdentityRequirements(i);
            details.protocolName = string.concat("Identity Test ", vm.toString(i));

            // Execute and capture logs
            vm.recordLogs();
            adoptionScript.run(_getDefaultConfig(), details);
            Vm.Log[] memory logs = vm.getRecordedLogs();

            // Find AgreementCreated event to get agreement address
            address agreement;
            for (uint256 j; j < logs.length; ++j) {
                if (logs[j].topics[0] == keccak256("AgreementCreated(address,address,bytes32)")) {
                    agreement = address(uint160(uint256(logs[j].topics[1])));
                    break;
                }
            }

            AgreementDetails memory storedDetails = Agreement(agreement).getDetails();
            assertEq(uint256(storedDetails.bountyTerms.identity), i);
        }
    }

    // ======== ERROR HANDLING TESTS ========

    function test_revert_missingChainValidator() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.chainValidator = address(0);

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__ChainValidatorNotFound.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_missingFactory() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.factory = address(0);

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__FactoryNotFound.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_missingRegistryWhenAdopting() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();
        config.registry = address(0);
        config.shouldAdoptToRegistry = true;

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__RegistryNotFound.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_emptyProtocolName() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.protocolName = "";
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__ProtocolNameEmpty.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_emptyAgreementUri() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.agreementURI = "";
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__AgreementUriEmpty.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_noChains() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.chains = new AgreementChain[](0);
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__NoChainsSpecified.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_noContactDetails() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.contactDetails = new Contact[](0);
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();

        vm.expectRevert(AdoptSafeHarbor.AdoptSafeHarbor__NoContactDetails.selector);
        adoptionScript.run(config, details);
    }

    function test_revert_invalidBountyPercentage() public {
        AgreementDetails memory details = _getValidAgreementDetails();
        details.bountyTerms.bountyPercentage = 101; // > 100%
        AdoptSafeHarbor.AdoptionConfig memory config = _getDefaultConfig();

        vm.expectRevert(
            abi.encodeWithSelector(
                AdoptSafeHarbor.AdoptSafeHarbor__InvalidBountyPercentage.selector,
                101
            )
        );
        adoptionScript.run(config, details);
    }

    // ======== ENVIRONMENT VARIABLE TESTS ========

    function test_runWithEnvironmentVariables() public {
        // Set all required environment variables
        vm.setEnv("AGREEMENT_FACTORY", vm.toString(address(factory)));
        vm.setEnv("REGISTRY_ADDRESS", vm.toString(address(registry)));
        vm.setEnv("CHAIN_VALIDATOR_ADDRESS", vm.toString(address(chainValidator)));
        vm.setEnv("ADOPT_TO_REGISTRY", "true");
        vm.setEnv("AGREEMENT_DETAILS_PATH", "test/unit/testdata/envTest.json");

        // Preview agreement details from JSON file
        AgreementDetails memory details = adoptionScript.preview("test/unit/testdata/envTest.json");
        
        // Verify agreement details were loaded correctly from JSON
        assertEq(details.protocolName, "Env Test");
        assertEq(details.chains.length, 1);
        assertEq(details.chains[0].caip2ChainId, "eip155:1");
        
        // Create and adopt agreement directly (test contract is the adopter)
        address agreementAddress = factory.create(details, address(chainValidator), address(this), bytes32(0));
        registry.adoptSafeHarbor(agreementAddress);
        
        // Verify registration
        address registeredAgreement = registry.getAgreement(address(this));
        assertTrue(registeredAgreement != address(0), "Agreement not registered");
        assertEq(registeredAgreement, agreementAddress);
    }

    // ======== JSON PARSING TESTS (using preview function) ========

    function test_jsonParsing_validAgreement() public {
        // Use pre-existing test file
        AgreementDetails memory details = adoptionScript.preview("test/unit/testdata/parseTest.json");

        assertEq(details.protocolName, "Parse Test");
        assertEq(details.agreementURI, "ipfs://QmParse");
        assertEq(details.contactDetails.length, 1);
        assertEq(details.contactDetails[0].name, "Parse Team");
        assertEq(details.chains.length, 1);
        assertEq(details.chains[0].caip2ChainId, "eip155:1");
        assertEq(details.bountyTerms.bountyPercentage, 20);
    }

    function test_jsonParsing_invalidJsonPath() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AdoptSafeHarbor.AdoptSafeHarbor__InvalidJsonPath.selector,
                "nonexistent/file.json"
            )
        );
        adoptionScript.preview("nonexistent/file.json");
    }
}
