// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Blocknumber, blockBlocknumber, zeroBlocknumber} from "../types/Blocknumber.sol";
import {Key32, KeyId} from "../types/Key32.sol";
import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {StateId} from "../types/StateId.sol";

interface IKeyValueStore {

    struct Key {
        ObjectType objectType;
        KeyId id;
    }

    struct Value {
        Metadata metadata;
        bytes data;
    }

    struct Metadata {
        ObjectType objectType;
        StateId state;
        address updatedBy;
        Blocknumber updatedIn;
        Blocknumber createdIn;
    }

    event LogInfoCreated(Key key, StateId state, address createdBy);
    event LogInfoUpdated(Key key, StateId state, address updatedBy, Blocknumber lastUpdatedIn);
    event LogStateUpdated(Key key, StateId stateOld, StateId stateNew, address updatedBy, Blocknumber lastUpdatedIn);

    // generic state changing functions
    function create(Key32 key, ObjectType objectType, StateId state, bytes memory data) external;
    function update(Key32 key, StateId state, bytes memory data) external;
    function updateData(Key32 key, bytes memory data) external;
    function updateState(Key32 key, StateId state) external;

    function createWithNftId(NftId nftId, ObjectType objectType, bytes memory data) external;
    function updateDataWithNftId(NftId nftId, bytes memory data) external;
    function updateStateWithNftId(NftId nftId, StateId state) external;

    function exists(Key32 key) external view returns (bool);
    function get(Key32 key) external view returns (Value memory value);
    function getData(Key32 key) external view returns (bytes memory data);
    function getMetadata(Key32 key) external view returns (Metadata memory metadata);
    function getState(Key32 key) external view returns (StateId state);

    function toKey32(ObjectType objectType, KeyId id) external pure returns(Key32);
}
