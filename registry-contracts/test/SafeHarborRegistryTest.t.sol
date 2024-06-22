// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages instead of Test because naming conflicts between "Accounts" and "Chains" against
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
        registry = new SafeHarborRegistry();
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
            assetRecoveryAddress: address(0x1),
            chainID: 1
        });

        details.chains[0].accounts[0] = Account({
            accountAddress: address(0x2),
            includeChildContracts: false,
            includeNewChildContracts: false
        });

        details.contactDetails[0] = Contact({
            name: "testName",
            role: "testRole",
            contact: "testContact"
        });
    }

    function assertEqualDetails(
        AgreementDetailsV1 memory details1,
        AgreementDetailsV1 memory details2
    ) public {
        assertEq(details1.protocolName, details2.protocolName);

        for (uint256 i = 0; i < details1.chains.length; i++) {
            assertEq(details1.chains[i].chainID, details2.chains[i].chainID);
            assertEq(
                details1.chains[i].assetRecoveryAddress,
                details2.chains[i].assetRecoveryAddress
            );

            for (uint256 j = 0; j < details1.chains[i].accounts.length; j++) {
                assertEq(
                    details1.chains[i].accounts[j].accountAddress,
                    details2.chains[i].accounts[j].accountAddress
                );
                assertTrue(
                    details1.chains[i].accounts[j].includeChildContracts ==
                        details2.chains[i].accounts[j].includeChildContracts
                );
                assertTrue(
                    details1.chains[i].accounts[j].includeNewChildContracts ==
                        details2.chains[i].accounts[j].includeNewChildContracts
                );
            }
        }

        for (uint256 i = 0; i < details1.contactDetails.length; i++) {
            assertEq(
                details1.contactDetails[i].name,
                details2.contactDetails[i].name
            );
            assertEq(
                details1.contactDetails[i].role,
                details2.contactDetails[i].role
            );
            assertEq(
                details1.contactDetails[i].contact,
                details2.contactDetails[i].contact
            );
        }

        assertEq(
            details1.bountyTerms.bountyPercentage,
            details2.bountyTerms.bountyPercentage
        );
        assertEq(
            details1.bountyTerms.bountyCapUSD,
            details2.bountyTerms.bountyCapUSD
        );
        assertTrue(
            details1.bountyTerms.retainable == details2.bountyTerms.retainable
        );
        assertTrue(
            details1.bountyTerms.identityRequirement ==
                details2.bountyTerms.identityRequirement
        );
        assertEq(
            details1.bountyTerms.diligenceRequirements,
            details2.bountyTerms.diligenceRequirements
        );
        assertTrue(
            details1.automaticallyUpgrade == details2.automaticallyUpgrade
        );
        assertEq(details1.agreementURI, details2.agreementURI);
    }

    function test_adoptSafeHarbor() public {
        // Impersonating the admin to enable the factory
        vm.prank(tx.origin);
        registry.enableFactory(address(factory));

        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(
            address(tx.origin),
            address(0),
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac)
        );
        factory.adoptSafeHarbor(details);
        assertEq(
            registry.agreements(address(tx.origin)),
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac)
        );

        // Make sure the agreement was recorded correctly
        AgreementV1 agreement = AgreementV1(
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac)
        );

        AgreementDetailsV1 memory outputDetails = agreement.getDetails();

        assertEqualDetails(details, outputDetails);
    }

    function test_updateSafeHarbor() public {
        // Impersonating the admin to enable the factory
        vm.prank(tx.origin);
        registry.enableFactory(address(factory));
        factory.adoptSafeHarbor(details);
        details.agreementURI = "ipfs://newHash";
        vm.expectEmit();
        emit SafeHarborRegistry.SafeHarborAdoption(
            address(tx.origin),
            address(0xffD4505B3452Dc22f8473616d50503bA9E1710Ac),
            address(0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81)
        );
        factory.adoptSafeHarbor(details);

        assertEq(
            registry.agreements(address(tx.origin)),
            address(0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81)
        );

        // Make sure the agreement was recorded correctly
        AgreementV1 agreement = AgreementV1(
            address(0x8d2C17FAd02B7bb64139109c6533b7C2b9CADb81)
        );

        AgreementDetailsV1 memory outputDetails = agreement.getDetails();

        assertEqualDetails(details, outputDetails);
    }

    function test_unableToAdoptWithoutApprovedFactory() public {
        vm.expectRevert("Only approved factories may adopt the Safe Harbor");
        factory.adoptSafeHarbor(details);
    }

    function test_enableFactory() public {
        vm.expectEmit();
        emit SafeHarborRegistry.FactoryEnabled(address(factory));
        // Impersonating the admin to enable the factory
        vm.prank(tx.origin);
        registry.enableFactory(address(factory));
        assertTrue(registry.agreementFactories(address(factory)));
    }

    function test_disableFactory() public {
        // Impersonating the admin to enable the factory
        vm.prank(tx.origin);
        registry.enableFactory(address(factory));
        vm.expectEmit();
        emit SafeHarborRegistry.FactoryDisabled(address(factory));
        // Impersonating the admin to disable the factory
        vm.prank(tx.origin);
        registry.disableFactory(address(factory));
        assertTrue(!registry.agreementFactories(address(factory)));
    }

    function test_transferAdminRights() public {
        address newAdmin = address(0x1);
        // Impersonating the admin to transfer admin rights
        vm.prank(tx.origin);
        registry.transferAdminRights(newAdmin);
        assertEq(registry.admin(), newAdmin);
    }
}
