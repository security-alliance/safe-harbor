// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/SafeHarborRegistry.sol";
import "../src/Agreement_v1.sol";

contract AgreementV1Test is TestBase, DSTest {
    SafeHarborRegistry registry;
    AgreementV1Factory factory;
    AgreementDetailsV1 details;

    uint256 mockKey = 100;

    function setUp() public {
        address fakeAdmin = address(0xaa);

        registry = new SafeHarborRegistry(fakeAdmin);
        factory = new AgreementV1Factory(address(registry));

        details = AgreementDetailsV1({
            protocolName: "testProtocol",
            chains: new Chain[](1),
            contactDetails: new Contact[](1),
            bountyTerms: BountyTerms({
                bountyPercentage: 10,
                bountyCapUSD: 100,
                retainable: false,
                identityRequirement: IdentityRequirement.Named,
                diligenceRequirements: "testDiligenceRequirements"
            }),
            automaticallyUpgrade: false,
            agreementURI: "ipfs://testHash"
        });

        details.chains[0] = Chain({
            accounts: new Account[](1),
            assetRecoveryAddress: address(0x11),
            chainID: 1
        });

        details.chains[0].accounts[0] = Account({
            accountAddress: vm.addr(mockKey),
            childContractScope: ChildContractScope.ExistingOnly,
            signature: new bytes(0)
        });

        details.contactDetails[0] = Contact({
            name: "testName",
            role: "testRole",
            contact: "testContact"
        });

        vm.startPrank(fakeAdmin);
    }

    function assertEq(
        AgreementDetailsV1 memory expected,
        AgreementDetailsV1 memory actual
    ) public {
        bytes memory expectedBytes = abi.encode(expected);
        bytes memory actualBytes = abi.encode(actual);

        assertEq0(expectedBytes, actualBytes);
    }

    function test_adoptSafeHarbor() public {
        address newAgreementAddr = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;

        registry.enableFactory(address(factory));

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(
            tx.origin,
            address(0),
            newAgreementAddr
        );
        factory.adoptSafeHarbor(details);
        assertEq(registry.agreements(tx.origin), newAgreementAddr);

        AgreementV1 newAgreement = AgreementV1(newAgreementAddr);
        AgreementDetailsV1 memory newDetails = newAgreement.getDetails();
        assertEq(details, newDetails);
    }

    function test_validateAccount() public {
        bytes32 hash = keccak256(abi.encode(details));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mockKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        details.chains[0].accounts[0].signature = signature;

        bool isValid = factory.validateAccount(
            details,
            details.chains[0].accounts[0]
        );
        assertTrue(isValid);
    }

    function test_validateAccount_invalid() public {
        uint256 fakeKey = 200;

        bytes32 hash = keccak256(abi.encode(details));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakeKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        details.chains[0].accounts[0].signature = signature;

        bool isValid = factory.validateAccount(
            details,
            details.chains[0].accounts[0]
        );
        assertTrue(!isValid);
    }
}
