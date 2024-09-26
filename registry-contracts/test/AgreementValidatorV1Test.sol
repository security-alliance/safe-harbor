// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/SafeHarborRegistry.sol";
import "../src/AgreementV1.sol";
import "./mock.sol";

contract AgreementValidatorV1Test is TestBase, DSTest {
    AgreementValidatorV1 validator;
    AgreementDetailsV1 details;

    uint256 mockKey = 100;

    function setUp() public {
        validator = new AgreementValidatorV1();
        details = getMockAgreementDetails(vm.addr(mockKey));
    }

    function assertEq(AgreementDetailsV1 memory expected, AgreementDetailsV1 memory actual) public {
        bytes memory expectedBytes = abi.encode(expected);
        bytes memory actualBytes = abi.encode(actual);

        assertEq0(expectedBytes, actualBytes);
    }

    function test_validateAccount() public {
        bytes32 digest = validator.encode(validator.DOMAIN_SEPARATOR(), details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mockKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        details.chains[0].accounts[0].signature = signature;

        bool isValid = validator.validateAccount(details, details.chains[0].accounts[0]);
        assertTrue(isValid);
    }

    function test_validateAccount_invalid() public {
        uint256 fakeKey = 200;

        bytes32 digest = validator.encode(validator.DOMAIN_SEPARATOR(), details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakeKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        details.chains[0].accounts[0].signature = signature;

        bool isValid = validator.validateAccount(details, details.chains[0].accounts[0]);
        assertTrue(!isValid);
    }

    function test_validateAccountByAddress() public {
        //* Deploy a new AgreementV1
        AgreementV1 newAgreement = new AgreementV1(details);
        address newAgreementAddr = address(newAgreement);

        //* Sign the details with the mock key
        bytes32 digest = validator.encode(validator.DOMAIN_SEPARATOR(), details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mockKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Update the account's signature in the details
        details.chains[0].accounts[0].signature = signature;

        //* Validate the signature using validateAccountByAddress
        bool isValid = validator.validateAccountByAddress(newAgreementAddr, details.chains[0].accounts[0]);

        //* Assert that the validation is successful
        assertTrue(isValid);
    }

    function test_validateAccountByAddress_invalid() public {
        //* Deploy a new AgreementV1
        AgreementV1 newAgreement = new AgreementV1(details);
        address newAgreementAddr = address(newAgreement);

        //* Sign the details with a fake key (to simulate an invalid signature)
        uint256 fakeKey = 200;
        bytes32 digest = validator.encode(validator.DOMAIN_SEPARATOR(), details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakeKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Update the account's signature in the details with an invalid signature
        details.chains[0].accounts[0].signature = signature;

        //* Validate the signature using validateAccountByAddress
        bool isValid = validator.validateAccountByAddress(newAgreementAddr, details.chains[0].accounts[0]);

        //* Assert that the validation fails
        assertTrue(!isValid);
    }
}
