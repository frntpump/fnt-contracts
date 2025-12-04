// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "../../libs/LibAppStorage.sol";
import {LibParticipant} from "../../libs/LibParticipant.sol";
import {LibPurchase} from "../../libs/LibPurchase.sol";
import {LibFNT} from "../../libs/LibFNT.sol";
import {LibErrors} from "../../libs/LibErrors.sol";
import {LibEvents} from "../../libs/LibEvents.sol";
import {AccessControl} from "../../shared/AccessControl.sol";
import {ReentrancyGuardTransient} from "../../shared/ReentrancyGuard.sol";
import {Participant, PurchaseConfiguration, PurchasePreview} from "../../shared/Structs.sol";

/**
 * @title PurchaseFacet
 * @author Forever Network
 * @notice Handles the token purchase logic for the FNT Diamond.
 * @dev This facet allows users to buy FNT tokens with native currency (BNB)
 * and manages the application of a "whale tax" on large purchases.
 * It integrates with the external FNT token contract for minting.
 */
contract PurchaseFacet is ReentrancyGuardTransient, AccessControl {
    // =============================================================
    //                       EXTERNAL FUNCTIONS
    // =============================================================

    /**
     * @notice Purchase FNT tokens by sending native currency.
     * @dev Converts the sent native currency (msg.value) into tokens based on the current purchase rate.
     * - Registers the buyer if they are not already a participant.
     * - Applies a whale tax if the gross purchase amount exceeds the configured threshold.
     * - Mints the net token amount (gross - tax) to the buyer.
     * - Records the purchase and any tax in the participant's storage.
     * @custom:modifier payable
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier unlockedFunction
     * @custom:modifier nonReentrant
     */
    function purchaseTokens() external payable whenGlobalNotPaused unlockedFunction nonReentrant {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        if (msg.value == 0) revert LibErrors.ZeroValue();

        // Check purchase validity and calculate amounts
        PurchasePreview memory computePurchase = previewPurchase(msg.value);

        bool canPurchase = computePurchase.canPurchase;
        string memory reason = computePurchase.reason;
        uint256 tokenAmount = computePurchase.tokenAmount;
        uint256 whaleTax = computePurchase.whaleTax;
        uint256 mintAmount = tokenAmount - whaleTax;

        if (!canPurchase) revert LibErrors.PurchaseFailed(reason);

        bytes8 uid = ds.addressToUid[_msgSender()];
        // --- Auto-registration if not a participant ---
        if (uid == 0) {
            (, uid) = LibParticipant._register(_msgSender(), address(0), 0, false);
        }

        // --- State Updates ---
        LibParticipant._updatePurchaseRecords(_msgSender(), tokenAmount, msg.value, whaleTax);

        // --- Minting ---
        // Mint the net amount to the buyer via the external token contract
        LibFNT._mint(_msgSender(), mintAmount);
        LibParticipant._updateParticipantStatus(_msgSender());

        emit LibEvents.TokensPurchased(_msgSender(), uid, msg.value, tokenAmount, whaleTax);
    }

    /**
     * @notice Redeem accumulated purchase tax for tokens.
     * @dev Allows a participant to claim the tokens that were collected as whale tax
     * from their own large purchases. Redemption is a one-time operation and requires
     * the participants to meet a configured referral threshold.
     * @custom:modifier whenGlobalNotPaused
     * @custom:modifier nonReentrant
     */
    function redeemPurchaseTax() external whenGlobalNotPaused unlockedFunction nonReentrant {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        PurchaseConfiguration storage cfg = ds.purchaseConfig;
        Participant storage participant = LibParticipant.getParticipant(_msgSender());

        if (!cfg.purchaseTaxRedemptionEnabled) revert LibErrors.PurchaseTaxRedemptionDisabled();
        if (participant.purchaseTaxRedeemed) revert LibErrors.PurchaseTaxAlreadyRedeemed();

        // Enforce referral threshold before checking tax presence to provide deterministic error semantics
        if (participant.referralCount < cfg.purchaseTaxRedemptionReferralThreshold) {
            revert LibErrors.RedeemThresholdNotMet(
                cfg.purchaseTaxRedemptionReferralThreshold, participant.referralCount
            );
        }

        if (participant.tokenPurchaseTax == 0) revert LibErrors.NoPurchaseTaxToRedeem();

        uint256 amount = participant.tokenPurchaseTax;

        // --- State Updates ---
        participant.tokenPurchaseTax = 0;
        participant.purchaseTaxRedeemed = true;
        participant.purchaseTaxRedeemedAt = uint48(block.timestamp);

        // --- Minting ---
        // Mint the redeemed tax tokens to the user
        LibFNT._mint(_msgSender(), amount);
        LibParticipant._updateParticipantStatus(_msgSender());

        emit LibEvents.PurchaseTaxRedeemed(_msgSender(), amount);
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Provides a detailed preview of a purchase outcome without executing the transaction.
     * @dev Calculates the gross token amount, whale tax, and checks all current purchase constraints (time, min amount, limits, active status).
     * @param value The amount of native currency (in wei, e.g., BNB) to be spent.
     * @return PurchasePreview A struct containing the simulation results:
     * - `tokenAmount`: The amount of tokens the user would receive before any whale tax.
     * - `whaleTax`: The amount of tokens to be set aside as whale tax.
     * - `canPurchase`: A boolean indicating if the purchase meets all current requirements.
     * - `reason`: A string explaining why the purchase might be invalid (e.g., "not_active").
     */
    function previewPurchase(uint256 value) public view returns (PurchasePreview memory) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        PurchaseConfiguration storage cfg = ds.purchaseConfig;
        Participant storage participant = LibParticipant.getParticipant(_msgSender());

        uint256 tokenAmount = 0;
        uint256 whaleTax = 0;

        if (value == 0) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "zero_value"});
        }

        if (!cfg.purchaseActive) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "not_active"});
        }

        if (cfg.purchaseStartTime != 0 && block.timestamp < cfg.purchaseStartTime) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "not_started"});
        }

        if (cfg.purchaseRate == 0) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "zero_rate"});
        }

        if (value < cfg.minPurchaseAmount) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "below_min"});
        }

        tokenAmount = LibPurchase.calculateTokenAmount(value, cfg.purchaseRate);

        if (tokenAmount == 0) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "zero_tokens"});
        }

        if ((tokenAmount + participant.purchasedTokens) > cfg.maxTokenPurchaseLimit) {
            return PurchasePreview({tokenAmount: 0, whaleTax: 0, canPurchase: false, reason: "exceeds_limit"});
        }

        // Compute whale tax threshold as a percentage (bps) of the maxTokenPurchaseLimit
        // Note: `cfg.whaleTaxThreshold` is interpreted as basis points (0-10000).
        uint256 thresholdAmount =
            LibPurchase.calculateWhaleThresholdAmount(cfg.maxTokenPurchaseLimit, cfg.whaleTaxThreshold);

        if (tokenAmount >= thresholdAmount) {
            whaleTax = LibPurchase.calculateWhaleTax(tokenAmount, cfg.whaleTaxBasisPoints);
        }

        return PurchasePreview({tokenAmount: tokenAmount, whaleTax: whaleTax, canPurchase: true, reason: "ok"});
    }
}
