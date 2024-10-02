// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../registry/IRegistry.sol";
import {ITargetLimitHandler} from "./ITargetLimitHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {NftId} from "../type/NftId.sol";
import {RegistryLinked} from "../shared/RegistryLinked.sol";
import {StakingStore} from "./StakingStore.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


contract TargetHandler is
    Initializable,
    AccessManaged,
    ITargetLimitHandler,
    RegistryLinked
{

    event LogTargetHandlerUpdateTriggersSet(uint16 tvlUpdatesTrigger, UFixed minTvlRatioTrigger, Blocknumber lastUpdateIn);

    StakingStore private _store;

    /// @dev Update trigger value: Number of TVL updates below which limit updates are suppressed
    uint16 private _tvlUpdatesTrigger; 
    /// @dev Maximum TVL ratio: Any ratio above this value will trigger a limit update
    UFixed private _minTvlRatioTrigger;
    Blocknumber private _lastUpdateIn;


    constructor (
        StakingStore stakingStore
    )
        AccessManaged(msg.sender)
    {
        // set final authority and registry
        setAuthority(_getRegistry().getAuthority());
        _store = stakingStore;

        // set default trigger values
        _setUpdateTriggers(
            10, // check after 2 TVL updates
            UFixedLib.toUFixed(1, -1)); // 10% deviation from baseline TVL
    }


    // TODO do we really need this?
    // if so: add onlyDeployer (new base contract? also for reader)
    // if not: remove oz intializer/initializable
    function initialize()
        external
        initializer()
    { }

    //--- staking functions -------------------------------------------------------//

    /// @dev Sets the TVL update triggers.
    function setUpdateTriggers(
        uint16 tvlUpdatesTrigger,
        UFixed minTvlRatioTrigger
    )
        external
        restricted()
    {
        _setUpdateTriggers(tvlUpdatesTrigger, minTvlRatioTrigger);
    }

    //--- ITargetLimitHandler -----------------------------------------------------//

    /// @inheritdoc ITargetLimitHandler
    // Current implementation only considers the TVL amounts. 
    // Future implementations may also consider target or token specific factors. 
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
        if (tvlUpdatesCount < _tvlUpdatesTrigger) {
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
        return ratio >= _minTvlRatioTrigger;
    }


    function _setUpdateTriggers(
        uint16 tvlUpdatesTrigger,
        UFixed minTvlRatioTrigger
    )
        internal
    {
        Blocknumber lastUpdateIn = _lastUpdateIn;
        _tvlUpdatesTrigger = tvlUpdatesTrigger;
        _minTvlRatioTrigger = minTvlRatioTrigger;
        _lastUpdateIn = BlocknumberLib.current();

        emit LogTargetHandlerUpdateTriggersSet(tvlUpdatesTrigger, minTvlRatioTrigger, lastUpdateIn);
    }
}
