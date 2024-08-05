// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RELEASE} from "../type/ObjectType.sol";
import {SCHEDULED, DEPLOYING, DEPLOYED, SKIPPED, ACTIVE, PAUSED, CLOSED} from "../type/StateId.sol";
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

        setStateTransition(RELEASE(), SCHEDULED(), SKIPPED());
        setStateTransition(RELEASE(), SCHEDULED(), DEPLOYING());
        setStateTransition(RELEASE(), DEPLOYING(), SKIPPED());
        setStateTransition(RELEASE(), DEPLOYING(), DEPLOYED());
        setStateTransition(RELEASE(), DEPLOYED(), SKIPPED());
        setStateTransition(RELEASE(), DEPLOYED(), ACTIVE());
        setStateTransition(RELEASE(), ACTIVE(), PAUSED());
        setStateTransition(RELEASE(), PAUSED(), ACTIVE());
    }
}
