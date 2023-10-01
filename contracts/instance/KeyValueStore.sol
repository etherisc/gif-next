// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Blocknumber, blockBlocknumber, zeroBlocknumber} from "../types/Blocknumber.sol";
import {Key32, KeyId, Key32Lib} from "../types/Key32.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {StateId} from "../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../types/Timestamp.sol";

import {IKeyValueStore} from "./IKeyValueStore.sol";

contract KeyValueStore is IKeyValueStore {

    mapping(Key32 key32 => Value value) private _value;
    address private _owner;

    modifier onlyOwner() {
        require(
            msg.sender == _owner,
            "ERROR:KVS-001:NOT_OWNER");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    function create(
        Key32 key32, 
        ObjectType objectType, 
        StateId state, 
        bytes memory data
    )
        public
        onlyOwner
    {
        require(objectType.gtz(), "ERROR:KVS-010:TYPE_UNDEFINED");
        require(state.gtz(), "ERROR:KVS-011:STATE_UNDEFINED");

        Metadata storage metadata = _value[key32].metadata;
        require(metadata.state.eqz(), "ERROR:KVS-012:ALREADY_CREATED");

        address createdBy = msg.sender;
        Blocknumber blocknumber = blockBlocknumber();

        // set metadata
        metadata.objectType = objectType;
        metadata.state = state;
        metadata.updatedBy = createdBy;
        metadata.updatedIn = blocknumber;
        metadata.createdIn = blocknumber;

        // set data
        _value[key32].data = data;

        emit LogInfoCreated(toKey(key32), state, createdBy);
    }

    function update(Key32 key32, StateId state, bytes memory data) public {
        require(state.gtz(), "ERROR:KVS-020:STATE_UNDEFINED");
        Metadata storage metadata = _value[key32].metadata;
        StateId stateOld = metadata.state;
        require(stateOld.gtz(), "ERROR:KVS-021:NOT_EXISTING");

        // update data
        _value[key32].data = data;

        // update metadata
        Key memory key = toKey(key32);
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;

        if (state != stateOld) {
            metadata.state = state;
            emit LogStateChanged(key, state, stateOld, updatedBy, lastUpdatedIn);
        }

        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        emit LogInfoUpdated(key, state, updatedBy, lastUpdatedIn);
    }

    function exists(Key32 key32) public view returns (bool) {
        return _value[key32].metadata.state.gtz();
    }

    function get(Key32 key32) public view returns (Value memory value) {
        return _value[key32];
    }

    function getMetadata(Key32 key32) public view returns (Metadata memory metadata) {
        return _value[key32].metadata;
    }

    function getData(Key32 key32) public view returns (bytes memory data) {
        return _value[key32].data;
    }

    function getState(Key32 key32) public view returns (StateId state) {
        return _value[key32].metadata.state;
    }

    function toKey32(ObjectType objectType, KeyId id) external pure returns(Key32) {
        return Key32Lib.toKey32(objectType, id);
    }

    function toKey(Key32 key32) public pure returns (Key memory key) {
        (ObjectType objectType, KeyId id) = key32.toKey();
        return Key(objectType, id);
    }
}
