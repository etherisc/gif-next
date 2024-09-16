// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ILifecycle} from "../shared/ILifecycle.sol";

import {Blocknumber} from "../type/Blocknumber.sol";
import {Key32, KeyId} from "../type/Key32.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {StateId} from "../type/StateId.sol";


interface IBaseStore is ILifecycle {

    error ErrorBaseStoreTypeUndefined(ObjectType objectType);
    error ErrorBaseStoreAlreadyCreated(Key32 key, ObjectType objectType);
    error ErrorBaseStoreNoLifecycle(ObjectType objectType);
    error ErrorBaseStoreStateZero(Key32 key);
    error ErrorBaseStoreNotExisting(Key32 key);


    struct Metadata {
        // slot 0
        ObjectType objectType;
        StateId state;
        Blocknumber updatedIn;
    }

    /// @dev check if a metadata entry with the key exists
    function exists(Key32 key) external view returns (bool);
    /// @dev retrieve the metadata for a given key
    function getMetadata(Key32 key) external view returns (Metadata memory metadata);
    /// @dev retrieve the state for a given key
    function getState(Key32 key) external view returns (StateId state);

    /// @dev convert an object type and an id to a key32
    function toKey32(ObjectType objectType, KeyId id) external pure returns(Key32);
}
