// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 

import {IRegistry} from "../registry/IRegistry.sol";
import {ITargetLimitHandler} from "./ITargetLimitHandler.sol";

import {Amount, AmountLib} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {StakingStore} from "./StakingStore.sol";
import {UFixed, UFixedLib} from "../type/UFixed.sol";


contract TargetHandler is
    Initializable,
    AccessManaged,
    ITargetLimitHandler
{

    IRegistry private _registry;
    StakingStore private _store;
    uint16 private _tvlUpdatesTrigger; // number of TVL updates below which limit updates are suppressed
    UFixed private _maxTvlRatio; // any ratio above this value will trigger a limit update


    constructor (
        IRegistry registry,
        StakingStore stakingStore
    )
        AccessManaged(msg.sender)
    {
        // set final authority and registry
        setAuthority(registry.getAuthority());
        _registry = registry;
        _store = stakingStore;
        _tvlUpdatesTrigger = 2; // check after 2 TVL updates TODO make this configurable
        _maxTvlRatio = UFixedLib.toUFixed(1, -1); // 10% above the baseline TVL amount TODO make this configurable
    }

    // TODO do we really need this?
    // if so: add onlyDeployer (new base contract? also for reader)
    // if not: remove oz intializer/initializable
    function initialize()
        external
        initializer()
    { }

    //--- target owner functions --------------------------------------------------//    
    //--- ITargetLimitHandler -----------------------------------------------------//

    /// @inheritdoc ITargetLimitHandler
    function updateLimit(NftId targetNftId)
        external
        virtual 
        restricted() 
        returns (Amount stakeLimitAmount)
    {
        _store.updateTargetLimit(targetNftId);
    }


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
        return ratio > _maxTvlRatio;
    }
}
