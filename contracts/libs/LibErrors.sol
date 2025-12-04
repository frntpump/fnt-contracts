// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title LibErrors
 * @author Forever Network
 * @notice Unified error library for the Forever Network Diamond
 * @dev This file consolidates all custom errors for the FNT Diamond,
 *      improving gas efficiency and code clarity.
 */
library LibErrors {
    // =============================================================
    //                    GENERAL & SYSTEM ERRORS
    // =============================================================

    /// @notice Thrown when a caller attempts to perform an action without the necessary authorization
    error Unauthorized();

    /// @notice Thrown when an address parameter is unexpectedly a zero address (0x00...00)
    error ZeroAddress();

    /// @notice Thrown when an amount parameter is unexpectedly zero
    error ZeroAmount();

    /// @notice Thrown when two array inputs must share the same length but do not
    error LengthMismatch();

    /// @notice Thrown when a native currency transfer fails
    error NativeTransferFailed();

    /// @notice Thrown when an action is attempted that should only occur before a certain state transition, but the transition has already happened
    error AlreadyTransitioned();

    // =============================================================
    //                       PAUSABLE ERRORS
    // =============================================================

    /// @notice Thrown when a function is called while the contract (or feature) is paused
    error EnforcedPause();

    /// @notice Thrown when a function expects the contract (or feature) to be paused, but it is not
    error ExpectedPause();

    // =============================================================
    //                 PARTICIPANT & REFERRAL ERRORS
    // =============================================================

    /// @notice Thrown when an action requires a registered participant, but the provided address is not registered
    error NotRegistered(address participant);

    /// @notice Thrown when a referrer is expected to be registered, but the provided referrer address is not
    error ReferrerNotRegistered();

    /// @notice Thrown when a referrer is expected to be active, but they are not
    error ReferrerInactive();

    /// @notice Thrown when an action requires an active participant, but the provided participant is inactive
    error UserInactive(address participant);

    /// @notice Thrown when an array or mapping access is attempted with an index that is out of valid bounds
    error IndexOutOfBounds();

    /// @notice Thrown when a participant attempts to refer themselves
    error SelfReferral();

    /// @notice Thrown when an address attempts to register as a participant but is already registered
    error AlreadyRegistered(address participant);

    /// @notice Thrown when a wallet is already linked to a participant
    error WalletAlreadyLinked(address wallet);

    /// @notice Thrown when attempting to unlink a wallet that is not linked
    error WalletNotLinked(address wallet);

    /// @notice Thrown when attempting an action that requires the primary wallet but caller is not
    error WalletNotPrimary(address wallet);

    /// @notice Thrown when attempting to unlink the primary wallet
    error WalletPrimaryUnlink(address wallet);

    /// @notice Thrown when the maximum number of linked wallets has been reached
    error MaxWalletsLinked();

    // =============================================================
    //                   PURCHASE & CLAIM ERRORS
    // =============================================================

    /// @notice Thrown when an operation requires a certain balance, but the available balance is insufficient
    error InsufficientBalance(uint256 balance, uint256 amount);

    /// @notice Thrown when a participant attempts to redeem purchase tax, but the purchase tax redemption feature is disabled
    error PurchaseTaxRedemptionDisabled();

    /// @notice Thrown when a participant attempts to redeem purchase tax that has already been redeemed
    error PurchaseTaxAlreadyRedeemed();

    /// @notice Thrown when a participant attempts to redeem purchase tax, but they have no accumulated purchase tax to redeem
    error NoPurchaseTaxToRedeem();

    /// @notice Thrown when a participant attempts to redeem purchase tax but has not met the required referral threshold
    error RedeemThresholdNotMet(uint16 required, uint48 current);

    /// @notice Thrown when a participant attempts to claim a bonus, but the specific bonus claim feature is not active
    error BonusClaimNotActive();

    /// @notice Thrown when a participant attempts to claim a bonus, but their accumulated amount is below the minimum claim threshold
    error BelowClaimThreshold(uint256 amount, uint256 threshold);

    /// @notice Thrown when a participant attempts to claim credited tokens, but the token credit claim feature is not active
    error CreditClaimNotActive();

    /// @notice Thrown when a TOKEN_CREDIT_ROLE actor attempts to credit more tokens than allowed
    error CreditAllowanceExceeded(uint256 allowance, uint256 requested);

    /// @notice Thrown when an invalid deposit amount is provided
    error InvalidDeposit();

    /// @notice Thrown when an invalid rate is provided for a calculation
    error InvalidRate();

    /// @notice Thrown when an invalid purchase rate (e.g., zero) is used in a purchase calculation
    error InvalidPurchaseRate();

    /// @notice Thrown when a percentage value in basis points (BPS) is outside the valid range (0-10000)
    error InvalidPercentageBps(uint16 percentage);

    /// @notice Thrown when a timestamp provided is in the future but not expected to be
    error InvalidFutureTime();

    /// @notice Thrown when limits (e.g., max purchase limit) are violated
    error InvalidLimits();

    /// @notice Thrown when a token purchase fails due to various reasons, with an accompanying reason string
    error PurchaseFailed(string reason);

    /// @notice Thrown when a transaction is expected to have a value, but zero value is provided
    error ZeroValue();

    /// @notice Thrown when there is no native balance available to withdraw from the contract
    error NoBalanceToWithdraw();

    /// @notice Thrown when a low-level call to an external contract fails
    error FailedCall();

    /// @notice Thrown when a token transfer operation fails
    error TransferFailed();

    /// @notice Thrown when the calculated whale tax amount exceeds the total token amount being purchased
    error WhaleTaxExceedsAmount();

    // =============================================================
    //                 SINGLE TOKEN STAKING ERRORS
    // =============================================================

    /// @notice Thrown when staking is attempted while the module is disabled
    error StakingDisabled();

    /// @notice Thrown when the staked amount is below the configured minimum
    error StakeAmountBelowMinimum(uint256 amount, uint256 minimum);

    /// @notice Thrown when a lock identifier does not exist
    error InvalidLockId(uint8 lockId);

    /// @notice Thrown when attempting to use a lock configuration that is disabled
    error LockConfigDisabled(uint8 lockId);

    /// @notice Thrown when a lock duration is not part of the supported set
    error InvalidLockDuration(uint64 duration);

    /// @notice Thrown when an APR value is outside the supported range
    error InvalidApr(uint32 aprBps);

    /// @notice Thrown when an auto-compound bonus value exceeds the supported range
    error InvalidBonus(uint16 bonusBps);

    /// @notice Thrown when a penalty basis-point value exceeds the supported range
    error InvalidPenaltyBps(uint16 penaltyBps);

    /// @notice Thrown when a minimum stake amount is invalid
    error InvalidMinimumStake(uint256 amount);

    /// @notice Thrown when an enabled flag is outside the supported set
    error InvalidEnabledFlag(uint8 flag);

    /// @notice Thrown when a staking position cannot be found
    error StakeNotFound(uint256 stakeId);

    /// @notice Thrown when a staking position is inactive
    error StakeNotActive(uint256 stakeId);

    /// @notice Thrown when no rewards are available for withdrawal or claim
    error NoRewardsAvailable();

    /// @notice Thrown when attempting to set auto-compound to its current value
    error AutoCompoundPreferenceUnchanged();

    /// @notice Thrown when attempting to withdraw more penalties than are available
    error PenaltyWithdrawalExceedsBalance(uint256 available, uint256 requested);

    /// @notice Thrown when a tier identifier is invalid for configuration updates
    error InvalidTierId(uint8 tierId);

    /// @notice Thrown when a tier referral threshold is zero or otherwise invalid
    error InvalidTierReferrals(uint8 tierId, uint48 minReferrals);

    /// @notice Thrown when a tier threshold is not strictly greater than the previous tier's threshold
    error TierThresholdBelowPrevious(uint8 tierId, uint48 newThreshold, uint48 previousThreshold);

    /// @notice Thrown when a tier threshold exceeds or matches the next tier's threshold
    error TierThresholdAboveNext(uint8 tierId, uint48 newThreshold, uint48 nextThreshold);

    /// @notice Thrown when a caller attempts to act on a stake they do not own
    error StakeNotOwner(uint256 stakeId, address caller);

    /// @notice Thrown when attempting to exit a locked stake without forcing an early exit
    error StakeStillLocked(uint256 stakeId, uint40 unlockTime);

    /// @notice Thrown when attempting to claim rewards from an auto-compounding stake
    error ClaimUnavailableForAutoCompound();

    /// @notice Thrown when insufficient fee is provided for a staking operation
    error InsufficientFee(uint256 provided, uint256 required);

    /// @notice Thrown when a staking fee transfer fails
    error StakingFeeTransferFailed();

    // =============================================================
    //                   REFERRAL CONFIG ERRORS
    // =============================================================

    /// @notice Thrown when the thresholds array in `RefRewardConfig` is empty
    error EmptyThresholds();

    /// @notice Thrown when the lengths of `thresholds` and `tokenRewards` arrays in `RefRewardConfig` do not match
    error ConfigLengthMismatch();

    /// @notice Thrown when `milestoneInterval` in `RefRewardConfig` is zero, which would cause division by zero
    error ZeroMilestoneInterval();

    /// @notice Thrown when `maxMilestones` in `RefRewardConfig` is zero or exceeds 100
    error InvalidMaxMilestones(uint256 maxMilestones);

    /// @notice Thrown when `maxMilestonePercentMultiplier` in `RefRewardConfig` is zero or exceeds 100
    error InvalidMaxMilestonePercentMultiplier(uint64 multiplier);

    /// @notice Thrown when referral `thresholds` in `RefRewardConfig` are not in strictly ascending order
    error ThresholdsNotAscending();

    /// @notice Thrown when `tokenRewards` in `RefRewardConfig` are not in ascending order
    error RewardsNotAscending();

    /// @notice Thrown when `sponsoredThreshold` in `RefMultiplierConfig` is zero
    error ZeroSponsoredThreshold();

    /// @notice Thrown when `unsponsoredThreshold` in `RefMultiplierConfig` is zero
    error ZeroUnsponsoredThreshold();

    /// @notice Thrown when `sponsoredMultiplier` in `RefMultiplierConfig` is less than or equal to 1 or greater than 10
    error InvalidSponsoredMultiplier(uint8 multiplier);

    /// @notice Thrown when `unsponsoredMultiplier` in `RefMultiplierConfig` is less than or equal to 1 or greater than 10
    error InvalidUnsponsoredMultiplier(uint8 multiplier);

    /// @notice Thrown when `sponsoredWindow` in `RefMultiplierConfig` is zero or greater than 20
    error InvalidSponsoredWindow(uint8 window);

    /// @notice Thrown when `unsponsoredWindow` in `RefMultiplierConfig` is zero or greater than 20
    error InvalidUnsponsoredWindow(uint8 window);

    // =============================================================
    //                    INITIALIZATION ERRORS
    // =============================================================

    /// @notice Thrown when the diamond has already been initialized
    error DiamondAlreadyInitialized();

    // =============================================================
    //                    ACCESS CONTROL ERRORS
    // =============================================================

    /// @notice Thrown when the caller is not the contract owner or does not have DEFAULT_ADMIN_ROLE
    error CallerMustBeAdminError();

    /// @notice Thrown when a function is locked via _lockFunction
    error FunctionLocked(bytes4 fnSig);

    /// @notice Thrown when bad confirmation is provided for role renunciation
    error AccessControlBadConfirmation();
}
