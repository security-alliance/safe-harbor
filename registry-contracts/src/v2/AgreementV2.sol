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

    function addChains(Chain[] memory _chains) external onlyOwner {
        for (uint256 i = 0; i < _chains.length; i++) {
            details.chains.push(_chains[i]);
        }
        emit AgreementUpdated();
    }

    function setChains(uint256[] memory _chainIds, Chain[] memory _chains) external onlyOwner {
        require(_chainIds.length == _chains.length, "Input arrays must have same length");

        for (uint256 i = 0; i < _chainIds.length; i++) {
            if (details.chains.length <= _chainIds[i]) {
                revert ChainNotFound();
            }

            details.chains[_chainIds[i]] = _chains[i];
        }

        emit AgreementUpdated();
    }

    /// @notice Removes chains from the agreement.
    /// @notice This function will move the last chain in the array to the index of
    /// @notice the removed chain, and then pop the last element. If calling this
    /// @notice function multiple times, the order of the chains will change.
    function removeChain(uint256 _chainId) external onlyOwner {
        if (details.chains.length <= _chainId) {
            revert ChainNotFound();
        }

        details.chains[_chainId] = details.chains[details.chains.length - 1];
        details.chains.pop();

        emit AgreementUpdated();
    }

    function addAccounts(uint256 _chainId, Account[] memory _accounts) external onlyOwner {
        if (details.chains.length <= _chainId) {
            revert ChainNotFound();
        }

        for (uint256 i = 0; i < _accounts.length; i++) {
            details.chains[_chainId].accounts.push(_accounts[i]);
        }

        emit AgreementUpdated();
    }

    function setAccounts(uint256 _chainId, uint256[] memory _accountIds, Account[] memory _accounts)
        external
        onlyOwner
    {
        if (details.chains.length <= _chainId) {
            revert ChainNotFound();
        }

        require(_accountIds.length == _accounts.length, "Input arrays must have same length");

        for (uint256 i = 0; i < _accountIds.length; i++) {
            if (details.chains[_chainId].accounts.length <= _accountIds[i]) {
                revert AccountNotFound();
            }
            details.chains[_chainId].accounts[_accountIds[i]] = _accounts[i];
        }

        emit AgreementUpdated();
    }

    /// @notice Function that removes an account from the agreement.
    /// @dev This function will move the last account in the array to the index of
    /// @dev the removed account, and then pop the last element. If calling this
    /// @dev function multiple times, the order of the accounts will change.
    function removeAccount(uint256 _chainId, uint256 _accountId) external onlyOwner {
        if (details.chains.length <= _chainId) {
            revert ChainNotFound();
        }

        if (details.chains[_chainId].accounts.length <= _accountId) {
            revert AccountNotFound();
        }

        uint256 lastAccountId = details.chains[_chainId].accounts.length - 1;
        details.chains[_chainId].accounts[_accountId] = details.chains[_chainId].accounts[lastAccountId];
        details.chains[_chainId].accounts.pop();
        emit AgreementUpdated();
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
