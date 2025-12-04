// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/ReentrancyGuardTransient.sol)

pragma solidity ^0.8.30;

import {TransientSlot} from "lib/openzeppelin-contracts/contracts/utils/TransientSlot.sol";

/**
 * @title ReentrancyGuardTransient
 * @author Forever Network
 * @dev Variant of oz {ReentrancyGuard} that uses transient storage.
 *
 * NOTE: This variant only works on networks where EIP-1153 is available.
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuardTransient {
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("forever.network.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x220ad8655f041652b3d8c799a87e2ceefe16c79f1c4a68f8d259f2c3f01fbe00; // prettier-ignore

    /**
     * @dev Thrown when a reentrant call is detected, preventing unauthorized re-entrancy.
     */
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    /**
     * @dev Internal view function that checks if a reentrant call is in progress.
     * Reverts with {ReentrancyGuardReentrantCall} if reentrancy is detected.
     */
    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    /**
     * @dev Internal function called before a `nonReentrant` function's execution.
     * Sets the reentrancy guard to "entered" state.
     */
    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, REENTRANCY_GUARD_STORAGE.asBoolean().tload() will be false
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().asBoolean().tstore(true);
    }

    /**
     * @dev Internal function called after a `nonReentrant` function's execution.
     * Resets the reentrancy guard to "not entered" state.
     */
    function _nonReentrantAfter() private {
        _reentrancyGuardStorageSlot().asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     * @return bool True if reentrancy is active, false otherwise.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().asBoolean().tload();
    }

    /**
     * @dev Returns the storage slot used for the reentrancy guard. This is a private constant.
     * @return bytes32 The storage slot for the reentrancy guard.
     */
    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}
