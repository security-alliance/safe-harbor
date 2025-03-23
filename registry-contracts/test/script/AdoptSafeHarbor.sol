// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/v1/SafeHarborRegistry.sol";
import "../../script/SafeHarborRegistryDeploy.s.sol";
import "../../script/AdoptSafeHarbor.s.sol";
import "../../src/v1/AgreementV1.sol";
import "../mock.sol";

contract AgreementValidatorV1Test is TestBase, DSTest {
    uint256 mockKey;
    address mockAddress;
    SafeHarborRegistry registry;
    string json;

    function setUp() public {
        // Deploy the safeharborRegistry
        string memory fakePrivateKey = "0xf0931a501a9b5fd5183d01f35526e5bc64d05d9d25d4005a8b1600ed6cd8d795";
        vm.setEnv("REGISTRY_DEPLOYER_PRIVATE_KEY", fakePrivateKey);

        SafeHarborRegistryDeploy script = new SafeHarborRegistryDeploy();
        script.run();

        address fallbackRegistry = address(0);
        address registryAddr = script.getExpectedAddress(fallbackRegistry);

        mockKey = 0xA11;
        mockAddress = vm.addr(mockKey);
        registry = SafeHarborRegistry(registryAddr);
        json = vm.readFile("test/mock.json");
    }

    function test_run() public {
        AdoptSafeHarbor script = new AdoptSafeHarbor();
        script.adopt(mockKey, registry, json);

        // Check if the agreement was adopted
        address agreementAddr = registry.getAgreement(mockAddress);
        AgreementV1 agreement = AgreementV1(agreementAddr);
        AgreementDetailsV1 memory gotDetails = agreement.getDetails();

        console.logString("--------------------------GOT--------------------------");
        logAgreementDetails(gotDetails);
        console.logString("--------------------------WANT--------------------------");
        logAgreementDetails(getMockAgreementDetails(address(0x1111111111111111111111111111111111111111)));

        assertEq(
            registry.hash(getMockAgreementDetails(address(0x1111111111111111111111111111111111111111))),
            registry.hash(gotDetails)
        );
    }
}
