// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";

interface ITargetLimitHandler {

    /// @dev Returns true iff the target limit update is required.
    function isLimitUpdateRequired(
        NftId targetNftId, 
        address token, 
        uint16 tvlUpdatesCount,
        Amount baselineTvlAmount, 
        Amount currentTvlAmount
    ) external view returns (bool updateIsRequired);
}