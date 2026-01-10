// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AgreementDetails, Chain, Account, Contact, BountyTerms } from "src/types/AgreementTypes.sol";
import { IChainValidator } from "src/interface/IChainValidator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { _hashString } from "src/utils/Utils.sol";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
/**
 * @dev
 * This contract is Ownable and mutable. It is intended to be used by entities adopting the
 * Safe Harbor agreement that either need to frequently update their terms, have too many terms to
 * fit in a single transaction, or wish to delegate the management of their agreement to a different
 * address than the deployer.
 */
// aderyn-ignore-next-line(centralization-risk)
contract Agreement is Ownable {
    // ----- ERRORS -----
    error Agreement__CannotSetBothAggregateBountyCapUsdAndRetainable();
    error Agreement__ChainNotFoundByCaip2Id(string caip2ChainId);
    error Agreement__AccountNotFoundByAddress(string caip2ChainId, string accountAddress);
    error Agreement__DuplicateChainId(string caip2ChainId);
    error Agreement__InvalidChainId(string caip2ChainId);
    error Agreement__ZeroAccountsForChainId(string caip2ChainId);
    error Agreement__ChainIdHasZeroLength();
    error Agreement__InvalidAssetRecoveryAddress(string caip2ChainId);
    error Agreement__ZeroAddress();
    error Agreement__BountyPercentageExceedsMaximum(uint256 bountyPercentage, uint256 maxPercentage);
    error Agreement__AggregateBountyCapLessThanBountyCap(uint256 aggregateBountyCapUSD, uint256 bountyCapUSD);
    error Agreement__InvalidAccountAddress(string caip2ChainId, uint256 accountIndex);
    error Agreement__InvalidContactDetails(uint256 contactIndex);
    error Agreement__CannotRemoveAllAccounts(string caip2ChainId);

    // ----- CONSTANTS -----
    /// @notice Maximum allowed bounty percentage (100%)
    uint256 public constant MAX_BOUNTY_PERCENTAGE = 100;

    // ----- STATE VARIABLES -----
    /// @notice Slot used for transient storage duplicate chain ID checking
    bytes32 private constant _DUPLICATE_CHECK_SLOT = keccak256("Agreement.duplicateChainIdCheck");

    /// @notice The Chain Validator contract for validating CAIP-2 chain IDs
    IChainValidator private immutable CHAIN_VALIDATOR;

    // Agreement details stored as separate variables to avoid requiring via-ir compiler
    string private protocolName;
    Contact[] private contactDetails;
    BountyTerms private bountyTerms;
    string private agreementURI;

    // Chain data stored separately to avoid nested struct issues
    string[] private chainIds;
    mapping(string caip2ChainId => string assetRecoveryAddress) private assetRecoveryAddresses;
    mapping(string caip2ChainId => Account[]) private accounts;

    // ----- EVENTS -----
    event ProtocolNameSet(string newName);
    event ContactDetailsSet(Contact[] newContactDetails);
    event ChainAdded(string caip2ChainId, string assetRecoveryAddress, Account[] accounts);
    event ChainSet(string caip2ChainId, string assetRecoveryAddress, Account[] accounts);
    event ChainRemoved(string caip2ChainId);
    event AccountAdded(string caip2ChainId, Account account);
    event AccountRemoved(string caip2ChainId, string accountAddress);
    event BountyTermsSet(BountyTerms newBountyTerms);

    // ----- CONSTRUCTOR -----

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    /// @param _chainValidator The address of the Chain Validator contract
    /// @param _initialOwner The owner of the agreement
    constructor(
        AgreementDetails memory _details,
        address _chainValidator,
        address _initialOwner
    )
        Ownable(_initialOwner)
    {
        if (_chainValidator == address(0)) {
            revert Agreement__ZeroAddress();
        }
        CHAIN_VALIDATOR = IChainValidator(_chainValidator);
        _validateBountyTerms(_details.bountyTerms);
        _validateContactDetails(_details.contactDetails);
        _validateChains(_details.chains);
        _setDetails(_details);
    }

    // ----- USER-FACING STATE-CHANGING FUNCTIONS -----

    /// @notice Function that sets the protocol name
    // aderyn-ignore-next-line(centralization-risk)
    function setProtocolName(string calldata _protocolName) external onlyOwner {
        emit ProtocolNameSet(_protocolName);
        protocolName = _protocolName;
    }

    /// @notice Function that sets the agreement contact details.
    // aderyn-ignore-next-line(centralization-risk)
    function setContactDetails(Contact[] calldata _contactDetails) external onlyOwner {
        _validateContactDetails(_contactDetails);
        emit ContactDetailsSet(_contactDetails);
        delete contactDetails;
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _contactDetails.length; i++) {
            contactDetails.push(_contactDetails[i]);
        }
    }

    /// @notice Function that adds multiple chains to the agreement.
    // aderyn-ignore-next-line(centralization-risk)
    function addChains(Chain[] calldata _chains) external onlyOwner {
        _validateChains(_chains);
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _chains.length; i++) {
            string memory chainId = _chains[i].caip2ChainId;
            if (_chainExists(chainId)) {
                revert Agreement__DuplicateChainId(chainId);
            }
            emit ChainAdded(chainId, _chains[i].assetRecoveryAddress, _chains[i].accounts);
            chainIds.push(chainId);
            assetRecoveryAddresses[chainId] = _chains[i].assetRecoveryAddress;
            // aderyn-ignore-next-line(costly-loop)
            for (uint256 j = 0; j < _chains[i].accounts.length; j++) {
                accounts[chainId].push(_chains[i].accounts[j]);
            }
        }
    }

    /// @notice Adds or updates chains in the agreement
    // aderyn-ignore-next-line(centralization-risk)
    function addOrSetChains(Chain[] memory _chains) external onlyOwner {
        _validateChains(_chains);
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _chains.length; i++) {
            string memory chainId = _chains[i].caip2ChainId;
            bool exists = _chainExists(chainId);
            if (!exists) {
                chainIds.push(chainId);
                emit ChainAdded(chainId, _chains[i].assetRecoveryAddress, _chains[i].accounts);
            } else {
                emit ChainSet(chainId, _chains[i].assetRecoveryAddress, _chains[i].accounts);
            }
            assetRecoveryAddresses[chainId] = _chains[i].assetRecoveryAddress;
            delete accounts[chainId];
            // aderyn-ignore-next-line(costly-loop)
            for (uint256 j = 0; j < _chains[i].accounts.length; j++) {
                accounts[chainId].push(_chains[i].accounts[j]);
            }
        }
    }

    /// @notice Function that sets multiple chains in the agreement, keeping existing chains.
    /// @dev This function replaces the existing chains with the new ones.
    // aderyn-ignore-next-line(centralization-risk)
    function setChains(Chain[] memory _chains) external onlyOwner {
        _validateChains(_chains);
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _chains.length; i++) {
            string memory chainId = _chains[i].caip2ChainId;
            if (!_chainExists(chainId)) {
                revert Agreement__ChainNotFoundByCaip2Id(chainId);
            }
            emit ChainSet(chainId, _chains[i].assetRecoveryAddress, _chains[i].accounts);
            assetRecoveryAddresses[chainId] = _chains[i].assetRecoveryAddress;
            delete accounts[chainId];
            // aderyn-ignore-next-line(costly-loop)
            for (uint256 j = 0; j < _chains[i].accounts.length; j++) {
                accounts[chainId].push(_chains[i].accounts[j]);
            }
        }
    }

    /// @notice Removes multiple chains from the agreement by CAIP-2 IDs.
    /// @param _caip2ChainIds Array of CAIP-2 IDs of the chains to remove
    // aderyn-ignore-next-line(centralization-risk)
    function removeChains(string[] memory _caip2ChainIds) external onlyOwner {
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _caip2ChainIds.length; i++) {
            string memory chainId = _caip2ChainIds[i];
            uint256 idx = _findChainIndex(chainId);
            emit ChainRemoved(chainId);
            delete assetRecoveryAddresses[chainId];
            delete accounts[chainId];
            uint256 lastIdx = chainIds.length - 1;
            if (idx != lastIdx) {
                chainIds[idx] = chainIds[lastIdx];
            }
            chainIds.pop();
        }
    }

    /// @notice Function that adds multiple accounts to the agreement.
    /// @param _caip2ChainId The CAIP-2 ID of the chain
    /// @param _accounts Array of accounts to add
    // aderyn-ignore-next-line(centralization-risk)
    function addAccounts(string memory _caip2ChainId, Account[] calldata _accounts) external onlyOwner {
        if (!_chainExists(_caip2ChainId)) {
            revert Agreement__ChainNotFoundByCaip2Id(_caip2ChainId);
        }
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _accounts.length; i++) {
            emit AccountAdded(_caip2ChainId, _accounts[i]);
            accounts[_caip2ChainId].push(_accounts[i]);
        }
    }

    /// @notice Function that removes multiple accounts from the agreement by addresses.
    /// @param _caip2ChainId The CAIP-2 ID of the chain containing the accounts
    /// @param _accountAddresses Array of account addresses to remove
    // aderyn-ignore-next-line(centralization-risk)
    function removeAccounts(string memory _caip2ChainId, string[] memory _accountAddresses) external onlyOwner {
        if (!_chainExists(_caip2ChainId)) {
            revert Agreement__ChainNotFoundByCaip2Id(_caip2ChainId);
        }
        // Ensure at least one account remains after removal
        if (_accountAddresses.length >= accounts[_caip2ChainId].length) {
            revert Agreement__CannotRemoveAllAccounts(_caip2ChainId);
        }
        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _accountAddresses.length; i++) {
            uint256 accountIndex = _findAccountIndex(_caip2ChainId, _accountAddresses[i]);
            emit AccountRemoved(_caip2ChainId, _accountAddresses[i]);

            uint256 lastAccountId = accounts[_caip2ChainId].length - 1;
            accounts[_caip2ChainId][accountIndex] = accounts[_caip2ChainId][lastAccountId];
            accounts[_caip2ChainId].pop();
        }
    }

    /// @notice Function that sets the bounty terms of the agreement.
    // aderyn-ignore-next-line(centralization-risk)
    function setBountyTerms(BountyTerms memory _bountyTerms) external onlyOwner {
        _validateBountyTerms(_bountyTerms);
        emit BountyTermsSet(_bountyTerms);
        bountyTerms = _bountyTerms;
    }

    // ----- INTERNAL STATE-CHANGING FUNCTIONS -----

    /// @notice Internal function to set all agreement details
    function _setDetails(AgreementDetails memory _details) internal {
        protocolName = _details.protocolName;
        agreementURI = _details.agreementURI;
        bountyTerms = _details.bountyTerms;

        // Copy contact details
        delete contactDetails;
        for (uint256 i = 0; i < _details.contactDetails.length; ++i) {
            contactDetails.push(_details.contactDetails[i]);
        }

        // Copy chains
        delete chainIds;
        for (uint256 i = 0; i < _details.chains.length; ++i) {
            string memory chainId = _details.chains[i].caip2ChainId;
            chainIds.push(chainId);
            assetRecoveryAddresses[chainId] = _details.chains[i].assetRecoveryAddress;

            delete accounts[chainId];
            for (uint256 j = 0; j < _details.chains[i].accounts.length; ++j) {
                accounts[chainId].push(_details.chains[i].accounts[j]);
            }
        }
    }

    /// @notice Internal function to validate chains (IDs, duplicates, accounts, recovery addresses)
    /// @dev Uses transient storage (tstore/tload) for duplicate checking
    function _validateChains(Chain[] memory _chains) internal {
        // Validate all chain data and check for duplicates in a single pass
        for (uint256 i = 0; i < _chains.length; i++) {
            // Validate chain ID
            if (bytes(_chains[i].caip2ChainId).length == 0) {
                revert Agreement__ChainIdHasZeroLength();
            }
            if (!CHAIN_VALIDATOR.isChainValid(_chains[i].caip2ChainId)) {
                revert Agreement__InvalidChainId(_chains[i].caip2ChainId);
            }
            // Validate accounts
            if (_chains[i].accounts.length == 0) {
                revert Agreement__ZeroAccountsForChainId(_chains[i].caip2ChainId);
            }
            // Validate each account has a non-empty address
            for (uint256 j = 0; j < _chains[i].accounts.length; j++) {
                if (bytes(_chains[i].accounts[j].accountAddress).length == 0) {
                    revert Agreement__InvalidAccountAddress(_chains[i].caip2ChainId, j);
                }
            }
            // Validate asset recovery address
            if (bytes(_chains[i].assetRecoveryAddress).length == 0) {
                revert Agreement__InvalidAssetRecoveryAddress(_chains[i].caip2ChainId);
            }
            // Check for duplicates using transient storage
            bytes32 slot = _duplicateCheckSlot(_chains[i].caip2ChainId);
            bool seen;
            assembly {
                seen := tload(slot)
            }
            if (seen) {
                revert Agreement__DuplicateChainId(_chains[i].caip2ChainId);
            }
            assembly {
                tstore(slot, 1)
            }
        }

        // Clear the transient storage in case this is within a batched transaction
        for (uint256 i = 0; i < _chains.length; i++) {
            bytes32 slot = _duplicateCheckSlot(_chains[i].caip2ChainId);
            assembly {
                tstore(slot, 0)
            }
        }
    }

    // ----- USER-FACING READ-ONLY FUNCTIONS -----

    /// @notice Function that returns the agreement details
    function getDetails() external view returns (AgreementDetails memory _details) {
        _details.protocolName = protocolName;
        _details.agreementURI = agreementURI;
        _details.bountyTerms = bountyTerms;

        // Copy contact details
        uint256 contactsLength = contactDetails.length;
        _details.contactDetails = new Contact[](contactsLength);
        for (uint256 i = 0; i < contactsLength; ++i) {
            _details.contactDetails[i] = contactDetails[i];
        }

        // Reconstruct chains
        uint256 chainsLength = chainIds.length;
        _details.chains = new Chain[](chainsLength);
        for (uint256 i = 0; i < chainsLength; ++i) {
            string memory chainId = chainIds[i];
            _details.chains[i].caip2ChainId = chainId;
            _details.chains[i].assetRecoveryAddress = assetRecoveryAddresses[chainId];

            Account[] storage accts = accounts[chainId];
            _details.chains[i].accounts = new Account[](accts.length);
            for (uint256 j = 0; j < accts.length; ++j) {
                _details.chains[i].accounts[j] = accts[j];
            }
        }
    }

    /// @notice Returns the protocol name
    function getProtocolName() external view returns (string memory) {
        return protocolName;
    }

    /// @notice Returns the bounty terms
    function getBountyTerms() external view returns (BountyTerms memory) {
        return bountyTerms;
    }

    /// @notice Returns the agreement URI
    function getAgreementURI() external view returns (string memory) {
        return agreementURI;
    }

    /// @notice Returns the chain validator address
    function getChainValidator() external view returns (address) {
        return address(CHAIN_VALIDATOR);
    }

    /// @notice Returns all chain IDs
    function getChainIds() external view returns (string[] memory) {
        return chainIds;
    }

    // ----- INTERNAL READ-ONLY FUNCTIONS -----

    /// @notice Internal function to validate bounty terms
    /// @dev Validates:
    ///      1. bountyPercentage <= MAX_BOUNTY_PERCENTAGE (100%)
    ///      2. aggregateBountyCapUSD >= bountyCapUSD when aggregateBountyCapUSD is set
    ///      3. Cannot set both aggregateBountyCapUSD and retainable
    function _validateBountyTerms(BountyTerms memory _bountyTerms) internal pure {
        // Validate bounty percentage does not exceed maximum (100%)
        if (_bountyTerms.bountyPercentage > MAX_BOUNTY_PERCENTAGE) {
            revert Agreement__BountyPercentageExceedsMaximum(_bountyTerms.bountyPercentage, MAX_BOUNTY_PERCENTAGE);
        }

        // Validate aggregate cap is >= individual cap when aggregate cap is set
        // Note: aggregateBountyCapUSD == 0 means no aggregate cap applies
        if (_bountyTerms.aggregateBountyCapUSD > 0 && _bountyTerms.aggregateBountyCapUSD < _bountyTerms.bountyCapUSD) {
            revert Agreement__AggregateBountyCapLessThanBountyCap(
                _bountyTerms.aggregateBountyCapUSD, _bountyTerms.bountyCapUSD
            );
        }

        // Cannot set both aggregate bounty cap and retainable
        if (_bountyTerms.aggregateBountyCapUSD > 0 && _bountyTerms.retainable) {
            revert Agreement__CannotSetBothAggregateBountyCapUsdAndRetainable();
        }
    }

    /// @notice Internal function to validate contact details
    /// @dev Validates that each contact has non-empty name and contact fields
    function _validateContactDetails(Contact[] memory _contactDetails) internal pure {
        for (uint256 i = 0; i < _contactDetails.length; i++) {
            if (bytes(_contactDetails[i].name).length == 0 || bytes(_contactDetails[i].contact).length == 0) {
                revert Agreement__InvalidContactDetails(i);
            }
        }
    }

    /// @notice Checks if a chain exists
    function _chainExists(string memory _caip2ChainId) internal view returns (bool) {
        bytes32 targetHash = _hashString(_caip2ChainId);
        uint256 length = chainIds.length;
        for (uint256 i = 0; i < length; ++i) {
            // aderyn-ignore-next-line(storage-array-memory-edit)
            if (_hashString(chainIds[i]) == targetHash) {
                return true;
            }
        }
        return false;
    }

    /// @notice Internal function to find chain index by CAIP-2 ID
    function _findChainIndex(string memory _caip2ChainId) internal view returns (uint256 chainIndex) {
        bytes32 targetHash = _hashString(_caip2ChainId);
        uint256 length = chainIds.length;
        for (uint256 i = 0; i < length; i++) {
            // aderyn-ignore-next-line(storage-array-memory-edit)
            if (_hashString(chainIds[i]) == targetHash) {
                return i;
            }
        }
        revert Agreement__ChainNotFoundByCaip2Id(_caip2ChainId);
    }

    /// @notice Internal function to find account index by address within a chain
    function _findAccountIndex(
        string memory _caip2ChainId,
        string memory _accountAddress
    )
        internal
        view
        returns (uint256 accountIndex)
    {
        bytes32 targetHash = _hashString(_accountAddress);
        Account[] storage chainAccounts = accounts[_caip2ChainId];
        for (uint256 i = 0; i < chainAccounts.length; i++) {
            // aderyn-ignore-next-line(storage-array-memory-edit)
            if (_hashString(chainAccounts[i].accountAddress) == targetHash) {
                return i;
            }
        }
        revert Agreement__AccountNotFoundByAddress(_caip2ChainId, _accountAddress);
    }

    /// @notice Computes the transient storage slot for duplicate chain ID checking
    function _duplicateCheckSlot(string memory _chainId) internal pure returns (bytes32 result) {
        bytes32 slot = _DUPLICATE_CHECK_SLOT;
        bytes32 chainIdHash = _hashString(_chainId);
        assembly {
            mstore(0x00, slot)
            mstore(0x20, chainIdHash)
            result := keccak256(0x00, 0x40)
        }
    }
}
