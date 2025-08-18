// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Importing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../script/v2/AdoptSafeHarborV2.s.sol";
import "../../script/v2/DeployRegistryV2.s.sol";
import {getMockAgreementDetails, logAgreementDetails} from "../v2/mock.sol";

contract AdoptSafeHarborV2Test is TestBase, DSTest {
    uint256 mockKey;
    address mockAddress;
    SafeHarborRegistryV2 registry;
    AgreementFactoryV2 factory;
    string json;

    function setUp() public {
        // Deploy the safeharborRegistry
        uint256 fakePrivateKey = 0xf0931a501a9b5fd5183d01f35526e5bc64d05d9d25d4005a8b1600ed6cd8d795;
        address deployerAddress = vm.addr(fakePrivateKey);

        string memory fakePrivateKeyHex = vm.toString(fakePrivateKey);
        vm.setEnv("REGISTRY_DEPLOYER_PRIVATE_KEY", fakePrivateKeyHex);

        DeployRegistryV2 script = new DeployRegistryV2();
        script.run();

        address registryAddr = script.getExpectedRegistryAddress(deployerAddress);
        address factoryAddr = script.getExpectedFactoryAddress();

        mockKey = 0xA11;
        mockAddress = vm.addr(mockKey);
        registry = SafeHarborRegistryV2(registryAddr);
        factory = AgreementFactoryV2(factoryAddr);

        string[] memory validChains = new string[](1);
        validChains[0] = "eip155:1";

        vm.prank(deployerAddress);
        registry.setValidChains(validChains);

        json = vm.readFile("test/v2/mock.json");
    }

    function test_adopt() public {
        AdoptSafeHarborV2 script = new AdoptSafeHarborV2();
        script.adopt(mockKey, registry, factory, json, mockAddress, true);

        // Check if the agreement was adopted
        address agreementAddr = registry.getAgreement(mockAddress);
        AgreementV2 agreement = AgreementV2(agreementAddr);
        AgreementDetailsV2 memory gotDetails = agreement.getDetails();

        console.logString("--------------------------GOT--------------------------");
        logAgreementDetails(gotDetails);
        console.logString("--------------------------WANT--------------------------");
        logAgreementDetails(getMockAgreementDetails("0x1111111111111111111111111111111111111111"));

        assertEq(
            keccak256(abi.encode(getMockAgreementDetails("0x1111111111111111111111111111111111111111"))),
            keccak256(abi.encode(gotDetails))
        );
    }
}
