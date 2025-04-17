// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgreementV2} from "./AgreementV2.sol";
import {SafeHarborRegistryV2} from "./SafeHarborRegistryV2.sol";
import {AgreementDetailsV2} from "./AgreementDetailsV2.sol";

/// @title Factory for creating AgreementV2 contracts
contract AgreementV2Factory {
    /// @notice Creates an AgreementV2 contract.
    function create(AgreementDetailsV2 memory details, address owner) external returns (address agreementAddress) {
        AgreementV2 agreement = new AgreementV2(details, owner);
        agreementAddress = address(agreement);
        return agreementAddress;
    }
}
