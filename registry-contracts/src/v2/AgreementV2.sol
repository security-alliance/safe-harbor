// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {
    AgreementDetailsV2,
    Chain,
    Account,
    Contact,
    BountyTerms,
    ChildContractScope,
    IdentityRequirements
} from "./AgreementDetailsV2.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

string constant _version = "1.1.0";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
/**
 * @dev
 * This contract is Ownable and mutable. It is intended to be used by entities adopting the
 * Safe Harbor agreement that either need to frequently update their terms, have too many terms to
 * fit in a single transaction, or wish to delegate the management of their agreement to a different
 * address than the deployer.
 */
contract AgreementV2 is Ownable {
    /// @notice The details of the agreement.
    AgreementDetailsV2 private details;

    /// ----- EVENTS -----

    /// @notice An event that records when a safe harbor agreement is updated.
    event AgreementUpdated();

    /// ----- ERRORS -----
    error ChainNotFound();
    error AccountNotFound();

    /// ----- METHODS -----

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    constructor(AgreementDetailsV2 memory _details, address _owner) Ownable(_owner) {
        details = _details;
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    function setProtocolName(string memory _protocolName) external onlyOwner {
        details.protocolName = _protocolName;
        emit AgreementUpdated();
    }

    function setContactDetails(Contact[] memory _contactDetails) external onlyOwner {
        details.contactDetails = _contactDetails;
        emit AgreementUpdated();
    }

    function addChain(Chain memory _chain) external onlyOwner {
        details.chains.push(_chain);
        emit AgreementUpdated();
    }

    function removeChain(uint256 _chainId) external onlyOwner {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (details.chains[i].id != _chainId) {
                continue;
            }

            details.chains[i] = details.chains[details.chains.length - 1];
            details.chains.pop();
            emit AgreementUpdated();
            return;
        }

        revert ChainNotFound();
    }

    function addAccount(uint256 _chainId, Account memory _account) external onlyOwner {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (details.chains[i].id != _chainId) {
                continue;
            }

            details.chains[i].accounts.push(_account);
            emit AgreementUpdated();
            return;
        }

        revert ChainNotFound();
    }

    function removeAccount(uint256 _chainId, string memory _account) external onlyOwner {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (details.chains[i].id != _chainId) {
                continue;
            }

            for (uint256 j = 0; j < details.chains[i].accounts.length; j++) {
                if (
                    keccak256(abi.encodePacked(details.chains[i].accounts[j].accountAddress))
                        != keccak256(abi.encodePacked(_account))
                ) {
                    continue;
                }

                details.chains[i].accounts[j] = details.chains[i].accounts[details.chains[i].accounts.length - 1];
                details.chains[i].accounts.pop();
                emit AgreementUpdated();
                return;
            }
        }

        revert AccountNotFound();
    }

    function setBountyTerms(BountyTerms memory _bountyTerms) external onlyOwner {
        details.bountyTerms = _bountyTerms;
        emit AgreementUpdated();
    }

    /// @notice Function that returns the details of the agreement.
    /// @dev You need a view function, else it won't convert storage to memory automatically for the nested structs.
    /// @return AgreementDetailsV2 The details of the agreement.
    function getDetails() external view returns (AgreementDetailsV2 memory) {
        return details;
    }
}
