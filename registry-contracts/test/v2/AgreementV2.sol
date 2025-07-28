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

    V2.AgreementDetailsV2 details;
    V2.AgreementV2 agreement;
    SafeHarborRegistryV2 registry;

    function setUp() public {
        mockKey = 0xA113;
        mockAddress = vm.addr(mockKey);
        owner = address(0x1);

        // Create registry and set valid chains
        registry = new SafeHarborRegistryV2(owner);
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
        assertFalse(agreement.owner() == address(0x02));
    }

    function testGetDetails() public {
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(details)), keccak256(abi.encode(_details)));
    }

    function testSetProtocolName() public {
        string memory newName = "Updated Protocol";

        // Should fail when called by non-owner
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
        vm.expectRevert();
        agreement.addChains(newChains);

        // Should fail when the chain is invalid
        V2.Chain[] memory invalidChains = new V2.Chain[](1);
        invalidChains[0] = V2.Chain({assetRecoveryAddress: "0x06", accounts: accounts, caip2ChainId: "eip155:999"});

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(V2.AgreementV2.InvalidChainId.selector, "eip155:999"));
        agreement.addChains(invalidChains);

        // Should succeed when called by owner
        vm.prank(owner);
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.addChains(newChains);

        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        V2.Chain memory _chain = _details.chains[_details.chains.length - 1];
        assertEq(keccak256(abi.encode(newChains[0])), keccak256(abi.encode(_chain)));

        // Should fail when adding duplicate chain
        vm.prank(owner);
        vm.expectRevert();
        agreement.addChains(newChains);
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
        vm.expectRevert();
        agreement.setChains(chains);

        // Should fail when chain doesn't exist
        V2.Chain[] memory nonExistentChains = new V2.Chain[](1);
        nonExistentChains[0] = V2.Chain({
            assetRecoveryAddress: "0x05",
            accounts: accounts,
            caip2ChainId: "eip155:999" // Non-existent chain
        });

        vm.prank(owner);
        vm.expectRevert();
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

    function testRemoveChain() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        V2.Chain[] memory newChains = new V2.Chain[](1);
        newChains[0] = V2.Chain({assetRecoveryAddress: "0x05", accounts: accounts, caip2ChainId: "eip155:2"});

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
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.removeChains(chainToRemove);

        // Verify the change
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(details)));
    }

    // Test adding accounts to a chain
    function testAddAccounts() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.None});

        // Should fail when called by non-owner
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

    function testRemoveAccount() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x02", childContractScope: V2.ChildContractScope.None});

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
        vm.expectEmit();
        emit V2.AgreementV2.AgreementUpdated();
        agreement.removeAccounts("eip155:1", accountToRemove);

        // Verify the change - should be back to original state
        V2.AgreementDetailsV2 memory _details = agreement.getDetails();
        assertEq(keccak256(abi.encode(_details)), keccak256(abi.encode(details)));
    }

    // Test setting bounty terms
    function testSetBountyTerms() public {
        V2.BountyTerms memory newTerms = details.bountyTerms;
        newTerms.bountyPercentage = 20;
        newTerms.bountyCapUSD = 2000000;

        // Should fail when called by non-owner
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

        // Should fail when trying to set both aggregateBountyCapUSD and retainable
        newTerms.aggregateBountyCapUSD = 1000000;
        newTerms.retainable = true;
        vm.prank(owner);
        vm.expectRevert(V2.AgreementV2.CannotSetBothAggregateBountyCapUSDAndRetainable.selector);
        agreement.setBountyTerms(newTerms);
    }

    function testConstructorCannotSetBothAggregateBountyCapUSDAndRetainable() public {
        V2.AgreementDetailsV2 memory invalidDetails = getMockAgreementDetails("0x01");
        invalidDetails.bountyTerms.aggregateBountyCapUSD = 1000;
        invalidDetails.bountyTerms.retainable = true;

        // Should fail when both conditions are true in constructor
        vm.expectRevert(V2.AgreementV2.CannotSetBothAggregateBountyCapUSDAndRetainable.selector);
        new V2.AgreementV2(invalidDetails, address(registry), owner);
    }

    function testConstructorDuplicateChainValidation() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.All});

        V2.Chain memory chain = V2.Chain({accounts: accounts, assetRecoveryAddress: "0x01", caip2ChainId: "eip155:1"});

        V2.Chain[] memory duplicateChains = new V2.Chain[](2);
        duplicateChains[0] = chain;
        duplicateChains[1] = chain;

        V2.AgreementDetailsV2 memory invalidDetails = V2.AgreementDetailsV2({
            protocolName: "testProtocol",
            chains: duplicateChains,
            contactDetails: details.contactDetails,
            bountyTerms: details.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(V2.AgreementV2.DuplicateChainId.selector, "eip155:1"));
        new V2.AgreementV2(invalidDetails, address(registry), owner);
    }

    function testConstructorInvalidChainValidation() public {
        V2.Account[] memory accounts = new V2.Account[](1);
        accounts[0] = V2.Account({accountAddress: "0x01", childContractScope: V2.ChildContractScope.All});

        V2.Chain memory chain = V2.Chain({accounts: accounts, assetRecoveryAddress: "0x01", caip2ChainId: "eip155:999"});

        V2.Chain[] memory invalidChains = new V2.Chain[](2);
        invalidChains[0] = chain;

        V2.AgreementDetailsV2 memory invalidDetails = V2.AgreementDetailsV2({
            protocolName: "testProtocol",
            chains: invalidChains,
            contactDetails: details.contactDetails,
            bountyTerms: details.bountyTerms,
            agreementURI: "ipfs://testHash"
        });

        vm.expectRevert(abi.encodeWithSelector(V2.AgreementV2.InvalidChainId.selector, "eip155:999"));
        new V2.AgreementV2(invalidDetails, address(registry), owner);
    }
}
