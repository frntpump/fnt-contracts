// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibErrors} from "./LibErrors.sol";

/**
 * @title LibPurchase
 * @author Forever Network
 * @notice A library for common calculations related to token purchases.
 */
library LibPurchase {
    /**
     * @notice Calculates the amount of tokens a user should receive for a given native currency value.
     * @param value The amount of native currency sent (in wei).
     * @param purchaseRate The price of one full token unit in wei.
     * @return uint256 The calculated token amount in its smallest unit (e.g., with 18 decimals).
     */
    function calculateTokenAmount(uint256 value, uint256 purchaseRate) internal pure returns (uint256) {
        if (purchaseRate == 0) revert LibErrors.InvalidPurchaseRate();
        unchecked {
            // Scale by token decimals so wei inputs produce 18-decimal token outputs
            return (value * 10 ** 18) / purchaseRate;
        }
    }

    /**
     * @notice Calculates the whale tax based on a token amount and basis points.
     * @param tokenAmount The gross amount of tokens being purchased.
     * @param basisPoints The tax rate in basis points (e.g., 3000 for 30%).
     * @return uint256 The calculated tax amount in token units.
     */
    function calculateWhaleTax(uint256 tokenAmount, uint16 basisPoints) internal pure returns (uint256) {
        if (basisPoints == 0) {
            return 0;
        }
        uint256 tax = (tokenAmount * basisPoints) / 10000;
        if (tax > tokenAmount) revert LibErrors.WhaleTaxExceedsAmount();
        return tax;
    }

    /**
     * @notice Calculates the absolute token threshold from a percentage of the max limit.
     * @dev `thresholdBps` is in basis points (0-10000), meaning `100` = 1%, `10000` = 100%.
     * @param maxLimit Maximum total token purchase limit (in token smallest units).
     * @param thresholdBps Threshold as basis points of `maxLimit` (e.g., 500 = 5%).
     * @return uint256 The absolute token amount threshold.
     */
    function calculateWhaleThresholdAmount(uint256 maxLimit, uint16 thresholdBps) internal pure returns (uint256) {
        return _applyPercentage(maxLimit, thresholdBps);
    }

    /**
     * @notice Internal helper function to apply a percentage (in basis points) to a given value.
     * @dev Used for calculating percentages with precision. Reverts if bps exceeds 10000 (100%).
     * Formula: result = (value * bps) / 10000
     * Example: _applyPercentage(1000, 2500) = 250 (25% of 1000)
     * @param value The base value to apply the percentage to.
     * @param bps The percentage in basis points (e.g., 100 = 1%, 10000 = 100%).
     * @return uint256 The calculated value after applying the percentage.
     */
    function _applyPercentage(uint256 value, uint16 bps) internal pure returns (uint256) {
        if (bps > 10_000) revert LibErrors.InvalidLimits();
        return (value * bps) / 10_000;
    }
}
