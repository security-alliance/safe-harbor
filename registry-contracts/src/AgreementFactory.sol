// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Agreement } from "src/Agreement.sol";
import { AgreementDetails } from "src/types/AgreementTypes.sol";

/// @title Factory for creating Agreement contracts
/// @notice Uses CREATE2 with chain-specific salts to prevent address collisions across chains
contract AgreementFactory {
    // ----- EVENTS -----
    event AgreementCreated(address indexed agreement, address indexed owner, bytes32 salt);

    // ----- EXTERNAL FUNCTIONS -----

    /// @notice Creates an Agreement contract using CREATE2.
    /// @dev The salt includes block.chainid to ensure different addresses on different chains.
    /// @param details The agreement details
    /// @param chainValidator The Chain Validator contract address
    /// @param owner The owner of the agreement
    /// @param salt A user-provided salt for additional uniqueness
    /// @return agreementAddress The address of the created agreement
    function create(
        AgreementDetails memory details,
        address chainValidator,
        address owner,
        bytes32 salt
    )
        external
        returns (address agreementAddress)
    {
        // Include chainid in salt to prevent cross-chain address collisions
        bytes32 finalSalt = keccak256(abi.encode(block.chainid, msg.sender, salt));

        Agreement agreement = new Agreement{ salt: finalSalt }(details, chainValidator, owner);
        agreementAddress = address(agreement);

        emit AgreementCreated(agreementAddress, owner, finalSalt);

        return agreementAddress;
    }

    /// @notice Computes the address where an agreement would be deployed.
    /// @param details The agreement details
    /// @param chainValidator The Chain Validator contract address
    /// @param owner The owner of the agreement
    /// @param salt A user-provided salt
    /// @param deployer The address that will call create() (msg.sender)
    /// @return The predicted agreement address
    function computeAddress(
        AgreementDetails memory details,
        address chainValidator,
        address owner,
        bytes32 salt,
        address deployer
    )
        external
        view
        returns (address)
    {
        bytes32 finalSalt = keccak256(abi.encode(block.chainid, deployer, salt));

        bytes32 bytecodeHash =
            keccak256(bytes.concat(type(Agreement).creationCode, abi.encode(details, chainValidator, owner)));

        return address(
            uint160(uint256(keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), finalSalt, bytecodeHash))))
        );
    }
}
