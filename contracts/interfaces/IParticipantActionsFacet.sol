// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IParticipantActionsFacet
 * @author Forever Network
 * @notice External interface for the ParticipantActionsFacet.
 */
interface IParticipantActionsFacet {
    // ============ Participant Management ============

    /**
     * @notice Links a new wallet address to the caller's existing participant UID.
     * @param newWallet The address of the new wallet to link.
     */
    function linkWallet(address newWallet) external;

    /**
     * @notice Dissociates a wallet address from the caller's participant UID.
     * @param walletToRemove The address to unlink.
     */
    function unlinkWallet(address walletToRemove) external;

    /**
     * @notice Manually updates a participant's active status based on their current FNT token balance.
     * @param participant The address of the participant to update.
     */
    function updateParticipantStatus(address participant) external;

    // ============ Bonus Claiming ============

    /**
     * @notice Claims accumulated deferred and referral token bonuses.
     */
    function claimTokenBonus() external;

    /**
     * @notice Claims accumulated native currency bonuses (BNB).
     */
    function claimNativeBonus() external;

    /**
     * @notice Claims manually credited tokens.
     * @param amount The amount of credited tokens to claim (0 for all available).
     */
    function claimCreditedTokens(uint256 amount) external;

    /**
     * @notice Claims all eligible bonuses (token bonus, credited tokens, and native bonus) in a single transaction.
     * @return tokenBonusClaimed The amount of token bonus claimed.
     * @return tokenCreditClaimed The amount of credited tokens claimed.
     * @return nativeClaimed The amount of native bonus claimed.
     */
    function claimAll() external returns (uint256 tokenBonusClaimed, uint256 tokenCreditClaimed, uint256 nativeClaimed);

    // ============ Admin Actions ============

    /**
     * @notice Manually credits tokens to a specified participant.
     * @param participantAddress The address of the participant to credit.
     * @param tokenAmount The amount of tokens to credit.
     * @param description A descriptive string for the credit transaction.
     */
    function creditTokens(address participantAddress, uint256 tokenAmount, string calldata description) external;
}
