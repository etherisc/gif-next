// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "../type/ObjectType.sol";
import {StateId} from "../type/StateId.sol";
import {ILifecycle} from "./ILifecycle.sol";

abstract contract Lifecycle is
    ILifecycle
{
    // TODO make private
    mapping(ObjectType objectType => StateId initialState)
        internal _initialState;

    mapping(ObjectType objectType => mapping(StateId stateFrom => mapping(StateId stateTo => bool isValid)))
        internal _isValidTransition;

    //function _initializeLifecycle() internal virtual;

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
