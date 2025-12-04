// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title LibEIP712
 * @author Forever Network
 * @notice A library for generating EIP-712 domain separators and typed data hashes.
 * @dev Supports meta-transaction signatures by handling chain ID changes after deployment.
 */
library LibEIP712 {
    /**
     * @notice Returns the EIP-712 domain separator for the current chain.
     * @dev Lazily computes a new domain separator if the current chain ID differs from the initial deployment chain ID.
     * @return bytes32 The calculated EIP-712 domain separator.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        return block.chainid == ds.eip712Info.initialChainId
            ? ds.eip712Info.initialDomainSeparator
            : _computeDomainSeparator();
    }

    /**
     * @notice Computes the EIP-712 domain separator for the current chain.
     * @dev Follows the EIP-712 specification, including the name, version ("1"), chainId, and verifyingContract address.
     * @return bytes32 The newly computed EIP-712 domain separator.
     */
    function _computeDomainSeparator() internal view returns (bytes32) {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(ds.eip712Info.name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Hashes the given EIP-712 structured data (structHash).
     * @dev Prefixes the struct hash with the EIP-712 domain separator.
     * @param structHash The hash of the structured data (the message).
     * @return bytes32 The final hash for signature verification.
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}
