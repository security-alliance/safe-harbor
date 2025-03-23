// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../v1/AgreementV1.sol";
import "openzeppelin-contracts/access/Ownable.sol";

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
/// @dev This contract is Ownable and mutable. It is intended to be used by entities adopting the
/// Safe Harbor agreement that either need to frequently update their terms, have too many terms to
/// fit in a single transaction, or wish to delegate the management of their agreement to a different
/// address than the deployer.
contract AgreementV2 is Ownable {
    /// @notice The details of the agreement.
    AgreementDetailsV1 private details;

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    constructor(AgreementDetailsV1 memory _details, address _owner) Ownable(_owner) {
        details = _details;
    }

    function version() external pure returns (string memory) {
        return _version;
    }

    function setProtocolName(string memory _protocolName) external onlyOwner {
        details.protocolName = _protocolName;
    }

    function setContactDetails(Contact[] memory _contactDetails) external onlyOwner {
        details.contactDetails = _contactDetails;
    }

    function addChains(Chain[] memory _chains) external onlyOwner {
        for (uint256 i = 0; i < _chains.length; i++) {
            details.chains.push(_chains[i]);
        }
    }

    function removeChain(uint256 _chainId) external onlyOwner {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (details.chains[i].id != _chainId) {
                continue;
            }

            details.chains[i] = details.chains[details.chains.length - 1];
            details.chains.pop();
            return;
        }
    }

    function addAccounts(uint256 _chainId, Account[] memory _account) external onlyOwner {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (details.chains[i].id != _chainId) {
                continue;
            }

            for (uint256 j = 0; j < _account.length; j++) {
                details.chains[i].accounts.push(_account[j]);
            }
            return;
        }
    }

    function removeAccount(uint256 _chainId, address _account) external onlyOwner {
        for (uint256 i = 0; i < details.chains.length; i++) {
            if (details.chains[i].id != _chainId) {
                continue;
            }

            for (uint256 j = 0; j < details.chains[i].accounts.length; j++) {
                if (details.chains[i].accounts[j].accountAddress != _account) {
                    continue;
                }

                details.chains[i].accounts[j] = details.chains[i].accounts[details.chains[i].accounts.length - 1];
                details.chains[i].accounts.pop();
                return;
            }
        }
    }

    function setBountyTerms(BountyTerms memory _bountyTerms) external onlyOwner {
        details.bountyTerms = _bountyTerms;
    }

    /// @notice Function that returns the details of the agreement.
    /// @dev You need a view function, else it won't convert storage to memory automatically for the nested structs.
    /// @return AgreementDetailsV1 The details of the agreement.
    function getDetails() external view returns (AgreementDetailsV1 memory) {
        return details;
    }
}
