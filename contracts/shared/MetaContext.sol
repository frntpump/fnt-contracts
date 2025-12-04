// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Context} from "lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {LibAppStorage} from "../libs/LibAppStorage.sol";

/**
 * @title MetaContext
 * @author Forever Network
 * @dev ERC2711 meta-transaction context variant using AppStorage.
 */
abstract contract MetaContext is Context {
    /**
     * @notice Checks if a given address is the configured trusted forwarder.
     * @dev This function is used to identify if an incoming transaction is a meta-transaction.
     * @param forwarder The address to check.
     * @return bool True if the address is the trusted forwarder, false otherwise.
     */
    function isTrustedForwarder(address forwarder) internal view returns (bool) {
        return forwarder == LibAppStorage.diamondStorage().metaTxContext.trustedForwarder;
    }

    /**
     * @dev Returns the address of the actual sender for a transaction.
     * If the `msg.sender` is a trusted forwarder, the actual sender is extracted from the end of `msg.data`.
     * Otherwise, it returns `msg.sender` directly.
     * @return sender The address of the original sender.
     */
    function _msgSender() internal view override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    /**
     * @dev Returns the `msg.data` for a transaction.
     * If the `msg.sender` is a trusted forwarder, the last 20 bytes (containing the actual sender) are truncated from `msg.data`.
     * Otherwise, it returns `msg.data` directly.
     * @return bytes The calldata for the original message.
     */
    function _msgData() internal view override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}
