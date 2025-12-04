// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibAppStorage} from "../../libs/LibAppStorage.sol";
import {TokenState} from "../../shared/Structs.sol";

/**
 * @title TokenDataFacet
 * @author Forever Network
 * @notice Manages token-related data such as total mints, credits, etc.
 * @dev This facet is stateless and relies on `LibParticipant` and `AppStorage` for state modifications.
 */
contract TokenDataFacet {
    /**
     * @notice Retrieves the total number of tokens minted in the system.
     * @return The total number of tokens minted.
     */
    function getTokenState() external view returns (TokenState memory) {
        return LibAppStorage.diamondStorage().tokenState;
    }
}
