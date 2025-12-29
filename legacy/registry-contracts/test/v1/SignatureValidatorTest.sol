// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Imporing these packages directly due to naming conflicts between "Account" and "Chain" structs.
import {TestBase} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/v1/SignatureValidator.sol";

contract SignatureValidatorTest is TestBase, DSTest {
    SignatureValidator validator;

    function setUp() public {
        validator = new SignatureValidator();
    }

    /// @notice Test isSignatureValid function with a valid EOA.
    function test_isSignatureValid_EOA() public {
        uint256 key = 100;

        bytes32 hash = keccak256(abi.encodePacked("Safe Harbor"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool isValid = validator.isSignatureValid(vm.addr(key), hash, signature);
        assertTrue(isValid);
    }

    /// @notice Test isSignatureValid function with an invalid EOA.
    function test_isSignatureValid_EOA_invalid() public {
        uint256 key = 100;
        address invalidAddress = address(0x11);

        bytes32 hash = keccak256(abi.encodePacked("Safe Harbor"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool isValid = validator.isSignatureValid(invalidAddress, hash, signature);
        assertTrue(!isValid);
    }

    /// @notice Test isSignatureValid function with a valid ERC1271 contract.
    function test_isSignatureValid_contract() public {
        uint256 key = 100;

        bytes32 hash = keccak256(abi.encodePacked("Safe Harbor"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        FakeERC1271 fakeContract = new FakeERC1271(hash, signature);
        bool isValid = validator.isSignatureValid(address(fakeContract), hash, signature);

        assertTrue(isValid);
    }

    /// @notice Test isSignatureValid function with an invalid valid ERC1271 contract.
    function test_isSignatureValid_contract_invalid() public {
        uint256 key = 100;
        bytes memory fakesignature = abi.encodePacked(uint256(1));

        bytes32 hash = keccak256(abi.encodePacked("Safe Harbor"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        FakeERC1271 fakeContract = new FakeERC1271(hash, fakesignature);
        bool isValid = validator.isSignatureValid(address(fakeContract), hash, signature);

        assertTrue(!isValid);
    }
}

contract FakeERC1271 {
    bytes32 wantHash;
    bytes wantSignature;

    constructor(bytes32 _wantHash, bytes memory _wantSignature) {
        wantHash = _wantHash;
        wantSignature = _wantSignature;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        if (hash == wantHash && keccak256(signature) == keccak256(wantSignature)) {
            return 0x1626ba7e;
        }
        return 0x0;
    }
}
