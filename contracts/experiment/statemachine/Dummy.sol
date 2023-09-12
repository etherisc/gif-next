// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ObjectType} from "../../types/ObjectType.sol";
import {StateId, toStateId, zeroStateId} from "../../types/StateId.sol";

contract LifeCycleModule {
    mapping(ObjectType objectType => StateId initialState)
        private _initialState;

    mapping(ObjectType objectType => mapping(StateId stateFrom => mapping(StateId stateTo => bool isValid)))
        private _isValidTransition;

    function getInitialState(
        ObjectType objectType
    ) external view returns (StateId) {
        return _initialState[objectType];
    }

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) external view returns (bool) {
        return _isValidTransition[objectType][fromId][toId];
    }
}
