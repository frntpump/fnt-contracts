// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "../../libs/LibAppStorage.sol";
import {LibConstants as LC} from "../../libs/LibConstants.sol";
import {LibParticipant} from "../../libs/LibParticipant.sol";
import {LibFNT} from "../../libs/LibFNT.sol";
import {LibErrors} from "../../libs/LibErrors.sol";
import {LibEvents} from "../../libs/LibEvents.sol";
import {AccessControl} from "../../shared/AccessControl.sol";
import {ReentrancyGuardTransient} from "../../shared/ReentrancyGuard.sol";
import {Participant, ClaimConfiguration, ClaimStatus, ClaimEligible} from "../../shared/Structs.sol";

/**
 * @title ParticipantActionsFacet
 * @author Forever Network
 * @notice Handles participant actions like claiming bonuses, managing purchases, and status updates.
 * @dev This facet is stateless and relies on `LibParticipant` and `AppStorage` for state modifications.
 */
contract ParticipantActionsFacet is ReentrancyGuardTransient, AccessControl {
    // =============================================================
    //                       EXTERNAL FUNCTIONS
    // =============================================================

    // ----------------- Participant Management ------------------

    /**
     * @notice Links a new wallet address to the caller's existing participant UID.
     * @dev Only the primary wallet associated with a participant UID can link new wallets.
     * @param newWallet The address of the new wallet to link.
     */
    function linkWallet(address newWallet) external whenGlobalNotPaused unlockedFunction {
        LibParticipant.linkWallet(_msgSender(), newWallet);
    }

    /**
     * @notice Dissociates a wallet address from the caller's participant UID.
     * @dev Only the primary wallet associated with a participant UID unlink wallets.
     * @param walletToRemove The address to unlink.
     */
    function unlinkWallet(address walletToRemove) external whenGlobalNotPaused unlockedFunction {
        LibParticipant.unlinkWallet(_msgSender(), walletToRemove);
    }

    /**
     * @notice Manually updates a participant's active status based on their current FNT token balance.
     * @dev Can be called by anyone, typically by the UI or a bot, to update a participant's active status
     * if their balance has changed relative to the existential deposit.
     * @param participant The address of the participant to update.
     */
    function updateParticipantStatus(address participant) external unlockedFunction {
        LibParticipant._updateParticipantStatus(participant);
    }

    // ----------------- Bonus Claiming ------------------

    /**
     * @notice Allows an active participant to claim accumulated deferred and referral token bonuses.
     * @dev Checks if token claims are active and if the participant meets the required claim threshold (which varies based on sponsored status).
     * Mints the claimed token amount to the participant and resets their internal balance.
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier unlockedFunction executes only when function is unlocked
     * @custom:modifier onlyActiveParticipant
     * @custom:modifier nonReentrant
     */
    function claimTokenBonus() external whenGlobalNotPaused unlockedFunction onlyActiveParticipant nonReentrant {
        _executeTokenBonusClaim();
    }

    /**
     * @notice Allows an active participant to claim accumulated native currency bonuses (BNB).
     * @dev Checks if native claims are active and if the participant meets the required claim threshold.
     * Sends the claimed native currency to the participant and resets their internal balance.
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier unlockedFunction executes only when function is unlocked
     * @custom:modifier onlyActiveParticipant
     * @custom:modifier nonReentrant
     */
    function claimNativeBonus() external whenGlobalNotPaused unlockedFunction onlyActiveParticipant nonReentrant {
        _executeNativeBonusClaim();
    }

    /**
     * @notice Allows an active participant to claim manually credited tokens.
     * @dev Checks if token credit claims are active. Claims the specified `amount` or the full available amount if `amount` is zero.
     * Mints the claimed tokens to the participant.
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier unlockedFunction executes only when function is unlocked
     * @custom:modifier onlyActiveParticipant
     * @custom:modifier nonReentrant
     * @param amount The amount of credited tokens to claim. Pass 0 to claim all available credited tokens.
     */
    function claimCreditedTokens(uint256 amount)
        external
        whenGlobalNotPaused
        unlockedFunction
        onlyActiveParticipant
        nonReentrant
    {
        _executeCreditedTokensClaim(amount);
    }

    /**
     * @notice Convenience function to claim all eligible bonuses (token bonus, credited tokens, and native bonus) in a single transaction.
     * @dev Executes {claimTokenBonus}, {claimCreditedTokens}, and {claimNativeBonus} if balances are non-zero.
     * @return tokenBonusClaimed The amount of deferred token bonus claimed.
     * @return tokenCreditClaimed The amount of credited tokens claimed.
     * @return nativeClaimed The amount of native bonus claimed.
     *
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier unlockedFunction executes only when function is unlocked
     * @custom:modifier onlyActiveParticipant
     * @custom:modifier nonReentrant
     */
    function claimAll()
        external
        whenGlobalNotPaused
        unlockedFunction
        onlyActiveParticipant
        nonReentrant
        returns (uint256 tokenBonusClaimed, uint256 tokenCreditClaimed, uint256 nativeClaimed)
    {
        // --- Setup: Read all storage pointers once for gas savings ---
        AppStorage storage ds = LibAppStorage.diamondStorage();
        address sender = _msgSender();
        Participant storage participant = LibParticipant.getParticipant(sender);
        ClaimConfiguration storage cfg = ds.claimConfig;
        ClaimStatus storage claimStatus = ds.claimStatus;
        ClaimEligible storage eligibility = ds.claimEligible[sender];

        // --- Cache amounts to claim before state changes ---
        tokenBonusClaimed = participant.tokenBonus;
        tokenCreditClaimed = participant.creditedTokens;
        nativeClaimed = participant.nativeBonus;

        uint256 totalTokensToMint = 0;
        bool anyClaimed = false;

        // --- 1. Process Token Bonus Claim ---
        if (tokenBonusClaimed > 0) {
            if (!claimStatus.tokenBonusClaimActive) revert LibErrors.BonusClaimNotActive();

            if (!eligibility.tokenBonus && !cfg.freeTokenClaimEnabled) {
                uint256 threshold =
                    participant.isSponsored ? cfg.sponsoredTokenClaimThreshold : cfg.participantTokenClaimThreshold;

                if (tokenBonusClaimed < threshold) {
                    revert LibErrors.BelowClaimThreshold(tokenBonusClaimed, threshold);
                }
                eligibility.tokenBonus = true;
            }

            participant.tokenBonus = 0;
            participant.tokenBonusClaimed += tokenBonusClaimed;

            if (participant.firstTokenClaimAt == 0) {
                participant.firstTokenClaimAt = uint48(block.timestamp);
            }
            participant.lastTokenClaimAt = uint48(block.timestamp);
            claimStatus.totalBonusClaimed += tokenBonusClaimed;
            totalTokensToMint += tokenBonusClaimed;
            anyClaimed = true;

            emit LibEvents.TokenBonusClaimed(sender, tokenBonusClaimed);
        }

        // --- 2. Process Credited Tokens Claim ---
        if (tokenCreditClaimed > 0) {
            if (!claimStatus.tokenCreditClaimActive) revert LibErrors.CreditClaimNotActive();

            participant.creditedTokens = 0;
            participant.creditedTokensClaimed += tokenCreditClaimed;
            totalTokensToMint += tokenCreditClaimed;
            anyClaimed = true;

            emit LibEvents.CreditedTokensClaimed(sender, tokenCreditClaimed);
        }

        // --- 3. Process Native Bonus Claim ---
        if (nativeClaimed > 0) {
            if (!claimStatus.nativeBonusClaimActive) revert LibErrors.BonusClaimNotActive();

            if (!eligibility.nativeBonus) {
                uint256 threshold =
                    participant.isSponsored ? cfg.sponsoredNativeClaimThreshold : cfg.participantNativeClaimThreshold;

                if (nativeClaimed < threshold) {
                    revert LibErrors.BelowClaimThreshold(nativeClaimed, threshold);
                }
                eligibility.nativeBonus = true;
            }

            participant.nativeBonus = 0;
            participant.nativeBonusClaimed += nativeClaimed;

            if (participant.firstNativeClaimAt == 0) {
                participant.firstNativeClaimAt = uint48(block.timestamp);
            }
            participant.lastNativeClaimAt = uint48(block.timestamp);
            claimStatus.totalNativeClaimed += nativeClaimed;

            (bool success,) = payable(sender).call{value: nativeClaimed}("");
            if (!success) revert LibErrors.NativeTransferFailed();
            anyClaimed = true;

            emit LibEvents.NativeBonusClaimed(sender, nativeClaimed);
        }

        // --- Finalization: Mint tokens and update status once ---
        if (totalTokensToMint > 0) {
            LibFNT._mint(sender, totalTokensToMint);
        }

        if (anyClaimed) {
            LibParticipant._updateParticipantStatus(sender);
        }
    }

    // ----------------- Admin Actions ------------------

    /**
     * @notice Manually credits tokens to a specified participant.
     * @dev Only callable by an account with the `TOKEN_CREDIT_ROLE`. Requires the participant to be registered.
     * Emits a {TokensCredited} event.
     * @custom:modifier onlyRole(TOKEN_CREDIT_ROLE)
     * @param participantAddress The address of the participant to credit.
     * @param tokenAmount The amount of tokens to credit (will be available for claim via {claimCreditedTokens}).
     * @param description A descriptive string for the credit transaction.
     */
    function creditTokens(address participantAddress, uint256 tokenAmount, string calldata description)
        external
        onlyRole(LC.TOKEN_CREDIT_ROLE)
        unlockedFunction
        nonReentrant
    {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[participantAddress];
        if (uid == bytes8(0)) revert LibErrors.NotRegistered(participantAddress);
        uint256 remainingAllowance = ds.tokenCreditAllowance[_msgSender()];
        if (tokenAmount > remainingAllowance) {
            revert LibErrors.CreditAllowanceExceeded(remainingAllowance, tokenAmount);
        }
        Participant storage participant = ds.participantsByUid[uid];

        if (participant.firstTokenCreditAt == 0) {
            participant.firstTokenCreditAt = uint48(block.timestamp);
        }

        participant.lastTokenCreditAt = uint48(block.timestamp);
        participant.creditedTokens += tokenAmount;
        unchecked {
            ds.tokenCreditAllowance[_msgSender()] = remainingAllowance - tokenAmount;
        }

        emit LibEvents.TokensCredited(participantAddress, tokenAmount, description);
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Internal function to execute the token bonus claim logic.
     * @dev This function handles all the checks and state updates required for claiming token bonuses.
     * It verifies claim activation, eligibility, updates participant balances, and mints tokens.
     */
    function _executeTokenBonusClaim() internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ClaimConfiguration storage cfg = ds.claimConfig;
        ClaimStatus storage claimStatus = ds.claimStatus;
        Participant storage participant = LibParticipant.getParticipant(_msgSender());
        ClaimEligible storage eligibility = ds.claimEligible[_msgSender()];

        if (!claimStatus.tokenBonusClaimActive) revert LibErrors.BonusClaimNotActive();

        if (!eligibility.tokenBonus && !cfg.freeTokenClaimEnabled) {
            uint256 threshold =
                participant.isSponsored ? cfg.sponsoredTokenClaimThreshold : cfg.participantTokenClaimThreshold;

            if (participant.tokenBonus < threshold) {
                revert LibErrors.BelowClaimThreshold(participant.tokenBonus, threshold);
            }

            eligibility.tokenBonus = true;
        }

        uint256 amountToClaim = participant.tokenBonus;
        participant.tokenBonus = 0;
        participant.tokenBonusClaimed += amountToClaim;

        if (participant.firstTokenClaimAt == 0) {
            participant.firstTokenClaimAt = uint48(block.timestamp);
        }

        participant.lastTokenClaimAt = uint48(block.timestamp);
        claimStatus.totalBonusClaimed += amountToClaim;
        LibFNT._mint(_msgSender(), amountToClaim);
        LibParticipant._updateParticipantStatus(_msgSender());

        emit LibEvents.TokenBonusClaimed(_msgSender(), amountToClaim);
    }

    /**
     * @notice Internal function to execute the native bonus claim logic.
     * @dev This function handles all the checks and state updates required for claiming native currency bonuses.
     * It verifies claim activation, eligibility, updates participant balances, and transfers native currency.
     */
    function _executeNativeBonusClaim() internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ClaimConfiguration storage cfg = ds.claimConfig;
        ClaimStatus storage claimStatus = ds.claimStatus;
        Participant storage participant = LibParticipant.getParticipant(_msgSender());
        ClaimEligible storage eligibility = ds.claimEligible[_msgSender()];

        if (!claimStatus.nativeBonusClaimActive) revert LibErrors.BonusClaimNotActive();

        if (!eligibility.nativeBonus) {
            uint256 threshold =
                participant.isSponsored ? cfg.sponsoredNativeClaimThreshold : cfg.participantNativeClaimThreshold;

            if (participant.nativeBonus < threshold) {
                revert LibErrors.BelowClaimThreshold(participant.nativeBonus, threshold);
            }

            eligibility.nativeBonus = true;
        }

        uint256 amountToClaim = participant.nativeBonus;
        participant.nativeBonus = 0;
        participant.nativeBonusClaimed += amountToClaim;

        if (participant.firstNativeClaimAt == 0) {
            participant.firstNativeClaimAt = uint48(block.timestamp);
        }

        participant.lastNativeClaimAt = uint48(block.timestamp);
        claimStatus.totalNativeClaimed += amountToClaim;

        (bool success,) = payable(_msgSender()).call{value: amountToClaim}("");
        if (!success) revert LibErrors.NativeTransferFailed();

        emit LibEvents.NativeBonusClaimed(_msgSender(), amountToClaim);
    }

    /**
     * @notice Internal function to execute the credited tokens claim logic.
     * @dev This function handles all the checks and state updates required for claiming manually credited tokens.
     * It verifies claim activation, available balance, updates participant balances, and mints tokens.
     * @param amount The amount of credited tokens to claim. Pass 0 to claim all available credited tokens.
     */
    function _executeCreditedTokensClaim(uint256 amount) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        ClaimStatus storage claimStatus = ds.claimStatus;
        Participant storage participant = LibParticipant.getParticipant(_msgSender());

        if (!claimStatus.tokenCreditClaimActive) revert LibErrors.CreditClaimNotActive();
        if (amount == 0) amount = participant.creditedTokens;
        if (amount > participant.creditedTokens) {
            revert LibErrors.InsufficientBalance(participant.creditedTokens, amount);
        }

        participant.creditedTokens -= amount;
        participant.creditedTokensClaimed += amount;

        LibFNT._mint(_msgSender(), amount);
        LibParticipant._updateParticipantStatus(_msgSender());

        emit LibEvents.CreditedTokensClaimed(_msgSender(), amount);
    }
}
