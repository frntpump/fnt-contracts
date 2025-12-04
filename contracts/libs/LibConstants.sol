// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title LibConstants
 * @author Forever Network
 * @notice Contains all constant values used throughout the Forever Network Diamond
 */
library LibConstants {
    // === Roles ===

    /**
     * @dev Full administrative control, the DAO Timelock's role.
     */
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Can pause and unpause the entire diamond, DAO Timelock's role.
     */
    bytes32 public constant GLOBAL_PAUSER_ROLE = keccak256("GLOBAL_PAUSER_ROLE");

    /**
     * @dev Can pause and unpause functions, DAO Timelock's role.
     */
    bytes32 public constant FUNCTION_PAUSER_ROLE = keccak256("FUNCTION_PAUSER_ROLE");

    /**
     * @dev Can access designated mint functions.
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Manages core system configurations.
     */
    bytes32 public constant CONFIG_MANAGER_ROLE = keccak256("CONFIG_MANAGER_ROLE");

    // --- Functional Roles ---

    /**
     * @dev Can register participants as "sponsored."
     */
    bytes32 public constant PRIME_SPONSOR_ROLE = keccak256("PRIME_SPONSOR_ROLE");

    /**
     * @dev Can credit participants with tokens outside of normal mechanisms.
     */
    bytes32 public constant TOKEN_CREDIT_ROLE = keccak256("TOKEN_CREDIT_ROLE");

    /**
     * @dev Can initiate withrawal of funds stuck in Diamond
     */
    bytes32 public constant EMERGENCY_WITHDRAWAL_ROLE = keccak256("EMERGENCY_WITHDRAWAL_ROLE");

    // === Sentinels ===
    // Sentinel value indicating an unsigned 256-bit integer parameter should remain unchanged.
    uint256 internal constant UNCHANGED_UINT256 = type(uint256).max;
    // Sentinel value indicating an unsigned 64-bit integer parameter should remain unchanged.
    uint64 internal constant UNCHANGED_UINT64 = type(uint64).max;
    // Sentinel value indicating an unsigned 48-bit integer parameter should remain unchanged.
    uint48 internal constant UNCHANGED_UINT48 = type(uint48).max;
    // Sentinel value indicating an unsigned 32-bit integer parameter should remain unchanged.
    uint32 internal constant UNCHANGED_UINT32 = type(uint32).max;
    // Sentinel value indicating an unsigned 16-bit integer parameter should remain unchanged.
    uint16 internal constant UNCHANGED_UINT16 = type(uint16).max;
    // Sentinel value indicating an unsigned 8-bit integer parameter should remain unchanged.
    uint8 internal constant UNCHANGED_UINT8 = type(uint8).max;

    // === Wallets ===
    // Maximum number of wallets that can be linked to a single participant UID.
    uint256 internal constant MAX_LINKED_WALLETS = 5;

    // === Pagination ===
    // Maximum number of items to return in a single page for paginated queries.
    uint256 internal constant MAX_PAGE = 500;
}
