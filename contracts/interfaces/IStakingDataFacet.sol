// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IStakingDataFacet {
    function hasActiveStakingPosition(address account) external view returns (bool);
}
