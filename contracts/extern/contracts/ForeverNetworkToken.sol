// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20CappedUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IForeverNetworkToken} from "../interfaces/IForeverNetworkToken.sol";
import {LibFees} from "../libs/LibFees.sol";
import {FeeTier, FeeConfig} from "../shared/Structs.sol";

/**
 * @title ForeverNetworkToken
 * @notice The core FNT token with integrated tiered fee mechanics and governance
 * @dev Upgradeable ERC20 with voting, capped supply, and dynamic tier-based fees
 */
contract ForeverNetworkToken is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20CappedUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard,
    IForeverNetworkToken
{
    using LibFees for FeeConfig;
    using SafeERC20 for IERC20;

    // ============ Constants ============
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    uint256 public constant MAX_SUPPLY = 10_000_000_000 ether; // 10 billion tokens
    uint256 public constant GOVERNANCE_TRANSITION_THRESHOLD = 10_000; // Mint count threshold

    // ============ State Variables ============
    address public treasuryAddress;
    address public daoTimelockAddress;
    address public initialAdmin;

    uint256 public mintCounter;
    uint256 public burnCounter;
    uint256 public totalEndowment;
    uint256 public totalOblation;

    bool public governanceTransitioned;
    mapping(address => bool) public blacklisted;

    // New tiered fee configurations
    FeeConfig private _mintFeeConfig;
    FeeConfig private _burnFeeConfig;

    // Emergency controls
    bool public emergencyMintPaused;
    bool public emergencyBurnPaused;

    uint256[50] private __gap; // Adjust for new storage variables

    // ============ Modifiers ============
    modifier onlyPreTransition() {
        if (governanceTransitioned) revert GovernanceAlreadyTransitioned();
        _;
    }

    modifier notBlacklisted(address account) {
        if (blacklisted[account]) revert Blacklisted(account);
        _;
    }

    modifier whenMintNotPaused() {
        if (emergencyMintPaused) revert MintEmergencyPaused();
        _;
    }

    modifier whenBurnNotPaused() {
        if (emergencyBurnPaused) revert BurnEmergencyPaused();
        _;
    }

    // ============ Initialization ============
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _treasury, address _daoTimelock, address _initialAdmin) public initializer {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_initialAdmin == address(0)) revert ZeroAddress();

        __ERC20_init("Forever Network Token", "FNT");
        __ERC20Capped_init(MAX_SUPPLY);
        __ERC20Votes_init();
        __ERC20Permit_init("Forever Network Token");
        __AccessControl_init();
        __Pausable_init();

        treasuryAddress = _treasury;
        daoTimelockAddress = _daoTimelock;
        initialAdmin = _initialAdmin;

        // Setup initial roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(MINTER_ROLE, _initialAdmin);
        _grantRole(GOVERNOR_ROLE, _initialAdmin);
        _grantRole(PAUSER_ROLE, _initialAdmin);
        _grantRole(FEE_MANAGER_ROLE, _initialAdmin);

        // Initialize with default tiered fee structures
        _initializeDefaultFees();
    }

    /**
     * @dev Initialize default fee tiers
     */
    function _initializeDefaultFees() private {
        // Default mint fee tiers
        _mintFeeConfig.tiers.push(FeeTier({threshold: 0, feeBps: 9000}));
        _mintFeeConfig.tiers.push(FeeTier({threshold: 700, feeBps: 6000}));
        _mintFeeConfig.tiers.push(FeeTier({threshold: 2000, feeBps: 5000}));
        _mintFeeConfig.tiers.push(FeeTier({threshold: 8000, feeBps: 2000}));

        // Default burn fee tiers
        _burnFeeConfig.tiers.push(FeeTier({threshold: 0, feeBps: 6000}));
        _burnFeeConfig.tiers.push(FeeTier({threshold: 700, feeBps: 5000}));
        _burnFeeConfig.tiers.push(FeeTier({threshold: 2000, feeBps: 4000}));
        _burnFeeConfig.tiers.push(FeeTier({threshold: 6000, feeBps: 3000}));
    }

    // ============ Core Functions ============

    /**
     * @notice Mint new tokens with automatic endowment calculation based on tier
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount)
        external
        override
        onlyRole(MINTER_ROLE)
        notBlacklisted(to)
        whenNotPaused
        whenMintNotPaused
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 currentSupply = totalSupply();
        uint256 capLimit = cap();
        uint256 newMintCounter;

        unchecked {
            newMintCounter = mintCounter + 1;
        }

        // Ensure base amount fits under cap
        if (currentSupply + amount > capLimit) {
            revert ExceedsCap(currentSupply + amount, capLimit);
        }

        // Compute endowment once; treasury is exempt from endowment minting
        uint256 endowment = (msg.sender != treasuryAddress) ? _mintFeeConfig.calculateFee(newMintCounter, amount) : 0;

        bool mintTreasury = (endowment > 0) && (currentSupply + amount + endowment <= capLimit);

        if (mintTreasury) {
            unchecked {
                totalEndowment += endowment;
            }
        }

        _mint(to, amount);

        if (mintTreasury) {
            _mint(treasuryAddress, endowment);
        }

        mintCounter = newMintCounter;

        emit TokensMinted(to, amount, mintTreasury ? endowment : 0);
    }

    /**
     * @notice Burn tokens minus oblation fee based on tier
     * @param amount Amount to burn
     */
    function burn(uint256 amount)
        public
        override(ERC20BurnableUpgradeable, IForeverNetworkToken)
        whenNotPaused
        whenBurnNotPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        uint256 bal = balanceOf(msg.sender);
        uint256 oblation;

        if (bal < amount) revert InsufficientBalance(msg.sender, bal, amount);

        // Increment burn counter
        uint256 newBurnCounter;

        unchecked {
            newBurnCounter = burnCounter + 1;
        }

        // Calculate oblation fee using current tier
        if (msg.sender != treasuryAddress) {
            oblation = _burnFeeConfig.calculateFee(newBurnCounter, amount);
        }

        if (amount <= oblation) revert AmountTooSmall();

        uint256 actualBurned = amount - oblation;

        unchecked {
            totalOblation += oblation;
        }

        // Process burn and fee
        _burn(msg.sender, actualBurned);
        if (oblation > 0) {
            _transfer(msg.sender, treasuryAddress, oblation);
        }

        burnCounter = newBurnCounter;

        emit TokensBurned(msg.sender, actualBurned, oblation);
    }

    /**
     * @notice Burn tokens from an account with allowance
     * @param account Account to burn from
     * @param value Amount to burn
     */
    function burnFrom(address account, uint256 value)
        public
        override(ERC20BurnableUpgradeable, IForeverNetworkToken)
        whenNotPaused
        whenBurnNotPaused
        nonReentrant
    {
        if (value == 0) revert ZeroAmount();
        uint256 bal = balanceOf(account);
        if (bal < value) revert InsufficientBalance(account, bal, value);

        uint256 newBurnCounter;

        unchecked {
            newBurnCounter = burnCounter + 1;
        }

        // Treasury exemption consistent with burn()
        uint256 oblation = (account == treasuryAddress) ? 0 : _burnFeeConfig.calculateFee(newBurnCounter, value);

        if (value <= oblation) revert AmountTooSmall();

        uint256 actualBurned = value - oblation;

        _spendAllowance(account, msg.sender, value);

        unchecked {
            totalOblation += oblation;
        }

        _burn(account, actualBurned);
        if (oblation > 0) {
            _transfer(account, treasuryAddress, oblation);
        }

        burnCounter = newBurnCounter;

        emit TokensBurned(account, actualBurned, oblation);
    }

    /**
     * @notice Transition governance from initial admin to DAO
     * @dev Can only be called once after threshold is met
     */
    function transitionGovernance() external override onlyPreTransition {
        if (mintCounter < GOVERNANCE_TRANSITION_THRESHOLD) {
            revert ThresholdNotMet(mintCounter, GOVERNANCE_TRANSITION_THRESHOLD);
        }
        if (daoTimelockAddress == address(0)) revert DaoTimelockNotSet();

        governanceTransitioned = true;

        // Revoke roles from initial admin
        _revokeRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _revokeRole(MINTER_ROLE, initialAdmin);
        _revokeRole(GOVERNOR_ROLE, initialAdmin);
        _revokeRole(PAUSER_ROLE, initialAdmin);
        _revokeRole(FEE_MANAGER_ROLE, initialAdmin);

        // Grant roles to DAO timelock
        _grantRole(DEFAULT_ADMIN_ROLE, daoTimelockAddress);
        _grantRole(MINTER_ROLE, daoTimelockAddress);
        _grantRole(GOVERNOR_ROLE, daoTimelockAddress);
        _grantRole(PAUSER_ROLE, daoTimelockAddress);
        _grantRole(FEE_MANAGER_ROLE, daoTimelockAddress);

        emit GovernanceTransitioned(initialAdmin, daoTimelockAddress);
    }

    // ============ Admin Functions ============

    function updateMintFeeConfig(FeeTier[] calldata newTiers) external override onlyRole(FEE_MANAGER_ROLE) {
        LibFees.validateFeeConfig(newTiers);

        delete _mintFeeConfig.tiers;

        for (uint256 i = 0; i < newTiers.length; i++) {
            _mintFeeConfig.tiers.push(newTiers[i]);
        }

        emit MintFeeConfigUpdated(newTiers);
    }

    function updateBurnFeeConfig(FeeTier[] calldata newTiers) external override onlyRole(FEE_MANAGER_ROLE) {
        LibFees.validateFeeConfig(newTiers);

        delete _burnFeeConfig.tiers;

        for (uint256 i = 0; i < newTiers.length; i++) {
            _burnFeeConfig.tiers.push(newTiers[i]);
        }

        emit BurnFeeConfigUpdated(newTiers);
    }

    function updateTreasury(address newTreasury) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasuryAddress;
        treasuryAddress = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function updateDaoTimelock(address newTimelock) external override onlyRole(DEFAULT_ADMIN_ROLE) onlyPreTransition {
        if (newTimelock == address(0)) revert ZeroAddress();
        daoTimelockAddress = newTimelock;
        emit DaoTimelockUpdated(newTimelock);
    }

    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external override onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Toggle the mint-specific emergency pause without affecting transfers.
     * @param _paused True pauses {mint}, false re-enables it.
     */
    function setEmergencyMintPause(bool _paused) external override(IForeverNetworkToken) onlyRole(PAUSER_ROLE) {
        emergencyMintPaused = _paused;
        emit EmergencyMintPauseUpdated(_paused);
    }

    /**
     * @notice Toggle the burn-specific emergency pause.
     * @param _paused True pauses {burn} and {burnFrom}, false re-enables them.
     */
    function setEmergencyBurnPause(bool _paused) external override(IForeverNetworkToken) onlyRole(PAUSER_ROLE) {
        emergencyBurnPaused = _paused;
        emit EmergencyBurnPauseUpdated(_paused);
    }

    /**
     * @notice Blacklist or un-blacklist an account, preventing transfers in either direction.
     * @param account Account whose transfer abilities are being toggled.
     * @param status True blacklists the account, false removes it from the blacklist.
     */
    function blacklistAddress(address account, bool status) external override onlyRole(GOVERNOR_ROLE) {
        if (account == address(0)) revert CannotBlacklistAddress(account);
        if (account == treasuryAddress) revert CannotBlacklistAddress(account);
        if (account == daoTimelockAddress) {
            revert CannotBlacklistAddress(account);
        }

        blacklisted[account] = status;
        emit BlacklistUpdated(account, status);
    }

    // ============ View Functions ============

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view override(IForeverNetworkToken, PausableUpgradeable) returns (bool) {
        return super.paused();
    }

    function isBlacklisted(address account) external view override returns (bool) {
        return blacklisted[account];
    }

    function isGovernanceTransitioned() external view override returns (bool) {
        return governanceTransitioned;
    }

    function getMintFeeConfig() external view override returns (FeeTier[] memory) {
        return _mintFeeConfig.tiers;
    }

    function getBurnFeeConfig() external view override returns (FeeTier[] memory) {
        return _burnFeeConfig.tiers;
    }

    function getMintFee(uint256 mintCount, uint256 amount) external view override returns (uint256) {
        return _mintFeeConfig.calculateFee(mintCount, amount);
    }

    function getBurnFee(uint256 burnCount, uint256 amount) external view override returns (uint256) {
        return _burnFeeConfig.calculateFee(burnCount, amount);
    }

    // ============ Internal Overrides ============

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20CappedUpgradeable, ERC20VotesUpgradeable)
        whenNotPaused
    {
        if (blacklisted[from]) revert Blacklisted(from);
        if (blacklisted[to]) revert Blacklisted(to);
        super._update(from, to, value);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, IERC20Permit, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // ============ Recovery Functions ============

    /**
     * @notice Rescue ERC20 tokens that were accidentally sent to this contract.
     * @param tokenContract Address of the ERC20 to withdraw.
     * @param to Recipient of the rescued tokens.
     * @param amount Exact amount to withdraw, or zero to sweep the full balance.
     */
    function withdrawForeignToken(address tokenContract, address to, uint256 amount)
        external
        override(IForeverNetworkToken)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (tokenContract == address(this)) revert CannotWithdrawSelf();
        if (to == address(0)) revert ZeroAddress();

        IERC20 token = IERC20(tokenContract);
        uint256 balance = token.balanceOf(address(this));
        uint256 transferAmount = (amount == 0 || amount > balance) ? balance : amount;

        if (transferAmount == 0) {
            revert InsufficientBalance(address(this), balance, transferAmount);
        }

        token.safeTransfer(to, transferAmount);
    }

    /**
     * @notice Rescue native chain currency (BNB on BSC) held by the contract.
     * @param to Recipient of the withdrawn funds.
     * @param amount Exact amount to withdraw, or zero to sweep the full balance.
     */
    function withdrawNativeToken(address to, uint256 amount)
        external
        override(IForeverNetworkToken)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (to == address(0)) revert ZeroAddress();

        uint256 balance = address(this).balance;
        uint256 transferAmount = (amount == 0 || amount > balance) ? balance : amount;

        if (transferAmount == 0) {
            revert InsufficientBalance(address(this), balance, transferAmount);
        }
        (bool success,) = payable(to).call{value: transferAmount}("");
        if (!success) revert TransferFailed();
    }

    receive() external payable {}
}
