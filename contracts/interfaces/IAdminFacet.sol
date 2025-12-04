// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    GlobalConfiguration,
    GlobalState,
    PurchaseConfiguration,
    ClaimConfiguration,
    ClaimStatus,
    RefRewardConfig,
    RefMultiplierConfig,
    EIP712Info
} from "../shared/Structs.sol";

/**
 * @title IAdminFacet
 * @author Forever Network
 * @notice External interface for the AdminFacet.
 */
interface IAdminFacet {
    // ============ System Control Functions ============

    /**
     * @notice Pauses the network.
     */
    function pause() external;

    /**
     * @notice Unpauses the network.
     */
    function unpause() external;

    /**
     * @notice Locks a specific function.
     * @param _functionSelector The bytes4 function selector to lock.
     */
    function lockFunction(bytes4 _functionSelector) external;

    /**
     * @notice Unlocks a specific function.
     * @param _functionSelector The bytes4 function selector to unlock.
     */
    function unlockFunction(bytes4 _functionSelector) external;

    /**
     * @notice Locks multiple functions in a single transaction.
     * @param _functionSelectors Array of bytes4 function selectors to lock.
     */
    function batchLockFunctions(bytes4[] calldata _functionSelectors) external;

    /**
     * @notice Unlocks multiple functions in a single transaction.
     * @param _functionSelectors Array of bytes4 function selectors to unlock.
     */
    function batchUnlockFunctions(bytes4[] calldata _functionSelectors) external;

    // ============ Fund Withdrawal Functions ============

    /**
     * @notice Withdraws native currency from the diamond.
     * @param to The address to send the native currency to.
     * @param amount The amount to withdraw (0 for entire balance).
     */
    function withdrawNativeToken(address to, uint256 amount) external;

    /**
     * @notice Withdraws any BEP20/ERC20 token from the diamond.
     * @param tokenContract The address of the token to withdraw.
     * @param to The address to send the tokens to.
     * @param amount The amount to withdraw (0 for entire balance).
     */
    function withdrawForeignToken(address tokenContract, address to, uint256 amount) external;

    // ============ Configuration Functions ============

    /**
     * @notice Updates the treasury address.
     * @param _treasury The new treasury address.
     */
    function updateTreasuryAddress(address _treasury) external;

    /**
     * @notice Updates the DAO timelock address.
     * @param _daoTimelock The new DAO timelock address.
     */
    function updateDaoTimelockAddress(address _daoTimelock) external;

    /**
     * @notice Pulls governance state from the external FNT token.
     */
    function syncFNTGovernance() external;

    /**
     * @notice Updates the FNT token address.
     * @param _fntToken The new FNT token address.
     */
    function updateFNTAddress(address _fntToken) external;

    /**
     * @notice Sets purchase start time.
     * @param _purchaseStartTime The new purchase start time.
     */
    function updatePurchaseStartTime(uint48 _purchaseStartTime) external;

    /**
     * @notice Sets global configuration parameters.
     * @param _existentialDeposit The minimum FNT balance for active status.
     * @param _refereeDeferredTokenBonus Deferred token bonus for new participants.
     * @param _refereeInstantTokenBonus Instant token bonus for new participants.
     */
    function setGlobalConfig(
        uint256 _existentialDeposit,
        uint256 _refereeDeferredTokenBonus,
        uint256 _refereeInstantTokenBonus
    ) external;

