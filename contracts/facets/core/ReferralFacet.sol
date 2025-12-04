// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "../../libs/LibAppStorage.sol";
import {LibReferral} from "../../libs/LibReferral.sol";
import {LibConstants as LC} from "../../libs/LibConstants.sol";
import {LibParticipant} from "../../libs/LibParticipant.sol";
import {LibErrors} from "../../libs/LibErrors.sol";
import {LibEvents} from "../../libs/LibEvents.sol";
import {AccessControl} from "../../shared/AccessControl.sol";
import {ReentrancyGuardTransient} from "../../shared/ReentrancyGuard.sol";
import {Participant} from "../../shared/Structs.sol";

/**
 * @title ReferralFacet
 * @author Forever Network
 * @notice Handles the logic for participant registration via referral and calculating associated rewards.
 * @dev This facet is stateless and interacts with AppStorage, relying on `LibReferral` and `LibParticipant` for core logic.
 */
contract ReferralFacet is ReentrancyGuardTransient, AccessControl {
    // =============================================================
    //                       EXTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Allows a participant to manually resync their tier against current `RefRewardConfig` thresholds.
     * @dev This will update the stored `tier` and `tierSyncedAt` and emit a {ParticipantTierUpdated} event if changed.
     * @return uint8 The newly computed tier.
     */
    function resyncTier() external whenGlobalNotPaused unlockedFunction returns (uint8) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        address participantAddr = _msgSender();
        bytes8 uid = ds.addressToUid[participantAddr];
        if (uid == bytes8(0)) revert LibErrors.NotRegistered(participantAddr);

        Participant storage p = ds.participantsByUid[uid];
        uint8 newTier = LibReferral.determineTier(p.referralCount, ds.refRewardConfig);
        if (newTier != p.tier) {
            p.tier = newTier;
            p.tierSyncedAt = uint48(block.timestamp);
            emit LibEvents.ParticipantTierUpdated(participantAddr, newTier, p.tierSyncedAt);
        }

        return newTier;
    }

    /**
     * @notice Allows a new user (`msg.sender`) to register and link to a referrer.
     * @dev This is the public entry point for referral-based registration. It validates both the referrer and referee,
     * registers the new participant, processes referrer updates (e.g., referral count), applies the referee's bonus,
     * and calculates/credits the referrer's token and native rewards.
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier nonReentrant
     * @param referrerId The uid of the existing participant who is referring the new user.
     */
    function registerWithReferral(bytes8 referrerId) external whenGlobalNotPaused unlockedFunction nonReentrant {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        address referee = _msgSender();
        if (referrerId == bytes8(0)) revert LibErrors.ReferrerNotRegistered();
        if (ds.addressToUid[referee] != bytes8(0)) revert LibErrors.AlreadyRegistered(referee);

        Participant storage referrerData = ds.participantsByUid[referrerId];
        address referrerAddress = referrerData.addr;

        if (referrerAddress == address(0)) revert LibErrors.ReferrerNotRegistered();
        if (referee == referrerAddress) revert LibErrors.SelfReferral();

        bool referrerActive = LibParticipant._updateParticipantStatus(referrerAddress);

        if (!referrerActive && !referrerData.isSponsored) revert LibErrors.ReferrerInactive();

        // Register the new user via the library
        uint48 referralIndex = referrerData.referralCount;
        uint48 currentReferralCount = referralIndex + 1;

        LibParticipant._register(referee, referrerAddress, referralIndex, false);
        LibParticipant._processReferrerUpdates(referrerAddress, referee, referralIndex);
        LibParticipant._applyRefereeBonus(referee);

        // Calculate rewards for the referrer
        bool isSponsored = referrerData.isSponsored;

        uint256 tokenReward = _calculateTokenReward(currentReferralCount, isSponsored);

        if (tokenReward > 0) {
            referrerData.tokenBonus += tokenReward;
            emit LibEvents.ReferralBonus(referrerAddress, tokenReward, 0);
        }

        // Update the new participant's status
        LibParticipant._updateParticipantStatus(_msgSender());
    }

    /**
     * @notice Allows an authorized sponsor to register a new participant as sponsored.
     * @dev This function registers the participant, links them to the sponsor (who is also registered if not already),
     * and updates the sponsor's referral count. Only callable by accounts with the `PRIME_SPONSOR_ROLE`.
     * @custom:modifier onlyRoleOrAdmin(PRIME_SPONSOR_ROLE)
     * @custom:modifier whenGlobalNotPaused
     * @param participantAddress The address of the new participant to be sponsored.
     */
    function registerSponsored(address participantAddress)
        external
        onlyRoleOrAdmin(LC.PRIME_SPONSOR_ROLE)
        whenGlobalNotPaused
    {
        if (participantAddress == address(0)) revert LibErrors.ZeroAddress();
        AppStorage storage ds = LibAppStorage.diamondStorage();
        if (ds.addressToUid[participantAddress] != bytes8(0)) {
            revert LibErrors.AlreadyRegistered(participantAddress);
        }

        address sponsor = _msgSender();
        if (ds.addressToUid[sponsor] == bytes8(0)) {
            LibParticipant._register(sponsor, address(0), 0, false);
        }

        bytes8 sponsorUid = ds.addressToUid[sponsor];
        uint48 referralIndex = ds.participantsByUid[sponsorUid].referralCount;

        LibParticipant._register(participantAddress, sponsor, referralIndex, true);
        LibParticipant._processReferrerUpdates(sponsor, participantAddress, referralIndex);
        LibParticipant._updateParticipantStatus(participantAddress);
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Previews the potential token and native rewards for a given referrer's next referral.
     * @dev This function simulates the rewards that would be earned if the referrer gets one more referral.
     * @param participantAddress The address of the referrer to preview rewards for.
     * @return tokenReward The estimated token reward for the next referral.
     * @return nativeReward The estimated native reward for the next referral, considering milestones.
     */
    function previewRewards(address participantAddress)
        external
        view
        returns (uint256 tokenReward, uint256 nativeReward)
    {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 referrerUid = ds.addressToUid[participantAddress];
        if (referrerUid != bytes8(0)) {
            Participant storage p = ds.participantsByUid[referrerUid];

            uint64 nextReferralCount = p.referralCount + 1;
            tokenReward = _calculateTokenReward(nextReferralCount, p.isSponsored);

            uint64 nextActiveCount = ds.activeRefereeCount[participantAddress] + 1;
            (nativeReward,) = LibReferral.calculateMilestoneReward(
                nextActiveCount, ds.lastMilestone[participantAddress], ds.refRewardConfig
            );
        }
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Internal function to calculate the token reward based on referral count and sponsorship status.
     * @param referralCount The current referral count.
     * @param isSponsored A boolean indicating if the participant is sponsored.
     * @return uint256 The calculated token reward.
     * @dev This function utilizes `LibReferral.calculateRewardWithMultiplier` to determine the reward.
     */
    function _calculateTokenReward(uint64 referralCount, bool isSponsored) internal view returns (uint256) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        return LibReferral.calculateRewardWithMultiplier(
            referralCount, isSponsored, ds.refRewardConfig, ds.refMultiplierConfig
        );
    }

    /**
     * @notice Internal function to calculate and update native rewards based on referral milestones.
     * @dev This function calculates milestone-based native rewards and updates the `lastMilestone` record for the referrer.
     * @param referrer The address of the referrer.
     * @param referralCount The current referral count.
     * @return uint256 The calculated native reward.
     */
}
