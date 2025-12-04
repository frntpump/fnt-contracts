// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PurchasePreview} from "../shared/Structs.sol";

/**
 * @title IPurchaseFacet
 * @author Forever Network
 * @notice External interface for the PurchaseFacet.
 */
interface IPurchaseFacet {
    // ============ Purchase Functions ============

    /**
     * @notice Purchase FNT tokens by sending native currency.
     */
    function purchaseTokens() external payable;

    /**
     * @notice Redeem accumulated purchase tax for tokens.
     */
    function redeemPurchaseTax() external;

    // ============ View Functions ============

    /**
     * @notice Provides a detailed preview of a purchase outcome without executing the transaction.
     * @param value The amount of native currency to be spent.
     * @return PurchasePreview A struct containing the simulation results.
     */
    function previewPurchase(uint256 value) external view returns (PurchasePreview memory);
}
