// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage, AppStorage, FunctionLockStorage} from "./LibAppStorage.sol";
import {LibConstants as LC} from "./LibConstants.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {
    GlobalConfiguration,
    PurchaseConfiguration,
    ClaimConfiguration,
    RefRewardConfig,
    RefMultiplierConfig
} from "../shared/Structs.sol";

/**
 * @title LibAdmin
 * @author Forever Network
 * @notice Handles systemwide updates + safe, partial updates for all configuration structs.
 * @dev Uses sentinel constants for unchanged values and flags for booleans.
 */
library LibAdmin {
    // =============================================================
    //                       NETWORK
    // =============================================================

    /**
     * @notice Updates the address of the FNT token contract.
     * @dev This function sets the address of the external FNT token that the diamond interacts with.
     * @param _fntToken The new address of the FNT token contract.
     */
    function updateFNTAddress(address _fntToken) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds.fntToken = _fntToken;
    }

    // =============================================================
    //                       FUNCTION LOCKING
    // =============================================================)

    /**
     * @notice Locks a specific function within the diamond.
     * @dev Prevents a function from being called by setting its lock status to true.
     * Emits a {FunctionsLocked} event.
     * @param functionSelector The bytes4 selector of the function to lock.
     */
    function _lockFunction(bytes4 functionSelector) internal {
        FunctionLockStorage storage s = LibAppStorage.functionLockStorage();
        s.locked[functionSelector] = true;

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = functionSelector;
        emit LibEvents.FunctionsLocked(functionSelectors);
    }

    /**
     * @notice Unlocks a specific function within the diamond.
     * @dev Allows a previously locked function to be called by setting its lock status to false.
     * Emits a {FunctionsUnlocked} event.
     * @param functionSelector The bytes4 selector of the function to unlock.
     */
    function _unlockFunction(bytes4 functionSelector) internal {
        FunctionLockStorage storage s = LibAppStorage.functionLockStorage();
        s.locked[functionSelector] = false;

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = functionSelector;
        emit LibEvents.FunctionsUnlocked(functionSelectors);
    }

    /**
     * @notice Checks if a specific function is currently locked.
     * @dev Reads the locked status from `FunctionLockStorage`.
     * @param functionSelector The bytes4 selector of the function to check.
     * @return bool True if the function is locked, false otherwise.
     */
    function _isFunctionLocked(bytes4 functionSelector) internal view returns (bool) {
        FunctionLockStorage storage s = LibAppStorage.functionLockStorage();
        return s.locked[functionSelector];
    }

    /**
     * @notice Locks multiple functions in a single transaction.
     * @dev Sets the lock status to true for all provided function selectors.
     * Emits a {FunctionsLocked} event with all locked selectors.
     * @param functionSelectors Array of bytes4 selectors to lock.
     */
    function _batchLockFunctions(bytes4[] calldata functionSelectors) internal {
        if (functionSelectors.length == 0) revert LibErrors.ZeroAmount();

        FunctionLockStorage storage s = LibAppStorage.functionLockStorage();

        for (uint256 i = 0; i < functionSelectors.length; i++) {
            s.locked[functionSelectors[i]] = true;
        }

        emit LibEvents.FunctionsLocked(functionSelectors);
    }

    /**
     * @notice Unlocks multiple functions in a single transaction.
     * @dev Sets the lock status to false for all provided function selectors.
     * Emits a {FunctionsUnlocked} event with all unlocked selectors.
     * @param functionSelectors Array of bytes4 selectors to unlock.
     */
    function _batchUnlockFunctions(bytes4[] calldata functionSelectors) internal {
        if (functionSelectors.length == 0) revert LibErrors.ZeroAmount();

        FunctionLockStorage storage s = LibAppStorage.functionLockStorage();

        for (uint256 i = 0; i < functionSelectors.length; i++) {
            s.locked[functionSelectors[i]] = false;
        }

        emit LibEvents.FunctionsUnlocked(functionSelectors);
    }

    // =============================================================
    //                    TOKEN CREDIT ALLOWANCES
    // =============================================================

    /**
     * @notice Sets the remaining manual token credit allowance for a TOKEN_CREDIT_ROLE actor.
     * @param creditor The address that will be able to call {ParticipantActionsFacet.creditTokens}.
     * @param allowance The allowance that will remain after the call; use this to replenish or revoke crediting power.
     */
    function setTokenCreditAllowance(address creditor, uint256 allowance) internal {
        if (creditor == address(0)) revert LibErrors.ZeroAddress();
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds.tokenCreditAllowance[creditor] = allowance;
    }

    /**
     * @notice Batch setter to configure multiple remaining credit allowances atomically.
     * @param creditors Array of TOKEN_CREDIT_ROLE addresses.
     * @param allowances Array of allowance values that map 1:1 with `creditors`.
     */
    function batchSetTokenCreditAllowances(address[] calldata creditors, uint256[] calldata allowances) internal {
        if (creditors.length != allowances.length) revert LibErrors.LengthMismatch();
        for (uint256 i = 0; i < creditors.length; i++) {
            setTokenCreditAllowance(creditors[i], allowances[i]);
        }
    }

    // =============================================================
    //                       TREASURY
    // =============================================================

    /**
     * @notice Updates the address of the treasury contract.
     * @dev This function sets the address where collected funds are sent.
     * @param _treasury The new address of the treasury contract.
     */
    function updateTreasuryAddress(address _treasury) internal {
        if (_treasury == address(0)) revert LibErrors.ZeroAddress();
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds.treasury = _treasury;
    }

    /**
     * @notice Updates the DAO timelock address stored in the diamond.
     * @dev Ensures the address is non-zero before persisting.
     * @param _daoTimelock The new DAO timelock address that should control governance post-transition.
     */
    function updateDaoTimelockAddress(address _daoTimelock) internal {
        if (_daoTimelock == address(0)) revert LibErrors.ZeroAddress();
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds.daoTimelock = _daoTimelock;
    }

    // =============================================================
    //                       GLOBAL CONFIG
    // =============================================================

    /**
     * @notice Updates the GlobalConfiguration partially.
     * @dev Allows updating individual fields of the global configuration struct.
     * Uses `LC.UNCHANGED_UINT256` as a sentinel value to indicate that a field should not be updated.
     * @param _existentialDeposit The minimum FNT balance required for a participant to be considered active.
     * @param _refereeDeferredTokenBonus The deferred token bonus given to a new participant on registration.
     * @param _refereeInstantTokenBonus The instant token bonus minted to a new participant on registration.
     */
    function updateGlobalConfig(
        uint256 _existentialDeposit,
        uint256 _refereeDeferredTokenBonus,
        uint256 _refereeInstantTokenBonus
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        if (_existentialDeposit != LC.UNCHANGED_UINT256) {
            ds.globalConfig.existentialDeposit = _existentialDeposit;
        }
        if (_refereeDeferredTokenBonus != LC.UNCHANGED_UINT256) {
            ds.globalConfig.refereeDeferredTokenBonus = _refereeDeferredTokenBonus;
        }
        if (_refereeInstantTokenBonus != LC.UNCHANGED_UINT256) {
            ds.globalConfig.refereeInstantTokenBonus = _refereeInstantTokenBonus;
        }
    }

    /**
     * @notice Provides the default GlobalConfiguration settings.
     * @dev These are the initial parameters for the network's global state, such as minimum deposit and referral bonuses.
     * @return GlobalConfiguration A memory struct containing the default global configuration.
     */
    function defaultGlobalConfiguration() internal pure returns (GlobalConfiguration memory) {
        return GlobalConfiguration({
            existentialDeposit: 50 ether, refereeDeferredTokenBonus: 15 ether, refereeInstantTokenBonus: 35 ether
        });
    }

    // =============================================================
    //                      PURCHASE CONFIG
    // =============================================================

    /**
     * @notice Updates the PurchaseConfiguration partially.
     * @dev Allows the DAO to modify purchase-related parameters. Uses sentinel values
     * (`LC.UNCHANGED_*`) to skip updating specific fields. Boolean flags are always updated.
     * Validates that percentage values (whaleTaxThreshold, whaleTaxBasisPoints) are within valid range (0-9999).
     * @param _purchaseActive New value for `purchaseActive` - controls if purchases are allowed.
     * @param _purchaseTaxRedemptionEnabled New value for `purchaseTaxRedemptionEnabled` - controls if tax redemption is allowed.
     * @param _purchaseTaxRedemptionReferralThreshold Minimum referrals needed for tax redemption, or `LC.UNCHANGED_UINT16` to skip.
     * @param _whaleTaxThreshold Percentage (basis points) of maxTokenPurchaseLimit that triggers whale tax, or `LC.UNCHANGED_UINT16` to skip.
     * @param _whaleTaxBasisPoints Whale tax rate in basis points, or `LC.UNCHANGED_UINT16` to skip.
     * @param _purchaseStartTime Unix timestamp when purchases can begin, or `LC.UNCHANGED_UINT48` to skip.
     * @param _purchaseRate Price of one token in wei, or `LC.UNCHANGED_UINT256` to skip.
     * @param _minPurchaseAmount Minimum purchase amount in wei, or `LC.UNCHANGED_UINT256` to skip.
     * @param _maxTokenPurchaseLimit Maximum tokens per participant, or `LC.UNCHANGED_UINT256` to skip.
     */
    function updatePurchaseConfig(
        bool _purchaseActive,
        bool _purchaseTaxRedemptionEnabled,
        uint16 _purchaseTaxRedemptionReferralThreshold,
        uint16 _whaleTaxThreshold,
        uint16 _whaleTaxBasisPoints,
        uint48 _purchaseStartTime,
        uint256 _purchaseRate,
        uint256 _minPurchaseAmount,
        uint256 _maxTokenPurchaseLimit
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds.purchaseConfig.purchaseActive = _purchaseActive;

        ds.purchaseConfig.purchaseTaxRedemptionEnabled = _purchaseTaxRedemptionEnabled;

        if (_purchaseTaxRedemptionReferralThreshold != LC.UNCHANGED_UINT16) {
            ds.purchaseConfig.purchaseTaxRedemptionReferralThreshold = _purchaseTaxRedemptionReferralThreshold;
        }
        if (_whaleTaxThreshold != LC.UNCHANGED_UINT16) {
            if (_whaleTaxThreshold >= 10_000) revert LibErrors.InvalidPercentageBps(_whaleTaxThreshold);
            ds.purchaseConfig.whaleTaxThreshold = _whaleTaxThreshold;
        }
        if (_whaleTaxBasisPoints != LC.UNCHANGED_UINT16) {
            if (_whaleTaxBasisPoints >= 10_000) revert LibErrors.InvalidPercentageBps(_whaleTaxBasisPoints);
            ds.purchaseConfig.whaleTaxBasisPoints = _whaleTaxBasisPoints;
        }
        if (_purchaseStartTime != LC.UNCHANGED_UINT48) {
            ds.purchaseConfig.purchaseStartTime = _purchaseStartTime;
        }

        if (_purchaseRate != LC.UNCHANGED_UINT256) ds.purchaseConfig.purchaseRate = _purchaseRate;
        if (_minPurchaseAmount != LC.UNCHANGED_UINT256) {
            ds.purchaseConfig.minPurchaseAmount = _minPurchaseAmount;
        }
        if (_maxTokenPurchaseLimit != LC.UNCHANGED_UINT256) {
            ds.purchaseConfig.maxTokenPurchaseLimit = _maxTokenPurchaseLimit;
        }
    }

    /**
     * @notice Provides the default PurchaseConfiguration settings.
     * @dev These are the initial parameters for token purchasing, including active status, tax settings, and rate limits.
     * @return PurchaseConfiguration A memory struct containing the default purchase configuration.
     */
    function defaultPurchaseConfiguration() internal pure returns (PurchaseConfiguration memory) {
        return PurchaseConfiguration({
            purchaseActive: true,
            purchaseTaxRedemptionEnabled: false,
            purchaseTaxRedemptionReferralThreshold: 15,
            whaleTaxThreshold: 7_000, // 70%
            whaleTaxBasisPoints: 3_000, // 30%
            purchaseStartTime: 1764417600,
            purchaseRate: 0.001 ether,
            minPurchaseAmount: 0.01 ether,
            maxTokenPurchaseLimit: 20_000 ether
        });
    }

    // =============================================================
    //                        CLAIM CONFIG
    // =============================================================

    /**
     * @notice Updates the ClaimConfiguration partially.
     * @dev Allows the DAO to modify claim thresholds for different participant types and bonus types.
     * Uses sentinel value (`LC.UNCHANGED_UINT256`) to skip updating specific fields. The `freeTokenClaimEnabled` boolean is always updated.
     * @param _freeTokenClaimEnabled New value for `freeTokenClaimEnabled` - controls if participants can claim without meeting thresholds.
     * @param _participantTokenClaimThreshold Minimum token bonus for regular participants to claim, or `LC.UNCHANGED_UINT256` to skip.
     * @param _sponsoredTokenClaimThreshold Minimum token bonus for sponsored participants to claim, or `LC.UNCHANGED_UINT256` to skip.
     * @param _participantNativeClaimThreshold Minimum native bonus for regular participants to claim, or `LC.UNCHANGED_UINT256` to skip.
     * @param _sponsoredNativeClaimThreshold Minimum native bonus for sponsored participants to claim, or `LC.UNCHANGED_UINT256` to skip.
     */
    function updateClaimConfig(
        bool _freeTokenClaimEnabled,
        uint256 _participantTokenClaimThreshold,
        uint256 _sponsoredTokenClaimThreshold,
        uint256 _participantNativeClaimThreshold,
        uint256 _sponsoredNativeClaimThreshold
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        ds.claimConfig.freeTokenClaimEnabled = _freeTokenClaimEnabled;

        if (_participantTokenClaimThreshold != LC.UNCHANGED_UINT256) {
            ds.claimConfig.participantTokenClaimThreshold = _participantTokenClaimThreshold;
        }
        if (_sponsoredTokenClaimThreshold != LC.UNCHANGED_UINT256) {
            ds.claimConfig.sponsoredTokenClaimThreshold = _sponsoredTokenClaimThreshold;
        }
        if (_participantNativeClaimThreshold != LC.UNCHANGED_UINT256) {
            ds.claimConfig.participantNativeClaimThreshold = _participantNativeClaimThreshold;
        }
        if (_sponsoredNativeClaimThreshold != LC.UNCHANGED_UINT256) {
            ds.claimConfig.sponsoredNativeClaimThreshold = _sponsoredNativeClaimThreshold;
        }
    }

    /**
     * @notice Provides the default ClaimConfiguration settings.
     * @dev These are the initial parameters for claim thresholds for various token and native bonuses.
     * @return ClaimConfiguration A memory struct containing the default claim configuration.
     */
    function defaultClaimConfiguration() internal pure returns (ClaimConfiguration memory) {
        return ClaimConfiguration({
            freeTokenClaimEnabled: false,
            participantTokenClaimThreshold: 100 ether,
            sponsoredTokenClaimThreshold: 400 ether,
            participantNativeClaimThreshold: 0.1 ether,
            sponsoredNativeClaimThreshold: 0.2 ether
        });
    }

    // =============================================================
    //                   CLAIM STATUS
    // =============================================================

    /**
     * @notice Updates the ClaimStatus, enabling or disabling different types of claims.
     * @dev This function allows the DAO to control whether token bonus, token credit, and native bonus claims are active.
     * @param _tokenBonusClaimActive Boolean to activate/deactivate token bonus claims.
     * @param _tokenCreditClaimActive Boolean to activate/deactivate token credit claims.
     * @param _nativeBonusClaimActive Boolean to activate/deactivate native bonus claims.
     */
    function updateClaimStatus(bool _tokenBonusClaimActive, bool _tokenCreditClaimActive, bool _nativeBonusClaimActive)
        internal
    {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ds.claimStatus.tokenBonusClaimActive = _tokenBonusClaimActive;
        ds.claimStatus.tokenCreditClaimActive = _tokenCreditClaimActive;
        ds.claimStatus.nativeBonusClaimActive = _nativeBonusClaimActive;
    }

    // =============================================================
    //                   REFERRAL REWARD CONFIG
    // =============================================================

    /**
     * @notice Updates the referral reward configuration.
     * @dev Passing empty arrays leaves array values unchanged. Sentinel values skip scalar fields.
     * This configuration controls the token and native rewards earned by referrers based on referral count milestones.
     * @param _thresholds New referral count thresholds array for token rewards. Empty array leaves existing thresholds unchanged.
     * @param _tokenRewards New token reward amounts array corresponding to thresholds. Empty array leaves existing rewards unchanged.
     * @param _milestoneBonus New base native bonus for reaching milestones, or `LC.UNCHANGED_UINT256` to skip.
     * @param _milestoneInterval New number of referrals between milestones, or `LC.UNCHANGED_UINT256` to skip.
     * @param _maxMilestones New maximum number of achievable milestones, or `LC.UNCHANGED_UINT256` to skip.
     * @param _milestonePercentMultiplier New progressive percentage increase per milestone, or `LC.UNCHANGED_UINT64` to skip.
     */
    function updateRefRewardConfig(
        uint48[] calldata _thresholds,
        uint256[] calldata _tokenRewards,
        uint256 _milestoneBonus,
        uint256 _milestoneInterval,
        uint256 _maxMilestones,
        uint64 _milestonePercentMultiplier
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        // Arrays are replaced only if non-empty
        if (_thresholds.length > 0) ds.refRewardConfig.thresholds = _thresholds;
        if (_tokenRewards.length > 0) ds.refRewardConfig.tokenRewards = _tokenRewards;

        if (_milestoneBonus != LC.UNCHANGED_UINT256) {
            ds.refRewardConfig.milestoneBonus = _milestoneBonus;
        }
        if (_milestoneInterval != LC.UNCHANGED_UINT256) {
            ds.refRewardConfig.milestoneInterval = _milestoneInterval;
        }
        if (_maxMilestones != LC.UNCHANGED_UINT256) ds.refRewardConfig.maxMilestones = _maxMilestones;
        if (_milestonePercentMultiplier != LC.UNCHANGED_UINT64) {
            ds.refRewardConfig.milestonePercentMultiplier = _milestonePercentMultiplier;
        }
    }

    /**
     * @notice Create default reward configuration.
     * @dev Provides the initial parameters for the referral reward system with 10 threshold tiers.
     * Thresholds range from 5 to 1500 referrals, with corresponding token rewards from 10 to 1000 FNT.
     * Milestone bonuses start at 0.1 BNB, occurring every 100 referrals, with a maximum of 50 milestones.
     * Each milestone increases rewards by 15% (1500 basis points).
     * @return Default configuration
     */
    function defaultRefRewardConfig() internal pure returns (RefRewardConfig memory) {
        uint48[] memory thresholds = new uint48[](10);
        thresholds[0] = 5;
        thresholds[1] = 15;
        thresholds[2] = 30;
        thresholds[3] = 50;
        thresholds[4] = 100;
        thresholds[5] = 300;
        thresholds[6] = 500;
        thresholds[7] = 700;
        thresholds[8] = 1000;
        thresholds[9] = 1500;

        uint256[] memory rewards = new uint256[](10);
        rewards[0] = 10 ether;
        rewards[1] = 20 ether;
        rewards[2] = 45 ether;
        rewards[3] = 90 ether;
        rewards[4] = 150 ether;
        rewards[5] = 250 ether;
        rewards[6] = 400 ether;
        rewards[7] = 600 ether;
        rewards[8] = 800 ether;
        rewards[9] = 1000 ether;

        return RefRewardConfig({
            thresholds: thresholds,
            tokenRewards: rewards,
            milestoneBonus: 0.1 ether,
            milestoneInterval: 100,
            maxMilestones: 50,
            milestonePercentMultiplier: 1500 // 15%
        });
    }

    // =============================================================
    //                  REFERRAL MULTIPLIER CONFIG
    // =============================================================

    /**
     * @notice Updates the referral multiplier configuration.
     * @dev Allows the DAO to modify the referral reward multiplier settings for both sponsored and unsponsored participants.
     * Uses sentinel value (`LC.UNCHANGED_UINT8`) to skip updating specific fields.
     * Multipliers provide bonus rewards for a limited window of referrals after reaching certain thresholds.
     * @param _sponsoredThreshold New referral count threshold to activate multiplier for sponsored participants, or `LC.UNCHANGED_UINT8` to skip.
     * @param _unsponsoredThreshold New referral count threshold to activate multiplier for regular participants, or `LC.UNCHANGED_UINT8` to skip.
     * @param _sponsoredMultiplier New multiplier factor for sponsored participants (e.g., 3 = 3x rewards), or `LC.UNCHANGED_UINT8` to skip.
     * @param _unsponsoredMultiplier New multiplier factor for regular participants (e.g., 2 = 2x rewards), or `LC.UNCHANGED_UINT8` to skip.
     * @param _sponsoredWindow New number of referrals where multiplier applies for sponsored participants, or `LC.UNCHANGED_UINT8` to skip.
     * @param _unsponsoredWindow New number of referrals where multiplier applies for regular participants, or `LC.UNCHANGED_UINT8` to skip.
     */
    function updateRefMultiplierConfig(
        uint8 _sponsoredThreshold,
        uint8 _unsponsoredThreshold,
        uint8 _sponsoredMultiplier,
        uint8 _unsponsoredMultiplier,
        uint8 _sponsoredWindow,
        uint8 _unsponsoredWindow
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        if (_sponsoredThreshold != LC.UNCHANGED_UINT8) {
            ds.refMultiplierConfig.sponsoredThreshold = _sponsoredThreshold;
        }
        if (_unsponsoredThreshold != LC.UNCHANGED_UINT8) {
            ds.refMultiplierConfig.unsponsoredThreshold = _unsponsoredThreshold;
        }

        if (_sponsoredMultiplier != LC.UNCHANGED_UINT8) {
            ds.refMultiplierConfig.sponsoredMultiplier = _sponsoredMultiplier;
        }
        if (_unsponsoredMultiplier != LC.UNCHANGED_UINT8) {
            ds.refMultiplierConfig.unsponsoredMultiplier = _unsponsoredMultiplier;
        }

        if (_sponsoredWindow != LC.UNCHANGED_UINT8) {
            ds.refMultiplierConfig.sponsoredWindow = _sponsoredWindow;
        }
        if (_unsponsoredWindow != LC.UNCHANGED_UINT8) {
            ds.refMultiplierConfig.unsponsoredWindow = _unsponsoredWindow;
        }
    }

    /**
     * @notice Provides the default RefMultiplierConfig settings.
     * @dev These are the initial parameters for referral reward multipliers, distinguishing between sponsored and unsponsored participants.
     * @return RefMultiplierConfig A memory struct containing the default referral multiplier configuration.
     */
    function defaultRefMultiplierConfig() internal pure returns (RefMultiplierConfig memory) {
        return RefMultiplierConfig({
            sponsoredThreshold: 50,
            unsponsoredThreshold: 15,
            sponsoredMultiplier: 4,
            unsponsoredMultiplier: 2,
            sponsoredWindow: 5,
            unsponsoredWindow: 3
        });
    }
}
