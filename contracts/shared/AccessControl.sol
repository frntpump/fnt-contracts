// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibDiamond} from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";
import {MetaContext} from "./MetaContext.sol";
import {LibAppStorage} from "../libs/LibAppStorage.sol";
import {LibAdmin} from "../libs/LibAdmin.sol";
import {LibConstants as LC} from "../libs/LibConstants.sol";
import {LibRoles} from "../libs/LibRoles.sol";
import {LibParticipant} from "../libs/LibParticipant.sol";
import {LibErrors} from "../libs/LibErrors.sol";
import {IAccessControl} from "../interfaces/IAccessControl.sol";

/**
 * @title AccessControl
 * @author Forever Network
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 */
abstract contract AccessControl is MetaContext, IAccessControl {
    /**
     * @dev Thrown when a function is locked via `_lockFunction`.
     * @param fnSig The 4-byte selector of the locked function.
     */
    error FunctionLocked(bytes4 fnSig);

    /**
     * @dev Modifier that restricts access to only the contract owner or an account with `DEFAULT_ADMIN_ROLE`.
     */
    modifier isAdmin() {
        _isAdmin();
        _;
    }

    /**
     * @dev Modifier that restricts access to functions only when the global pause is not active.
     */
    modifier whenGlobalNotPaused() {
        _whenGlobalNotPaused();
        _;
    }

    /**
     * @dev Modifier that restricts access to functions that are not specifically locked.
     */
    modifier unlockedFunction() {
        _unlockedFunction();
        _;
    }

    /**
     * @dev Modifier that restricts access to functions only for active participants.
     */
    modifier onlyActiveParticipant() {
        _onlyActiveParticipant();
        _;
    }

    /**
     * @dev Modifier that restricts access to accounts that have been granted the specified `role`.
     * @param role The bytes32 hash of the role required for access.
     */
    modifier onlyRole(bytes32 role) {
        _onlyRole(role);
        _;
    }

    /**
     * @dev Modifier that restricts access to accounts that have either the specified `role` or the `DEFAULT_ADMIN_ROLE`, or are the contract owner.
     * @param role The bytes32 hash of the role that grants access.
     */
    modifier onlyRoleOrAdmin(bytes32 role) {
        _onlyRoleOrAdmin(role);
        _;
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     * @param role The bytes32 hash of the role to check.
     * @param account The address of the account to query.
     * @return bool `true` if the account has the role, `false` otherwise.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return LibRoles.hasRole(role, account);
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     * @param role The bytes32 hash of the role to query.
     * @return bytes32 The bytes32 hash of the admin role for the given `role`.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return LibRoles.getRoleAdmin(role);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     * @param role The bytes32 hash of the role to grant.
     * @param account The address of the account to grant the role to.
     */
    function grantRole(bytes32 role, address account) public virtual isAdmin {
        LibRoles._grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     * @param role The bytes32 hash of the role whose admin is being set.
     * @param adminRole The bytes32 hash of the role that will be the new admin for `role`.
     */
    function setRoleAdmin(bytes32 role, bytes32 adminRole) public virtual isAdmin {
        LibRoles._setRoleAdmin(role, adminRole);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     * @param role The bytes32 hash of the role to revoke.
     * @param account The address of the account to revoke the role from.
     */
    function revokeRole(bytes32 role, address account) public virtual isAdmin {
        LibRoles._revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     * @param role The bytes32 hash of the role to renounce.
     * @param callerConfirmation The address of the caller, used for confirmation.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        LibRoles._revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Internal function to check if the caller has the specified `role`.
     * Reverts with {Unauthorized} if the caller does not have the role.
     * @param role The bytes32 hash of the role to check.
     */
    function _onlyRole(bytes32 role) internal view {
        if (!LibRoles.hasRole(role, _msgSender())) {
            revert LibErrors.Unauthorized();
        }
    }

    /**
     * @dev Internal function to check if the caller has either the specified `role`, the `DEFAULT_ADMIN_ROLE`, or is the contract owner.
     * Reverts with {Unauthorized} if none of these conditions are met.
     * @param role The bytes32 hash of the role to check.
     */
    function _onlyRoleOrAdmin(bytes32 role) internal view {
        // Check if the user has ANY of the required permissions
        bool isPrivileged =
            (LibRoles.hasRole(role, _msgSender()) || LibRoles.hasRole(LC.DEFAULT_ADMIN_ROLE, _msgSender())
                || LibDiamond.contractOwner() == _msgSender());

        if (!isPrivileged) {
            revert LibErrors.Unauthorized();
        }
    }

    /**
     * @dev Internal function to check if the caller is an active participant.
     * Reverts with {UserInactive} if the caller is not an active participant.
     */
    function _onlyActiveParticipant() internal view {
        if (!LibParticipant._participantActive(LibParticipant.getParticipant(_msgSender()).uid)) {
            revert LibErrors.UserInactive(_msgSender());
        }
    }

    /**
     * @dev Internal function to check if the global pause is active.
     * Reverts with {EnforcedPause} if the global pause is active.
     */
    function _whenGlobalNotPaused() internal view {
        if (LibAppStorage.diamondStorage().globalState.paused) {
            revert LibErrors.EnforcedPause();
        }
    }

    /**
     * @dev Internal function to check if the current function is locked.
     * Reverts with {FunctionLocked} if the current function (identified by its selector) is locked.
     */
    function _unlockedFunction() internal view {
        if (LibAdmin._isFunctionLocked(msg.sig)) {
            revert LibErrors.FunctionLocked(msg.sig);
        }
    }

    /**
     * @dev Internal function to check if the caller is the contract owner or has the `DEFAULT_ADMIN_ROLE`.
     * Reverts with {CallerMustBeAdminError} if neither condition is met.
     */
    function _isAdmin() internal view {
        if (LibDiamond.contractOwner() != _msgSender() && !LibRoles.hasRole(LC.DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert LibErrors.CallerMustBeAdminError();
        }
    }
}
