// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FeeTier, FeeConfig} from "../shared/Structs.sol";

/// @title LibFees
/// @dev A library for calculating dynamic, tier-based fees for minting and burning.
library LibFees {
    uint16 constant MAX_FEE_BPS = 9500; // 95%
    uint16 constant BASIS_POINTS = 10_000; // 100%

    error TiersNotSorted();
    error FeeTooHigh(uint16 maxFeeBps);
    error InvalidThreshold();

    /**
     * @notice Calculates the fee for a given transaction count and amount based on the provided fee config.
     * @dev Finds the appropriate tier by iterating through the sorted tiers in reverse for efficiency.
     * @param config The fee configuration (e.g., for mints or burns).
     * @param transactionCount The current mint or burn count to determine the fee tier.
     * @param amount The base amount to calculate the fee from.
     * @return The calculated fee amount in token units.
     */
    function calculateFee(FeeConfig storage config, uint256 transactionCount, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (config.tiers.length == 0 || amount == 0) {
            return 0;
        }

        uint16 feeBps = 0;

        // Find the highest applicable tier by iterating from highest to lowest
        // This is more efficient when transaction counts are high
        for (uint256 i = config.tiers.length; i > 0; i--) {
            uint256 index = i - 1;
            if (transactionCount >= config.tiers[index].threshold) {
                feeBps = config.tiers[index].feeBps;
                break;
            }
        }

        if (feeBps == 0) {
            return 0;
        }

        // Use unchecked for gas optimization since we know feeBps <= MAX_FEE_BPS
        unchecked {
            return (amount * feeBps) / BASIS_POINTS;
        }
    }

    /**
     * @notice Validates a new fee configuration to ensure correctness.
     * @dev Checks that tiers are sorted by threshold and fees are within the max limit.
     * @param newTiers The new array of fee tiers.
     */
    function validateFeeConfig(FeeTier[] memory newTiers) internal pure {
        if (newTiers.length == 0) {
            return; // Empty config is valid (no fees)
        }

        // First tier must start at threshold 0
        if (newTiers[0].threshold != 0) {
            revert InvalidThreshold();
        }

        uint256 lastThreshold = 0;
        for (uint256 i = 0; i < newTiers.length; i++) {
            if (i > 0 && newTiers[i].threshold <= lastThreshold) {
                revert TiersNotSorted();
            }
            if (newTiers[i].feeBps > MAX_FEE_BPS) {
                revert FeeTooHigh(MAX_FEE_BPS);
            }
            lastThreshold = newTiers[i].threshold;
        }
    }

    /**
     * @notice Apply a percentage fee to an amount
     * @param amount The base amount
     * @param bps The fee in basis points
     * @return The fee amount
     */
    function applyPercentage(uint256 amount, uint16 bps) internal pure returns (uint256) {
        if (bps == 0 || amount == 0) {
            return 0;
        }
        unchecked {
            return (amount * bps) / BASIS_POINTS;
        }
    }
}
