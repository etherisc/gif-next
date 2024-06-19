// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {RELEASE} from "../type/ObjectType.sol";
import {SCHEDULED, DEPLOYING, DEPLOYED, ACTIVE, PAUSED, CLOSED/*, FREE*/} from "../type/StateId.sol";
import {Lifecycle} from "../shared/Lifecycle.sol";

contract ReleaseLifecycle is
    Lifecycle
{
    constructor() {
        _setupLifecycle();
    }

    function _setupLifecycle()
        private
    {
        _initialState[RELEASE()] = SCHEDULED();

        _isValidTransition[RELEASE()][SCHEDULED()][DEPLOYING()] = true;
        _isValidTransition[RELEASE()][DEPLOYING()][DEPLOYING()] = true;
        _isValidTransition[RELEASE()][DEPLOYING()][ACTIVE()] = true;
        _isValidTransition[RELEASE()][ACTIVE()][PAUSED()] = true;
        _isValidTransition[RELEASE()][PAUSED()][ACTIVE()] = true;
        _isValidTransition[RELEASE()][PAUSED()][CLOSED()] = true;
        //_isValidTransition[RELEASE()][ACTIVE()][FREE()] = true;
    }
}
