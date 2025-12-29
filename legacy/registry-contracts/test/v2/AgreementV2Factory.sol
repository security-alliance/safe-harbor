// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../../src/v2/SafeHarborRegistryV2.sol";
import "../../src/v2/AgreementFactoryV2.sol";
import {AgreementV2} from "../../src/v2/AgreementV2.sol";
import "../../src/v2/AgreementDetailsV2.sol";
import {getMockAgreementDetails} from "./mock.sol";

contract AgreementFactoryV2Test is TestBase, DSTest {
    SafeHarborRegistryV2 registry;
    AgreementFactoryV2 factory;

    address deployer;
    address protocol;

    AgreementDetailsV2 agreementDetails;

    function setUp() public {
        deployer = address(0xD3);
        protocol = address(0xAB);

        registry = new SafeHarborRegistryV2(deployer);
        factory = new AgreementFactoryV2();

        string[] memory validChains = new string[](2);
        validChains[0] = "eip155:1";
        validChains[1] = "eip155:2";
        vm.prank(deployer);
        registry.setValidChains(validChains);

        agreementDetails = getMockAgreementDetails("0xAABB");
    }

    function test_create() public {
        vm.prank(protocol);
        address agreementAddress = factory.create(agreementDetails, address(registry), protocol);

        AgreementV2 agreement = AgreementV2(agreementAddress);
        AgreementDetailsV2 memory storedDetails = agreement.getDetails();
        assertEq(keccak256(abi.encode(storedDetails)), keccak256(abi.encode(agreementDetails)));

        assertEq(agreement.owner(), protocol, "Agreement owner should be protocol");
    }
}
