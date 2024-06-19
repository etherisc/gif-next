// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {TARGET, COMPONENT, STAKE} from "../type/ObjectType.sol";
import {INITIAL} from "../type/StateId.sol";
import {Lifecycle} from "../shared/Lifecycle.sol";

contract StakingLifecycle is
    Lifecycle
{
    constructor() {
        _setupLifecycle();
    }

    function _setupLifecycle()
        private
    {
        _initialState[TARGET()] = INITIAL();

        _initialState[COMPONENT()] = INITIAL();

        _initialState[STAKE()] = INITIAL();
    }
}
