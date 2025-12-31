// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {
    AgreementDetails,
    Contact,
    ChildContractScope,
    Account as SHAccount,
    Chain as SHChain,
    BountyTerms
} from "src/types/AgreementTypes.sol";
import {Agreement} from "src/Agreement.sol";
import {SafeHarborRegistry} from "src/SafeHarborRegistry.sol";
import {ChainValidator} from "src/ChainValidator.sol";
import {getMockAgreementDetails} from "test/utils/GetAgreementDetails.sol";

contract AgreementTest is Test {
    uint256 mockKey;
    address mockAddress;
    address owner;

    Agreement agreement;
    SafeHarborRegistry registry;
    ChainValidator chainValidator;

    function setUp() public {
        mockKey = 0xA113;
        mockAddress = vm.addr(mockKey);
        owner = address(0x1);

        // Create chain validator and set valid chains
        chainValidator = new ChainValidator(owner);
        string[] memory validChains = new string[](2);
        validChains[0] = "eip155:1";
        validChains[1] = "eip155:2";
        vm.prank(owner);
        chainValidator.setValidChains(validChains);

        // Create registry with chain validator
        registry = new SafeHarborRegistry(owner, address(chainValidator));

        AgreementDetails memory details = getMockAgreementDetails("0x01");
        agreement = new Agreement(details, address(registry), owner);
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
        newChains[0] = SHChain({ assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:2" });

        // Should fail when called by non-owner
        vm.expectRevert();
        agreement.addChains(newChains);

        // Should fail when the chain is invalid
        SHChain[] memory invalidChains = new SHChain[](1);
        invalidChains[0] = SHChain({ assetRecoveryAddress: "0x06", accounts: accounts, caip2ChainId: "eip155:999" });

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__InvalidChainId.selector, "eip155:999"));
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
        newChains[0] = SHChain({ assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:2" });

        vm.prank(owner);
        agreement.addChains(newChains);

        // Should fail when called by non-owner
        vm.expectRevert();
        string[] memory chainToRemove = new string[](1);
        chainToRemove[0] = "eip155:2";
        agreement.removeChains(chainToRemove);

        // Should fail when removing non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        string[] memory nonExistentChain = new string[](1);
        nonExistentChain[0] = "eip155:999";
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
        new Agreement(invalidDetails, address(registry), owner);
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
        new Agreement(invalidDetails, address(registry), owner);
    }

    function testConstructorInvalidChainValidation() public {
        AgreementDetails memory baseDetails = getMockAgreementDetails("0x01");

        SHAccount[] memory accounts = new SHAccount[](1);
        accounts[0] = SHAccount({ accountAddress: "0x01", childContractScope: ChildContractScope.All });

        SHChain memory chain = SHChain({ accounts: accounts, assetRecoveryAddress: "0x01", caip2ChainId: "eip155:999" });

        SHChain[] memory invalidChains = new SHChain[](2);
        invalidChains[0] = chain;

        AgreementDetails memory invalidDetails = AgreementDetails({
            protocolName: "testProtocol",
            chains: invalidChains,
            contactDetails: baseDetails.contactDetails,
            bountyTerms: baseDetails.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(Agreement.Agreement__InvalidChainId.selector, "eip155:999"));
        new Agreement(invalidDetails, address(registry), owner);
    }
}
