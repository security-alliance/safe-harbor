// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/SafeHarborRegistry.sol";
import "../src/Agreement_v1.sol";

contract SafeHarborRegistryTest is TestBase, DSTest {
    SafeHarborRegistry registry;
    AgreementV1Factory factory;
    AgreementDetailsV1 details;

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
            accountAddress: address(0x22),
            childContractScope: ChildContractScope.ExistingOnly
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

        // Adopt new agreement
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

    function test_adoptSafeHarbor_update() public {
        address initialAgreementAddr = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
        address newAgreementAddr = 0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81;

        // Create an initial agreement
        registry.enableFactory(address(factory));
        factory.adoptSafeHarbor(details);

        // Adopt new agreement
        details.agreementURI = "ipfs://newHash";
        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(
            tx.origin,
            initialAgreementAddr,
            newAgreementAddr
        );
        factory.adoptSafeHarbor(details);

        assertEq(registry.agreements(tx.origin), newAgreementAddr);

        AgreementV1 newAgreement = AgreementV1(newAgreementAddr);
        AgreementDetailsV1 memory newDetails = newAgreement.getDetails();
        assertEq(details, newDetails);
    }

    function testadoptSafeHarbor_disabledFactory() public {
        registry.disableFactory(address(factory));
        vm.expectRevert("Only approved factories may adopt the Safe Harbor");
        factory.adoptSafeHarbor(details);
    }

    function test_enableFactory() public {
        vm.expectEmit();
        emit SafeHarborRegistry.FactoryEnabled(address(0xff));
        registry.enableFactory(address(0xff));

        assertTrue(registry.agreementFactories(address(0xff)));
    }

    function test_enableFactory_notAdmin() public {
        vm.stopPrank();
        vm.startPrank(address(0xcc));

        vm.expectRevert("Only the admin can perform this action");
        registry.enableFactory(address(0xff));
    }

    function test_disableFactory() public {
        vm.expectEmit();
        emit SafeHarborRegistry.FactoryDisabled(address(0xff));
        registry.disableFactory(address(0xff));

        assertTrue(!registry.agreementFactories(address(0xff)));
    }

    function test_disableFactory_notAdmin() public {
        vm.stopPrank();
        vm.startPrank(address(0xcc));

        vm.expectRevert("Only the admin can perform this action");
        registry.disableFactory(address(0xff));
    }

    function test_transferAdminRights() public {
        registry.transferAdminRights(address(0xbb));

        assertEq(registry.admin(), address(0xbb));
    }

    function test_transferAdminRights_notAdmin() public {
        vm.stopPrank();
        vm.startPrank(address(0xcc));

        vm.expectRevert("Only the admin can perform this action");
        registry.transferAdminRights(address(0xbb));
    }
}
