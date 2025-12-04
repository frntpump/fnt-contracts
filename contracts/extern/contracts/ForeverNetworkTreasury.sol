// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IForeverNetworkTreasury} from "../interfaces/IForeverNetworkTreasury.sol";

/// @title ForeverNetworkTreasury - gas-optimized multi-asset treasury
/// @notice Multi-owner treasury with granular allocations, signed claims, vesting, and permit flows.
/// @dev Relies on composite keys for storage packing.
contract ForeverNetworkTreasury is
    IForeverNetworkTreasury,
    AccessControl,
    ReentrancyGuard,
    IERC721Receiver,
    IERC1155Receiver
{
    using SafeERC20 for IERC20;

    /// @dev Compact periodic allocation descriptor.
    struct PeriodicAllocation {
        uint128 amount;
        uint32 interval;
        bool enabled;
    }

    /// @dev ERC20 vesting schedule.
    struct Vesting {
        address token;
        address beneficiary;
        uint256 totalAmount;
        uint256 released;
        uint32 start;
        uint32 cliff;
        uint32 duration;
        bool revocable;
        bool revoked;
    }

    /// @dev Roles used for access control operations.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant FUNDS_WITHDRAWER_ROLE = keccak256("FUNDS_WITHDRAWER_ROLE");

    /// @dev Bit masks for packed one-time allocations.
    uint256 private constant ONE_TIME_CLAIMED_FLAG = uint256(1) << 255;
    uint256 private constant ONE_TIME_AMOUNT_MASK = ONE_TIME_CLAIMED_FLAG - 1;

    /// @dev EIP-712 domain separator and claim type hash.
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant CLAIM_TYPEHASH = keccak256(
        "Claim(uint8 assetType,address token,uint256 tokenId,uint256 amount,uint256 nonce,uint256 expiry,address recipient)"
    );

    /// @dev Storage for packed one-time allocations keyed by account + asset key.
    mapping(bytes32 => uint256) private _oneTimePacked;

    /// @dev Storage for role-based periodic allocations keyed by role + asset key.
    mapping(bytes32 => PeriodicAllocation) public rolePeriodic;

    /// @dev Storage for account-based periodic allocations keyed by account + asset key.
    mapping(bytes32 => PeriodicAllocation) public addressPeriodic;

    /// @dev Last claim timestamps for role-based allocations keyed by role + asset + account.
    mapping(bytes32 => uint32) private _roleLastClaim;

    /// @dev Last claim timestamps for account-based allocations keyed by account + asset.
    mapping(bytes32 => uint32) private _addressLastClaim;

    /// @dev ERC20 vesting schedules and beneficiary index.
    uint256 public vestingCount;
    mapping(uint256 => Vesting) public vestings;
    mapping(address => uint256[]) internal _beneficiaryVestings;

    /// @dev Replay protection for manager signatures.
    mapping(address => uint256) public nonces;

    /// @notice Initializes roles and computes the EIP-712 domain separator.
    /// @param admins Accounts that receive DEFAULT_ADMIN_ROLE.
    /// @param managers Accounts that receive MANAGER_ROLE.
    /// @param withdrawers Accounts that receive FUNDS_WITHDRAWER_ROLE.
    constructor(address[] memory admins, address[] memory managers, address[] memory withdrawers) {
        if (admins.length == 0) revert NeedAdmin();
        for (uint256 i = 0; i < admins.length; ++i) {
            _grantRole(DEFAULT_ADMIN_ROLE, admins[i]);
        }
        for (uint256 i = 0; i < managers.length; ++i) {
            _grantRole(MANAGER_ROLE, managers[i]);
        }
        for (uint256 i = 0; i < withdrawers.length; ++i) {
            _grantRole(FUNDS_WITHDRAWER_ROLE, withdrawers[i]);
        }

        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ForeverTreasury")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /// @notice Builds the canonical asset key for a given asset descriptor.
    /// @param assetType Asset type (NATIVE, ERC20, ERC721, ERC1155).
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId Token identifier for NFTs (ignored for NATIVE/ERC20).
    /// @return Hash key used across allocation mappings.
    function assetKey(AssetType assetType, address token, uint256 tokenId)
        public
        pure
        override(IForeverNetworkTreasury)
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(hex"01", uint8(assetType), token, tokenId));
    }

    /// @notice Internal helper to build role+asset composite keys.
    /// @param role Role identifier hashed via keccak256.
    /// @param aKey Asset key returned from {assetKey}.
    /// @return Composite key for rolePeriodic mapping.
    function _roleAssetKey(bytes32 role, bytes32 aKey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"10", role, aKey));
    }

    /// @notice Internal helper to build role+asset+account claim keys.
    /// @param role Role identifier hashed via keccak256.
    /// @param aKey Asset key returned from {assetKey}.
    /// @param account Account that claims the allocation.
    /// @return Composite key for _roleLastClaim mapping.
    function _roleAccountClaimKey(bytes32 role, bytes32 aKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"11", role, aKey, account));
    }

    /// @notice Internal helper to build account+asset composite keys for periodic allocations.
    /// @param account Beneficiary account.
    /// @param aKey Asset key returned from {assetKey}.
    /// @return Composite key for addressPeriodic mapping.
    function _addressAssetKey(address account, bytes32 aKey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"20", account, aKey));
    }

    /// @notice Internal helper to build account+asset claim keys.
    /// @param account Beneficiary account.
    /// @param aKey Asset key returned from {assetKey}.
    /// @return Composite key for _addressLastClaim mapping.
    function _addressClaimKey(address account, bytes32 aKey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"21", account, aKey));
    }

    /// @notice Internal helper to build account+asset keys for one-time allocations.
    /// @param account Beneficiary account.
    /// @param aKey Asset key returned from {assetKey}.
    /// @return Composite key for _oneTimePacked mapping.
    function _oneTimeKey(address account, bytes32 aKey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"30", account, aKey));
    }

    /// @notice Accepts direct NATIVE transfers and emits an accounting event.
    receive() external payable {
        emit ReceivedNATIVE(msg.sender, msg.value);
    }

    /// @notice Accepts fallback NATIVE transfers and emits an accounting event when value is present.
    fallback() external payable {
        if (msg.value > 0) {
            emit ReceivedNATIVE(msg.sender, msg.value);
        }
    }

    /// @notice ERC721 receiver hook to satisfy safe transfer checks.
    /// @param operator Address that initiated the transfer.
    /// @param from Address that owned the NFT.
    /// @param tokenId Identifier of the received token.
    /// @param data Additional call data (unused).
    /// @return Selector required by ERC721.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        override(IForeverNetworkTreasury, IERC721Receiver)
        returns (bytes4)
    {
        operator; // silence unused warning
        data;
        emit ERC721ReceivedEvent(from, msg.sender, tokenId);
        return this.onERC721Received.selector;
    }

    /// @notice ERC1155 single token receiver hook.
    /// @param operator Address that initiated the transfer.
    /// @param from Address that owned the token.
    /// @param id Token identifier.
    /// @param value Token amount.
    /// @param data Additional call data (unused).
    /// @return Selector required by ERC1155.
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        override(IForeverNetworkTreasury, IERC1155Receiver)
        returns (bytes4)
    {
        operator;
        data;
        emit ERC1155ReceivedEvent(from, msg.sender, id, value);
        return this.onERC1155Received.selector;
    }

    /// @notice ERC1155 batch receiver hook.
    /// @param operator Address that initiated the transfer.
    /// @param from Address that owned the tokens.
    /// @param ids Token identifiers.
    /// @param values Token amounts.
    /// @param data Additional call data (unused).
    /// @return Selector required by ERC1155 batch transfer.
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override(IForeverNetworkTreasury, IERC1155Receiver) returns (bytes4) {
        operator;
        data;
        for (uint256 i = 0; i < ids.length; ++i) {
            emit ERC1155ReceivedEvent(from, msg.sender, ids[i], values[i]);
        }
        return this.onERC1155BatchReceived.selector;
    }

    /// @notice Reports supported interfaces (AccessControl + receiver interfaces).
    /// @param interfaceId Interface identifier queried by callers.
    /// @return True when interfaceId is supported.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IForeverNetworkTreasury, AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IForeverNetworkTreasury).interfaceId
            || interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Sets or updates a role-based periodic allocation.
    /// @param role Role identifier receiving the allocation.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @param amount Amount released per interval.
    /// @param interval Cooldown between claims.
    /// @param enabled Flag to enable or disable the allocation.
    function setRolePeriodicAllocation(
        bytes32 role,
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint128 amount,
        uint32 interval,
        bool enabled
    ) external override(IForeverNetworkTreasury) onlyRole(MANAGER_ROLE) {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 key = _roleAssetKey(role, aKey);
        rolePeriodic[key] = PeriodicAllocation({amount: amount, interval: interval, enabled: enabled});
        emit RolePeriodicAllocationSet(role, aKey, amount, interval, enabled);
    }

    /// @notice Sets or updates an account-based periodic allocation.
    /// @param account Beneficiary account.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-Native assets.
    /// @param tokenId NFT identifier when applicable.
    /// @param amount Amount released per interval.
    /// @param interval Cooldown between claims.
    /// @param enabled Flag to enable or disable the allocation.
    function setAddressPeriodicAllocation(
        address account,
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint128 amount,
        uint32 interval,
        bool enabled
    ) external onlyRole(MANAGER_ROLE) {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 key = _addressAssetKey(account, aKey);
        addressPeriodic[key] = PeriodicAllocation({amount: amount, interval: interval, enabled: enabled});
        emit AddressPeriodicAllocationSet(account, aKey, amount, interval, enabled);
    }

    /// @notice Sets an account-based one-time allocation.
    /// @param account Beneficiary account.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @param amount Amount made claimable (must fit in 255 bits).
    function setAddressOneTimeAllocation(
        address account,
        AssetType assetType,
        address token,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        if (amount > ONE_TIME_AMOUNT_MASK) revert AmountTooLarge();
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 key = _oneTimeKey(account, aKey);
        _oneTimePacked[key] = amount;
        emit AddressOneTimeAllocationSet(account, aKey, amount);
    }

    /// @notice Claims a role-based periodic allocation for the caller.
    /// @param role Role being claimed.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    function claimRolePeriodicForRole(bytes32 role, AssetType assetType, address token, uint256 tokenId)
        external
        nonReentrant
        onlyRole(role)
    {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 key = _roleAssetKey(role, aKey);
        PeriodicAllocation memory alloc = rolePeriodic[key];
        if (!(alloc.enabled && alloc.amount > 0 && alloc.interval > 0)) revert NoAllocation();

        bytes32 claimK = _roleAccountClaimKey(role, aKey, msg.sender);
        uint32 last = _roleLastClaim[claimK];
        uint32 now32 = _now32();
        if (now32 < last + alloc.interval) revert NotYet();

        _roleLastClaim[claimK] = now32;
        _dispatchAsset(msg.sender, assetType, token, tokenId, uint256(alloc.amount));
        emit RolePeriodicClaim(msg.sender, role, aKey, alloc.amount);
    }

    /// @notice Claims an account-based periodic allocation for the caller.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    function claimAddressPeriodic(AssetType assetType, address token, uint256 tokenId) external nonReentrant {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 key = _addressAssetKey(msg.sender, aKey);
        PeriodicAllocation memory alloc = addressPeriodic[key];
        if (!(alloc.enabled && alloc.amount > 0 && alloc.interval > 0)) revert NoAllocation();

        bytes32 claimK = _addressClaimKey(msg.sender, aKey);
        uint32 last = _addressLastClaim[claimK];
        uint32 now32 = _now32();
        if (now32 < last + alloc.interval) revert NotYet();

        _addressLastClaim[claimK] = now32;
        _dispatchAsset(msg.sender, assetType, token, tokenId, uint256(alloc.amount));
        emit AddressPeriodicClaim(msg.sender, aKey, alloc.amount);
    }

    /// @notice Claims an account-based one-time allocation for the caller.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    function claimAddressOneTime(AssetType assetType, address token, uint256 tokenId) external nonReentrant {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 key = _oneTimeKey(msg.sender, aKey);
        uint256 packed = _oneTimePacked[key];
        if (packed == 0) revert NoAllocation();
        if ((packed & ONE_TIME_CLAIMED_FLAG) != 0) revert AlreadyClaimed();

        uint256 amount = packed & ONE_TIME_AMOUNT_MASK;
        _oneTimePacked[key] = packed | ONE_TIME_CLAIMED_FLAG;

        _dispatchAsset(msg.sender, assetType, token, tokenId, amount);
        emit AddressOneTimeClaim(msg.sender, aKey, amount);
    }

    /// @notice Executes a manager-approved claim via EIP-712 signature.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @param amount Amount authorized in the signature.
    /// @param nonce Expected manager nonce.
    /// @param expiry Expiration timestamp (0 for none).
    /// @param v Signature V value.
    /// @param r Signature R value.
    /// @param s Signature S value.
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
    ) external payable nonReentrant {
        address recipient = msg.sender;
        bytes32 aKey = assetKey(assetType, token, tokenId);

        bytes32 structHash =
            keccak256(abi.encode(CLAIM_TYPEHASH, uint8(assetType), token, tokenId, amount, nonce, expiry, recipient));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0) || !hasRole(MANAGER_ROLE, signer)) revert BadSignatureOrAuthority();
        if (expiry != 0 && block.timestamp > expiry) revert Expired();

        if (nonces[signer] != nonce) revert BadNonce();
        unchecked {
            nonces[signer] = nonce + 1;
        }

        _dispatchAsset(recipient, assetType, token, tokenId, uint256(amount));
        emit ClaimedBySignature(recipient, signer, aKey, amount);
    }

    /// @notice Pulls ERC20 tokens via EIP-2612 permit before transferring them into the treasury.
    /// @param token ERC20 token supporting permits.
    /// @param owner Address granting approval.
    /// @param amount Amount approved and transferred.
    /// @param deadline Permit deadline timestamp.
    /// @param v Signature V value.
    /// @param r Signature R value.
    /// @param s Signature S value.
    function permitAndPull(
        address token,
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        if (token == address(0) || owner == address(0)) revert ZeroArg();
        IERC20Permit(token).permit(owner, address(this), amount, deadline, v, r, s);
        IERC20(token).safeTransferFrom(owner, address(this), amount);
        emit ERC20Received(owner, token, amount);
    }

    /// @notice Creates an ERC20 vesting schedule for a beneficiary.
    /// @param token ERC20 token address.
    /// @param beneficiary Recipient of vested tokens.
    /// @param totalAmount Total amount locked into the vesting schedule.
    /// @param start Vesting start timestamp.
    /// @param cliffOffset Offset from start until cliff.
    /// @param duration Total vesting duration.
    /// @param revocable Whether DEFAULT_ADMIN_ROLE can revoke the schedule.
    /// @return vestingId Identifier of the created vesting schedule.
    function createVesting(
        address token,
        address beneficiary,
        uint256 totalAmount,
        uint32 start,
        uint32 cliffOffset,
        uint32 duration,
        bool revocable
    ) external onlyRole(MANAGER_ROLE) returns (uint256 vestingId) {
        if (token == address(0) || beneficiary == address(0)) revert ZeroAddress();
        if (totalAmount == 0 || duration < cliffOffset) revert BadParams();

        vestingId = ++vestingCount;
        uint32 cliff = start + cliffOffset;
        vestings[vestingId] = Vesting({
            token: token,
            beneficiary: beneficiary,
            totalAmount: totalAmount,
            released: 0,
            start: start,
            cliff: cliff,
            duration: duration,
            revocable: revocable,
            revoked: false
        });
        _beneficiaryVestings[beneficiary].push(vestingId);
        emit VestingCreated(vestingId, token, beneficiary, totalAmount, start, cliff, duration, revocable);
    }

    /// @notice Releases vested tokens for a given vesting schedule.
    /// @param vestingId Identifier of the vesting schedule.
    function releaseVested(uint256 vestingId) external nonReentrant {
        Vesting storage v = vestings[vestingId];
        if (v.beneficiary == address(0)) revert InvalidVesting();
        if (v.revoked) revert Revoked();

        uint256 vested = _vestedAmount(v);
        uint256 unreleased = vested - v.released;
        if (unreleased == 0) revert NothingToRelease();

        v.released += unreleased;
        IERC20(v.token).safeTransfer(v.beneficiary, unreleased);
        emit VestingReleased(vestingId, v.beneficiary, unreleased);
    }

    /// @notice Revokes a revocable vesting schedule and returns unvested funds to `to`.
    /// @param vestingId Identifier of the vesting schedule.
    /// @param to Recipient of the refunded (unvested) tokens.
    function revokeVesting(uint256 vestingId, address to) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        Vesting storage v = vestings[vestingId];
        if (!v.revocable || v.revoked) revert NotRevocable();
        if (to == address(0)) revert BadRecipient();

        uint256 vested = _vestedAmount(v);
        uint256 unreleased = vested - v.released;
        uint256 refund = v.totalAmount - vested;
        v.revoked = true;

        if (unreleased > 0) {
            v.released += unreleased;
            IERC20(v.token).safeTransfer(v.beneficiary, unreleased);
            emit VestingReleased(vestingId, v.beneficiary, unreleased);
        }
        if (refund > 0) {
            IERC20(v.token).safeTransfer(to, refund);
        }
        emit VestingRevoked(vestingId, msg.sender, refund);
    }

    /// @notice Returns the list of vesting IDs for a beneficiary.
    /// @param beneficiary Account to query.
    /// @return Array of vesting identifiers.
    function beneficiaryVestings(address beneficiary) external view returns (uint256[] memory) {
        return _beneficiaryVestings[beneficiary];
    }

    /// @notice Returns the next claim timestamp for role-based allocations.
    /// @param role Role identifier.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @param account Account that would claim.
    /// @return Timestamp when the allocation becomes claimable (max uint256 if disabled).
    function nextRoleClaimAvailable(bytes32 role, AssetType assetType, address token, uint256 tokenId, address account)
        external
        view
        returns (uint256)
    {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 pK = _roleAssetKey(role, aKey);
        PeriodicAllocation memory alloc = rolePeriodic[pK];
        if (!alloc.enabled || alloc.interval == 0) {
            return type(uint256).max;
        }
        bytes32 claimK = _roleAccountClaimKey(role, aKey, account);
        return uint256(_roleLastClaim[claimK]) + alloc.interval;
    }

    /// @notice Returns the next claim timestamp for account-based allocations.
    /// @param account Beneficiary account.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @return Timestamp when the allocation becomes claimable (max uint256 if disabled).
    function nextAddressClaimAvailable(address account, AssetType assetType, address token, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 pK = _addressAssetKey(account, aKey);
        PeriodicAllocation memory alloc = addressPeriodic[pK];
        if (!alloc.enabled || alloc.interval == 0) {
            return type(uint256).max;
        }
        bytes32 claimK = _addressClaimKey(account, aKey);
        return uint256(_addressLastClaim[claimK]) + alloc.interval;
    }

    /// @notice Reads an account-based one-time allocation.
    /// @param account Beneficiary account.
    /// @param assetType Asset type distributed.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @return amount Amount allocated.
    /// @return claimed Whether the allocation has been claimed.
    function readOneTime(address account, AssetType assetType, address token, uint256 tokenId)
        external
        view
        returns (uint256 amount, bool claimed)
    {
        bytes32 aKey = assetKey(assetType, token, tokenId);
        bytes32 k = _oneTimeKey(account, aKey);
        uint256 packed = _oneTimePacked[k];
        if (packed == 0) {
            return (0, false);
        }
        claimed = (packed & ONE_TIME_CLAIMED_FLAG) != 0;
        amount = packed & ONE_TIME_AMOUNT_MASK;
    }

    /// @notice Withdraw any asset type.
    /// @param assetType Asset type being withdrawn.
    /// @param token Token address for non-NATIVE assets.
    /// @param tokenId NFT identifier when applicable.
    /// @param amount Amount to withdraw (ignored for ERC721 where it transfers tokenId).
    /// @param to Recipient of the withdrawn assets.
    function emergencyWithdraw(AssetType assetType, address token, uint256 tokenId, uint256 amount, address to)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (to == address(0)) revert BadRecipient();
        _dispatchAsset(to, assetType, token, tokenId, amount);
        emit EmergencyWithdrawal(msg.sender, assetType, token, tokenId, amount, to);
    }

    /// @notice Pulls ERC20 tokens from a third party using standard allowance flow.
    /// @param from Address providing the allowance.
    /// @param token ERC20 token address.
    /// @param amount Amount to transfer into the treasury.
    function pullERC20From(address from, address token, uint256 amount)
        external
        nonReentrant
        onlyRole(FUNDS_WITHDRAWER_ROLE)
    {
        if (token == address(0)) revert ZeroToken();
        IERC20(token).safeTransferFrom(from, address(this), amount);
        emit ERC20Received(from, token, amount);
    }

    /// @notice Grants MANAGER_ROLE to an account.
    /// @param account Account receiving the role.
    function grantManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MANAGER_ROLE, account);
    }

    /// @notice Revokes MANAGER_ROLE from an account.
    /// @param account Account losing the role.
    function revokeManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANAGER_ROLE, account);
    }

    /// @notice Grants FUNDS_WITHDRAWER_ROLE to an account.
    /// @param account Account receiving the role.
    function grantWithdrawer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(FUNDS_WITHDRAWER_ROLE, account);
    }

    /// @notice Revokes FUNDS_WITHDRAWER_ROLE from an account.
    /// @param account Account losing the role.
    function revokeWithdrawer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(FUNDS_WITHDRAWER_ROLE, account);
    }

    /// @notice Returns the current timestamp as uint32, ensuring it fits vesting/claim storage.
    /// @return now32 Current timestamp truncated to uint32.
    function _now32() internal view returns (uint32 now32) {
        if (block.timestamp > type(uint32).max) revert TimestampOverflow();
        now32 = uint32(block.timestamp);
    }

    /// @notice Dispatches assets to a recipient based on the provided asset type descriptor.
    /// @param to Recipient of the assets.
    /// @param assetType Asset type (NATIVE, ERC20, ERC721, ERC1155).
    /// @param token Token contract address when applicable.
    /// @param tokenId NFT identifier for ERC721/1155 transfers.
    /// @param amount Amount being transferred.
    function _dispatchAsset(address to, AssetType assetType, address token, uint256 tokenId, uint256 amount) internal {
        if (assetType == AssetType.NATIVE) {
            if (address(this).balance < amount) revert InsufficientNative();
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert NativeSendFailed();
            return;
        }

        if (assetType == AssetType.ERC20) {
            if (token == address(0)) revert TokenZero();
            IERC20(token).safeTransfer(to, amount);
            return;
        }

        if (assetType == AssetType.ERC721) {
            if (token == address(0)) revert TokenZero();
            IERC721(token).safeTransferFrom(address(this), to, tokenId);
            return;
        }

        if (token == address(0)) revert TokenZero();
        IERC1155(token).safeTransferFrom(address(this), to, tokenId, amount, "");
    }

    /// @notice Computes the vested amount for a given schedule.
    /// @param v Vesting schedule memory snapshot.
    /// @return Amount vested so far.
    function _vestedAmount(Vesting memory v) internal view returns (uint256) {
        uint256 t = block.timestamp;
        if (t < v.cliff) {
            return 0;
        }
        if (t >= uint256(v.start) + uint256(v.duration) || v.revoked) {
            return v.totalAmount;
        }
        uint256 elapsed = t - uint256(v.start);
        return (v.totalAmount * elapsed) / uint256(v.duration);
    }
}
