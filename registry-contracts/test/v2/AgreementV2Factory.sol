// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementV2Factory.sol";
import {AgreementV2} from "../../src/v2/AgreementV2.sol";
import "../../src/v2/AgreementDetailsV2.sol";
import {getMockAgreementDetails} from "./mock.sol";

contract AgreementFactoryV2Test is TestBase, DSTest {
    SafeHarborRegistryV2 registry;
    AgreementV2Factory factory;

    address deployer;
    address protocol;
    address owner;

    AgreementDetailsV2 agreementDetails;

    function setUp() public {
        // Set up test accounts
        deployer = address(0xD3);
        protocol = address(0xAB);
        owner = address(0xDEF);

        registry = new SafeHarborRegistryV2(address(0), deployer);
        factory = new AgreementV2Factory();

        // Set up mock agreement details
        agreementDetails = getMockAgreementDetails("0xAABB");
    }

    function test_createAndRegisterAgreemenr() public {
        vm.prank(protocol);
        address agreementAddress = factory.createAndRegisterAgreement(agreementDetails, address(registry), protocol);

        // Verify the agreement was created
        assertTrue(agreementAddress != address(0), "Agreement address should not be zero");
        assertTrue(agreementAddress.code.length > 0, "No contract deployed at agreement address");

        // Verify the details are correct
        AgreementV2 agreement = AgreementV2(agreementAddress);
        AgreementDetailsV2 memory storedDetails = agreement.getDetails();
        assertEq(keccak256(abi.encode(storedDetails)), keccak256(abi.encode(agreementDetails)));

        // Verify ownership is set to protocol
        assertEq(agreement.owner(), protocol, "Agreement owner should be protocol");
    }
}
