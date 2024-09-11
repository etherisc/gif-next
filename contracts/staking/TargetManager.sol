// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ITargetManager} from "./ITargetManager.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {StakingStore} from "./StakingStore.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";

contract TargetManager is ITargetManager {

    // TODO - update to the correct location
    bytes32 public constant TARGET_MANAGER_LOCATION_V1 = 0xafe8d746212ed26a47154f4b8f6d1a97d2f772496775791d25bd456e342b7f00;

    struct TargetManagerStorage {
        StakingStore _store;
        uint16 _tvlUpdatesTrigger; // number of TVL updates below which limit updates are suppressed
        UFixed _maxTvlRatio; // any ratio above this value will trigger a limit update
    }


    function __TargetManager_init(
        StakingStore stakingStore,
        uint16 tvlUpdatesTrigger,
        UFixed maxTvlRatio
    )
        internal
        virtual
        // TODO add onlyInitializing()
    {
        TargetManagerStorage storage $ = _getTargetManagerStorage();
        $._store = stakingStore;
        $._tvlUpdatesTrigger = tvlUpdatesTrigger;
        $._maxTvlRatio = maxTvlRatio;
    }


    //--- target limit manager interface ------------------------------------//


    /// @inheritdoc ITargetManager
    function updateLimit(NftId targetNftId)
        external
        virtual 
        // TODO add restricted() 
        returns (Amount stakeLimitAmount)
    {
        TargetManagerStorage storage $ = _getTargetManagerStorage();
        $._store.updateTargetLimit(targetNftId);
    }


    /// @dev Returns true iff the target limit update is required.
    /// Current implementation only considers the TVL amounts. 
    /// Future implementations may also consider target or token specific factors. 
    function isLimitUpdateRequired(
        NftId, // targetNftId
        address , // token
        uint16 tvlUpdatesCount,
        Amount baselineTvlAmount, 
        Amount currentTvlAmount
    )
        external 
        virtual
        view
        returns (bool updateIsRequired)
    {
        // no update required if below the TVL updates trigger
        TargetManagerStorage storage $ = _getTargetManagerStorage();
        if (tvlUpdatesCount < $._tvlUpdatesTrigger) {
            return false;
        }

        // no update required if both amounts are zero
        Amount zero = AmountLib.zero();
        if (baselineTvlAmount == zero && currentTvlAmount == zero) {
            return false;

        // update required if one amount is zero
        } else if (baselineTvlAmount == zero || currentTvlAmount == zero) {
            return true;
        }

        // calculate the ratio of the current TVL amount to the baseline TVL amount
        UFixed baseline = baselineTvlAmount.toUFixed();
        UFixed current = currentTvlAmount.toUFixed();
        UFixed ratio;

        if (baseline > current) { ratio = baseline / current; }
        else { ratio = current / baseline; }

        // update required if the ratio is above the maximum TVL ratio
        return ratio > $._maxTvlRatio;
    }


    function _getTargetManagerStorage() private pure returns (TargetManagerStorage storage $) {
        assembly {
            $.slot := TARGET_MANAGER_LOCATION_V1
        }
    }
}
