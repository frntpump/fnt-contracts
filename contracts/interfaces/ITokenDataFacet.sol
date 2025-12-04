// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TokenState} from "../shared/Structs.sol";

/**
 * @title ITokenDataFacet
 * @author Forever Network
 * @notice External interface for the TokenDataFacet.
 */
interface ITokenDataFacet {
    /**
     * @notice Gets the current token state statistics.
     * @return state The token state containing purchase times, total purchased, and total minted.
     */
    function getTokenState() external view returns (TokenState memory state);
}
