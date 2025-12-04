// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Structs
 * @author Forever Network
 * @notice Defines all data structures used throughout the Forever Network Diamond
 */

/**
 * @dev Global state variables for the FNT Diamond.
 */
struct GlobalState {
    bool paused;
    uint48 participantCount;
    uint48 referralCount;
    uint48 purchaserCount;
    uint48 sponsoredParticipantCount;
    uint256 totalNativeClaimed;
    uint256 totalTokenClaimed;
}

/**
 * @dev State variables related to the FNT token's operations.
 */
struct TokenState {
    uint48 purchaseTimes;
    uint64 mintTimes;
    uint256 totalPurchased;
    uint256 totalMinted;
}

/**
 * @dev Configuration parameters for global system behavior.
 */
struct GlobalConfiguration {
    /// @dev Minimum FNT balance required for active status.
    uint256 existentialDeposit;
    /// @dev Deferred token bonus for new participants upon registration.
    uint256 refereeDeferredTokenBonus;
    /// @dev Instant token bonus minted for new participants upon registration.
    uint256 refereeInstantTokenBonus;
}

/**
 * @dev Stores context information for meta-transactions (EIP-2771).
 */
struct MetaTxContextStorage {
    address trustedForwarder;
}

/**
 * @dev Information used for EIP-712 typed data signing.
 */
struct EIP712Info {
    /// @dev Domain separator computed at contract deployment.
    bytes32 initialDomainSeparator;
    /// @dev Chain ID at contract deployment.
    uint256 initialChainId;
    string name;
}

/**
 * @dev Data structure for managing roles within the AccessControl system.
 */
struct RoleData {
    mapping(address => bool) hasRole;
    bytes32 adminRole;
}

/**
 * @dev Configuration parameters for token purchase mechanics.
 * @dev OPTIMIZED: Packed booleans and small integers together.
 */
struct PurchaseConfiguration {
    bool purchaseActive;
    bool purchaseTaxRedemptionEnabled;
    /// @dev Minimum referrals required for purchase tax redemption eligibility.
    uint16 purchaseTaxRedemptionReferralThreshold;
    /// @dev Percentage of maxTokenPurchaseLimit where whale tax applies (basis points).
    uint16 whaleTaxThreshold;
    /// @dev Whale tax rate in basis points.
    uint16 whaleTaxBasisPoints;
    uint48 purchaseStartTime;
    uint256 purchaseRate;
    uint256 minPurchaseAmount;
    uint256 maxTokenPurchaseLimit;
}

/**
 * @dev Structure representing a preview of a token purchase, including calculated amounts and validity.
 */
struct PurchasePreview {
    /// @dev Gross token amount before any tax deduction.
    uint256 tokenAmount;
    /// @dev Token amount deducted as whale tax.
    uint256 whaleTax;
    /// @dev Whether the purchase can proceed.
    bool canPurchase;
    /// @dev Reason code if canPurchase is false (e.g., "not_active", "below_min").
    string reason;
}

/// @notice Configuration for referral rewards
struct RefRewardConfig {
    uint48[] thresholds; // Referral count thresholds
    uint256[] tokenRewards; // Token rewards for each threshold
    uint256 milestoneBonus; // Base milestone bonus
    uint256 milestoneInterval; // Referrals between milestones
    uint256 maxMilestones; // Maximum milestone count
    uint64 milestonePercentMultiplier; // Progressive % reward increase per milestone
}

/// @notice Multiplier configuration for different participant types
struct RefMultiplierConfig {
    uint8 sponsoredThreshold;
    uint8 unsponsoredThreshold;
    uint8 sponsoredMultiplier;
    uint8 unsponsoredMultiplier;
    uint8 sponsoredWindow; // Window for multiplier application
    uint8 unsponsoredWindow;
}

/**
 * @dev Configuration parameters for various claim types.
 */
struct ClaimConfiguration {
    bool freeTokenClaimEnabled;
    uint256 participantTokenClaimThreshold;
    uint256 sponsoredTokenClaimThreshold;
    uint256 participantNativeClaimThreshold;
    uint256 sponsoredNativeClaimThreshold;
}

/**
 * @notice Participant data structure.
 * @dev All participant-related state is stored within this struct in AppStorage.
 *      New fields must always be appended to the end to maintain storage compatibility.
 * @dev OPTIMIZED: Packed small fields together to save storage slots.
 */
struct Participant {
    address addr;
    address referrer;
    bytes8 uid;
    bool isActive;
    bool isSponsored;
    bool purchaseTaxRedeemed;
    bool countedAsActiveReferral;
    uint8 tier;
    uint48 id;
    uint48 referralCount;
    uint48 referralPos;
    uint48 registeredAt;
    uint48 firstActiveAt;
    uint64 lastActivityBlock;
    uint48 firstReferralAt;
    uint48 lastReferralAt;
    uint48 timesPurchased;
    uint48 firstPurchaseAt;
    uint48 lastPurchaseAt;
    uint48 purchaseTaxRedeemedAt;
    uint48 tierSyncedAt;
    uint48 firstTokenClaimAt;
    uint48 lastTokenClaimAt;
    uint48 firstNativeClaimAt;
    uint48 lastNativeClaimAt;
    uint48 firstTokenCreditAt;
    uint48 lastTokenCreditAt;
    uint256 purchasedTokens;
    uint256 tokenPurchaseTax;
    uint256 nativePurchaseAmount;
    uint256 tokenBonus;
    uint256 tokenBonusClaimed;
    uint256 nativeBonus;
    uint256 nativeBonusClaimed;
    uint256 creditedTokens;
    uint256 creditedTokensClaimed;
}

