// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {StateId} from "../../types/StateId.sol";

interface ISMEE {
    error ErrorInitialStateUndefined();
    error ErrorStartStateUndefined();
    error ErrorNextStateUndefined();
    error ErrorStateChangeInvalid(StateId currentStateId, StateId newStateId);

    event LogInitialStateSet(StateId initialStateId);
    event LogStateChanged(StateId oldStateId, StateId newStateId);
}

interface ISM is ISMEE {
    function changeToState(StateId newStateId) external;
    function isValidTransition(StateId currentStateId, StateId newStateId) external view returns(bool isValid);
    function getState() external view returns(StateId currentStateId);
}
