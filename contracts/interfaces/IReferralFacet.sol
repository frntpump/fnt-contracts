// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IReferralFacet
 * @author Forever Network
 * @notice External interface for the ReferralFacet.
 */
interface IReferralFacet {
    // ============ Registration Functions ============

    /**
     * @notice Allows a new user to register and link to a referrer.
     * @param referrerId The uid of the existing participant who is referring the new user.
     */
    function registerWithReferral(bytes8 referrerId) external;

    /**
     * @notice Allows an authorized sponsor to register a new participant as sponsored.
     * @param participantAddress The address of the new participant to be sponsored.
     */
    function registerSponsored(address participantAddress) external;

    // ============ View Functions ============

    /**
     * @notice Previews the potential token and native rewards for a given referrer's next referral.
     * @param participantAddress The address of the referrer to preview rewards for.
     * @return tokenReward The estimated token reward for the next referral.
     * @return nativeReward The estimated native reward for the next referral.
     */
    function previewRewards(address participantAddress)
        external
        view
        returns (uint256 tokenReward, uint256 nativeReward);
}
