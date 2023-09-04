// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {StateId, toStateId, zeroStateId} from "../../types/StateId.sol";
import {ISM} from "./ISM.sol";

contract SM is ISM {

    mapping(StateId currentState => mapping(StateId newState => bool isValid)) private _isValidTransition;

    StateId internal _state;


    function setInitialState(StateId initialStateId) internal {
        if(initialStateId == zeroStateId()) {
            revert ErrorInitialStateUndefined();
        }

        _state = initialStateId;
    }


    function addTransition(StateId currentStateId, StateId nextStateId) internal {
        if(currentStateId == zeroStateId()) {
            revert ErrorStartStateUndefined();
        }

        if(nextStateId == zeroStateId()) {
            revert ErrorNextStateUndefined();
        }

        _isValidTransition[currentStateId][nextStateId] = true;
    }


    function changeToState(StateId newStateId) external override {
        if(!_isValidTransition[_state][newStateId]) {
            revert ErrorStateChangeInvalid(_state, newStateId);
        }

        StateId stateOld = _state;
        _state = newStateId;

        emit LogStateChanged(stateOld, _state);
    }

    function isValidTransition(StateId currentStateId, StateId newStateId) external view override returns(bool isValid) {
        return _isValidTransition[currentStateId][newStateId];
    }

    function getState() external view override returns(StateId state) {
        return _state;
    }
}
