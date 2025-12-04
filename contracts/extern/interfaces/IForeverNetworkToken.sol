// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {FeeTier} from "../shared/Structs.sol";

/**
 * @title IForeverNetworkToken
 * @dev Interface for the core FNT token, defining its economic and governance functions.
 */
interface IForeverNetworkToken is IERC20, IERC20Permit {
    // --- Events ---
    event MintFeeConfigUpdated(FeeTier[] newTiers);
    event BurnFeeConfigUpdated(FeeTier[] newTiers);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event DaoTimelockUpdated(address indexed newDaoTimelock);
    event GovernanceTransitioned(address indexed from, address indexed to);
    event TokensMinted(address indexed to, uint256 amount, uint256 endowment);
    event TokensBurned(address indexed from, uint256 amount, uint256 oblation);
    event BlacklistUpdated(address indexed account, bool status);
    event EmergencyMintPauseUpdated(bool paused);
    event EmergencyBurnPauseUpdated(bool paused);

    error ZeroAddress();
    error ZeroAmount();
    error Blacklisted(address account);
    error MintEmergencyPaused();
    error BurnEmergencyPaused();
    error ExceedsCap(uint256 attempted, uint256 cap);
    error InsufficientBalance(address account, uint256 balance, uint256 required);
    error AmountTooSmall();
    error ThresholdNotMet(uint256 current, uint256 required);
    error DaoTimelockNotSet();
    error CannotBlacklistAddress(address account);
    error CannotWithdrawSelf();
    error TransferFailed();
    error NotAuthorized();
    error GovernanceAlreadyTransitioned();

    // --- Core Functions ---
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 value) external;

    // --- Admin & Governance Functions ---
    function updateMintFeeConfig(FeeTier[] calldata newTiers) external;
    function updateBurnFeeConfig(FeeTier[] calldata newTiers) external;
    function updateTreasury(address newTreasury) external;
    function updateDaoTimelock(address newDaoTimelock) external;
    function blacklistAddress(address account, bool status) external;
    function transitionGovernance() external;
    function paused() external view returns (bool);
    function pause() external;
    function unpause() external;
    function setEmergencyMintPause(bool _paused) external;
    function setEmergencyBurnPause(bool _paused) external;

    // --- View Functions ---
    function isBlacklisted(address account) external view returns (bool);
    function governanceTransitioned() external view returns (bool);
    function getMintFeeConfig() external view returns (FeeTier[] memory);
    function getBurnFeeConfig() external view returns (FeeTier[] memory);
    function mintCounter() external view returns (uint256);
    function burnCounter() external view returns (uint256);
    function getMintFee(uint256 mintCount, uint256 amount) external view returns (uint256);
    function getBurnFee(uint256 burnCount, uint256 amount) external view returns (uint256);
    function isGovernanceTransitioned() external view returns (bool);
    function daoTimelockAddress() external view returns (address);

    // --- Recovery Functions ---
    function withdrawForeignToken(address tokenContract, address to, uint256 amount) external;
    function withdrawNativeToken(address to, uint256 amount) external;
}
