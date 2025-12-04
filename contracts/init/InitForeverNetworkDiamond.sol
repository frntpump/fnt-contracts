// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibDiamond} from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";
import {AppStorage, LibAppStorage} from "../libs/LibAppStorage.sol";
import {LibSingleStaking} from "../libs/LibSingleStaking.sol";
import {LibConstants as LC} from "../libs/LibConstants.sol";
import {LibRoles} from "../libs/LibRoles.sol";
import {LibAdmin} from "../libs/LibAdmin.sol";
import {LibEIP712} from "../libs/LibEIP712.sol";
import {LibErrors} from "../libs/LibErrors.sol";
import {LibEvents} from "../libs/LibEvents.sol";
import {AccessControl} from "../shared/AccessControl.sol";
import {IAccessControl} from "../interfaces/IAccessControl.sol";
import {SingleStakingConfig, SingleStakingLockConfig, StakeTier} from "../shared/Structs.sol";

/**
 * @title InitForeverNetworkDiamond
 * @author Forever Network
 * @notice Contract to initialize the Diamond's state variables and supported interfaces.
 * @dev This contract is called once during the diamond's deployment to set up initial state.
 */
contract InitForeverNetworkDiamond is AccessControl {
    /**
     * @notice Bootstraps the diamond by initializing all state variables and supported interfaces.
     * @dev This function should be called exactly once during diamond deployment. It sets up:
     * - Diamond initialization flag to prevent re-initialization
     * - Global pause state (initially paused)
     * - EIP712 domain information for meta-transactions
     * - Default configurations for global, purchase, claim, and referral systems
     * - Single staking configurations
     * - Supported interface registration for IAccessControl
     * Emits an {InitializeDiamond} event on success.
     * Reverts with {DiamondAlreadyInitialized} if already initialized.
     */
    function bootstrap() external {
        AppStorage storage ds = LibAppStorage.diamondStorage();

        if (ds.diamondInitialized) {
            revert LibErrors.DiamondAlreadyInitialized();
        }
        ds.diamondInitialized = true;
        ds.globalState.paused = true;

        ds.eip712Info.name = "forever.network.diamond";
        ds.eip712Info.initialChainId = block.chainid;
        ds.eip712Info.initialDomainSeparator = LibEIP712._computeDomainSeparator();

        ds.globalConfig = LibAdmin.defaultGlobalConfiguration();
        ds.purchaseConfig = LibAdmin.defaultPurchaseConfiguration();
        ds.claimConfig = LibAdmin.defaultClaimConfiguration();
        ds.refRewardConfig = LibAdmin.defaultRefRewardConfig();
        ds.refMultiplierConfig = LibAdmin.defaultRefMultiplierConfig();

        _seedSingleStaking(ds);

        LibRoles._grantRole(LC.DEFAULT_ADMIN_ROLE, _msgSender());
        LibRoles._grantRole(LC.PRIME_SPONSOR_ROLE, _msgSender());
        LibRoles._grantRole(LC.GLOBAL_PAUSER_ROLE, _msgSender());

        LibDiamond.DiamondStorage storage _ds = LibDiamond.diamondStorage();
        _ds.supportedInterfaces[type(IAccessControl).interfaceId] = true;
        emit LibEvents.InitializeDiamond(_msgSender());
    }

    /**
     * @notice Initializes the single-token staking module with default configurations.
     * @dev Sets up:
     * - Global staking configuration with enabled status, auto-compound bonus, penalties, minimum stake, and fees
     * - Seven lock configurations with varying durations (7, 14, 30, 45, 60, 90 days) and APRs
     * - Seven tier configurations (None, Bronze, Silver, Gold, Platinum, Diamond, Mythril) with referral requirements and bonus APRs
     * All configurations are set to enabled by default.
     * Initial fees are set to 0 and can be updated by the admin.
     * @param ds Storage pointer to the AppStorage struct.
     */
    function _seedSingleStaking(AppStorage storage ds) private {
        ds.singleStaking.config = SingleStakingConfig({
            enabled: true,
            autoCompoundBonusBps: 3_000,
            earlyUnstakePrincipalPenaltyBps: 2_000,
            earlyUnstakeRewardPenaltyBps: 6_000,
            minStakeAmount: 100 ether,
            stakeCreationFee: 0.003 ether,
            unstakeFee: 0.001 ether,
            penaltyRecipient: address(0),
            feeRecipient: address(0)
        });
        ds.singleStaking.nextPositionId = 1;
        ds.singleStaking.lockConfigCount = 7;

        ds.singleStaking.lockConfigs[0] =
            SingleStakingLockConfig({duration: uint40(14 days), aprBps: 15_000, enabled: true});
        ds.singleStaking.lockConfigs[1] =
            SingleStakingLockConfig({duration: uint40(20 days), aprBps: 20_000, enabled: true});
        ds.singleStaking.lockConfigs[2] =
            SingleStakingLockConfig({duration: uint40(30 days), aprBps: 35_000, enabled: true});
        ds.singleStaking.lockConfigs[3] =
            SingleStakingLockConfig({duration: uint40(45 days), aprBps: 55_000, enabled: true});
        ds.singleStaking.lockConfigs[4] =
            SingleStakingLockConfig({duration: uint40(60 days), aprBps: 70_000, enabled: true});
        ds.singleStaking.lockConfigs[5] =
            SingleStakingLockConfig({duration: uint40(90 days), aprBps: 85_000, enabled: true});

        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.None, 0, 0, true);
        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.Bronze, 25, 1_000, true);
        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.Silver, 50, 1_500, true);
        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.Gold, 75, 2_000, true);
        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.Platinum, 100, 2_500, true);
        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.Diamond, 200, 3_000, true);
        LibSingleStaking.seedTier(ds.singleStaking, StakeTier.Mythril, 500, 4_000, true);
    }
}
