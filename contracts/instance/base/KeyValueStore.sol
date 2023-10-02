// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Blocknumber, blockBlocknumber, zeroBlocknumber} from "../../types/Blocknumber.sol";
import {Key32, KeyId, Key32Lib} from "../../types/Key32.sol";
import {NftId} from "../../types/NftId.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {StateId, ACTIVE} from "../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../types/Timestamp.sol";

import {Lifecycle} from "./Lifecycle.sol";
import {IKeyValueStore} from "./IKeyValueStore.sol";

contract KeyValueStore is Lifecycle, IKeyValueStore {

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
        bytes memory data
    )
        public
        onlyOwner
    {
        require(objectType.gtz(), "ERROR:KVS-010:TYPE_UNDEFINED");

        Metadata storage metadata = _value[key32].metadata;
        require(metadata.state.eqz(), "ERROR:KVS-012:ALREADY_CREATED");

        address createdBy = msg.sender;
        Blocknumber blocknumber = blockBlocknumber();
        StateId initialState = hasLifecycle(objectType) ? getInitialState(objectType) : ACTIVE();

        // set metadata
        metadata.objectType = objectType;
        metadata.state = initialState;
        metadata.updatedBy = createdBy;
        metadata.updatedIn = blocknumber;
        metadata.createdIn = blocknumber;

        // set data
        _value[key32].data = data;

        emit LogInfoCreated(toKey(key32), initialState, createdBy);
    }

    function update(Key32 key32, StateId state, bytes memory data) 
        public
        onlyOwner
    {
        require(state.gtz(), "ERROR:KVS-020:STATE_UNDEFINED");
        Metadata storage metadata = _value[key32].metadata;
        StateId stateOld = metadata.state;
        require(stateOld.gtz(), "ERROR:KVS-021:NOT_EXISTING");

        // update data
        _value[key32].data = data;

        // update metadata (and state)
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;
        metadata.state = state;
        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        // create log entries
        Key memory key = toKey(key32);
        emit LogStateUpdated(key, state, stateOld, updatedBy, lastUpdatedIn);
        emit LogInfoUpdated(key, state, updatedBy, lastUpdatedIn);
    }

    function updateData(Key32 key32, bytes memory data) 
        public
        onlyOwner
    {
        Metadata storage metadata = _value[key32].metadata;
        StateId state = metadata.state;
        require(state.gtz(), "ERROR:KVS-030:NOT_EXISTING");

        // update data
        _value[key32].data = data;

        // update metadata
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;
        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        // create log entry
        Key memory key = toKey(key32);
        emit LogInfoUpdated(key, state, updatedBy, lastUpdatedIn);
    }

    function updateState(Key32 key32, StateId state)
        public
        onlyOwner
    {
        require(state.gtz(), "ERROR:KVS-040:STATE_UNDEFINED");
        Metadata storage metadata = _value[key32].metadata;
        StateId stateOld = metadata.state;
        require(stateOld.gtz(), "ERROR:KVS-041:NOT_EXISTING");

        // update metadata (and state)
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;
        metadata.state = state;
        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        // create log entry
        Key memory key = toKey(key32);
        emit LogStateUpdated(key, state, stateOld, updatedBy, lastUpdatedIn);
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