    /**
     * @notice Sets purchase configuration parameters.
     * @param _purchaseActive Whether purchases are active.
     * @param _purchaseTaxRedemptionEnabled Whether tax redemption is enabled.
     * @param _purchaseTaxRedemptionReferralThreshold Minimum referrals for tax redemption.
     * @param _whaleTaxThreshold Whale tax threshold percentage.
     * @param _whaleTaxBasisPoints Whale tax rate in basis points.
     * @param _purchaseStartTime Purchase start timestamp.
     * @param _purchaseRate Purchase rate (wei per token unit).
     * @param _minPurchaseAmount Minimum purchase amount.
     * @param _maxTokenPurchaseLimit Maximum tokens per participant.
     */
    function setPurchaseConfig(
        bool _purchaseActive,
        bool _purchaseTaxRedemptionEnabled,
        uint16 _purchaseTaxRedemptionReferralThreshold,
        uint16 _whaleTaxThreshold,
        uint16 _whaleTaxBasisPoints,
        uint48 _purchaseStartTime,
        uint256 _purchaseRate,
        uint256 _minPurchaseAmount,
        uint256 _maxTokenPurchaseLimit
    ) external;

    /**
     * @notice Sets claim configuration parameters.
     * @param _freeTokenClaimEnabled Whether free token claims are enabled.
     * @param _participantTokenClaimThreshold Token claim threshold for regular participants.
     * @param _sponsoredTokenClaimThreshold Token claim threshold for sponsored participants.
     * @param _participantNativeClaimThreshold Native claim threshold for regular participants.
     * @param _sponsoredNativeClaimThreshold Native claim threshold for sponsored participants.
     */
    function setClaimConfig(
        bool _freeTokenClaimEnabled,
        uint256 _participantTokenClaimThreshold,
        uint256 _sponsoredTokenClaimThreshold,
        uint256 _participantNativeClaimThreshold,
        uint256 _sponsoredNativeClaimThreshold
    ) external;

    /**
     * @notice Sets claim status for different bonus types.
     * @param _tokenBonusClaimActive Whether token bonus claims are active.
     * @param _tokenCreditClaimActive Whether token credit claims are active.
     * @param _nativeBonusClaimActive Whether native bonus claims are active.
     */
    function setClaimStatus(bool _tokenBonusClaimActive, bool _tokenCreditClaimActive, bool _nativeBonusClaimActive)
        external;

    /**
     * @notice Sets referral reward configuration.
     * @param _thresholds Referral count thresholds.
     * @param _tokenRewards Token rewards for each threshold.
     * @param _milestoneBonus Milestone bonus amount.
     * @param _milestoneInterval Milestone interval.
     * @param _maxMilestones Maximum milestones.
     * @param _milestonePercentMultiplier Milestone percentage multiplier.
     */
    function setRefRewardConfig(
        uint48[] calldata _thresholds,
        uint256[] calldata _tokenRewards,
        uint256 _milestoneBonus,
        uint256 _milestoneInterval,
        uint256 _maxMilestones,
        uint64 _milestonePercentMultiplier
    ) external;

    /**
     * @notice Sets referral multiplier configuration.
     * @param _sponsoredThreshold Threshold for sponsored participants.
     * @param _unsponsoredThreshold Threshold for unsponsored participants.
     * @param _sponsoredMultiplier Multiplier for sponsored participants.
     * @param _unsponsoredMultiplier Multiplier for unsponsored participants.
     * @param _sponsoredWindow Window for sponsored multiplier.
     * @param _unsponsoredWindow Window for unsponsored multiplier.
     */
    function setRefMultiplierConfig(
        uint8 _sponsoredThreshold,
        uint8 _unsponsoredThreshold,
        uint8 _sponsoredMultiplier,
        uint8 _unsponsoredMultiplier,
        uint8 _sponsoredWindow,
        uint8 _unsponsoredWindow
    ) external;

    /**
     * @notice Sets the trusted forwarder for meta-transactions.
     * @param _trustedForwarder The trusted forwarder address.
     */
    function setTrustedForwarder(address _trustedForwarder) external;

    // ============ Token Credit Allowance Functions ============

    /**
     * @notice Sets the remaining manual token credit allowance for a creditor.
     * @param creditor The TOKEN_CREDIT_ROLE actor whose allowance is being configured.
     * @param allowance The allowance amount that will remain after the call.
     */
    function setTokenCreditAllowance(address creditor, uint256 allowance) external;

