// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol" as Test;
import "../../src/v2/AgreementV2.sol" as V2;
import {SafeHarborRegistryV2} from "../../src/v2/SafeHarborRegistryV2.sol";
import {getMockAgreementDetails} from "./mock.sol";

contract AgreementV2Test is Test.Test {
    uint256 mockKey;
    address mockAddress;
    address owner;
    address notOwner;

    V2.AgreementDetailsV2 details;
    V2.AgreementV2 agreement;
    SafeHarborRegistryV2 registry;

    function setUp() public {
        mockKey = 0xA113;
        mockAddress = vm.addr(mockKey);
        owner = address(0x1);
        notOwner = address(0x2);

        // Create registry and set valid chains
        registry = new SafeHarborRegistryV2(address(0), owner);
        string[] memory validChains = new string[](2);
        validChains[0] = "eip155:1";
        validChains[1] = "eip155:2";
        vm.prank(owner);
        registry.setValidChains(validChains);

        details = getMockAgreementDetails("0x01");
        agreement = new V2.AgreementV2(details, address(registry), owner);
    }

    function testOwner() public {
        assertEq(agreement.owner(), owner);
        assertFalse(agreement.owner() == notOwner);
    }

    function testGetDetails() public {
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(details)), keccak256(abi.encode(_details)));
    }

    function testSetProtocolName() public {
        string memory newName = "Updated Protocol";

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setProtocolName(newName);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.setProtocolName(newName);

        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(_details.protocolName, newName);
    }

    function testSetContactDetails() public {
        V2.Contact[] memory newContacts = new V2.Contact[](2);
        newContacts[0] = V2.Contact({name: "New Contact 1", contact: "@newcontact1"});

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setContactDetails(newContacts);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.setContactDetails(newContacts);

        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(newContacts)), keccak256(abi.encode(_details.contactDetails)));
    }

    function testAddChains() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x04", childContractScope: V2.ChildContractScope.None});

        V2.Chain[] memory newChains = new V2.Chain[](1);
        newChains[0] = V2.Chain({assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:2"});

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.addChains(newChains);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.addChains(newChains);
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();

        V2.Chain memory _chain = _details.chains[_details.chains.length - 1];
        assertEq(keccak256(abi.encode(newChains[0])), keccak256(abi.encode(_chain)));
    }

    function testSetChains() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x04", childContractScope: V2.ChildContractScope.None});

        V2.Chain[] memory chains = new V2.Chain[](1);
        chains[0] = V2.Chain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:1" // Update existing chain
        });

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setChains(chains);

        // Should fail when chain doesn't exist
        vm.prank(owner);
        vm.expectRevert();
        V2.Chain[] memory nonExistentChains = new V2.Chain[](1);
        nonExistentChains[0] = V2.Chain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:999" // Non-existent chain
        });
        agreement.setChains(nonExistentChains);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.setChains(chains);

        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(_details.chains.length, 1);
        assertEq(keccak256(abi.encode(chains[0])), keccak256(abi.encode(_details.chains[0])));
    }

    function testAddChainsPreventsDuplicates() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x04", childContractScope: V2.ChildContractScope.None});

        // Test adding chain that already exists (conflicts with mock data)
        V2.Chain[] memory existingChain = new V2.Chain[](1);
        existingChain[0] = V2.Chain({assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:1"});

        vm.prank(owner);
        vm.expectRevert();
        agreement.addChains(existingChain);
    }

    function testRemoveChain() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        V2.Chain[] memory newChains = new V2.Chain[](1);
        newChains[0] = V2.Chain({assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:2"});

        vm.prank(owner);
        agreement.addChains(newChains);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.removeChain("eip155:2");

        // Should fail when removing non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.removeChain("eip155:999");

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.removeChain("eip155:2");

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(details)));
    }

    // Test adding accounts to a chain
    function testAddAccounts() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.addAccounts("eip155:1", accounts);

        // Should fail when adding to non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.addAccounts("eip155:999", accounts);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.addAccounts("eip155:1", accounts);

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        V2.Account memory _account = _details.chains[0].accounts[_details.chains[0].accounts.length - 1];

        assertEq(keccak256(abi.encode(accounts[0])), keccak256(abi.encode(_account)));
    }

    function testSetAccounts() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        string[] memory accountAddresses = new string[](1);
        accountAddresses[0] = "0x01"; // Account that exists in mock data

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setAccounts("eip155:1", accountAddresses, accounts);

        // should fail when setting to non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.setAccounts("eip155:999", accountAddresses, accounts);

        // should fail when setting to non-existent account
        vm.prank(owner);
        vm.expectRevert();
        string[] memory nonExistentAccounts = new string[](1);
        nonExistentAccounts[0] = "0x999";
        agreement.setAccounts("eip155:1", nonExistentAccounts, accounts);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.setAccounts("eip155:1", accountAddresses, accounts);

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        V2.Account memory _account = _details.chains[0].accounts[0];
        assertEq(keccak256(abi.encode(accounts[0])), keccak256(abi.encode(_account)));
    }

    function testRemoveAccount() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x02", childContractScope: V2.ChildContractScope.None});

        vm.prank(owner);
        agreement.addAccounts("eip155:1", accounts);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.removeAccount("eip155:1", "0x02");

        // Should fail when removing from non-existent chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.removeAccount("eip155:999", "0x02");

        // Should fail when removing non-existent account
        vm.prank(owner);
        vm.expectRevert();
        agreement.removeAccount("eip155:1", "0x999");

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.removeAccount("eip155:1", "0x02");

        // Verify the change - should be back to original state
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(details)));
    }

    // Test setting bounty terms
    function testSetBountyTerms() public {
        V2.BountyTerms memory newTerms = V2.BountyTerms({
            bountyPercentage: 20,
            bountyCapUSD: 1000000,
            retainable: true,
            identity: V2.IdentityRequirements.Named,
            diligenceRequirements: "Diligence",
            aggregateBountyCapUSD: 0
        });

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setBountyTerms(newTerms);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.setBountyTerms(newTerms);

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(newTerms)), keccak256(abi.encode(_details.bountyTerms)));
    }

    // Test that constructor validation works for bounty terms
    function testConstructorCannotSetBothAggregateBountyCapUSDAndRetainable() public {
        V2.AgreementDetailsV2 memory invalidDetails = getMockAgreementDetails("0x01");
        invalidDetails.bountyTerms.aggregateBountyCapUSD = 1000; // Set to > 0
        invalidDetails.bountyTerms.retainable = true; // Set to true

        // Should fail when both conditions are true in constructor
        vm.expectRevert(V2.AgreementV2.CannotSetBothAggregateBountyCapUSDAndRetainable.selector);
        new V2.AgreementV2(invalidDetails, address(registry), owner);
    }

    // Test that constructor validation works for duplicate chain IDs
    function testConstructorDuplicateChainValidation() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.All});

        V2.Chain[] memory duplicateChains = new V2.Chain[](2);
        duplicateChains[0] =
            V2.Chain({accounts: new V2.Account[](1), assetRecoveryAddress: "0x01", caip2ChainId: "eip155:1"});
        duplicateChains[0].accounts[0] = accounts[0];
        duplicateChains[1] =
            V2.Chain({accounts: new V2.Account[](1), assetRecoveryAddress: "0x02", caip2ChainId: "eip155:1"}); // Duplicate!
        duplicateChains[1].accounts[0] = accounts[0];

        V2.Contact[] memory contacts = new V2.Contact[](1);
        contacts[0] = V2.Contact({name: "Test Name", contact: "test@mail.com"});

        V2.BountyTerms memory bountyTerms = V2.BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 100,
            retainable: true,
            identity: V2.IdentityRequirements.Anonymous,
            diligenceRequirements: "none",
            aggregateBountyCapUSD: 0
        });

        V2.AgreementDetailsV2 memory invalidDetails = V2.AgreementDetailsV2({
            protocolName: "testProtocol",
            chains: duplicateChains,
            contactDetails: contacts,
            bountyTerms: bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        // Should fail when duplicate chain IDs are provided in constructor
        vm.expectRevert();
        new V2.AgreementV2(invalidDetails, address(registry), owner);
    }

    // Test that constructor validation works for invalid chain IDs
    function testConstructorInvalidChainValidation() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.All});

        V2.Chain[] memory invalidChains = new V2.Chain[](1);
        invalidChains[0] = V2.Chain({
            accounts: new V2.Account[](1),
            assetRecoveryAddress: "0x01",
            caip2ChainId: "eip155:999" // Invalid chain ID
        });
        invalidChains[0].accounts[0] = accounts[0];

        V2.Contact[] memory contacts = new V2.Contact[](1);
        contacts[0] = V2.Contact({name: "Test Name", contact: "test@mail.com"});

        V2.BountyTerms memory bountyTerms = V2.BountyTerms({
            bountyPercentage: 10,
            bountyCapUSD: 100,
            retainable: true,
            identity: V2.IdentityRequirements.Anonymous,
            diligenceRequirements: "none",
            aggregateBountyCapUSD: 0
        });

        V2.AgreementDetailsV2 memory invalidDetails = V2.AgreementDetailsV2({
            protocolName: "testProtocol",
            chains: invalidChains,
            contactDetails: contacts,
            bountyTerms: bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        // Should fail when invalid chain ID is provided in constructor
        vm.expectRevert(abi.encodeWithSelector(V2.AgreementV2.InvalidChainId.selector, "eip155:999"));
        new V2.AgreementV2(invalidDetails, address(registry), owner);
    }

    // Test adding chains with invalid chain IDs
    function testAddChainsInvalidChain() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x04", childContractScope: V2.ChildContractScope.None});

        V2.Chain[] memory invalidChains = new V2.Chain[](1);
        invalidChains[0] = V2.Chain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:999" // Invalid chain ID
        });

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(V2.AgreementV2.InvalidChainId.selector, "eip155:999"));
        agreement.addChains(invalidChains);
    }

    // Test setting chains with invalid chain IDs
    function testSetChainsInvalidChain() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x04", childContractScope: V2.ChildContractScope.None});

        V2.Chain[] memory invalidChains = new V2.Chain[](1);
        invalidChains[0] = V2.Chain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:999" // Invalid chain ID - not in registry
        });

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(V2.AgreementV2.InvalidChainId.selector, "eip155:999"));
        agreement.setChains(invalidChains);
    }

    // Test that setting both aggregateBountyCapUSD > 0 and retainable = true fails
    function testCannotSetBothAggregateBountyCapUSDAndRetainable() public {
        V2.BountyTerms memory invalidTerms = V2.BountyTerms({
            bountyPercentage: 20,
            bountyCapUSD: 1000000,
            retainable: true,
            identity: V2.IdentityRequirements.Named,
            diligenceRequirements: "Diligence",
            aggregateBountyCapUSD: 1000 // Set to > 0
        });

        // Should fail when both conditions are true
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.CannotSetBothAggregateBountyCapUSDAndRetainable.selector);
        agreement.setBountyTerms(invalidTerms);

        // Verify the original terms are unchanged
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(details.bountyTerms)), keccak256(abi.encode(_details.bountyTerms)));
    }
}
