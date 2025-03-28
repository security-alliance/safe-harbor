// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol" as Test;
import "../../src/v2/AgreementV2.sol" as V2;
import "../../src/v1/AgreementV1.sol" as V1;
import "../mock.sol";

contract AgreementV2Test is Test.Test {
    uint256 mockKey;
    address mockAddress;
    address owner;
    address notOwner;

    V1.AgreementDetailsV1 details;
    V2.AgreementV2 agreement;

    function setUp() public {
        mockKey = 0xA11CE;
        mockAddress = vm.addr(mockKey);
        owner = address(0x1);
        notOwner = address(0x2);

        details = getMockAgreementDetails(mockAddress);
        agreement = new V2.AgreementV2(details, owner);
    }

    function testOwner() public {
        assertEq(agreement.owner(), owner);
        assertFalse(agreement.owner() == notOwner);
    }

    function testGetDetails() public {
        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
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
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.setProtocolName(newName);

        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        assertEq(_details.protocolName, newName);
    }

    function testSetContactDetails() public {
        V1.Contact[] memory newContacts = new V1.Contact[](2);
        newContacts[0] = V1.Contact({name: "New Contact 1", contact: "@newcontact1"});

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setContactDetails(newContacts);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.setContactDetails(newContacts);

        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(newContacts)), keccak256(abi.encode(_details.contactDetails)));
    }

    function testAddChains() public {
        V1.Account[] memory accounts = new V1.Account[](1);
        accounts[0] = V1.Account({
            accountAddress: address(0x4),
            childContractScope: V1.ChildContractScope.None,
            signature: new bytes(0)
        });

        V1.Chain memory newChain = V1.Chain({assetRecoveryAddress: address(0x11), accounts: accounts, id: 2});

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.addChain(newChain);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.addChain(newChain);
        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        V1.Chain memory _chain = _details.chains[_details.chains.length - 1];

        assertEq(keccak256(abi.encode(newChain)), keccak256(abi.encode(_chain)));
    }

    function testRemoveChain() public {
        uint256 chainId = 2;

        V1.Account[] memory accounts = new V1.Account[](1);
        accounts[0] = V1.Account({
            accountAddress: address(0x4),
            childContractScope: V1.ChildContractScope.None,
            signature: new bytes(0)
        });

        V1.Chain memory newChain = V1.Chain({assetRecoveryAddress: address(0x11), accounts: accounts, id: chainId});

        vm.prank(owner);
        agreement.addChain(newChain);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.removeChain(chainId);

        // Should fail when removing non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.ChainNotFound.selector);
        agreement.removeChain(999);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.removeChain(chainId);

        // Verify the change
        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(details)));
    }

    // Test adding accounts to a chain
    function testAddAccount() public {
        V1.Account memory newAccount = V1.Account({
            accountAddress: address(0x5),
            childContractScope: V1.ChildContractScope.None,
            signature: new bytes(0)
        });

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.addAccount(1, newAccount);

        // Should fail when adding to non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.ChainNotFound.selector);
        agreement.addAccount(999, newAccount);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.addAccount(1, newAccount);

        // Verify the change
        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        V1.Account memory _account = _details.chains[0].accounts[_details.chains[0].accounts.length - 1];

        assertEq(keccak256(abi.encode(newAccount)), keccak256(abi.encode(_account)));
    }

    function testRemoveAccount() public {
        address accountAddress = address(0x5);
        uint256 chainId = 1;

        V1.Account memory newAccount = V1.Account({
            accountAddress: accountAddress,
            childContractScope: V1.ChildContractScope.None,
            signature: new bytes(0)
        });

        vm.prank(owner);
        agreement.addAccount(chainId, newAccount);

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.removeAccount(chainId, accountAddress);

        // Should fail when removing from non-existent chain
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.AccountNotFound.selector);
        agreement.removeAccount(999, accountAddress);

        // Should fail when removing non-existent account
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.AccountNotFound.selector);
        agreement.removeAccount(chainId, address(0x6));

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.removeAccount(chainId, accountAddress);

        // Verify the change
        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(details)));
    }

    // Test setting bounty terms
    function testSetBountyTerms() public {
        V1.BountyTerms memory newTerms = V1.BountyTerms({
            bountyPercentage: 20,
            bountyCapUSD: 1000000,
            retainable: true,
            identity: V1.IdentityRequirements.Named,
            diligenceRequirements: "Diligence"
        });

        // Should fail when called by non-owner
        vm.prank(notOwner);
        vm.expectRevert();
        agreement.setBountyTerms(newTerms);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.SafeHarborUpdate();
        agreement.setBountyTerms(newTerms);

        // Verify the change
        V1.AgreementDetailsV1 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(newTerms)), keccak256(abi.encode(_details.bountyTerms)));
    }
}