    /**
     * @notice Batch-updates manual token credit allowances.
     * @param creditors Array of TOKEN_CREDIT_ROLE actors.
     * @param allowances Array of allowance amounts mapped 1:1 to `creditors`.
     */
    function batchSetTokenCreditAllowances(address[] calldata creditors, uint256[] calldata allowances) external;

    /**
     * @notice Returns the remaining manual token credit allowance for a creditor.
     * @param creditor The TOKEN_CREDIT_ROLE actor to query.
     * @return uint256 Remaining allowance value.
     */
    function getTokenCreditAllowance(address creditor) external view returns (uint256);

    // ============ Access Control Functions ============

    /**
     * @notice Checks if an account has a role.
     * @param role The role to check.
     * @param account The account to check.
     * @return bool True if the account has the role.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @notice Gets the admin role for a given role.
     * @param role The role to query.
     * @return bytes32 The admin role.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @notice Grants a role to an account.
     * @param role The role to grant.
     * @param account The account to grant the role to.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @notice Revokes a role from an account.
     * @param role The role to revoke.
     * @param account The account to revoke the role from.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @notice Renounces a role from the caller.
     * @param role The role to renounce.
     * @param callerConfirmation Confirmation of the caller.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // ============ View Functions ============

    /**
     * @notice Gets the initial EIP712 domain information.
     * @return EIP712Info The EIP712 domain information.
     */
    function getInitialEIP712Info() external view returns (EIP712Info memory);

    /**
     * @notice Gets the global state of the network.
     * @return GlobalState The global network state.
     */
    function getGlobalState() external view returns (GlobalState memory);

    /**
     * @notice Gets the global configuration.
     * @return GlobalConfiguration The global configuration.
     */
    function getGlobalConfig() external view returns (GlobalConfiguration memory);

    /**
     * @notice Gets the purchase configuration.
     * @return PurchaseConfiguration The purchase configuration.
     */
    function getPurchaseConfig() external view returns (PurchaseConfiguration memory);

    /**
     * @notice Gets the claim configuration.
     * @return ClaimConfiguration The claim configuration.
     */
    function getClaimConfig() external view returns (ClaimConfiguration memory);

    /**
     * @notice Gets the claim status.
     * @return ClaimStatus The claim status.
     */
    function getClaimStatus() external view returns (ClaimStatus memory);

    /**
     * @notice Gets the referral reward configuration.
     * @return RefRewardConfig The referral reward configuration.
     */
    function getRefRewardConfig() external view returns (RefRewardConfig memory);

    /**
     * @notice Gets the referral multiplier configuration.
     * @return RefMultiplierConfig The referral multiplier configuration.
     */
    function getRefMultiplierConfig() external view returns (RefMultiplierConfig memory);

    /**
     * @notice Checks if the contract is paused.
     * @return bool True if paused.
     */
    function isForeverPaused() external view returns (bool);

    /**
     * @notice Checks if a function is locked.
     * @param _functionSelector The function selector to check.
     * @return bool True if locked.
     */
    function isFunctionLocked(bytes4 _functionSelector) external view returns (bool);

    /**
     * @notice Gets the FNT token address.
     * @return address The FNT token address.
     */
    function getFNTAddress() external view returns (address);

    /**
     * @notice Gets the trusted forwarder address.
     * @return address The trusted forwarder address.
     */
    function getTrustedForwarder() external view returns (address);

    /**
     * @notice Gets the treasury address.
     * @return address The treasury address.
     */
    function getTreasuryAddress() external view returns (address);

    /**
     * @notice Gets the DAO timelock address.
     * @return address The DAO timelock address.
     */
    function getDaoTimelockAddress() external view returns (address);

    /**
     * @notice Checks if governance has transitioned.
     * @return bool True if transitioned.
     */
    function isGovernanceTransitioned() external view returns (bool);
}
