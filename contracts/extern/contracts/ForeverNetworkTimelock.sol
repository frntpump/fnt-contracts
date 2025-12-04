// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title ForeverNetworkTimelock
 * @notice Timelock controller for governance proposals
 * @dev Adds delay to proposal execution for security
 */
contract ForeverNetworkTimelock is TimelockController {
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
