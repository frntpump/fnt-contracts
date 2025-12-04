// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
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
} from "../shared/Structs.sol";

/**
 * @title IParticipantData
 * @author Forever Network
 * @notice Interface for querying participant data and status.
 */
interface IParticipantData {
    /**
     * @notice Checks if an address is registered as a participant.
     * @param participantAddress The address to check.
     * @return registered True if the address is registered.
     */
    function isRegistered(address participantAddress) external view returns (bool registered);

    /**
     * @notice Checks if a participant is currently active (meets existential deposit requirement).
     * @param participantAddress The address to check.
     * @return active True if the participant is active.
     */
    function isActive(address participantAddress) external view returns (bool active);

    /**
     * @notice Gets registration information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The registration information including UID, timestamps, and sponsor status.
     */
    function getParticipantRegistrationInfo(address participantAddress)
        external
        view
        returns (ParticipantRegistrationInfo memory info);

    /**
     * @notice Gets referral information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The referral information including referrer, referral count, and rewards.
     */
    function getParticipantReferralInfo(address participantAddress)
        external
        view
        returns (ParticipantReferralInfo memory info);

    /**
     * @notice Gets purchase information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The purchase information including total purchased and whale tax.
     */
    function getParticipantPurchaseInfo(address participantAddress)
        external
        view
        returns (ParticipantPurchaseInfo memory info);

    /**
     * @notice Gets activity information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The activity information including linked wallets and active status.
     */
    function getParticipantActivityInfo(address participantAddress)
        external
        view
        returns (ParticipantActivityInfo memory info);

    /**
     * @notice Gets bonus information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The bonus information including deferred and instant token bonuses, and native bonus.
     */
    function getParticipantBonusInfo(address participantAddress)
        external
        view
        returns (ParticipantBonusInfo memory info);

    /**
     * @notice Gets credited token information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The credit information including total credited and claimed amounts.
     */
    function getParticipantCreditInfo(address participantAddress)
        external
        view
        returns (ParticipantCreditInfo memory info);

    /**
     * @notice Gets claim history information for a participant.
     * @param participantAddress The address of the participant.
     * @return info The claim information including last claim timestamps and redeemed status.
     */
    function getParticipantClaimInfo(address participantAddress)
        external
        view
        returns (ParticipantClaimInfo memory info);

    /**
     * @notice Gets all claimable amounts for a participant.
     * @param participantAddress The address of the participant.
     * @return amounts The claimable amounts for token bonus, native bonus, and credited tokens.
     */
    function getParticipantClaimableAmounts(address participantAddress)
        external
        view
        returns (ParticipantClaimableAmounts memory amounts);

    /**
     * @notice Gets claim eligibility status for a participant.
     * @param participantAddress The address of the participant.
     * @return eligible The eligibility status for each type of claim.
     */
    function getParticipantClaimEligibility(address participantAddress)
        external
        view
        returns (ClaimEligible memory eligible);

    /**
     * @notice Gets a specific referral by index.
     * @param referrer The address of the referrer.
     * @param index The index of the referral to retrieve.
     * @return referral The address of the referral at the specified index.
     */
    function getReferralAt(address referrer, uint256 index) external view returns (address referral);

    /**
     * @notice Gets a paginated list of referrals for a referrer.
     * @param referrer The address of the referrer.
     * @param offset The starting index for pagination.
     * @param limit The maximum number of referrals to return.
     * @return referrals Array of referral addresses.
     */
    function getReferrals(address referrer, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory referrals);

    /**
     * @notice Gets a paginated list of purchasers ordered by purchase time.
     * @param offset The starting index for pagination.
     * @param limit The maximum number of addresses to return.
     * @return purchasers Array of purchaser addresses.
     */
    function getOrderedPurchasers(uint256 offset, uint256 limit) external view returns (address[] memory purchasers);

    /**
     * @notice Gets the unique identifier (UID) for a participant.
     * @param participant The address of the participant.
     * @return uid The participant's unique 8-byte identifier.
     */
    function getParticipantUid(address participant) external view returns (bytes8 uid);

    /**
     * @notice Gets the complete participant data struct.
     * @param participantAddress The address of the participant.
     * @return participant The complete participant data structure.
     */
    function getParticipant(address participantAddress) external view returns (Participant memory participant);
}
