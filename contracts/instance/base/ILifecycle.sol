// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../type/NftId.sol";
import {ObjectType} from "../../type/ObjectType.sol";
import {StateId} from "../../type/StateId.sol";

interface ILifecycle {

    error ErrorNoLifecycle(NftId nftId, ObjectType objectType);
    error ErrorInvalidStateTransition(
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
