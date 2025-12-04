// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IForeverNetworkTreasury - Interface for ForeverNetworkTreasury
/// @notice Defines the public interface for the multi-asset treasury contract.
interface IForeverNetworkTreasury {
    /// @dev Supported asset types.
    enum AssetType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }

    /// @dev Custom errors for revert conditions.
    error NeedAdmin();
    error AmountTooLarge();
    error NoAllocation();
    error NotYet();
    error AlreadyClaimed();
    error BadSignatureOrAuthority();
    error Expired();
    error BadNonce();
    error ZeroArg();
    error ZeroAddress();
    error BadParams();
    error InvalidVesting();
    error Revoked();
    error NothingToRelease();
    error NotRevocable();
    error BadRecipient();
    error ZeroToken();
    error TimestampOverflow();
    error TokenZero();
    error InsufficientNative();
    error NativeSendFailed();

    /// @dev Emitted when the treasury receives native NATIVE.
    event ReceivedNATIVE(address indexed from, uint256 amount);

    /// @dev Emitted when ERC20 tokens are deposited directly or via pull flows.
    event ERC20Received(address indexed from, address indexed token, uint256 amount);

    /// @dev Emitted when ERC721 tokens are transferred into the treasury.
    event ERC721ReceivedEvent(address indexed from, address indexed token, uint256 tokenId);

    /// @dev Emitted when ERC1155 tokens are transferred into the treasury.
    event ERC1155ReceivedEvent(address indexed from, address indexed token, uint256 tokenId, uint256 amount);

    /// @dev Emitted when role-based periodic allocations change.
    event RolePeriodicAllocationSet(
        bytes32 indexed role, bytes32 indexed assetKey, uint128 amount, uint32 interval, bool enabled
    );

    /// @dev Emitted when account-based periodic allocations change.
    event AddressPeriodicAllocationSet(
        address indexed account, bytes32 indexed assetKey, uint128 amount, uint32 interval, bool enabled
    );

    /// @dev Emitted when account-based one-time allocations change.
    event AddressOneTimeAllocationSet(address indexed account, bytes32 indexed assetKey, uint256 amount);

    /// @dev Emitted when a role-based periodic allocation is claimed.
    event RolePeriodicClaim(address indexed claimer, bytes32 indexed role, bytes32 indexed assetKey, uint128 amount);

    /// @dev Emitted when an account-based periodic allocation is claimed.
    event AddressPeriodicClaim(address indexed account, bytes32 indexed assetKey, uint128 amount);

    /// @dev Emitted when an account-based one-time allocation is claimed.
    event AddressOneTimeClaim(address indexed account, bytes32 indexed assetKey, uint256 amount);

    /// @dev Emitted when a signed claim is executed.
    event ClaimedBySignature(
        address indexed recipient, address indexed signer, bytes32 indexed assetKey, uint128 amount
    );

    /// @dev Emitted when a vesting schedule is created.
    event VestingCreated(
        uint256 indexed vestingId,
        address indexed token,
        address indexed beneficiary,
        uint256 totalAmount,
        uint32 start,
        uint32 cliff,
        uint32 duration,
        bool revocable
    );

    /// @dev Emitted when vested tokens are released.
    event VestingReleased(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);

    /// @dev Emitted when a vesting schedule is revoked.
    event VestingRevoked(uint256 indexed vestingId, address indexed admin, uint256 refunded);

    /// @dev Emitted when DEFAULT_ADMIN_ROLE performs an emergency withdrawal.
    event EmergencyWithdrawal(
        address indexed admin, AssetType assetType, address token, uint256 tokenId, uint256 amount, address to
    );

    /// @notice Builds the canonical asset key for a given asset descriptor.
    function assetKey(AssetType assetType, address token, uint256 tokenId) external pure returns (bytes32);

    /// @notice Accepts direct NATIVE transfers and emits an accounting event.
    receive() external payable;

    /// @notice Accepts fallback NATIVE transfers and emits an accounting event when value is present.
    fallback() external payable;

    /// @notice ERC721 receiver hook to satisfy safe transfer checks.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);

    /// @notice ERC1155 single token receiver hook.
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4);

    /// @notice ERC1155 batch receiver hook.
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);

    /// @notice Reports supported interfaces (AccessControl + receiver interfaces).
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /// @notice Sets or updates a role-based periodic allocation.
    function setRolePeriodicAllocation(
        bytes32 role,
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint128 amount,
        uint32 interval,
        bool enabled
    ) external;

    /// @notice Sets or updates an account-based periodic allocation.
    function setAddressPeriodicAllocation(
        address account,
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint128 amount,
        uint32 interval,
        bool enabled
    ) external;

    /// @notice Sets an account-based one-time allocation.
    function setAddressOneTimeAllocation(
        address account,
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint256 amount
    ) external;

    /// @notice Claims a role-based periodic allocation for the caller.
    function claimRolePeriodicForRole(bytes32 role, AssetType assetType, address token, uint256 tokenId) external;

    /// @notice Claims an account-based periodic allocation for the caller.
    function claimAddressPeriodic(AssetType assetType, address token, uint256 tokenId) external;

    /// @notice Claims an account-based one-time allocation for the caller.
    function claimAddressOneTime(AssetType assetType, address token, uint256 tokenId) external;

    /// @notice Executes a manager-approved claim via EIP-712 signature.
    function claimBySignature(
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint128 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /// @notice Pulls ERC20 tokens via EIP-2612 permit before transferring them into the treasury.
    function permitAndPull(
        address token,
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Creates an ERC20 vesting schedule for a beneficiary.
    function createVesting(
        address token,
        address beneficiary,
        uint256 totalAmount,
        uint32 start,
        uint32 cliffOffset,
        uint32 duration,
        bool revocable
    ) external returns (uint256 vestingId);

    /// @notice Releases vested tokens for a given vesting schedule.
    function releaseVested(uint256 vestingId) external;

    /// @notice Revokes a revocable vesting schedule and returns unvested funds to `to`.
    function revokeVesting(uint256 vestingId, address to) external;

    /// @notice Returns the list of vesting IDs for a beneficiary.
    function beneficiaryVestings(address beneficiary) external view returns (uint256[] memory);

    /// @notice Returns the next claim timestamp for role-based allocations.
    function nextRoleClaimAvailable(bytes32 role, AssetType assetType, address token, uint256 tokenId, address account)
        external
        view
        returns (uint256);

    /// @notice Returns the next claim timestamp for account-based allocations.
    function nextAddressClaimAvailable(address account, AssetType assetType, address token, uint256 tokenId)
        external
        view
        returns (uint256);

    /// @notice Reads an account-based one-time allocation.
    function readOneTime(address account, AssetType assetType, address token, uint256 tokenId)
        external
        view
        returns (uint256 amount, bool claimed);

    /// @notice Withdraw any asset type.
    function emergencyWithdraw(AssetType assetType, address token, uint256 tokenId, uint256 amount, address to) external;

    /// @notice Pulls ERC20 tokens from a third party using standard allowance flow.
    function pullERC20From(address from, address token, uint256 amount) external;

    /// @notice Grants MANAGER_ROLE to an account.
    function grantManager(address account) external;

    /// @notice Revokes MANAGER_ROLE from an account.
    function revokeManager(address account) external;

    /// @notice Grants FUNDS_WITHDRAWER_ROLE to an account.
    function grantWithdrawer(address account) external;

    /// @notice Revokes FUNDS_WITHDRAWER_ROLE from an account.
    function revokeWithdrawer(address account) external;
}
