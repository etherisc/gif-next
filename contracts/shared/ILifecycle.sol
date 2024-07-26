// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ObjectType} from "../type/ObjectType.sol";
import {StateId} from "../type/StateId.sol";

interface ILifecycle {

    error ErrorNoLifecycle(address contractAddress, ObjectType objectType);
    error ErrorFromStateMissmatch(address contractAddress, ObjectType objectType, StateId actual, StateId required);
    error ErrorInvalidStateTransition(
        address contractAddress,
        ObjectType objectType,
        StateId fromStateId,
        StateId toStateId
    );

    function hasLifecycle(
        ObjectType objectType
    ) external view returns (bool);

    function getInitialState(
        ObjectType objectType
    ) external view returns (StateId);

    function isValidTransition(
        ObjectType objectType,
        StateId fromId,
        StateId toId
    ) external view returns (bool);
}
