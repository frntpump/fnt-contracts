// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    GlobalState,
    GlobalConfiguration,
    PurchaseConfiguration,
    RefRewardConfig,
    RefMultiplierConfig,
    ClaimConfiguration,
    TokenState,
    ClaimEligible,
    ClaimStatus,
    RoleData,
    Participant,
    EIP712Info,
    MetaTxContextStorage,
    SingleStakingState
} from "../shared/Structs.sol";

/**
 * @title AppStorage
 * @author Forever Network
 * @notice The central storage struct for the FN Diamond.
 * @dev Consolidates all state variables to be accessible by different facets.
 * New fields should always be appended to the end for storage compatibility.
 * @dev OPTIMIZED: Booleans and addresses packed together to minimize storage slots.
 */
struct AppStorage {
    // ============================================================
    // Initialization flags & critical addresses
    // ============================================================
    /// @dev Flag indicating whether the diamond has been initialized.
    bool diamondInitialized;
    /// @dev Cached flag indicating whether governance has transitioned to the DAO according to the FNT token.
    bool governanceTransitioned;
    /// @dev Address of the DAO timelock that should control the diamond once governance transitions.
    address daoTimelock;
    /// @dev The address of the external FNT token contract integrated with the diamond.
    address fntToken;
    /// @dev The address of the DAO treasury contract.
    address treasury;

    // ============================================================
    // EIP712 & Meta-Transaction Context
    // ============================================================
    /// @dev Stores EIP712 domain information for meta-transactions.
    EIP712Info eip712Info;
    /// @dev Stores context related to meta-transactions, including the trusted forwarder.
    MetaTxContextStorage metaTxContext;

    // ============================================================
    // System State Structs
    // ============================================================
    /// @dev Global state variables, including the paused status of the contract.
    GlobalState globalState;
    /// @dev State variables related to the FNT token, such as total supply.
    TokenState tokenState;
    /// @dev Current status of various claims (token bonus, token credit, native bonus).
    ClaimStatus claimStatus;

    // ============================================================
    // Configuration Structs
    // ============================================================
    /// @dev Global configuration parameters for the network.
    GlobalConfiguration globalConfig;
    /// @dev Configuration parameters for token purchases.
    PurchaseConfiguration purchaseConfig;
    /// @dev Configuration parameters for token and native bonus claims.
    ClaimConfiguration claimConfig;
    /// @dev Configuration for referral token rewards and milestones.
    RefRewardConfig refRewardConfig;
    /// @dev Configuration for referral reward multipliers.
    RefMultiplierConfig refMultiplierConfig;

    // ============================================================
    // Access Control State
    // ============================================================
    /// @dev Mapping from role hash to `RoleData` struct, storing admin and members for each role.
    mapping(bytes32 role => RoleData) _roles;

    // ============================================================
    // Participant & Referral State
    // ============================================================
    /// @dev Stores the uids of sponsored participants.
    bytes8[] sponsoredParticipants;
    /// @dev Mapping from participant address to their unique identifier (UID).
    mapping(address => bytes8) addressToUid;
    /// @dev Mapping from unique identifier (UID) to an array of addresses linked to that participant.
    mapping(bytes8 => address[]) uidToAddresses;
    /// @dev Mapping from unique identifier (UID) to `Participant` struct, storing all participant-specific data.
    mapping(bytes8 => Participant) participantsByUid;
    /// @dev Mapping storing the referral tree, where `referrerAddress => index => refereeAddress`.
    mapping(address => mapping(uint256 => address)) referralTree;
    /// @dev Ordered list of participants who have made purchases, by the order of their first purchase.
    mapping(uint256 => address) orderedPurchasers;
    /// @dev Records the last achieved referral milestone for each participant.
    mapping(address => uint256) lastMilestone;
    /// @dev Stores eligibility status for different claim types for each address.
    mapping(address => ClaimEligible) claimEligible;
    /// @dev Tracks the number of referees that have reached active status for each referrer.
    mapping(address => uint64) activeRefereeCount;
    /// @dev Per-creditor allowance for manual token credits, controlled by admins.
    mapping(address => uint256) tokenCreditAllowance;

    // ============================================================
    // Single Token Staking
    // ============================================================
    /// @dev Storage bucket for the single-token staking module.
    SingleStakingState singleStaking;
}

/**
 * @title FunctionLockStorage
 * @author Forever Network
 * @notice Storage struct for managing locked functions within the diamond.
 * @dev Stores a boolean indicating whether a function, identified by its selector, is locked.
 */
struct FunctionLockStorage {
    /**
     * @notice Mapping from function selector to a boolean indicating if the function is locked.
     * @dev `true` means the function is locked and cannot be called.
     */
    mapping(bytes4 => bool) locked;
}

/**
 * @title LibAppStorage
 * @author Forever Network
 * @notice A helper library to provide a standardized, gas-efficient way for facets to access storage structs.
 * @dev This library uses a designated storage slots to access the structs, ensuring all facets
 *      interact with the same state.
 */
library LibAppStorage {
    /**
     * @notice Storage slot for AppStorage, derived according to EIP-7201.
     * @dev This constant represents the unique storage position for the `AppStorage` struct.
     */
    bytes32 private constant APP_STORAGE_POSITION = 0x7e7d6d1b04ebf05a6bae1680909a6972f14c776a3476533cc7d04098e886e200; // prettier-ignore

    /**
     * @notice Storage slot for FunctionLockStorage, derived according to EIP-7201.
     * @dev This constant represents the unique storage position for the `FunctionLockStorage` struct.
     */
    bytes32 private constant FUNCLOCK_STORAGE_POSITION =
        0xe81973074b1f734631d2d1092f6000f5fbbec89beafefecaa82cc792ca832200; // prettier-ignore

    /**
     * @notice Returns a storage pointer to the AppStorage struct.
     * @return ds A storage pointer to the AppStorage.
     */
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := APP_STORAGE_POSITION
        }
    }

    /**
     * @notice Returns a storage pointer to the FunctionLockStorage struct.
     * @return ds A storage pointer to the FunctionLockStorage.
     */
    function functionLockStorage() internal pure returns (FunctionLockStorage storage ds) {
        bytes32 position = FUNCLOCK_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
