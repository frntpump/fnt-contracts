// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {RefRewardConfig, RefMultiplierConfig} from "../shared/Structs.sol";
import {LibErrors} from "./LibErrors.sol";

/**
 * @title LibReferral
 * @author Forever Network
 * @notice Library for referral reward calculations
 * @dev Implements progressive reward structure with milestones
 */
library LibReferral {
    // Constants for fixed-point arithmetic
    uint256 private constant PERCENT_SCALE = 10_000;

    /**
     * @notice Calculate base token rewards based on referral count.
     * @dev Determines which reward tier applies to the given referral count by iterating from highest to lowest threshold.
     * If the referral count is below the first threshold, the first tier reward is returned.
     * If the referral count meets or exceeds a threshold, the corresponding reward is returned.
     * @param referralCount Number of referrals the participant has made.
     * @param config Reward configuration containing threshold and reward arrays.
     * @return tokenReward Base token reward amount (in token smallest units, e.g., wei) for the current referral count.
     */
    function calculateBaseReward(uint64 referralCount, RefRewardConfig memory config)
        internal
        pure
        returns (uint256 tokenReward)
    {
        if (config.thresholds.length == 0 || config.tokenRewards.length == 0) revert LibErrors.EmptyThresholds();
        if (referralCount < config.thresholds[0]) {
            return config.tokenRewards[0];
        }

        // Find applicable tier (iterate from highest to lowest)
        for (uint256 i = config.thresholds.length; i > 0; i--) {
            if (referralCount >= config.thresholds[i - 1]) {
                return config.tokenRewards[i - 1];
            }
        }

        // Should theoretically not be reached if thresholds are correctly configured and referralCount >= thresholds[0]
        // Default to the first reward if no threshold is met (e.g., referralCount is 0 and thresholds[0] is > 0)
        return config.tokenRewards[0];
    }

    /**
     * @notice Calculate rewards with multiplier applied based on participant type and referral count.
     * @dev First calculates the base reward, then checks if the participant qualifies for a multiplier bonus.
     * Multipliers apply for a limited "window" of referrals after reaching the threshold.
     * For example, if sponsored threshold is 50 with a window of 5 and multiplier of 3:
     * - Referral #50 (position 0) gets 3x reward
     * - Referral #51 (position 1) gets 3x reward
     * - ...
     * - Referral #54 (position 4) gets 3x reward
     * - Referral #55 (position 5) gets normal reward (outside window)
     * - Referral #100 (position 0 in next cycle) gets 3x reward again
     * @param referralCount Number of referrals the participant has made.
     * @param isSponsored Whether the participant is sponsored (affects which threshold/multiplier applies).
     * @param rewardConfig Reward configuration containing thresholds and base rewards.
     * @param multiplierConfig Multiplier configuration containing thresholds, multipliers, and windows.
     * @return Final token reward with multiplier applied (if applicable).
     */
    function calculateRewardWithMultiplier(
        uint64 referralCount,
        bool isSponsored,
        RefRewardConfig memory rewardConfig,
        RefMultiplierConfig memory multiplierConfig
    ) internal pure returns (uint256) {
        uint256 baseReward = calculateBaseReward(referralCount, rewardConfig);

        if (isSponsored && referralCount >= multiplierConfig.sponsoredThreshold) {
            uint256 position = referralCount % multiplierConfig.sponsoredThreshold;
            if (position < multiplierConfig.sponsoredWindow) {
                return baseReward * multiplierConfig.sponsoredMultiplier;
            }
        }

        if (!isSponsored && referralCount >= multiplierConfig.unsponsoredThreshold) {
            uint256 position = referralCount % multiplierConfig.unsponsoredThreshold;
            if (position < multiplierConfig.unsponsoredWindow) {
                return baseReward * multiplierConfig.unsponsoredMultiplier;
            }
        }

        return baseReward;
    }

    /**
     * @notice Determine the participant tier index (1-based) using reward thresholds.
     * @dev Returns 1 when below the first threshold. The returned value is 1-based index
     *      matching the threshold slot (so tier 1 corresponds to thresholds[0]).
     * @param referralCount The number of referrals the participant has.
     * @param config The referral reward configuration containing thresholds.
     * @return uint8 The computed tier (1 = lowest, otherwise 2..n)
     */
    function determineTier(uint64 referralCount, RefRewardConfig memory config) internal pure returns (uint8) {
        uint256 len = config.thresholds.length;
        if (len == 0) return 0;

        if (referralCount < config.thresholds[0]) return 1;

        for (uint256 i = len; i > 0;) {
            unchecked {
                i--;
            }
            if (referralCount >= config.thresholds[i]) {
                // casting to 'uint8' is safe because i < len <= 255 (reasonable config size)
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint8(i + 1); // 1-based tier index
            }
        }
        return 1; // Should not reach here if config is valid
    }

    /**
     * @notice Computes milestone referral rewards using a simple arithmetic progression.
     * @dev
     * - Model: R(m) = B + (m-1) * I, where I = B * p / PERCENT_SCALE
     * - R(m) is the individual reward for milestone m
     * - B is the baseReward (milestoneBonus)
     * - p is the percentMultiplier (in basis points, e.g., 1500 = 15%)
     * - I is the increment per milestone
     *
     * - The total reward for a range of milestones is calculated in O(1) using
     * the formula for the sum of an arithmetic series:
     * S_n = n/2 * (a_1 + a_n)
     *
     * - All calculations are done with fixed-point math to avoid floating-point precision issues.
     *
     * Example: If a participant goes from 200 to 500 referrals with:
     * - milestoneInterval = 100
     * - milestoneBonus = 0.1 BNB
     * - milestonePercentMultiplier = 1500 (15%)
     * They cross milestones 2, 3, 4, 5 and receive cumulative rewards for all.
     *
     * @param currentCount Current referral count of the participant.
     * @param lastMilestone Last milestone number claimed by the participant.
     * @param config Reward configuration containing milestone parameters.
     * @return nativeReward Total native reward (in wei) for all unclaimed milestones.
     * @return newMilestone New milestone value to store (capped at maxMilestones).
     */
    function calculateMilestoneReward(uint64 currentCount, uint256 lastMilestone, RefRewardConfig memory config)
        internal
        pure
        returns (uint256 nativeReward, uint256 newMilestone)
    {
        uint256 currentMilestone = currentCount / config.milestoneInterval;

        // Cap at max milestones
        if (currentMilestone > config.maxMilestones) {
            currentMilestone = config.maxMilestones;
        }
        if (lastMilestone > config.maxMilestones) {
            lastMilestone = config.maxMilestones;
        }

        if (currentMilestone <= lastMilestone) {
            return (0, lastMilestone);
        }

        // We have new milestones to claim.
        // Use O(1) formula for sum of arithmetic series:
        // S_n = n/2 * (a_1 + a_n)
        //
        // n = currentMilestone - lastMilestone
        // a_1 = Reward for (lastMilestone + 1)
        // a_n = Reward for currentMilestone
        //
        // R(m) = B + (m-1) * I
        // I = (B * p) / PERCENT_SCALE
        //
        // a_1 = B + (lastMilestone) * I
        // a_n = B + (currentMilestone - 1) * I
        //
        // a_1 + a_n = 2B + (lastMilestone + currentMilestone - 1) * I
        //
        // S_n = n/2 * [2B + (m_l + m_c - 1) * (B * p) / PERCENT_SCALE]
        // S_n = n/2 * [ (2B * PERCENT_SCALE + (m_l + m_c - 1) * B * p) / PERCENT_SCALE ]
        // S_n = (n * B) / (2 * PERCENT_SCALE) * [ 2 * PERCENT_SCALE + p * (m_l + m_c - 1) ]

        uint256 n = currentMilestone - lastMilestone;
        uint256 B = config.milestoneBonus;
        uint64 p = config.milestonePercentMultiplier;

        // (m_l + m_c - 1)
        uint256 sumM = lastMilestone + currentMilestone - 1;

        // [ 2 * PERCENT_SCALE + p * (m_l + m_c - 1) ]
        uint256 scaledSum = (2 * PERCENT_SCALE) + (p * sumM);

        // (n * B * scaled_sum)
        uint256 numerator = n * B * scaledSum;

        // (2 * PERCENT_SCALE)
        uint256 denominator = 2 * PERCENT_SCALE;

        // S_n = numerator / denominator
        nativeReward = numerator / denominator;
        newMilestone = currentMilestone;
    }

    /**
     * @notice Validate reward configuration parameters.
     * @dev Ensures array lengths match, thresholds and rewards are ascending,
     *      and that milestone configuration values are within safe bounds.
     * @param config The reward configuration struct to validate.
     */
    function validateRewardConfig(RefRewardConfig memory config) internal pure {
        uint256 len = config.thresholds.length;
        if (len == 0) revert LibErrors.EmptyThresholds();

        if (len != config.tokenRewards.length) revert LibErrors.ConfigLengthMismatch();
        if (config.milestoneInterval == 0) revert LibErrors.ZeroMilestoneInterval();

        uint256 maxMilestones = config.maxMilestones;
        if (maxMilestones == 0 || maxMilestones > 100) revert LibErrors.InvalidMaxMilestones(maxMilestones);

        if (config.milestonePercentMultiplier > PERCENT_SCALE) {
            revert LibErrors.InvalidMaxMilestonePercentMultiplier(config.milestonePercentMultiplier);
        }

        // Cache memory arrays locally for cheaper access
        uint48[] memory thresholds = config.thresholds;
        uint256[] memory rewards = config.tokenRewards;

        // Validate ascending order for thresholds and rewards in a single loop
        uint48 prevThreshold = thresholds[0];
        uint256 prevReward = rewards[0];
        unchecked {
            for (uint256 i = 1; i < len; ++i) {
                uint48 t = thresholds[i];
                uint256 r = rewards[i];

                if (t <= prevThreshold) revert LibErrors.ThresholdsNotAscending();
                if (r < prevReward) revert LibErrors.RewardsNotAscending();

                prevThreshold = t;
                prevReward = r;
            }
        }
    }

    /**
     * @notice Validate referral multiplier configuration parameters.
     * @dev Ensures that:
     * - Both sponsored and unsponsored thresholds are non-zero
     * - Both multipliers are between 2 and 10 (inclusive) - must provide meaningful bonus
     * - Both windows are between 1 and 20 (inclusive) - reasonable duration for multiplier effect
     * Reverts with specific errors if any validation fails.
     * @param config The multiplier configuration struct to validate.
     */
    function validateMultiplierConfig(RefMultiplierConfig memory config) internal pure {
        if (config.sponsoredThreshold == 0) revert LibErrors.ZeroSponsoredThreshold();
        if (config.unsponsoredThreshold == 0) revert LibErrors.ZeroUnsponsoredThreshold();
        if (config.sponsoredMultiplier <= 1 || config.sponsoredMultiplier > 10) {
            revert LibErrors.InvalidSponsoredMultiplier(config.sponsoredMultiplier);
        }
        if (config.unsponsoredMultiplier <= 1 || config.unsponsoredMultiplier > 10) {
            revert LibErrors.InvalidUnsponsoredMultiplier(config.unsponsoredMultiplier);
        }
        if (config.sponsoredWindow == 0 || config.sponsoredWindow > 20) {
            revert LibErrors.InvalidSponsoredWindow(config.sponsoredWindow);
        }
        if (config.unsponsoredWindow == 0 || config.unsponsoredWindow > 20) {
            revert LibErrors.InvalidUnsponsoredWindow(config.unsponsoredWindow);
        }
    }
}
