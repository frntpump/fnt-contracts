// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "./LibAppStorage.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {
    SingleStakingState,
    SingleStakePosition,
    SingleStakingConfig,
    SingleStakingLockConfig,
    SingleStakingTierConfig,
    SingleStakingTierConfigUpdate,
    StakeTier
} from "../shared/Structs.sol";
import {LibConstants as LC} from "./LibConstants.sol";

/// @title LibSingleStaking
/// @author Forever Network
/// @notice Helper utilities for the single-token staking facet.
library LibSingleStaking {
    uint16 internal constant BPS_DENOMINATOR = 10_000;
    uint32 internal constant MIN_BASE_APR_BPS = 1_500; // 15%
    uint32 internal constant MAX_BASE_APR_BPS = 200_000; // 2,000%
    uint32 internal constant MAX_BONUS_BPS = 5_000; // +50%
    uint32 internal constant MAX_REFERRAL_BONUS_BPS = 20_000; // +200%
    uint8 internal constant MAX_TIER_INDEX = uint8(StakeTier.Mythril);
    uint256 internal constant YEAR_IN_SECONDS = 365 days;

    /**
     * @notice Returns the staking storage bucket from AppStorage.
     * @dev Provides a convenient accessor to the single staking state within the diamond storage.
     * @return ss Storage pointer to the SingleStakingState struct.
     */
    function stakingStorage() internal view returns (SingleStakingState storage ss) {
        return LibAppStorage.diamondStorage().singleStaking;
    }

    /**
     * @notice Returns a pointer to the requested lock configuration.
     * @dev Validates that the lock ID exists before returning the configuration.
     * Reverts with {InvalidLockId} if the lock ID is greater than or equal to the total lock count.
     * @param ss Storage pointer to the SingleStakingState.
     * @param lockId The identifier of the lock configuration to retrieve.
     * @return lockCfg Storage pointer to the SingleStakingLockConfig.
     */
    function lockStorage(SingleStakingState storage ss, uint8 lockId)
        internal
        view
        returns (SingleStakingLockConfig storage lockCfg)
    {
        if (lockId >= ss.lockConfigCount) revert LibErrors.InvalidLockId(lockId);
        lockCfg = ss.lockConfigs[lockId];
    }

    /**
     * @notice Loads a stake position and ensures it exists and is active.
     * @dev Retrieves the position from storage and validates that it's marked as active.
     * Reverts with {StakeNotFound} if the position doesn't exist or is inactive.
     * @param ss Storage pointer to the SingleStakingState.
     * @param stakeId The unique identifier of the staking position.
     * @return position Storage pointer to the SingleStakePosition.
     */
    function positionStorage(SingleStakingState storage ss, uint256 stakeId)
        internal
        view
        returns (SingleStakePosition storage position)
    {
        position = ss.positions[stakeId];
        if (!position.active) revert LibErrors.StakeNotFound(stakeId);
    }

    /**
     * @notice Accrues rewards into storage for a position.
     * @dev Calculates rewards based on elapsed time since last update, using the formula:
     * rewards = (rewardBase * aprBps * elapsed) / (YEAR_IN_SECONDS * BPS_DENOMINATOR)
     * If auto-compounding is enabled, rewards are added to rewardBase and compoundedRewards.
     * If auto-compounding is disabled, rewards are added to unclaimedRewards.
     * Updates the lastUpdate timestamp to current block.timestamp.
     * @param position Storage pointer to the SingleStakePosition to settle.
     * @return newlyAccrued The amount of rewards accrued during this settlement (0 if position is inactive or no time has elapsed).
     */
    function settle(SingleStakePosition storage position) internal returns (uint256 newlyAccrued) {
        if (!position.active) return 0;

        uint256 lastUpdate = uint256(position.lastUpdate);
        if (block.timestamp <= lastUpdate) return 0;

        uint256 elapsed = block.timestamp - lastUpdate;
        newlyAccrued = (position.rewardBase * position.aprBps * elapsed) / (YEAR_IN_SECONDS * BPS_DENOMINATOR);
        position.lastUpdate = uint40(block.timestamp);

        if (newlyAccrued == 0) return 0;

        if (position.autoCompound) {
            position.rewardBase += newlyAccrued;
            position.compoundedRewards += newlyAccrued;
            emit LibEvents.SingleStakeRewardsAccrued(
                position.owner, position.stakedAmount, newlyAccrued, position.rewardBase, true
            );
        } else {
            position.unclaimedRewards += newlyAccrued;
            emit LibEvents.SingleStakeRewardsAccrued(
                position.owner, position.stakedAmount, newlyAccrued, position.rewardBase, false
            );
        }
    }

    /**
     * @notice Computes pending rewards for a position without mutating state.
     * @dev This is a view function that calculates what rewards would be available if settled now.
     * Uses the same formula as `settle()` but doesn't modify storage.
     * Useful for UI display or preview functions.
     * @param position Storage pointer to the SingleStakePosition to query.
     * @return totalPending Total pending rewards (unclaimed + compounded, depending on auto-compound setting).
     * @return accruedSinceUpdate Rewards accrued since the last settlement (not yet added to position).
     */
    function pendingRewards(SingleStakePosition storage position)
        internal
        view
        returns (uint256 totalPending, uint256 accruedSinceUpdate)
    {
        if (!position.active) {
            return (position.unclaimedRewards + position.compoundedRewards, 0);
        }

        uint256 lastUpdate = uint256(position.lastUpdate);
        if (block.timestamp > lastUpdate) {
            uint256 elapsed = block.timestamp - lastUpdate;
            accruedSinceUpdate = (position.rewardBase * position.aprBps * elapsed) / (YEAR_IN_SECONDS * BPS_DENOMINATOR);
        }

        if (position.autoCompound) {
            totalPending = position.compoundedRewards + accruedSinceUpdate;
        } else {
            totalPending = position.unclaimedRewards + accruedSinceUpdate;
        }
    }

    /**
     * @notice Removes a position and keeps owner arrays compact.
     * @dev Implements efficient removal by swapping the position to remove with the last position in the owner's array,
     * then popping the last element. This maintains O(1) removal complexity.
     * Also cleans up the positionIndexInOwner mapping and deletes the position from the positions mapping.
     * @param ss Storage pointer to the SingleStakingState.
     * @param stakeId The unique identifier of the staking position to remove.
     */
    function removePosition(SingleStakingState storage ss, uint256 stakeId) internal {
        SingleStakePosition storage position = ss.positions[stakeId];
        address owner = position.owner;
        uint256[] storage ownerArray = ss.ownerPositions[owner];
        uint256 index = ss.positionIndexInOwner[stakeId];
        uint256 lastIndex = ownerArray.length - 1;

        if (index != lastIndex) {
            uint256 lastStakeId = ownerArray[lastIndex];
            ownerArray[index] = lastStakeId;
            ss.positionIndexInOwner[lastStakeId] = index;
        }

        ownerArray.pop();
        delete ss.positionIndexInOwner[stakeId];
        delete ss.positions[stakeId];
    }

    /**
     * @notice Validates that staking is enabled.
     * @dev Convenience function to check the enabled flag and revert if staking is disabled.
     * @param enabled The enabled status to check.
     */
    function ensureEnabled(bool enabled) internal pure {
        if (!enabled) revert LibErrors.StakingDisabled();
    }

    /**
     * @notice Validates that a stake amount meets the minimum requirement.
     * @dev Reverts with {StakeAmountBelowMinimum} if the amount is less than the configured minimum.
     * @param amount The stake amount to validate.
     * @param minimum The minimum stake amount required.
     */
    function ensureAmountAboveMinimum(uint256 amount, uint256 minimum) internal pure {
        if (amount < minimum) revert LibErrors.StakeAmountBelowMinimum(amount, minimum);
    }

    /**
     * @notice Validates base APR values are within acceptable range.
     * @dev Ensures APR is between MIN_BASE_APR_BPS (15%) and MAX_BASE_APR_BPS (200%).
     * Reverts with {InvalidApr} if the value is outside this range.
     * @param aprBps The APR value in basis points to validate.
     */
    function validateApr(uint32 aprBps) internal pure {
        if (aprBps < MIN_BASE_APR_BPS || aprBps > MAX_BASE_APR_BPS) revert LibErrors.InvalidApr(aprBps);
    }

    /**
     * @notice Validates bonus APR values are within acceptable range.
     * @dev Ensures bonus APR does not exceed MAX_BONUS_BPS (50%).
     * Reverts with {InvalidBonus} if the value is too high.
     * @param bonusBps The bonus APR value in basis points to validate.
     */
    function validateBonus(uint16 bonusBps) internal pure {
        if (bonusBps > MAX_BONUS_BPS) revert LibErrors.InvalidBonus(bonusBps);
    }

    /**
     * @notice Validates penalty values are within acceptable range.
     * @dev Ensures penalty does not exceed 100% (10000 basis points).
     * Reverts with {InvalidPenaltyBps} if the value is too high.
     * @param penaltyBps The penalty value in basis points to validate.
     */
    function validatePenalty(uint16 penaltyBps) internal pure {
        if (penaltyBps > BPS_DENOMINATOR) revert LibErrors.InvalidPenaltyBps(penaltyBps);
    }

    /**
     * @notice Validates lock durations against a fixed set of allowed values.
     * @dev Only allows durations of 7, 14, 30, 45, 60, or 90 days as per product specification.
     * Reverts with {InvalidLockDuration} if the duration is not one of these values.
     * @param duration The lock duration in seconds to validate.
     */
    function validateDuration(uint64 duration) internal pure {
        if (
            duration != 7 days && duration != 14 days && duration != 30 days && duration != 45 days
                && duration != 60 days && duration != 90 days
        ) {
            revert LibErrors.InvalidLockDuration(duration);
        }
    }

    /**
     * @notice Helper to resolve enabled flag updates encoded as uint8.
     * @dev The enabledFlag encoding is:
     * - 0: No change (return current value, changed = false)
     * - 1: Disable (return false, changed = true if current was true)
     * - 2: Enable (return true, changed = true if current was false)
     * Reverts with {InvalidEnabledFlag} if the flag value is not 0, 1, or 2.
     * @param current The current enabled status.
     * @param enabledFlag The encoded flag indicating the desired change.
     * @return newValue The new enabled value.
     * @return changed Whether the value actually changed from current.
     */
    function resolveEnabled(bool current, uint8 enabledFlag) internal pure returns (bool newValue, bool changed) {
        if (enabledFlag == 0) return (current, false);
        if (enabledFlag == 1) return (false, current);
        if (enabledFlag == 2) return (true, !current);
        revert LibErrors.InvalidEnabledFlag(enabledFlag);
    }

    /**
     * @notice Ensures the new auto-compound flag differs from current setting.
     * @dev Prevents unnecessary state updates when the user tries to set auto-compound to its current value.
     * Reverts with {AutoCompoundPreferenceUnchanged} if current and requested are the same.
     * @param current The current auto-compound setting.
     * @param requested The requested auto-compound setting.
     */
    function requirePreferenceChange(bool current, bool requested) internal pure {
        if (current == requested) revert LibErrors.AutoCompoundPreferenceUnchanged();
    }

    /**
     * @notice Ensures penalty withdrawals do not exceed the retained balance.
     * @dev Validates that the requested withdrawal amount is available in the penalty token balance.
     * Reverts with {PenaltyWithdrawalExceedsBalance} if requested > available.
     * @param available The current penalty token balance available for withdrawal.
     * @param requested The amount requested for withdrawal.
     */
    function enforcePenaltyWithdrawal(uint256 available, uint256 requested) internal pure {
        if (requested > available) revert LibErrors.PenaltyWithdrawalExceedsBalance(available, requested);
    }

    /**
     * @notice Ensures there are rewards available before minting.
     * @dev Validates that the reward amount is non-zero before proceeding with minting.
     * Reverts with {NoRewardsAvailable} if amount is 0.
     * @param amount The reward amount to validate.
     */
    function ensureRewardsAvailable(uint256 amount) internal pure {
        if (amount == 0) revert LibErrors.NoRewardsAvailable();
    }

    /**
     * @notice Collects a staking fee in native currency (BNB) and transfers it to the configured recipient.
     * @dev Validates that msg.value is sufficient to cover the required fee.
     * If a fee recipient is configured, transfers the fee to that address.
     * If no recipient is configured (address(0)), the fee stays in the diamond.
     * Reverts with {InsufficientStakingFee} if msg.value < required fee.
     * Reverts with {StakingFeeTransferFailed} if the transfer to the recipient fails.
     * Emits a {SingleStakingFeeCollected} event upon successful fee collection.
     * @param config Storage pointer to the SingleStakingConfig containing fee settings.
     * @param feeAmount The required fee amount in wei.
     * @param feeType A string describing the type of fee ("stake" or "unstake").
     * @param actor The address of the user performing the action (for event attribution).
     */
    function collectStakingFee(
        SingleStakingConfig storage config,
        uint256 feeAmount,
        string memory feeType,
        address actor
    ) internal {
        if (msg.value < feeAmount) {
            revert LibErrors.InsufficientFee(msg.value, feeAmount);
        }

        address recipient = config.feeRecipient;

        // If a fee recipient is configured, transfer the fee
        if (recipient != address(0) && feeAmount > 0) {
            (bool success,) = payable(recipient).call{value: feeAmount}("");
            if (!success) revert LibErrors.StakingFeeTransferFailed();

            emit LibEvents.SingleStakingFeeCollected(actor, feeType, feeAmount);
        } else if (feeAmount > 0) {
            // Fee stays in diamond if no recipient configured
            emit LibEvents.SingleStakingFeeCollected(actor, feeType, feeAmount);
        }

        // Refund any overpayment back to the caller to enforce exactness
        uint256 overpayment = msg.value - feeAmount;
        if (overpayment > 0) {
            (bool refundOk,) = payable(actor).call{value: overpayment}("");
            if (!refundOk) revert LibErrors.StakingFeeTransferFailed();
        }
    }

    /**
     * @notice Normalises duration sentinel values for configuration updates.
     * @dev If duration is the sentinel value (UNCHANGED_UINT64), returns (false, 0) to skip the update.
     * Otherwise, validates the duration and returns (true, normalised_duration).
     * @param duration The duration value to normalise (may be sentinel value).
     * @return shouldUpdate Whether the duration should be updated.
     * @return normalised The normalised duration value (converted to uint40).
     */
    function normaliseDuration(uint64 duration) internal pure returns (bool shouldUpdate, uint40 normalised) {
        if (duration == LC.UNCHANGED_UINT64) return (false, 0);
        validateDuration(duration);
        // casting to 'uint40' is safe because validateDuration() restricts duration to one of
        // {7, 14, 30, 45, 60, 90} days which are all far below 2^40-1 seconds
        // forge-lint: disable-next-line(unsafe-typecast)
        return (true, uint40(duration));
    }

    /**
     * @notice Normalises APR sentinel values for configuration updates.
     * @dev If aprBps is the sentinel value (UNCHANGED_UINT32), returns (false, 0) to skip the update.
     * Otherwise, validates the APR and returns (true, aprBps).
     * @param aprBps The APR value to normalise (may be sentinel value).
     * @return shouldUpdate Whether the APR should be updated.
     * @return normalised The normalised APR value.
     */
    function normaliseApr(uint32 aprBps) internal pure returns (bool shouldUpdate, uint32 normalised) {
        if (aprBps == LC.UNCHANGED_UINT32) return (false, 0);
        validateApr(aprBps);
        return (true, aprBps);
    }

    /**
     * @notice Normalises minimum stake sentinel values for configuration updates.
     * @dev If minStakeAmount is the sentinel value (UNCHANGED_UINT256), returns (false, 0) to skip the update.
     * Otherwise, validates the amount is non-zero and returns (true, minStakeAmount).
     * Reverts with {InvalidMinimumStake} if a non-sentinel value of 0 is provided.
     * @param minStakeAmount The minimum stake amount to normalise (may be sentinel value).
     * @return shouldUpdate Whether the minimum stake should be updated.
     * @return normalised The normalised minimum stake amount.
     */
    function normaliseMinStake(uint256 minStakeAmount) internal pure returns (bool shouldUpdate, uint256 normalised) {
        if (minStakeAmount == LC.UNCHANGED_UINT256) return (false, 0);
        if (minStakeAmount == 0) revert LibErrors.InvalidMinimumStake(minStakeAmount);
        return (true, minStakeAmount);
    }

    /**
     * @notice Determines Staking referral tier and bonus APR based on referral count.
     * @dev First determines which tier the participant qualifies for based on their referral count,
     * then calculates the corresponding bonus APR for that tier.
     * @param ss Storage pointer to the SingleStakingState.
     * @param referralCount The participant's current referral count.
     * @return tier The StakeTier enum value the participant qualifies for.
     * @return bonusBps The bonus APR in basis points for the determined tier.
     */
    function determineReferralBonus(SingleStakingState storage ss, uint256 referralCount)
        internal
        view
        returns (StakeTier tier, uint16 bonusBps)
    {
        tier = _getTierFromReferrals(ss, referralCount);
        bonusBps = _calculateReferralBoost(ss, tier);
    }

    /**
     * @notice Returns all configured tier settings ordered by tier id.
     * @dev Iterates through all possible tier IDs (0 to MAX_TIER_INDEX) and collects their configurations.
     * Used for UI display and configuration queries.
     * @param ss Storage pointer to the SingleStakingState.
     * @return tiers An array of SingleStakingTierConfig structs containing all tier configurations.
     */
    function collectTierConfigs(SingleStakingState storage ss)
        internal
        view
        returns (SingleStakingTierConfig[] memory tiers)
    {
        uint256 length = uint256(MAX_TIER_INDEX) + 1;
        tiers = new SingleStakingTierConfig[](length);
        for (uint256 i = 0; i < length; i++) {
            // MAX_TIER_INDEX is <= 255 ensuring cast safety.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8 tierId = uint8(i);
            tiers[i] = ss.tierConfigs[tierId];
        }
    }

    /**
     * @notice Updates a tier configuration with validation enforced.
     * @dev Applies the update payload to the specified tier, validating:
     * - Tier ID is valid (not None and within MAX_TIER_INDEX)
     * - Referral thresholds are properly ordered (greater than previous tier, less than next tier)
     * - Bonus APR is within acceptable range
     * Only updates fields that are not sentinel values.
     * @param ss Storage pointer to the SingleStakingState.
     * @param update The update payload containing the tier and values to update.
     * @return snapshot A memory copy of the updated tier configuration.
     */
    function updateTierConfig(SingleStakingState storage ss, SingleStakingTierConfigUpdate calldata update)
        internal
        returns (SingleStakingTierConfig memory snapshot)
    {
        StakeTier tier = update.tier;
        uint8 tierId = uint8(tier);

        if (tier == StakeTier.None || tierId > MAX_TIER_INDEX) revert LibErrors.InvalidTierId(tierId);

        SingleStakingTierConfig storage config = ss.tierConfigs[tierId];

        if (update.minReferrals != LC.UNCHANGED_UINT48) {
            _validateTierThreshold(ss, tier, update.minReferrals);
            config.minReferrals = update.minReferrals;
        }

        if (update.bonusAprBps != LC.UNCHANGED_UINT16) {
            _validateReferralBonus(update.bonusAprBps);
            config.bonusAprBps = update.bonusAprBps;
        }

        if (update.enabledFlag != 0) {
            (bool newEnabled, bool changed) = resolveEnabled(config.enabled, update.enabledFlag);
            if (changed) {
                config.enabled = newEnabled;
            }
        }

        snapshot = SingleStakingTierConfig({
            minReferrals: config.minReferrals, bonusAprBps: config.bonusAprBps, enabled: config.enabled
        });
    }

    /**
     * @notice Seeds a Staking tier configuration during initialization.
     * @dev Used during contract initialization where ordering is pre-validated.
     * Skips runtime validation checks that are performed in updateTierConfig.
     * Directly writes the tier configuration to storage.
     * @param ss Storage pointer to the SingleStakingState.
     * @param tier The StakeTier enum value to seed.
     * @param minReferrals Minimum referrals required for the tier.
     * @param bonusAprBps Bonus APR in basis points for the tier.
     * @param enabled Whether the tier is initially enabled.
     */
    function seedTier(
        SingleStakingState storage ss,
        StakeTier tier,
        uint48 minReferrals,
        uint16 bonusAprBps,
        bool enabled
    ) internal {
        uint8 tierId = uint8(tier);
        if (tierId > MAX_TIER_INDEX) revert LibErrors.InvalidTierId(tierId);
        ss.tierConfigs[tierId] =
            SingleStakingTierConfig({minReferrals: minReferrals, bonusAprBps: bonusAprBps, enabled: enabled});
    }

    /**
     * @notice Internal function to determine which Staking tier a participant qualifies for based on referral count.
     * @dev Iterates from highest tier to lowest, returning the first tier where:
     * - The tier is enabled
     * - The tier has a non-zero minReferrals threshold
     * - The participant's referral count meets or exceeds the threshold
     * Returns StakeTier.None if no tier is matched or referral count is 0.
     * @param ss Storage pointer to the SingleStakingState.
     * @param referralCount The participant's current referral count.
     * @return The highest StakeTier the participant qualifies for.
     */
    function _getTierFromReferrals(SingleStakingState storage ss, uint256 referralCount)
        private
        view
        returns (StakeTier)
    {
        if (referralCount == 0) {
            return StakeTier.None;
        }

        for (uint256 i = MAX_TIER_INDEX;; i--) {
            // MAX_TIER_INDEX is <= 255 ensuring cast safety.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8 tierIndex = uint8(i);
            SingleStakingTierConfig storage config = ss.tierConfigs[tierIndex];
            if (config.enabled && config.minReferrals > 0 && referralCount >= config.minReferrals) {
                // forge-lint: disable-next-line(unsafe-typecast)
                return StakeTier(tierIndex);
            }
            if (i == 0) break;
        }

        return StakeTier.None;
    }

    /**
     * @notice Internal function to calculate the referral boost APR for a given staking tier.
     * @dev Returns 0 if the tier is None or if the tier configuration is disabled.
     * Otherwise returns the bonusAprBps from the tier configuration.
     * @param ss Storage pointer to the SingleStakingState.
     * @param tier The StakeTier to get the bonus for.
     * @return The bonus APR in basis points for the tier.
     */
    function _calculateReferralBoost(SingleStakingState storage ss, StakeTier tier) private view returns (uint16) {
        if (tier == StakeTier.None) return 0;

        SingleStakingTierConfig storage config = ss.tierConfigs[uint8(tier)];
        if (!config.enabled) return 0;
        return config.bonusAprBps;
    }

    /**
     * @notice Internal function to validate referral bonus APR values.
     * @dev Ensures the bonus APR does not exceed MAX_REFERRAL_BONUS_BPS (200%).
     * Reverts with {InvalidBonus} if the value is too high.
     * @param bonusBps The bonus APR value in basis points to validate.
     */
    function _validateReferralBonus(uint16 bonusBps) private pure {
        if (bonusBps > MAX_REFERRAL_BONUS_BPS) revert LibErrors.InvalidBonus(bonusBps);
    }

    /**
     * @notice Internal function to validate tier threshold ordering and values.
     * @dev Ensures that:
     * - The new threshold is non-zero (except for tier None which isn't updated)
     * - Bronze tier (first real tier) must have a non-zero threshold
     * - Each tier's threshold is strictly greater than the previous tier's threshold
     * - Each tier's threshold is strictly less than the next tier's threshold
     * This maintains a properly ordered progression of tiers.
     * Reverts with appropriate errors if validation fails.
     * @param ss Storage pointer to the SingleStakingState.
     * @param tier The tier being updated.
     * @param newThreshold The new referral count threshold to validate.
     */
    function _validateTierThreshold(SingleStakingState storage ss, StakeTier tier, uint48 newThreshold) private view {
        uint8 tierId = uint8(tier);
        if (newThreshold == 0) revert LibErrors.InvalidTierReferrals(tierId, newThreshold);

        if (tierId > uint8(StakeTier.Bronze)) {
            StakeTier previousTier = StakeTier(tierId - 1);
            uint48 previousThreshold = ss.tierConfigs[uint8(previousTier)].minReferrals;
            if (previousThreshold != 0 && newThreshold <= previousThreshold) {
                revert LibErrors.TierThresholdBelowPrevious(tierId, newThreshold, previousThreshold);
            }
        } else if (tier == StakeTier.Bronze && newThreshold == 0) {
            revert LibErrors.InvalidTierReferrals(tierId, newThreshold);
        }

        if (tierId < MAX_TIER_INDEX) {
            StakeTier nextTier = StakeTier(tierId + 1);
            uint48 nextThreshold = ss.tierConfigs[uint8(nextTier)].minReferrals;
            if (nextThreshold != 0 && newThreshold >= nextThreshold) {
                revert LibErrors.TierThresholdAboveNext(tierId, newThreshold, nextThreshold);
            }
        }
    }
}
