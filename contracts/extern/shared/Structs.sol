// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

struct FeeTier {
    uint256 threshold; // The transaction count at which this tier becomes active.
    uint16 feeBps; // The fee in basis points (e.g., 100 bps = 1%).
}

struct FeeConfig {
    FeeTier[] tiers;
}
