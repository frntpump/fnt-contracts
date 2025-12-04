// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "../../libs/LibAppStorage.sol";
import {LibParticipant} from "../../libs/LibParticipant.sol";
import {LibErrors} from "../../libs/LibErrors.sol";
import {LibConstants as LC} from "../../libs/LibConstants.sol";
import {
    GlobalState,
    Participant,
    ParticipantRegistrationInfo,
    ParticipantPurchaseInfo,
    ParticipantReferralInfo,
    ParticipantClaimableAmounts,
    ParticipantActivityInfo,
    ParticipantBonusInfo,
    ParticipantClaimInfo,
    ParticipantCreditInfo,
    ClaimEligible
} from "../../shared/Structs.sol";

/**
 * @title ParticipantDataFacet
 * @author Forever Network
 * @notice Handles all read-only functions for retrieving comprehensive participant data.
 * @dev This facet is stateless and reads all information directly from the AppStorage struct.
 * All getters are categorized by the information type (Registration, Referral, Purchase, etc.).
 */
contract ParticipantDataFacet {
    // ============ View Functions ============

    /**
     * @notice Retrieves the unique identifier (UID) for a participant.
     * @param participantAddress The address of the participant.
     * @return bytes8 The UID of the participant, or zero if not registered.
     */
    function getParticipantUid(address participantAddress) external view returns (bytes8) {
        return LibAppStorage.diamondStorage().addressToUid[participantAddress];
    }

    /**
     * @notice Retrieves all information about a participant.
     * @param participantAddress The address of the participant.
     * @return Participant the participant details.
     */
    function getParticipant(address participantAddress) external view returns (Participant memory) {
        return LibParticipant.getParticipant(participantAddress);
    }

    /**
     * @notice Retrieves the UIDs of all sponsored participants.
     * @return bytes8[] An array of bytes8 representing the UIDs of sponsored participants.
     */
    function getSponsoredParticipants() external view returns (bytes8[] memory) {
        return LibAppStorage.diamondStorage().sponsoredParticipants;
    }

    /**
     * @notice Checks if an address is a registered participant.
     * @param participantAddress The address to check.
     * @return bool True if the participant is registered (has a non-zero ID), false otherwise.
     */
    function isRegistered(address participantAddress) external view returns (bool) {
        return LibAppStorage.diamondStorage().addressToUid[participantAddress] != bytes8(0);
    }

    /**
     * @notice Checks if an address is an active participant.
     * @param participantAddress The address to check.
     * @return bool True if the participant is registered and has FNT > existential deposit, false otherwise.
     */
    function isActive(address participantAddress) external view returns (bool) {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return LibParticipant._participantActive(participant.uid);
    }

    /**
     * @notice Checks if a participant exists, is sponsored or active.
     * @param participantUid UID to check.
     * @return bool True if the participant is active or sponsored, false otherwise.
     */
    function isValidReferrer(bytes8 participantUid) external view returns (bool) {
        return LibParticipant._participantActive(participantUid)
            || LibAppStorage.diamondStorage().participantsByUid[participantUid].isSponsored;
    }

    /**
     * @notice Retrieves basic registration details for a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantRegistrationInfo A struct containing the unique ID, referrer address, registration time, and sponsorship status.
     */
    function getParticipantRegistrationInfo(address participantAddress)
        external
        view
        returns (ParticipantRegistrationInfo memory)
    {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantRegistrationInfo({
            id: participant.id,
            referrer: participant.referrer,
            registeredAt: participant.registeredAt,
            isSponsored: participant.isSponsored
        });
    }

    /**
     * @notice Retrieves referral-related statistics and timestamps for a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantReferralInfo A struct containing the referrer, their position in the referrer's tree, total referral count, and key referral timestamps.
     */
    function getParticipantReferralInfo(address participantAddress)
        external
        view
        returns (ParticipantReferralInfo memory)
    {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantReferralInfo({
            referrer: participant.referrer,
            referralPos: participant.referralPos,
            referralCount: participant.referralCount,
            firstReferralAt: participant.firstReferralAt,
            lastReferralAt: participant.lastReferralAt
        });
    }

    /**
     * @notice Retrieves the total number of a participant's referees who have become active.
     * @param participantAddress The address of the participant.
     * @return uint64 The number of active referees.
     */
    function getActiveRefereeCount(address participantAddress) external view returns (uint64) {
        return LibAppStorage.diamondStorage().activeRefereeCount[participantAddress];
    }

    /**
     * @notice Retrieves token purchase details for a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantPurchaseInfo A struct detailing tokens purchased, native currency spent, number of purchases, tax information, and first purchase time.
     */
    function getParticipantPurchaseInfo(address participantAddress)
        external
        view
        returns (ParticipantPurchaseInfo memory)
    {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantPurchaseInfo({
            purchasedTokens: participant.purchasedTokens,
            nativePurchaseAmount: participant.nativePurchaseAmount,
            timesPurchased: participant.timesPurchased,
            tokenPurchaseTax: participant.tokenPurchaseTax,
            purchaseTaxRedeemed: participant.purchaseTaxRedeemed,
            firstPurchaseAt: participant.firstPurchaseAt
        });
    }

    /**
     * @notice Retrieves the active status and activity timestamps for a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantActivityInfo A struct indicating if the participant is currently active, their first active timestamp, and the last block they were active.
     */
    function getParticipantActivityInfo(address participantAddress)
        external
        view
        returns (ParticipantActivityInfo memory)
    {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantActivityInfo({
            isActive: participant.isActive,
            firstActiveAt: participant.firstActiveAt,
            lastActivityBlock: participant.lastActivityBlock
        });
    }

    /**
     * @notice Retrieves the current accumulated token and native currency bonuses of a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantBonusInfo A struct containing the unclaimed token and native bonuses.
     */
    function getParticipantBonusInfo(address participantAddress) external view returns (ParticipantBonusInfo memory) {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantBonusInfo({tokenBonus: participant.tokenBonus, nativeBonus: participant.nativeBonus});
    }

    /**
     * @notice Retrieves information about tokens credited tokens to a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantCreditInfo A struct containing the total credited tokens (unclaimed portion) and the timestamp of the last credit.
     */
    function getParticipantCreditInfo(address participantAddress) external view returns (ParticipantCreditInfo memory) {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantCreditInfo({
            creditedTokens: participant.creditedTokens, lastTokenCreditAt: participant.lastTokenCreditAt
        });
    }

    /**
     * @notice Retrieves the total claimed amounts and timestamps for all bonuses.
     * @param participantAddress The address of the participant.
     * @return ParticipantClaimInfo A struct containing the total amounts claimed for token bonus, native bonus, and credited tokens, along with key claim timestamps.
     */
    function getParticipantClaimInfo(address participantAddress) external view returns (ParticipantClaimInfo memory) {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantClaimInfo({
            tokenBonusClaimed: participant.tokenBonusClaimed,
            nativeBonusClaimed: participant.nativeBonusClaimed,
            creditedTokensClaimed: participant.creditedTokensClaimed,
            firstTokenClaimAt: participant.firstTokenClaimAt,
            lastNativeClaimAt: participant.lastNativeClaimAt
        });
    }

    /**
     * @notice Retrieves all currently available claimable amounts for a participant.
     * @param participantAddress The address of the participant.
     * @return ParticipantClaimableAmounts A struct containing the unclaimed amounts of token bonus, native bonus, and credited tokens.
     */
    function getParticipantClaimableAmounts(address participantAddress)
        external
        view
        returns (ParticipantClaimableAmounts memory)
    {
        Participant storage participant = LibParticipant.getParticipant(participantAddress);

        return ParticipantClaimableAmounts({
            tokenBonus: participant.tokenBonus,
            nativeBonus: participant.nativeBonus,
            creditedTokens: participant.creditedTokens
        });
    }

    /**
     * @notice Gets the address of a specific referee by index in a referrer's referral tree.
     * @dev Reverts if the index is out of bounds (i.e., greater than or equal to the referrer's count).
     * @param referrer The address of the referrer.
     * @param index The 0-based index of the referee in the referral tree.
     * @return address The address of the referee at the specified index.
     */
    function getReferralAt(address referrer, uint256 index) external view returns (address) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[referrer];
        if (index >= ds.participantsByUid[uid].referralCount) revert LibErrors.IndexOutOfBounds();
        return ds.referralTree[referrer][index];
    }

    /**
     * @notice Retrieves a paginated list of all direct referrals (referees) for a given referrer.
     * @dev Returns an empty array if the referrer is not registered or if the offset exceeds the referral count. Limits the page size to `LC.MAX_PAGE`.
     * @param referrer The address of the referrer.
     * @param offset The starting index for the slice.
     * @param limit The maximum number of referrals to return.
     * @return result A dynamically sized array of referee addresses.
     */
    function getReferrals(address referrer, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory result)
    {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[referrer];
        if (uid == 0) revert LibErrors.NotRegistered(referrer);

        uint256 count = ds.participantsByUid[uid].referralCount;
        if (offset >= count) return new address[](0);

        uint256 adjustedLimit = limit > LC.MAX_PAGE ? LC.MAX_PAGE : limit;
        uint256 end = offset + adjustedLimit > count ? count : offset + adjustedLimit;
        uint256 length = end - offset;

        result = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = ds.referralTree[referrer][offset + i];
        }
        return result;
    }

    /**
     * @notice Retrieves the claim eligibility status for a participant.
     * @param participantAddress The address of the participant.
     * @return ClaimEligible A struct indicating if the participant has met claim thresholds for token bonuses, token credits, and native bonuses.
     */
    function getParticipantClaimEligibility(address participantAddress) external view returns (ClaimEligible memory) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        Participant storage p = LibParticipant.getParticipant(participantAddress);

        bool tokenBonusEligible =
            ds.claimStatus.tokenBonusClaimActive && p.tokenBonus >= ds.claimConfig.participantTokenClaimThreshold;
        bool nativeBonusEligible =
            ds.claimStatus.nativeBonusClaimActive && p.nativeBonus >= ds.claimConfig.participantNativeClaimThreshold;
        bool tokenCreditEligible = ds.claimStatus.tokenCreditClaimActive && p.creditedTokens > 0;

        return ClaimEligible({
            tokenBonus: tokenBonusEligible, nativeBonus: nativeBonusEligible, tokenCredit: tokenCreditEligible
        });
    }

    /**
     * @notice Retrieves a paginated list of participants in the order of their first purchase.
     * @dev Used to track the purchasing history of the protocol. Limits the page size to `LC.MAX_PAGE`.
     * @param offset The starting index for the slice.
     * @param limit The maximum number of purchaser addresses to return.
     * @return address[] A dynamically sized array of participant addresses who have made purchases.
     */
    function getOrderedPurchasers(uint256 offset, uint256 limit) external view returns (address[] memory) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        GlobalState storage globalState = ds.globalState;
        uint256 count = globalState.purchaserCount;

        if (offset > count) return new address[](0);

        uint256 adjustedLimit = limit > LC.MAX_PAGE ? LC.MAX_PAGE : limit;
        uint256 end = offset + adjustedLimit > count ? count : offset + adjustedLimit;
        uint256 length = end - offset;

        address[] memory purchasers = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            purchasers[i] = ds.orderedPurchasers[offset + i];
        }
        return purchasers;
    }
}
