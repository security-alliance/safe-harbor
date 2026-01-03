// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import {
    AgreementDetails,
    Contact,
    ChildContractScope,
    Account as SHAccount,
    Chain as SHChain,
    BountyTerms
} from "src/types/AgreementTypes.sol";
import { Agreement } from "src/Agreement.sol";
import { SafeHarborRegistry } from "src/SafeHarborRegistry.sol";
import { ChainValidator } from "src/ChainValidator.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeploySafeHarbor } from "script/Deploy.s.sol";
import { getMockAgreementDetails } from "test/utils/GetAgreementDetails.sol";

contract AgreementTest is Test {
    uint256 mockKey;
    address mockAddress;
    address owner;

    Agreement agreement;
    SafeHarborRegistry registry;
    ChainValidator chainValidator;
    HelperConfig helperConfig;
    DeploySafeHarbor deployer;

    function setUp() public {
        mockKey = 0xA113;
        mockAddress = vm.addr(mockKey);

        // Use HelperConfig and DeploySafeHarbor for deployment
        helperConfig = new HelperConfig();
        deployer = new DeploySafeHarbor();

        // Initialize deployer with helperConfig
        deployer.initialize(helperConfig);

        // Get network config (will use anvil config for local testing)
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        owner = networkConfig.owner;

        // Deploy ChainValidator using CREATE3
        chainValidator = ChainValidator(deployer.deployChainValidator());

        // Deploy SafeHarborRegistry using CREATE3
        registry = SafeHarborRegistry(deployer.deployRegistry());

        // Create a test agreement
        AgreementDetails memory details = getMockAgreementDetails("0x01");
        vm.prank(owner);
        agreement = new Agreement(details, address(chainValidator), owner);
    }

    function testOwner() public view {
        assertEq(agreement.owner(), owner);
        assertFalse(agreement.owner() == address(0x02));
    }

    function testGetDetails() public view {
        AgreementDetails memory _details = agreement.getDetails();
        AgreementDetails memory expectedDetails = getMockAgreementDetails("0x01");
        assertEq(keccak256(abi.encode(expectedDetails)), keccak256(abi.encode(_details)));
    }

    function testSetProtocolName() public {
        string memory newName = "Updated Protocol";

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.setProtocolName(newName);

        // Should succeed when called by owner
        vm.prank(owner);
        // TODO: Expect event
        agreement.setProtocolName(newName);

        AgreementDetails memory _details = agreement.getDetails();
        assertEq(_details.protocolName, newName);
    }

    function testSetContactDetails() public {
        Contact[] memory newContacts = new Contact[](2);
        newContacts[0] = Contact({ name: "New Contact 1", contact: "@newcontact1" });

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.setContactDetails(newContacts);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.setContactDetails(newContacts);

        AgreementDetails memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(newContacts)), keccak256(abi.encode(_details.contactDetails)));
    }

    function testAddChains() public {
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x04", childContractScope: ChildContractScope.None });

        SHChain[] memory newChains = new SHChain[](1);
        newChains[0] = SHChain({ assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:56" });

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.addChains(newChains);

        // Should fail when the chain is invalid
        SHChain[] memory invalidChains = new SHChain[](1);
        invalidChains[0] =
            SHChain({ assetRecoveryAddress: "0x06", accounts: accounts, caip2ChainId: "eip155:99999999" });

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__InvalidChainId.selector, "eip155:99999999"));
        agreement.addChains(invalidChains);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.addChains(newChains);

        AgreementDetails memory _details = agreement.getDetails();
        SHChain memory _chain = _details.chains[_details.chains.length - 1];
        assertEq(keccak256(abi.encode(newChains[0])), keccak256(abi.encode(_chain)));

        // Should fail when adding duplicate chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.addChains(newChains);
    }

    function testSetChains() public {
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x04", childContractScope: ChildContractScope.None });

        SHChain[] memory chains = new SHChain[](1);
        chains[0] = SHChain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:1" // Update existing chain
        });

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.setChains(chains);

        // Should fail when chain doesn't exist
        SHChain[] memory nonExistentChains = new SHChain[](1);
        nonExistentChains[0] = SHChain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:999" // Non-existent chain
        });

        vm.prank(owner);
        vm.expectRevert();
        agreement.setChains(nonExistentChains);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.setChains(chains);

        AgreementDetails memory _details = agreement.getDetails();
        assertEq(_details.chains.length, 1);
        assertEq(keccak256(abi.encode(chains[0])), keccak256(abi.encode(_details.chains[0])));
    }

    function testRemoveChain() public {
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.None });

        SHChain[] memory newChains = new SHChain[](1);
        newChains[0] = SHChain({ assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:56" });

        vm.prank(owner);
        agreement.addChains(newChains);

        // Should fail when called by non-owner
        vm.expectRevert();
        string[] memory chainToRemove = new string[](1);
        chainToRemove[0] = "eip155:56";
        agreement.removeChains(chainToRemove);

        // Should fail when removing non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        string[] memory nonExistentChain = new string[](1);
        nonExistentChain[0] = "eip155:99999999";
        agreement.removeChains(nonExistentChain);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.removeChains(chainToRemove);

        // Verify the change
        AgreementDetails memory _details = agreement.getDetails();
        AgreementDetails memory expectedDetails = getMockAgreementDetails("0x01");
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(expectedDetails)));
    }

    // Test adding accounts to a chain
    function testAddAccounts() public {
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.None });

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.addAccounts("eip155:1", accounts);

        // Should fail when adding to non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.addAccounts("eip155:999", accounts);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.addAccounts("eip155:1", accounts);

        // Verify the change
        AgreementDetails memory _details = agreement.getDetails();
        SHAccount memory _account = _details.chains[0].accounts[_details.chains[0].accounts.length - 1];

        assertEq(keccak256(abi.encode(accounts[0])), keccak256(abi.encode(_account)));
    }

    function testRemoveAccounts() public {
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x02", childContractScope: ChildContractScope.None });

        vm.prank(owner);
        agreement.addAccounts("eip155:1", accounts);

        // Should fail when called by non-owner
        vm.expectRevert();
        string[] memory accountToRemove = new string[](1);
        accountToRemove[0] = "0x02";
        agreement.removeAccounts("eip155:1", accountToRemove);

        // Should fail when removing from non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.removeAccounts("eip155:999", accountToRemove);

        // Should fail when removing non-existent account
        vm.prank(owner);
        vm.expectRevert();
        string[] memory nonExistentAccount = new string[](1);
        nonExistentAccount[0] = "0x999";
        agreement.removeAccounts("eip155:1", nonExistentAccount);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.removeAccounts("eip155:1", accountToRemove);

        // Verify the change - should be back to original state
        AgreementDetails memory _details = agreement.getDetails();
        AgreementDetails memory expectedDetails = getMockAgreementDetails("0x01");
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(expectedDetails)));
    }

    // Test setting bounty terms
    function testSetBountyTerms() public {
        AgreementDetails memory initialDetails = getMockAgreementDetails("0x01");
        BountyTerms memory newTerms = initialDetails.bountyTerms;
        newTerms.bountyPercentage = 20;
        newTerms.bountyCapUSD = 2_000_000;

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.setBountyTerms(newTerms);

        // Should succeed when called by owner
        vm.prank(owner);
        agreement.setBountyTerms(newTerms);

        // Verify the change
        AgreementDetails memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(newTerms)), keccak256(abi.encode(_details.bountyTerms)));

        // Should fail when trying to set both aggregateBountyCapUSD and retainable
        newTerms.aggregateBountyCapUSD = 1_000_000;
        newTerms.retainable = true;
        vm.prank(owner);
        vm.expectRevert(Agreement.Agreement__CannotSetBothAggregateBountyCapUsdAndRetainable.selector);
        agreement.setBountyTerms(newTerms);
    }

    function testConstructorCannotSetBothAggregateBountyCapUSDAndRetainable() public {
        AgreementDetails memory invalidDetails = getMockAgreementDetails("0x01");
        invalidDetails.bountyTerms.aggregateBountyCapUSD = 1000;
        invalidDetails.bountyTerms.retainable = true;

        // Should fail when both conditions are true in constructor
        vm.expectRevert(Agreement.Agreement__CannotSetBothAggregateBountyCapUsdAndRetainable.selector);
        new Agreement(invalidDetails, address(chainValidator), owner);
    }

    function testConstructorDuplicateChainValidation() public {
        AgreementDetails memory baseDetails = getMockAgreementDetails("0x01");

        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.All });

        SHChain memory chain = SHChain({ accounts: accounts, assetRecoveryAddress: "0x01", caip2ChainId: "eip155:1" });

        SHChain[] memory duplicateChains = new SHChain[](2);
        duplicateChains[0] = chain;
        duplicateChains[1] = chain;

        AgreementDetails memory invalidDetails = AgreementDetails({
            protocolName: "testProtocol",
            chains: duplicateChains,
            contactDetails: baseDetails.contactDetails,
            bountyTerms: baseDetails.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__DuplicateChainId.selector, "eip155:1"));
        new Agreement(invalidDetails, address(chainValidator), owner);
    }

    function testConstructorInvalidChainValidation() public {
        AgreementDetails memory baseDetails = getMockAgreementDetails("0x01");

        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.All });

        SHChain memory chain =
            SHChain({ accounts: accounts, assetRecoveryAddress: "0x01", caip2ChainId: "eip155:99999999" });

        SHChain[] memory invalidChains = new SHChain[](1);
        invalidChains[0] = chain;

        AgreementDetails memory invalidDetails = AgreementDetails({
            protocolName: "testProtocol",
            chains: invalidChains,
            contactDetails: baseDetails.contactDetails,
            bountyTerms: baseDetails.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__InvalidChainId.selector, "eip155:99999999"));
        new Agreement(invalidDetails, address(chainValidator), owner);
    }

    function testConstructorZeroChainValidatorAddress() public {
        AgreementDetails memory details = getMockAgreementDetails("0x01");

        vm.expectRevert(Agreement.Agreement__ZeroAddress.selector);
        new Agreement(details, address(0), owner);
    }

    function testConstructorZeroAccountsValidation() public {
        AgreementDetails memory baseDetails = getMockAgreementDetails("0x01");

        SHAccount[] memory emptyAccounts = new SHAccount[](0);

        SHChain memory chain =
            SHChain({ accounts: emptyAccounts, assetRecoveryAddress: "0x01", caip2ChainId: "eip155:1" });

        SHChain[] memory chainsWithNoAccounts = new SHChain[](1);
        chainsWithNoAccounts[0] = chain;

        AgreementDetails memory invalidDetails = AgreementDetails({
            protocolName: "testProtocol",
            chains: chainsWithNoAccounts,
            contactDetails: baseDetails.contactDetails,
            bountyTerms: baseDetails.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__ZeroAccountsForChainId.selector, "eip155:1"));
        new Agreement(invalidDetails, address(chainValidator), owner);
    }

    function testConstructorInvalidAssetRecoveryAddress() public {
        AgreementDetails memory baseDetails = getMockAgreementDetails("0x01");

        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.All });

        SHChain memory chain = SHChain({
            accounts: accounts,
            assetRecoveryAddress: "", // Empty recovery address
            caip2ChainId: "eip155:1"
        });

        SHChain[] memory chainsWithInvalidRecovery = new SHChain[](1);
        chainsWithInvalidRecovery[0] = chain;

        AgreementDetails memory invalidDetails = AgreementDetails({
            protocolName: "testProtocol",
            chains: chainsWithInvalidRecovery,
            contactDetails: baseDetails.contactDetails,
            bountyTerms: baseDetails.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__InvalidAssetRecoveryAddress.selector, "eip155:1"));
        new Agreement(invalidDetails, address(chainValidator), owner);
    }

    function testConstructorZeroLengthChainId() public {
        AgreementDetails memory baseDetails = getMockAgreementDetails("0x01");

        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.All });

        SHChain memory chain = SHChain({
            accounts: accounts,
            assetRecoveryAddress: "0x01",
            caip2ChainId: "" // Empty chain ID
        });

        SHChain[] memory chainsWithEmptyId = new SHChain[](1);
        chainsWithEmptyId[0] = chain;

        AgreementDetails memory invalidDetails = AgreementDetails({
            protocolName: "testProtocol",
            chains: chainsWithEmptyId,
            contactDetails: baseDetails.contactDetails,
            bountyTerms: baseDetails.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(Agreement.Agreement__ChainIdHasZeroLength.selector);
        new Agreement(invalidDetails, address(chainValidator), owner);
    }

    function testAddOrSetChains() public {
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x04", childContractScope: ChildContractScope.None });

        // Test adding a new chain via addOrSetChains
        SHChain[] memory newChains = new SHChain[](1);
        newChains[0] = SHChain({ assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:56" });

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.addOrSetChains(newChains);

        // Should succeed when called by owner - adds new chain
        vm.prank(owner);
        agreement.addOrSetChains(newChains);

        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 2); // Original chain + new chain

        // Now test updating an existing chain via addOrSetChains
        SHAccount[] memory updatedAccounts = new SHAccount[](1);
        updatedAccounts[0] = SHAccount({ accountAddress: "0x99", childContractScope: ChildContractScope.All });

        SHChain[] memory updateChains = new SHChain[](1);
        updateChains[0] =
            SHChain({ assetRecoveryAddress: "0x88", accounts: updatedAccounts, caip2ChainId: "eip155:56" });

        vm.prank(owner);
        agreement.addOrSetChains(updateChains);

        details = agreement.getDetails();
        assertEq(details.chains.length, 2); // Should still be 2 chains

        // Verify the chain was updated
        bool found = false;
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (keccak256(bytes(details.chains[i].caip2ChainId)) == keccak256(bytes("eip155:56"))) {
                assertEq(details.chains[i].assetRecoveryAddress, "0x88");
                assertEq(details.chains[i].accounts[0].accountAddress, "0x99");
                found = true;
                break;
            }
        }
        assertTrue(found, "Chain eip155:56 not found after update");
    }

    function testRemoveOnlyChain() public {
        // Remove the only chain (tests idx == lastIdx path in removeChains)
        string[] memory chainToRemove = new string[](1);
        chainToRemove[0] = "eip155:1";

        vm.prank(owner);
        agreement.removeChains(chainToRemove);

        AgreementDetails memory details = agreement.getDetails();
        assertEq(details.chains.length, 0);
    }

    function testRemoveFirstChainOfMultiple() public {
        // Add a second chain so we have multiple
        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x04", childContractScope: ChildContractScope.None });

        SHChain[] memory newChains = new SHChain[](1);
        newChains[0] = SHChain({ assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:56" });

        vm.prank(owner);
        agreement.addChains(newChains);

        // Verify we have 2 chains
        AgreementDetails memory detailsBefore = agreement.getDetails();
        assertEq(detailsBefore.chains.length, 2);

        // Remove the FIRST chain (idx=0, lastIdx=1, so idx != lastIdx)
        // This tests the branch where we swap with the last element
        string[] memory chainToRemove = new string[](1);
        chainToRemove[0] = "eip155:1"; // This is the first chain

        vm.prank(owner);
        agreement.removeChains(chainToRemove);

        // Verify only second chain remains
        AgreementDetails memory detailsAfter = agreement.getDetails();
        assertEq(detailsAfter.chains.length, 1);
        assertEq(detailsAfter.chains[0].caip2ChainId, "eip155:56");
    }

    function testGetters() public view {
        // Test getProtocolName
        string memory protocolName = agreement.getProtocolName();
        assertEq(protocolName, "testProtocolV2");

        // Test getBountyTerms
        BountyTerms memory terms = agreement.getBountyTerms();
        assertEq(terms.bountyPercentage, 10);
        assertEq(terms.bountyCapUSD, 100);

        // Test getAgreementURI
        string memory uri = agreement.getAgreementURI();
        assertEq(uri, "ipfs://testHash");

        // Test getChainValidator
        address chainValidatorAddress = agreement.getChainValidator();
        assertEq(chainValidatorAddress, address(chainValidator));

        // Test getChainIds
        string[] memory chainIds = agreement.getChainIds();
        assertEq(chainIds.length, 1);
        assertEq(chainIds[0], "eip155:1");
    }
}
