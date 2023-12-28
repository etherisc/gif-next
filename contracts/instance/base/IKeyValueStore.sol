// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Blocknumber, blockBlocknumber, zeroBlocknumber} from "../../types/Blocknumber.sol";
import {Key32, KeyId} from "../../types/Key32.sol";
import {NftId} from "../../types/NftId.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {StateId} from "../../types/StateId.sol";

import {ILifecycle} from "./ILifecycle.sol";

interface IKeyValueStore is ILifecycle {

    struct Value {
        Metadata metadata;
        bytes data;
    }

    struct Metadata {
        ObjectType objectType;
        StateId state;
        // TODO updatedBy needs concept that says what value should go here
        // eg account outside gif objects that initiated the tx
        // implies the caller needs to be propagated through all calls up to key values store itself
        // to always have the instance address there doesn't seem to make sense
        address updatedBy;
        Blocknumber updatedIn;
        Blocknumber createdIn;
    }

    event LogInfoCreated(ObjectType objectType, KeyId keyId, StateId state, address createdBy, address txOrigin);
    event LogInfoUpdated(ObjectType objectType, KeyId keyId, StateId state, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogStateUpdated(ObjectType objectType, KeyId keyId, StateId stateOld, StateId stateNew, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);

    // generic state changing functions
    function create(Key32 key, bytes memory data) external;
    function update(Key32 key, bytes memory data, StateId state) external;
    function updateData(Key32 key, bytes memory data) external;
    function updateState(Key32 key, StateId state) external;

    function exists(Key32 key) external view returns (bool);
    function get(Key32 key) external view returns (Value memory value);
    function getData(Key32 key) external view returns (bytes memory data);
    function getMetadata(Key32 key) external view returns (Metadata memory metadata);
    function getState(Key32 key) external view returns (StateId state);

    function toKey32(ObjectType objectType, KeyId id) external pure returns(Key32);
}
