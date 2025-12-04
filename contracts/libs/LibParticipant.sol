// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {LibFNT} from "./LibFNT.sol";
import {LibConstants as LC} from "./LibConstants.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibReferral} from "./LibReferral.sol";
import {Participant, GlobalState, GlobalConfiguration} from "../shared/Structs.sol";

/**
 * @title LibParticipant
 * @author Forever Network
 * @notice A stateless library for handling all participant-related state modifications.
 * @dev It operates on the AppStorage struct to ensure consistent state changes
 *      across all facets related to participant management.
 */
library LibParticipant {
    /**
     * @notice Retrieves the `Participant` storage struct for the `msg.sender`.
     * @dev This is a convenience function to get the current caller's participant data.
     * @return p A storage pointer to the `Participant` struct of the caller.
     */
    function getParticipant() internal view returns (Participant storage p) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[msg.sender];
        p = ds.participantsByUid[uid];
    }

    /**
     * @notice Retrieves the `Participant` storage struct for a given address.
     * @dev Used to access participant data for any specified address.
     * @param participantAddress The address for which to retrieve participant data.
     * @return p A storage pointer to the `Participant` struct of the specified address.
     */
    function getParticipant(address participantAddress) internal view returns (Participant storage p) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[participantAddress];
        p = ds.participantsByUid[uid];
    }

    /**
     * @notice Links a new wallet address to an existing participant's UID.
     * @dev The caller (`msg.sender`) must be the primary wallet of a registered participant.
     * Reverts if the `newWallet` is zero address, already linked, or if the maximum number of wallets is reached.
     * Emits a {WalletLinked} event upon successful linkage.
     * @param actor The address of the participant initiating the link.
     * @param newWallet The address of the new wallet to link to the participant.
     */
    function linkWallet(address actor, address newWallet) internal {
        if (newWallet == address(0)) revert LibErrors.ZeroAddress();

        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[actor];

        if (uid == 0) revert LibErrors.NotRegistered(actor);

        if (ds.uidToAddresses[uid].length >= LC.MAX_LINKED_WALLETS) {
            revert LibErrors.MaxWalletsLinked();
        }

        Participant storage participant = ds.participantsByUid[uid];

        if (ds.addressToUid[newWallet] != 0) revert LibErrors.WalletAlreadyLinked(newWallet);
        if (actor != participant.addr) revert LibErrors.WalletNotPrimary(actor);

        ds.addressToUid[newWallet] = uid;
        ds.uidToAddresses[uid].push(newWallet);

        emit LibEvents.WalletLinked(uid, newWallet);
    }

    /**
     * @notice Unlinks a wallet address from an existing participant's UID.
     * @dev The caller (`msg.sender`) must be the primary wallet of the participant. The wallet to remove cannot be the primary wallet.
     * Reverts if the `walletToRemove` is not linked or is the primary wallet.
     * Emits a {WalletUnlinked} event upon successful unlinking.
     * @param actor The address of the participant initiating the unlink.
     * @param walletToRemove The address of the wallet to unlink from the participant.
     */
    function unlinkWallet(address actor, address walletToRemove) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[actor];
        if (uid == 0) revert LibErrors.NotRegistered(actor);

        Participant storage participant = ds.participantsByUid[uid];
        if (actor != participant.addr) revert LibErrors.WalletNotPrimary(walletToRemove);
        if (walletToRemove == participant.addr) revert LibErrors.WalletPrimaryUnlink(walletToRemove);
        if (ds.addressToUid[walletToRemove] != uid) revert LibErrors.WalletNotLinked(walletToRemove);

        // Delete mapping
        delete ds.addressToUid[walletToRemove];

        // Compact uidToAddresses
        address[] storage wallets = ds.uidToAddresses[uid];
        uint256 len = wallets.length;
        for (uint256 i = 0; i < len; i++) {
            if (wallets[i] == walletToRemove) {
                wallets[i] = wallets[len - 1];
                wallets.pop();
                break;
            }
        }

        emit LibEvents.WalletUnlinked(uid, walletToRemove);
    }

    /**
     * @notice Registers a new participant, initializing their record in storage.
     * @dev This internal function is the single point of entry for creating new participant records.
     *      It checks the participant's token balance to determine their initial active status.
     * @param participantAddress The address of the new participant.
     * @param referrer The address of the referrer, if any.
     * @param referralIndex The index of this referral for the referrer.
     * @param isSponsored A boolean indicating if the participant is sponsored.
     * @return id The new participant's unique numerical ID.
     * @return uid The new participant's unique identifier (bytes8).
     */
    function _register(address participantAddress, address referrer, uint48 referralIndex, bool isSponsored)
        internal
        returns (uint64 id, bytes8 uid)
    {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        GlobalState storage globalState = ds.globalState;
        uid = bytes8(keccak256(abi.encodePacked(participantAddress, block.timestamp, block.prevrandao)));

        if (isSponsored) {
            ++globalState.sponsoredParticipantCount;
            ds.sponsoredParticipants.push(uid);
        }

        ds.participantsByUid[uid] = Participant({
            id: ++globalState.participantCount,
            uid: uid,
            addr: participantAddress,
            referrer: referrer,
            isActive: false,
            isSponsored: isSponsored,
            purchaseTaxRedeemed: false,
            registeredAt: uint48(block.timestamp),
            firstActiveAt: 0,
            lastActivityBlock: uint64(block.number),
            tier: 0,
            referralCount: 0,
            referralPos: referralIndex,
            firstReferralAt: 0,
            lastReferralAt: 0,
            firstPurchaseAt: 0,
            lastPurchaseAt: 0,
            timesPurchased: 0,
            purchaseTaxRedeemedAt: 0,
            firstTokenClaimAt: 0,
            lastTokenClaimAt: 0,
            tokenBonus: 0,
            tokenBonusClaimed: 0,
            nativeBonus: 0,
            nativeBonusClaimed: 0,
            firstNativeClaimAt: 0,
            lastNativeClaimAt: 0,
            purchasedTokens: 0,
            nativePurchaseAmount: 0,
            tokenPurchaseTax: 0,
            firstTokenCreditAt: 0,
            lastTokenCreditAt: 0,
            creditedTokens: 0,
            creditedTokensClaimed: 0,
            countedAsActiveReferral: false,
            tierSyncedAt: 0
        });

        ds.addressToUid[participantAddress] = uid;
        ds.uidToAddresses[uid].push(participantAddress);

        emit LibEvents.ParticipantRegistered(ds.participantsByUid[uid]);

        return (ds.participantsByUid[uid].id, uid);
    }

    /**
     * @notice Updates the referrer's data after a new referral.
     * @dev This function increments the referrer's referral count and updates timestamps.
     * Also records the referee in the referrer's referral tree.
     * @param referrerAddress The address of the referrer.
     * @param refereeAddress The address of the new participant.
     * @param referralIndex The index of this referral for the referrer.
     */
    function _processReferrerUpdates(address referrerAddress, address refereeAddress, uint64 referralIndex) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        GlobalState storage globalState = ds.globalState;
        bytes8 referrerUid = ds.addressToUid[referrerAddress];
        Participant storage referrer = ds.participantsByUid[referrerUid];

        if (referrer.firstReferralAt == 0) {
            referrer.firstReferralAt = uint48(block.timestamp);
        }

        referrer.lastReferralAt = uint48(block.timestamp);
        ++referrer.referralCount;

        // Update participant tier based on current referral count and configured thresholds
        _syncReferralTier(ds, referrer);

        ++globalState.referralCount;
        ds.referralTree[referrerAddress][referralIndex] = refereeAddress;

        emit LibEvents.ReferralRecorded(referrerAddress, refereeAddress);
    }

    /**
     * @notice Applies the registration bonus to a new participant.
     * @dev This function handles both instant and deferred token bonuses for the new referee.
     *      The actual token minting for the instant bonus is delegated to an external call.
     * @param participantAddress The address of the new participant receiving the bonus.
     */
    function _applyRefereeBonus(address participantAddress) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[participantAddress];
        Participant storage participant = ds.participantsByUid[uid];
        GlobalConfiguration storage cfg = ds.globalConfig;

        if (cfg.refereeDeferredTokenBonus > 0) {
            participant.tokenBonus += cfg.refereeDeferredTokenBonus;
        }
        if (cfg.refereeInstantTokenBonus > 0) {
            // External call to the token contract to mint the instant bonus
            LibFNT._mint(participantAddress, cfg.refereeInstantTokenBonus);
        }
    }

    /**
     * @notice Updates a participant's active status based on their token balance.
     * @dev This function is critical for ensuring that participants meet the existential deposit requirement.
     *      It checks the FNT token balance against the `existentialDeposit` and updates `isActive` accordingly.
     *      It emits a {ParticipantStatusUpdated} event if the participant's status changes.
     * @param participantAddress The address of the participant to update.
     * @return bool A boolean indicating the participant's new active status.
     */
    function _updateParticipantStatus(address participantAddress) internal returns (bool) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        bytes8 uid = ds.addressToUid[participantAddress];
        if (uid == bytes8(0)) return false;
        Participant storage participant = ds.participantsByUid[uid];

        bool prevActive = participant.isActive;
        // External call to the token contract to get the current balance
        bool newActive = _participantActive(uid);

        if (prevActive != newActive) {
            participant.isActive = newActive;

            if (newActive && participant.firstActiveAt == 0) {
                participant.firstActiveAt = uint48(block.timestamp);
                participant.countedAsActiveReferral = true;
                _creditMilestoneReward(ds, participant);
            }

            emit LibEvents.ParticipantStatusUpdated(participantAddress, newActive, uint64(block.number), true);
        }

        participant.lastActivityBlock = uint64(block.number);
        _syncReferralTier(ds, participant);

        return newActive;
    }

    /**
     * @notice Determines if a participant is currently active based on their FNT token balance.
     * @dev A participant is considered active if their FNT balance is greater than or equal to the `existentialDeposit`.
     * @param uid The unique identifier of the participant.
     * @return bool True if the participant is active, false otherwise.
     */
    function _participantActive(bytes8 uid) internal view returns (bool) {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        if (uid == bytes8(0)) return false;

        Participant storage p = ds.participantsByUid[uid];
        uint256 existentialDeposit = ds.globalConfig.existentialDeposit;

        // Use the canonical address from the participant struct
        return LibFNT._balanceOf(p.addr) >= existentialDeposit;
    }

    /**
     * @notice Updates the purchase records for a participant and the global status.
     * @dev This function increments purchased token amounts, native currency spent, and purchase count.
     * It also records any whale tax incurred and updates global token state.
     * @param participantAddress The address of the participant making the purchase.
     * @param tokenAmount The amount of tokens purchased (gross, before tax deduction).
     * @param nativeValue The amount of native currency spent for the purchase.
     * @param whaleTax The amount of tokens deducted as whale tax.
     */
    function _updatePurchaseRecords(
        address participantAddress,
        uint256 tokenAmount,
        uint256 nativeValue,
        uint256 whaleTax
    ) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        GlobalState storage globalState = ds.globalState;
        bytes8 uid = ds.addressToUid[participantAddress];
        Participant storage participant = ds.participantsByUid[uid];

        if (participant.firstPurchaseAt == 0) {
            participant.firstPurchaseAt = uint48(block.timestamp);
            ds.orderedPurchasers[globalState.purchaserCount] = participantAddress;
            ++globalState.purchaserCount;
        }

        participant.purchasedTokens += tokenAmount;
        participant.nativePurchaseAmount += nativeValue;
        ++participant.timesPurchased;

        if (whaleTax > 0) {
            participant.tokenPurchaseTax += whaleTax;
        }

        ds.tokenState.totalPurchased += tokenAmount;
        ++ds.tokenState.purchaseTimes;
    }

    /**
     * @notice Handles accounting side-effects when a referee transitions to an active state for the first time.
     * @dev Increments the referrer's active referee count and accrues any pending native milestone rewards.
     *      Returns true when downstream tier synchronization should run.
     * @param ds AppStorage pointer for accessing shared state.
     * @param referee Storage pointer to the participant that just became active.
     */
    function _creditMilestoneReward(AppStorage storage ds, Participant storage referee) private returns (bool) {
        address referrerAddress = referee.referrer;
        if (referrerAddress == address(0)) return false;

        bytes8 referrerUid = ds.addressToUid[referrerAddress];
        if (referrerUid == bytes8(0)) return false;

        Participant storage referrer = ds.participantsByUid[referrerUid];
        uint64 newActiveCount = ++ds.activeRefereeCount[referrerAddress];

        (uint256 nativeReward, uint256 newMilestone) =
            LibReferral.calculateMilestoneReward(newActiveCount, ds.lastMilestone[referrerAddress], ds.refRewardConfig);

        if (newMilestone > ds.lastMilestone[referrerAddress]) {
            ds.lastMilestone[referrerAddress] = newMilestone;
        }

        if (nativeReward > 0) {
            referrer.nativeBonus += nativeReward;
            emit LibEvents.ReferralBonus(referrerAddress, 0, nativeReward);
        }

        return true;
    }

    /**
     * @notice Resynchronizes the participant's tier based on the current active referral count.
     * @param ds AppStorage pointer for accessing shared state.
     */
    function _syncReferralTier(AppStorage storage ds, Participant storage participant) private {
        uint8 newTier = LibReferral.determineTier(participant.referralCount, ds.refRewardConfig);
        if (newTier != participant.tier) {
            participant.tier = newTier;
            participant.tierSyncedAt = uint48(block.timestamp);
            emit LibEvents.ParticipantTierUpdated(participant.addr, newTier, participant.tierSyncedAt);
        }
    }
}