/**
 * @dev Structure for basic registration information of a participant.
 */
struct ParticipantRegistrationInfo {
    uint64 id;
    address referrer;
    uint48 registeredAt;
    bool isSponsored;
}

/**
 * @dev Structure for referral-related information of a participant.
 */
struct ParticipantReferralInfo {
    address referrer;
    uint64 referralPos;
    uint64 referralCount;
    uint48 firstReferralAt;
    uint48 lastReferralAt;
}

/**
 * @dev Structure for token purchase details of a participant.
 */
struct ParticipantPurchaseInfo {
    uint64 timesPurchased;
    bool purchaseTaxRedeemed;
    uint48 firstPurchaseAt;
    uint256 purchasedTokens;
    uint256 nativePurchaseAmount;
    uint256 tokenPurchaseTax;
}

/**
 * @dev Structure for activity status and timestamps of a participant.
 */
struct ParticipantActivityInfo {
    bool isActive;
    uint48 firstActiveAt;
    uint64 lastActivityBlock;
}

/**
 * @dev Structure for the current accumulated and unclaimed bonuses of a participant.
 */
struct ParticipantBonusInfo {
    uint256 tokenBonus;
    uint256 nativeBonus;
}

/**
 * @dev Structure for information regarding manually credited tokens for a participant.
 */
struct ParticipantCreditInfo {
    uint256 creditedTokens;
    uint48 lastTokenCreditAt;
}

/**
 * @dev Structure for total claimed amounts and timestamps for all bonuses of a participant.
 */
struct ParticipantClaimInfo {
    uint256 tokenBonusClaimed;
    uint256 nativeBonusClaimed;
    uint256 creditedTokensClaimed;
    uint48 firstTokenClaimAt;
    uint48 lastNativeClaimAt;
}

/**
 * @dev Structure for all currently available (unclaimed) bonus amounts for a participant.
 */
struct ParticipantClaimableAmounts {
    uint256 tokenBonus;
    uint256 nativeBonus;
    uint256 creditedTokens;
}

/**
 * @dev Overall status of various claim types within the system.
 * @dev OPTIMIZED: Packed booleans together.
 */
struct ClaimStatus {
    bool tokenBonusClaimActive;
    bool tokenCreditClaimActive;
    bool nativeBonusClaimActive;
    uint256 totalBonusClaimed;
    uint256 totalNativeClaimed;
    uint256 totalTokenCreditClaimed;
}

/**
 * @dev Stores eligibility status for different claim types for a given address.
 */
struct ClaimEligible {
    bool tokenBonus;
    bool tokenCredit;
    bool nativeBonus;
}

// --- Single Token Staking ---

/// @notice Staking tiers determined by referral counts.
enum StakeTier {
    None,
    Bronze,
    Silver,
    Gold,
    Platinum,
    Diamond,
    Mythril
}

/// @notice Configuration for a staking tier referral bonus.
struct SingleStakingTierConfig {
    /// @dev Minimum referrals required to qualify for the tier.
    uint48 minReferrals;
    /// @dev Additional APR in basis points applied when the tier is active.
    uint16 bonusAprBps;
    bool enabled;
}

/**
 * @dev Configuration for a specific lock period in the single-token staking module.
 */
struct SingleStakingLockConfig {
    /// @dev Lock duration in seconds; must match one of the allowed presets.
    uint40 duration;
    /// @dev APR expressed in basis points (10000 = 100%).
    uint32 aprBps;
    bool enabled;
}

/**
 * @dev Global configuration for the single-token staking module.
 * @dev OPTIMIZED: Packed small fields and addresses together.
 */
struct SingleStakingConfig {
    bool enabled;
    // === Basis points ===
    uint16 autoCompoundBonusBps;
    uint16 earlyUnstakePrincipalPenaltyBps;
    uint16 earlyUnstakeRewardPenaltyBps;

    uint256 minStakeAmount;
    uint256 stakeCreationFee;
    uint256 unstakeFee;

    // === Addresses ===
    /// @dev Zero address retains penalties within the diamond.
    address penaltyRecipient;
    address feeRecipient;
}

/**
 * @dev Internal representation of an individual staking position.
 * @dev OPTIMIZED: Packed small fields together for gas efficiency.
 */
struct SingleStakePosition {
    address owner;
    uint8 lockId;
    uint8 referralTier;
    bool autoCompound;
    bool active;

    // === Principal and base reward ===
    uint256 stakedAmount;
    uint256 rewardBase;

    // === Reward tracking ===
    uint256 unclaimedRewards;
    uint256 compoundedRewards;
    uint256 totalClaimedRewards;

