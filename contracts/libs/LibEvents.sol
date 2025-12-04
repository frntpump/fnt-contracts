// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Participant, SingleStakingConfig} from "../shared/Structs.sol";

/**
 * @title LibEvents
 * @author Forever Network
 * @notice Unified event library for the Forever Network Diamond
 * @dev This file consolidates all custom events for the FNT Diamond,
 *      ensuring consistency and preventing duplication across facets.
 */
library LibEvents {
    // =============================================================
    //                    DIAMOND STANDARD EVENTS
    // =============================================================

    /// @notice Emitted when the ownership of the contract is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // =============================================================
    //                   ACCESS CONTROL EVENTS
    // =============================================================

    /// @notice Emitted when the admin role for a specific role is changed
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /// @notice Emitted when a role is granted to an account
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /// @notice Emitted when a role is revoked from an account
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    // =============================================================
    //                   PARTICIPANT & WALLET EVENTS
    // =============================================================

    /// @notice Emitted when a new participant is successfully registered
    event ParticipantRegistered(Participant participant);

    /// @notice Emitted when a participant's tier is updated/resynced
    event ParticipantTierUpdated(address indexed participant, uint8 newTier, uint48 syncedAt);

    /// @notice Emitted when a new wallet address is linked to an existing participant's UID
    event WalletLinked(bytes8 uid, address newWallet);

    /// @notice Emitted when a wallet address is unlinked from an existing participant's UID
    event WalletUnlinked(bytes8 uid, address walletToRemove);

    /// @notice Emitted when a participant's active status changes
    event ParticipantStatusUpdated(
        address indexed participant, bool isActive, uint64 lastActivityBlock, bool significantUpdate
    );

    // =============================================================
    //                     REFERRAL EVENTS
    // =============================================================

    /// @notice Emitted when a new referral is successfully recorded
    event ReferralRecorded(address indexed referrer, address indexed referee);

    /// @notice Emitted when a referrer earns a referral bonus (token or native)
    event ReferralBonus(address indexed referrer, uint256 tokenAmount, uint256 nativeAmount);

    // =============================================================
    //                     PURCHASE EVENTS
    // =============================================================

    /// @notice Emitted when a participant successfully purchases FNT tokens
    event TokensPurchased(
        address indexed buyer, bytes8 indexed buyerId, uint256 nativeValue, uint256 tokenAmount, uint256 whaleTax
    );

    /// @notice Emitted when a participant successfully redeems their accumulated purchase tax for tokens
    event PurchaseTaxRedeemed(address indexed redeemer, uint256 tokenAmount);

    // =============================================================
    //                      CLAIM EVENTS
    // =============================================================

    /// @notice Emitted when a participant claims their accumulated token bonus
    event TokenBonusClaimed(address indexed participant, uint256 tokenAmount);

    /// @notice Emitted when a participant claims their accumulated native currency bonus
    event NativeBonusClaimed(address indexed participant, uint256 nativeAmount);

    /// @notice Emitted when a participant claims manually credited tokens
    event CreditedTokensClaimed(address indexed participant, uint256 amount);

    /// @notice Emitted when tokens are manually credited to a participant
    event TokensCredited(address indexed participant, uint256 amount, string indexed description);

    // =============================================================
    //                  SINGLE TOKEN STAKING EVENTS
    // =============================================================

    /// @notice Emitted when a new single-token staking position is created
    event SingleStakeCreated(
        address indexed staker, uint256 indexed stakeId, uint256 amount, uint8 lockId, bool autoCompound, uint32 aprBps
    );

    /// @notice Emitted when rewards are claimed from a single-token staking position
    event SingleStakeRewardsClaimed(address indexed staker, uint256 indexed stakeId, uint256 rewardsMinted);

    /// @notice Emitted when a staking position is exited
    event SingleStakeWithdrawn(
        address indexed staker,
        uint256 indexed stakeId,
        uint256 principalReturned,
        uint256 rewardsMinted,
        uint256 principalPenalty,
        uint256 rewardPenalty,
        bool forcedExit
    );

    /// @notice Emitted when the auto-compound preference of a staking position changes
    event SingleStakeAutoCompoundSet(
        address indexed staker, uint256 indexed stakeId, bool autoCompound, uint32 newAprBps
    );

    /// @notice Emitted when rewards accrue to a staking position during settlement
    event SingleStakeRewardsAccrued(
        address indexed staker,
        uint256 indexed stakeId,
        uint256 rewardsAccrued,
        uint256 newRewardBase,
        bool autoCompounded
    );

    /// @notice Emitted when a staking position is settled (rewards calculated and applied)
    event SingleStakeSettled(
        address indexed staker, uint256 indexed stakeId, uint256 accruedSinceLastUpdate, uint256 totalPendingRewards
    );

    /// @notice Emitted when a staking position's APR components are updated
    event SingleStakeAprUpdated(
        address indexed staker,
        uint256 indexed stakeId,
        uint32 baseAprBps,
        uint16 referralBonusBps,
        uint16 autoCompoundBonusBps,
        uint32 finalAprBps
    );

    /// @notice Emitted when additional funds are added to an existing staking position
    event SingleStakeAmountAdded(
        address indexed staker, uint256 indexed stakeId, uint256 amountAdded, uint256 newTotalAmount
    );

    /// @notice Emitted whenever the global staking configuration is updated
    event SingleStakingConfigUpdated(SingleStakingConfig config);

    /// @notice Emitted when a lock configuration is created or updated
    event SingleStakingLockConfigured(uint8 indexed lockId, uint40 duration, uint32 aprBps, bool enabled);

    /// @notice Emitted when a staking tier configuration is updated
    event SingleStakingTierConfigured(uint8 indexed tierId, uint48 minReferrals, uint32 bonusAprBps, bool enabled);

    /// @notice Emitted when accumulated principal penalties are withdrawn from the diamond
    event SingleStakingPenaltiesWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when a staking fee is collected
    event SingleStakingFeeCollected(address indexed payer, string feeType, uint256 amount);

    // =============================================================
    //                     ADMIN & GOVERNANCE EVENTS
    // =============================================================

    /// @notice Emitted when the network is paused
    event GlobalPaused(address indexed pauser);

    /// @notice Emitted when the network is unpaused
    event GlobalUnpaused(address indexed unpauser);

    /// @notice Emitted when a function is locked
    event LockedFunction(bytes4 indexed functionSelector);

    /// @notice Emitted when a function is unlocked
    event UnlockedFunction(bytes4 indexed functionSelector);

    /// @notice Emitted when a token address is updated
    event TokenAddressUpdated(string indexed tokenType, address indexed newAddress);

    /// @notice Emitted when the purchase start time is updated
    event PurchaseStartTimeUpdated(uint48 oldTime, uint48 newTime);

    /// @notice Emitted when the purchase active status is updated
    event PurchaseActiveUpdated(bool oldActive, bool newActive);

    /// @notice Emitted when the global configuration is updated
    event GlobalConfigurationUpdated(
        uint256 existentialDeposit, uint256 refereeDeferredTokenBonus, uint256 refereeInstantTokenBonus
    );

    /// @notice Emitted when the purchase configuration is updated
    event PurchaseConfigurationUpdated(
        bool purchaseActive,
        bool purchaseTaxRedemptionEnabled,
        uint16 purchaseTaxRedemptionReferralThreshold,
        uint16 whaleTaxThreshold,
        uint16 whaleTaxBasisPoints,
        uint48 purchaseStartTime,
        uint256 purchaseRate,
        uint256 minPurchaseAmount,
        uint256 maxTokenPurchaseLimit
    );

    /// @notice Emitted when the claim configuration is updated
    event ClaimConfigurationUpdated(
        bool freeTokenClaimEnabled,
        uint256 participantTokenClaimThreshold,
        uint256 sponsoredTokenClaimThreshold,
        uint256 participantNativeClaimThreshold,
        uint256 sponsoredNativeClaimThreshold
    );

    /// @notice Emitted when the claim status is updated
    event ClaimStatusUpdated(bool tokenBonusClaimActive, bool tokenCreditClaimActive, bool nativeBonusClaimActive);

    /// @notice Emitted when the referral reward configuration is updated
    event RefRewardConfigUpdated(
        uint48[] thresholds,
        uint256[] tokenRewards,
        uint256 milestoneBonus,
        uint256 milestoneInterval,
        uint256 maxMilestones,
        uint64 milestonePercentMultiplier
    );

    /// @notice Emitted when the referral multiplier configuration is updated
    event RefMultiplierConfigUpdated(
        uint8 sponsoredThreshold,
        uint8 unsponsoredThreshold,
        uint8 sponsoredMultiplier,
        uint8 unsponsoredMultiplier,
        uint8 sponsoredWindow,
        uint8 unsponsoredWindow
    );

    /// @notice Emitted when the trusted forwarder is set
    event TrustedForwarderSet(address indexed oldForwarder, address indexed newForwarder);

    /// @notice Emitted when a TOKEN_CREDIT_ROLE allowance is updated by the admin
    event TokenCreditAllowanceSet(address indexed creditor, uint256 newAllowance);

    /// @notice Emitted when the treasury address is updated
    event TreasuryAddressUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when the DAO timelock address stored on the diamond is updated
    event DaoTimelockAddressUpdated(address indexed oldDaoTimelock, address indexed newDaoTimelock);

    /// @notice Emitted when native currency is transferred
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when tokens are transferred
    event TokenTransfer(address indexed token, address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when governance of the FNT token is transitioned to a new admin (DAO)
    event GovernanceTransitioned(address indexed newAdmin);

    /// @notice Emitted when functions are locked
    event FunctionsLocked(bytes4[] functionSelectors);

    /// @notice Emitted when functions are unlocked
    event FunctionsUnlocked(bytes4[] functionSelectors);

    /// @notice Emitted when tokens are minted
    event Mint(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when the diamond is initialized
    event InitializeDiamond(address sender);
}
