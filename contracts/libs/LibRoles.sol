// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {IAccessControl as I} from "../interfaces/IAccessControl.sol";

/**
 * @title LibRoles
 * @author Forever Network
 * @notice Library for managing role-based access control in the diamond
 */
library LibRoles {
    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @notice Checks if a specific `account` has been granted a `role`.
     * @dev This function reads directly from the `_roles` mapping in `AppStorage`.
     * @param role The bytes32 hash of the role to check.
     * @param account The address of the account to check.
     * @return bool `true` if the `account` has the `role`, `false` otherwise.
     */
    function hasRole(bytes32 role, address account) internal view returns (bool) {
        return LibAppStorage.diamondStorage()._roles[role].hasRole[account];
    }

    /**
     * @notice Returns the admin role that controls a given `role`.
     * @dev This function is used to determine which role has the authority to grant or revoke another role.
     * @param role The bytes32 hash of the role to query.
     * @return bytes32 The bytes32 hash of the admin role for the given `role`.
     */
    function getRoleAdmin(bytes32 role) internal view returns (bytes32) {
        return LibAppStorage.diamondStorage()._roles[role].adminRole;
    }

    /**
     * @dev Reverts with an {IAccessControl.AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     * @param role The bytes32 hash of the role to check against `msg.sender`.
     */
    function _checkRole(bytes32 role) internal view {
        _checkRole(role, msg.sender);
    }

    /**
     * @dev Reverts with an {IAccessControl.AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     * @param role The bytes32 hash of the role to check.
     * @param account The address of the account to verify.
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert I.AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     * @param role The bytes32 hash of the role whose admin is being set.
     * @param adminRole The bytes32 hash of the role that will be the new admin for `role`.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds._roles[role].adminRole = adminRole;
        emit I.RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     * @param role The bytes32 hash of the role to grant.
     * @param account The address of the account to grant the role to.
     * @return bool `true` if the role was granted, `false` if the account already had the role.
     */
    function _grantRole(bytes32 role, address account) internal returns (bool) {
        if (!hasRole(role, account)) {
            AppStorage storage ds = LibAppStorage.diamondStorage();
            ds._roles[role].hasRole[account] = true;
            emit I.RoleGranted(role, account, msg.sender);
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` from `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     * @param role The bytes32 hash of the role to revoke.
     * @param account The address of the account to revoke the role from.
     * @return bool `true` if the role was revoked, `false` if the account did not have the role.
     */
    function _revokeRole(bytes32 role, address account) internal returns (bool) {
        if (hasRole(role, account)) {
            AppStorage storage ds = LibAppStorage.diamondStorage();
            ds._roles[role].hasRole[account] = false;
            emit I.RoleRevoked(role, account, msg.sender);
            return true;
        } else {
            return false;
        }
    }
}
