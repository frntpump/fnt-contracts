// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";
import {TokenState} from "../shared/Structs.sol";
import {IForeverNetworkToken} from "../extern/interfaces/IForeverNetworkToken.sol";
import {FeeTier} from "../extern/shared/Structs.sol";
import {LibEvents} from "./LibEvents.sol";

/**
 * @title LibFNT
 * @author Forever Network
 * @notice A library for interacting with the deployed ForeverNetworkToken (FNT).
 * @dev Provides internal wrappers for external/public functions
 *      of the ForeverNetworkToken contract and its base OpenZeppelin modules.
 *      Uses diamond storage to access the deployed FNT token address.
 */
library LibFNT {
    // =============================================================
    //                         INTERNAL HELPERS
    // =============================================================

    /// @dev Returns the interface for the deployed FNT token.
    function _token() internal view returns (IForeverNetworkToken) {
        return IForeverNetworkToken(LibAppStorage.diamondStorage().fntToken);
    }

    // =============================================================
    //                           CORE ERC20
    // =============================================================

    /**
     * @notice Returns the total supply of the token.
     * @return uint256 The total supply of FNT tokens.
     */
    function _totalSupply() internal view returns (uint256) {
        return _token().totalSupply();
    }

    /**
     * @notice Returns the balance of a participant address.
     * @param participant The address to query.
     * @return uint256 The balance of FNT tokens for the given address.
     */
    function _balanceOf(address participant) internal view returns (uint256) {
        return _token().balanceOf(participant);
    }

    /**
     * @notice Transfers tokens to another address.
     * @param to Recipient address.
     * @param value Amount to transfer.
     * @return success True if transfer succeeded.
     */
    function _transfer(address to, uint256 value) internal returns (bool success) {
        return _token().transfer(to, value);
    }

    /**
     * @notice Approves a spender to spend tokens on behalf of the caller.
     * @param spender Address authorized to spend.
     * @param value Allowance amount.
     * @return success True if approval succeeded.
     */
    function _approve(address spender, uint256 value) internal returns (bool success) {
        return _token().approve(spender, value);
    }

    /**
     * @notice Transfers tokens on behalf of another account.
     * @param from Source address.
     * @param to Recipient address.
     * @param value Amount to transfer.
     * @return success True if transfer succeeded.
     */
    function _transferFrom(address from, address to, uint256 value) internal returns (bool success) {
        return _token().transferFrom(from, to, value);
    }

    /**
     * @notice Returns the allowance from owner to spender.
     * @param owner Token owner address.
     * @param spender Spender address.
     * @return uint256 Remaining allowance.
     */
    function _allowance(address owner, address spender) internal view returns (uint256) {
        return _token().allowance(owner, spender);
    }

    // =============================================================
    //                           MINT / BURN
    // =============================================================

    /**
     * @notice Mints new tokens to an address.
     * @dev Updates internal state tracking and emits Mint(0x0, to, value).
     * @param to Recipient address.
     * @param value Amount to mint.
     */
    function _mint(address to, uint256 value) internal {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        TokenState storage tokenState = ds.tokenState;

        tokenState.totalMinted += value;
        tokenState.mintTimes += 1;

        _token().mint(to, value);
        emit LibEvents.Mint(address(0), to, value);
    }

    /**
     * @notice Burns tokens from caller.
     * @param value Amount to burn.
     */
    function _burn(uint256 value) internal {
        _token().burn(value);
    }

    /**
     * @notice Burns tokens from another account.
     * @param account Address whose tokens are burned.
     * @param value Amount to burn.
     */
    function _burnFrom(address account, uint256 value) internal {
        _token().burnFrom(account, value);
    }

    // =============================================================
    //                            PERMIT (EIP-2612)
    // =============================================================

    /**
     * @notice Approves via off-chain signature (EIP-2612).
     * @param owner The address of the token owner.
     * @param spender The address of the spender to approve.
     * @param value The amount of tokens to approve.
     * @param deadline The time at which the permit will expire.
     * @param v The recovery byte of the signature.
     * @param r The R component of the signature.
     * @param s The S component of the signature.
     */
    function _permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        internal
    {
        _token().permit(owner, spender, value, deadline, v, r, s);
    }

    /**
     * @notice Returns the current nonce of an owner.
     * @param owner The address of the token owner.
     * @return uint256 The current nonce for the given owner.
     */
    function _nonces(address owner) internal view returns (uint256) {
        return _token().nonces(owner);
    }

    // =============================================================
    //                        GOVERNANCE
    // =============================================================

    /**
     * @notice Pauses token transfers.
     */
    function _pause() internal {
        _token().pause();
    }

    /**
     * @notice Unpauses token transfers.
     */
    function _unpause() internal {
        _token().unpause();
    }

    /**
     * @notice Returns whether the token is paused.
     * @return bool True if the token is paused, false otherwise.
     */
    function _paused() internal view returns (bool) {
        return _token().paused();
    }

    /**
     * @notice Synchronises the cached governance state with the external FNT token.
     * @dev Pulls the DAO timelock and governance flag from the token and mirrors them into diamond storage.
     * @return transitioned The latest governance transition flag reported by the token.
     * @return daoTimelock The DAO timelock address reported by the token.
     * @return stateChanged True if any cached field was changed during the sync.
     */
    function _syncGovernanceState() internal returns (bool transitioned, address daoTimelock, bool stateChanged) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        IForeverNetworkToken token = _token();

        transitioned = token.governanceTransitioned();
        daoTimelock = token.daoTimelockAddress();

        if (ds.daoTimelock != daoTimelock) {
            ds.daoTimelock = daoTimelock;
            stateChanged = true;
        }

        if (ds.governanceTransitioned != transitioned) {
            ds.governanceTransitioned = transitioned;
            stateChanged = true;
        }
    }

    /**
     * @notice Returns the cached DAO timelock address.
     */
    function _daoTimelock() internal view returns (address) {
        return LibAppStorage.diamondStorage().daoTimelock;
    }

    /**
     * @notice Returns whether governance has transitioned to DAO.
     * @return bool True if governance has transitioned to DAO, false otherwise.
     */
    function _governanceTransitioned() internal view returns (bool) {
        AppStorage storage ds = LibAppStorage.diamondStorage();
        if (ds.governanceTransitioned) {
            return true;
        }
        return _token().governanceTransitioned();
    }

    /**
     * @notice Updates the mint fee tiers.
     * @param newTiers An array of `FeeTier` structs defining the new mint fee tiers.
     */
    function _updateMintFeeConfig(FeeTier[] calldata newTiers) internal {
        _token().updateMintFeeConfig(newTiers);
    }

    /**
     * @notice Updates the burn fee tiers.
     * @param newTiers An array of `FeeTier` structs defining the new burn fee tiers.
     */
    function _updateBurnFeeConfig(FeeTier[] calldata newTiers) internal {
        _token().updateBurnFeeConfig(newTiers);
    }

    /**
     * @notice Updates the treasury address.
     * @param newTreasury The new address for the treasury.
     */
    function _updateTreasury(address newTreasury) internal {
        _token().updateTreasury(newTreasury);
    }

    // =============================================================
    //                      BLACKLIST MANAGEMENT
    // =============================================================

    /**
     * @notice Adds an account to the blacklist.
     * @param account The address to blacklist.
     */
    function _blacklist(address account) internal {
        _token().blacklistAddress(account, true);
    }

    /**
     * @notice Removes an account from the blacklist.
     * @param account The address to unblacklist.
     */
    function _unblacklist(address account) internal {
        _token().blacklistAddress(account, false);
    }

    /**
     * @notice Returns whether an account is blacklisted.
     * @param account The address to check.
     * @return bool True if the account is blacklisted, false otherwise.
     */
    function _isBlacklisted(address account) internal view returns (bool) {
        return _token().isBlacklisted(account);
    }

    // =============================================================
    //                      FEE CONFIGURATION QUERIES
    // =============================================================

    /**
     * @notice Retrieves the current mint fee configuration.
     * @return FeeTier[] An array of `FeeTier` structs representing the mint fee tiers.
     */
    function _getMintFeeConfig() internal view returns (FeeTier[] memory) {
        return _token().getMintFeeConfig();
    }

    /**
     * @notice Retrieves the current burn fee configuration.
     * @return FeeTier[] An array of `FeeTier` structs representing the burn fee tiers.
     */
    function _getBurnFeeConfig() internal view returns (FeeTier[] memory) {
        return _token().getBurnFeeConfig();
    }

    // =============================================================
    //                           COUNTERS
    // =============================================================

    /**
     * @notice Returns the total number of mint operations performed.
     * @return uint256 The current mint counter value.
     */
    function _mintCounter() internal view returns (uint256) {
        return _token().mintCounter();
    }

    /**
     * @notice Returns the total number of burn operations performed.
     * @return uint256 The current burn counter value.
     */
    function _burnCounter() internal view returns (uint256) {
        return _token().burnCounter();
    }
}