    // === Timestamps and durations ===
    uint40 startTime;
    uint40 lastUpdate;
    uint40 lockDuration;
    uint40 unlockTime;
    uint32 baseAprBps;
    uint32 aprBps;
    uint16 autoCompoundBonusBps;
    uint16 referralBonusBps;
    uint16 earlyPrincipalPenaltyBps;
    uint16 earlyRewardPenaltyBps;
}

/**
 * @dev Aggregate storage for the single-token staking module.
 */
struct SingleStakingState {
    /// @dev Global staking configuration.
    SingleStakingConfig config;
    /// @dev Total amount of principal currently staked.
    uint256 totalStaked;
    /// @dev Total rewards minted to stakers across all time.
    uint256 totalRewardsMinted;
    /// @dev Cumulative rewards forfeited due to early exits.
    uint256 totalRewardPenalties;
    /// @dev Cumulative principal penalties collected from early exits.
    uint256 totalPrincipalPenalties;
    /// @dev Principal penalties retained within the diamond and available for withdrawal.
    uint256 penaltyTokenBalance;
    /// @dev Next staking position identifier.
    uint256 nextPositionId;
    /// @dev Number of lock configurations currently defined.
    uint8 lockConfigCount;
    /// @dev Mapping of lock identifier to lock configuration.
    mapping(uint8 => SingleStakingLockConfig) lockConfigs;
    /// @dev Mapping of stake identifier to position data.
    mapping(uint256 => SingleStakePosition) positions;
    /// @dev Mapping of owner address to owned stake identifiers.
    mapping(address => uint256[]) ownerPositions;
    /// @dev Mapping of stake identifier to its index in the owner's stake array (for O(1) removals).
    mapping(uint256 => uint256) positionIndexInOwner;
    /// @dev Mapping of tier identifier to tier configuration.
    mapping(uint8 => SingleStakingTierConfig) tierConfigs;
}

/**
 * @dev Struct containing key Single staking metrics.
 */
struct SingleStakingMetrics {
    uint256 totalStaked;
    uint256 totalRewardsMinted;
    uint256 totalRewardPenalties;
    uint256 totalPrincipalPenalties;
    uint256 penaltyTokenBalance;
    uint256 nextPositionId;
    uint8 lockConfigCount;
}

/**
 * @dev Payload for updating the global staking configuration.
 */
struct SingleStakingConfigUpdate {
    /// @dev New minimum stake amount or `LibConstants.UNCHANGED_UINT256` to skip.
    uint256 minStakeAmount;
    /// @dev New stake creation fee in wei or `LibConstants.UNCHANGED_UINT256` to skip.
    uint256 stakeCreationFee;
    /// @dev New unstake fee in wei or `LibConstants.UNCHANGED_UINT256` to skip.
    uint256 unstakeFee;
    /// @dev New auto-compounding bonus in basis points or `LibConstants.UNCHANGED_UINT16` to skip.
    uint16 autoCompoundBonusBps;
    /// @dev New principal penalty in basis points or `LibConstants.UNCHANGED_UINT16` to skip.
    uint16 earlyUnstakePrincipalPenaltyBps;
    /// @dev New reward penalty in basis points or `LibConstants.UNCHANGED_UINT16` to skip.
    uint16 earlyUnstakeRewardPenaltyBps;
    /// @dev Recipient of future principal penalties (set `setPenaltyRecipient` to true to update).
    address penaltyRecipient;
    /// @dev Recipient of staking fees (set `setFeeRecipient` to true to update).
    address feeRecipient;
    /// @dev Toggle for penalty recipient update.
    bool setPenaltyRecipient;
    /// @dev Toggle for fee recipient update.
    bool setFeeRecipient;
    /// @dev Desired enabled flag (set `setEnabled` to true to update).
    bool enabled;
    /// @dev Toggle for enabled flag update.
    bool setEnabled;
}

/**
 * @dev Payload for updating or creating a lock configuration.
 */
struct SingleStakingLockUpdate {
    /// @dev Identifier of the lock configuration to update. Equal to `lockConfigCount` to append a new one.
    uint8 lockId;
    /// @dev New lock duration in seconds or `LibConstants.UNCHANGED_UINT64` to skip.
    uint64 duration;
    /// @dev New APR in basis points or `LibConstants.UNCHANGED_UINT32` to skip.
    uint32 aprBps;
    /// @dev Whether to enable (2) or disable (1) the lock option. Use 0 to leave unchanged.
    uint8 enabledFlag;
}

/// @dev Payload for updating a tier configuration.
struct SingleStakingTierConfigUpdate {
    /// @dev Tier identifier to update.
    StakeTier tier;
    /// @dev New minimum referrals or `LibConstants.UNCHANGED_UINT48` to skip.
    uint48 minReferrals;
    /// @dev New bonus APR in basis points or `LibConstants.UNCHANGED_UINT16` to skip.
    uint16 bonusAprBps;
    /// @dev Whether to enable (2) or disable (1) the tier. Use 0 to leave unchanged.
    uint8 enabledFlag;
}
