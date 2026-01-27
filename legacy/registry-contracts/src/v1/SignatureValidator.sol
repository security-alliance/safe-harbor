// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC1271.sol";

contract SignatureValidator {
    /// @notice Returns the signer of a hash.
    /// @param hash The unsigned hash.
    /// @param signature The signature.
    /// @return signer The signer of the hash.
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address signer) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "Invalid signature");
    }

    /// @notice Returns whether an EOA signed a given hash.
    /// @param wantSigner The signer to check for.
    /// @param hash The hash that was signed.
    /// @param signature The signature.
    function isEOASignatureValid(address wantSigner, bytes32 hash, bytes memory signature)
        internal
        pure
        returns (bool)
    {
        address signer = recoverSigner(hash, signature);
        return signer == wantSigner;
    }

    /// @notice Returns whether a contract signed a given hash.
    /// @param wantSigner The signer to check for.
    /// @param hash The hash that was signed.
    /// @param signature The signature.
    function isContractSignatureValid(address wantSigner, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool)
    {
        bytes4 result = IERC1271(wantSigner).isValidSignature(hash, signature);

        // EIP-1271 magic value
        // https://eips.ethereum.org/EIPS/eip-1271
        return result == 0x1626ba7e;
    }

    /// @notice Returns whether an address is a contract.
    /// @param addr The address to check.
    function isContract(address addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }

    /// @notice Returns whether a signature is valid.
    /// @param wantSigner The signer to check for.
    /// @param hash The hash that was signed.
    /// @param signature The signature.
    function isSignatureValid(address wantSigner, bytes32 hash, bytes memory signature) public view returns (bool) {
        if (isContract(wantSigner)) {
            return isContractSignatureValid(wantSigner, hash, signature);
        } else {
            return isEOASignatureValid(wantSigner, hash, signature);
        }
    }
}
