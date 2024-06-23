// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "../type/ObjectType.sol";
import {StateId, zeroStateId} from "../type/StateId.sol";
import {ILifecycle} from "./ILifecycle.sol";

abstract contract Lifecycle is
    ILifecycle
{
    mapping(ObjectType objectType => StateId initialState)
        private _initialState;

    mapping(ObjectType objectType => mapping(StateId stateFrom => mapping(StateId stateTo => bool isValid)))
        private _isValidTransition;

    /// @dev child class must implement and CALL setup func at deployment/initializaton time
    function _setupLifecycle() internal virtual;

    function setInitialState(ObjectType ttype, StateId state) internal virtual {
        assert(_initialState[ttype] == zeroStateId());
        _initialState[ttype] = state;
    }

    function setStateTransition(ObjectType ttype, StateId oldState, StateId newState) internal virtual {
        assert(_isValidTransition[ttype][oldState][newState] == false);
        _isValidTransition[ttype][oldState][newState] = true;
    }

    function hasLifecycle(
        ObjectType objectType
    )
        public
        view
        override
        returns (bool)
    {
        return _initialState[objectType].gtz();
    }

    function getInitialState(
        ObjectType objectType
    )
        public
        view
        returns (StateId)
    {
        return _initialState[objectType];
    }

    function checkTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    )
        public
        view
    {
        // revert if no life cycle support
        if (_initialState[objectType].eqz()) {
            revert ErrorNoLifecycle(objectType);
        }

        // enforce valid state transition
        if (!_isValidTransition[objectType][fromId][toId]) {
            revert ErrorInvalidStateTransition(objectType, fromId, toId);
        }
    }

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) public view returns (bool) {
        return _isValidTransition[objectType][fromId][toId];
    }
}
