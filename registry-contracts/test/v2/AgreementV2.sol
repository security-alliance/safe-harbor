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

    function setUp() public {
        mockKey = 0xA113;
        mockAddress = vm.addr(mockKey);
        owner = address(0x1);
        notOwner = address(0x2);

        details = getMockAgreementDetails("0x01");
        agreement = new V2.AgreementV2(details, owner);
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
        chains[0] = V2.Chain({assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:2"});
        uint256[] memory chainIds = new uint256[](1);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        chainIds[0] = 0;
        agreement.setChains(chainIds, chains);

        // Should fail when chainIds are greater than chains length
        vm.prank(owner);
        vm.expectRevert();
        chainIds[0] = 999;
        agreement.setChains(chainIds, chains);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        chainIds[0] = 0;
        agreement.setChains(chainIds, chains);

        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(_details.chains.length, 1);
        assertEq(keccak256(abi.encode(chains[0])), keccak256(abi.encode(_details.chains[0])));
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
        agreement.removeChain(1);

        // Should fail when removing non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.ChainNotFound.selector);
        agreement.removeChain(999);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.removeChain(1);

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
        agreement.addAccounts(0, accounts);

        // Should fail when adding to non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.ChainNotFound.selector);
        agreement.addAccounts(999, accounts);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.addAccounts(0, accounts);

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        V2.Account memory _account = _details.chains[0].accounts[_details.chains[0].accounts.length - 1];

        assertEq(keccak256(abi.encode(accounts[0])), keccak256(abi.encode(_account)));
    }

    function testSetAccounts() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        uint256[] memory accountIds = new uint256[](1);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        accountIds[0] = 0;
        agreement.setAccounts(0, accountIds, accounts);

        // should fail when setting to non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.ChainNotFound.selector);
        accountIds[0] = 0;
        agreement.setAccounts(999, accountIds, accounts);

        // should fail when setting to non-existent account
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.AccountNotFound.selector);
        accountIds[0] = 999;
        agreement.setAccounts(0, accountIds, accounts);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        accountIds[0] = 0;
        agreement.setAccounts(0, accountIds, accounts);

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        V2.Account memory _account = _details.chains[0].accounts[0];
        assertEq(keccak256(abi.encode(accounts[0])), keccak256(abi.encode(_account)));
    }

    function testRemoveAccount() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        vm.prank(owner);
        agreement.addAccounts(0, accounts);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.removeAccount(0, 1);

        // Should fail when removing from non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.ChainNotFound.selector);
        agreement.removeAccount(999, 1);

        // Should fail when removing non-existent account
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.AccountNotFound.selector);
        agreement.removeAccount(0, 999);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.removeAccount(0, 1);

        // Verify the change
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
