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
import {SafeHarborRegistryV2, VERSION} from "./SafeHarborRegistryV2.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
/**
 * @dev
 * This contract is Ownable and mutable. It is intended to be used by entities adopting the
 * Safe Harbor agreement that either need to frequently update their terms, have too many terms to
 * fit in a single transaction, or wish to delegate the management of their agreement to a different
 * address than the deployer.
 */
contract AgreementV2 is Ownable {
    // ----- STATE VARIABLES -----

    /// @notice The details of the agreement.
    AgreementDetailsV2 private details;

    /// @notice The Safe Harbor Registry V2 contract
    SafeHarborRegistryV2 private registry;

    /// @notice Temporary mapping used for duplicate chain ID validation
    mapping(bytes32 => bool) private _tempChainIdSeen;

    // ----- EVENTS -----

    /// @notice An event that records when a safe harbor agreement is updated.
    event AgreementUpdated();

    // ----- ERRORS -----

    error ChainNotFound();
    error AccountNotFound();
    error CannotSetBothAggregateBountyCapUSDAndRetainable();
    error ChainNotFoundByCaip2Id(string caip2ChainId);
    error AccountNotFoundByAddress(string caip2ChainId, string accountAddress);
    error DuplicateChainId(string caip2ChainId);
    error InvalidChainId(string caip2ChainId);

    // ----- CONSTRUCTOR -----

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    /// @param _registry The address of the Safe Harbor Registry V2 contract
    /// @param _owner The owner of the agreement
    constructor(AgreementDetailsV2 memory _details, address _registry, address _owner) Ownable(_owner) {
        registry = SafeHarborRegistryV2(_registry);
        _validateBountyTerms(_details.bountyTerms);
        _validateNoDuplicateChainIds(_details.chains);
        _validateChainIds(_details.chains);
        details = _details;
    }

    // ----- EXTERNAL FUNCTIONS -----

    function version() external pure returns (string memory) {
        return VERSION;
    }

    /// @notice Function that returns the agreement details
    /// @dev You need a view function, else it won't convert storage to memory automatically for the nested structs.
    function getDetails() external view returns (AgreementDetailsV2 memory) {
        return details;
    }

    /// @notice Function that sets the protocol name
    function setProtocolName(string memory _protocolName) external onlyOwner {
        details.protocolName = _protocolName;
        emit AgreementUpdated();
    }

    /// @notice Function that sets the agreement contact details.
    function setContactDetails(Contact[] memory _contactDetails) external onlyOwner {
        details.contactDetails = _contactDetails;
        emit AgreementUpdated();
    }

    /// @notice Function that adds multiple chains to the agreement.
    function addChains(Chain[] memory _chains) external onlyOwner {
        // Validate chain IDs are valid
        _validateChainIds(_chains);
        // Validate no duplicates with existing chains
        for (uint256 i = 0; i < _chains.length; i++) {
            details.chains.push(_chains[i]);
        }
        _validateNoDuplicateChainIds(details.chains);

        emit AgreementUpdated();
    }

    /// @notice Function that sets multiple chains in the agreement, keeping existing chains.
    /// @dev This function replaces the existing chains with the new ones.
    function setChains(Chain[] memory _chains) external onlyOwner {
        for (uint256 i = 0; i < _chains.length; i++) {
            uint256 chainIndex = _findChainIndex(_chains[i].caip2ChainId);
            details.chains[chainIndex] = _chains[i];
        }

        emit AgreementUpdated();
    }

    /// @notice Removes multiple chains from the agreement by CAIP-2 IDs.
    /// @param _caip2ChainIds Array of CAIP-2 IDs of the chains to remove
    function removeChains(string[] memory _caip2ChainIds) external onlyOwner {
        for (uint256 i = 0; i < _caip2ChainIds.length; i++) {
            uint256 chainIndex = _findChainIndex(_caip2ChainIds[i]);
            details.chains[chainIndex] = details.chains[details.chains.length - 1];
            details.chains.pop();
        }
        emit AgreementUpdated();
    }

    /// @notice Function that adds multiple accounts to the agreement.
    /// @param _caip2ChainId The CAIP-2 ID of the chain
    /// @param _accounts Array of accounts to add
    function addAccounts(string memory _caip2ChainId, Account[] memory _accounts) external onlyOwner {
        uint256 chainIndex = _findChainIndex(_caip2ChainId);

        for (uint256 i = 0; i < _accounts.length; i++) {
            details.chains[chainIndex].accounts.push(_accounts[i]);
        }

        emit AgreementUpdated();
    }

    /// @notice Function that removes multiple accounts from the agreement by addresses.
    /// @param _caip2ChainId The CAIP-2 ID of the chain containing the accounts
    /// @param _accountAddresses Array of account addresses to remove
    function removeAccounts(string memory _caip2ChainId, string[] memory _accountAddresses) external onlyOwner {
        uint256 chainIndex = _findChainIndex(_caip2ChainId);
        for (uint256 i = 0; i < _accountAddresses.length; i++) {
            uint256 accountIndex = _findAccountIndex(chainIndex, _accountAddresses[i]);

            uint256 lastAccountId = details.chains[chainIndex].accounts.length - 1;
            details.chains[chainIndex].accounts[accountIndex] = details.chains[chainIndex].accounts[lastAccountId];
            details.chains[chainIndex].accounts.pop();
        }
        emit AgreementUpdated();
    }

    /// @notice Function that sets the bounty terms of the agreement.
    function setBountyTerms(BountyTerms memory _bountyTerms) external onlyOwner {
        _validateBountyTerms(_bountyTerms);
        details.bountyTerms = _bountyTerms;
        emit AgreementUpdated();
    }

    // ----- INTERNAL FUNCTIONS -----

    /// @notice Internal function to validate that chains don't have duplicate CAIP-2 IDs
    function _validateNoDuplicateChainIds(Chain[] memory _chains) internal {
        // Clean up the temporary mapping
        for (uint256 i = 0; i < _chains.length; i++) {
            bytes32 chainIdHash = keccak256(bytes(_chains[i].caip2ChainId));
            delete _tempChainIdSeen[chainIdHash];
        }

        // Check for duplicates
        for (uint256 i = 0; i < _chains.length; i++) {
            bytes32 chainIdHash = keccak256(bytes(_chains[i].caip2ChainId));
            if (_tempChainIdSeen[chainIdHash]) {
                revert DuplicateChainId(_chains[i].caip2ChainId);
            }
            _tempChainIdSeen[chainIdHash] = true;
        }
    }

    /// @notice Internal function to validate that all chain IDs in the agreement are valid
    function _validateChainIds(Chain[] memory _chains) internal view {
        for (uint256 i = 0; i < _chains.length; i++) {
            if (!registry.isChainValid(_chains[i].caip2ChainId)) {
                revert InvalidChainId(_chains[i].caip2ChainId);
            }
        }
    }

    /// @notice Internal function to validate bounty terms
    function _validateBountyTerms(BountyTerms memory _bountyTerms) internal pure {
        if (_bountyTerms.aggregateBountyCapUSD > 0 && _bountyTerms.retainable) {
            revert CannotSetBothAggregateBountyCapUSDAndRetainable();
        }
    }

    /// @notice Internal function to find chain index by CAIP-2 ID
    function _findChainIndex(string memory _caip2ChainId) internal view returns (uint256 chainIndex) {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (keccak256(bytes(details.chains[i].caip2ChainId)) == keccak256(bytes(_caip2ChainId))) {
                return i;
            }
        }
        revert ChainNotFoundByCaip2Id(_caip2ChainId);
    }

    /// @notice Internal function to find account index by address within a chain
    function _findAccountIndex(uint256 _chainIndex, string memory _accountAddress)
        internal
        view
        returns (uint256 accountIndex)
    {
        for (uint256 i = 0; i < details.chains[_chainIndex].accounts.length; i++) {
            if (
                keccak256(bytes(details.chains[_chainIndex].accounts[i].accountAddress))
                    == keccak256(bytes(_accountAddress))
            ) {
                return i;
            }
        }
        revert AccountNotFoundByAddress(details.chains[_chainIndex].caip2ChainId, _accountAddress);
    }
}
