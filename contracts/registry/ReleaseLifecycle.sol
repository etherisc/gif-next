// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RELEASE} from "../type/ObjectType.sol";
import {SCHEDULED, DEPLOYING, ACTIVE, PAUSED, CLOSED/*, FREE*/} from "../type/StateId.sol";
import {Lifecycle} from "../shared/Lifecycle.sol";

contract ReleaseLifecycle is
    Lifecycle
{
    constructor() {
        _setupLifecycle();
    }

    function _setupLifecycle()
        internal 
        override
    {
        setInitialState(RELEASE(), SCHEDULED());

        setStateTransition(RELEASE(), SCHEDULED(), DEPLOYING());
        setStateTransition(RELEASE(), DEPLOYING(), DEPLOYING());
        setStateTransition(RELEASE(), DEPLOYING(), ACTIVE());
        setStateTransition(RELEASE(), ACTIVE(), PAUSED());
        setStateTransition(RELEASE(), PAUSED(), ACTIVE());
    }
}
