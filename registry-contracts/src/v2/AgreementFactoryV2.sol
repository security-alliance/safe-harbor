// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgreementV2} from "./AgreementV2.sol";
import {SafeHarborRegistryV2} from "./SafeHarborRegistryV2.sol";
import {AgreementDetailsV2} from "./AgreementDetailsV2.sol";

/// @title Factory for creating AgreementV2 contracts
contract AgreementFactoryV2 {
    /// @notice Creates an AgreementV2 contract.
    /// @param details The agreement details
    /// @param registry The Safe Harbor Registry V2 address
    /// @param owner The owner of the agreement
    function create(AgreementDetailsV2 memory details, address registry, address owner)
        external
        returns (address agreementAddress)
    {
        AgreementV2 agreement = new AgreementV2(details, registry, owner);
        agreementAddress = address(agreement);
        return agreementAddress;
    }
}
