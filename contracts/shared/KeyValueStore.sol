// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Blocknumber, blockBlocknumber, zeroBlocknumber} from "../type/Blocknumber.sol";
import {Key32, KeyId, Key32Lib} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {StateId, ACTIVE, KEEP_STATE} from "../type/StateId.sol";
import {Timestamp, TimestampLib} from "../type/Timestamp.sol";

import {Lifecycle} from "./Lifecycle.sol";
import {IKeyValueStore} from "./IKeyValueStore.sol";

contract KeyValueStore is
    Lifecycle, 
    IKeyValueStore
{

    mapping(Key32 key32 => Value value) private _value;

    function create(
        Key32 key32, 
        bytes memory data
    )
        internal
    {
        ObjectType objectType = key32.toObjectType();
        if (objectType.eqz()) {
            revert ErrorKeyValueStoreTypeUndefined(objectType);
        }

        Metadata storage metadata = _value[key32].metadata;
        if (metadata.state.gtz()) {
            revert ErrorKeyValueStoreAlreadyCreated(key32, objectType);
        }

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

        // solhint-disable-next-line avoid-tx-origin
        emit LogInfoCreated(key32.toObjectType(), key32.toKeyId(), initialState, createdBy, tx.origin);
    }

    function update(
        Key32 key32, 
        bytes memory data,
        StateId state
    ) 
        internal
    {
        if (state.eqz()) {
            revert ErrorKeyValueStoreStateZero(key32);
        }

        Metadata storage metadata = _value[key32].metadata;
        StateId stateOld = metadata.state;
        if (stateOld.eqz()) {
            revert ErrorKeyValueStoreNotExisting(key32);
        }

        // update data
        _value[key32].data = data;

        // update state 
        if(state != KEEP_STATE()) {
            checkTransition(metadata.objectType, stateOld, state);
            metadata.state = state;
        }

        // update reest of metadata
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;

        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        // create log entries
        // solhint-disable avoid-tx-origin
        emit LogStateUpdated(key32.toObjectType(), key32.toKeyId(), stateOld, state, updatedBy, tx.origin, lastUpdatedIn);
        emit LogInfoUpdated(key32.toObjectType(), key32.toKeyId(), state, updatedBy, tx.origin, lastUpdatedIn);
        // solhing-enable
    }

    function updateData(Key32 key32, bytes memory data) 
        internal
    {
        Metadata storage metadata = _value[key32].metadata;
        StateId state = metadata.state;
        if (state.eqz()) {
            revert ErrorKeyValueStoreNotExisting(key32);
        }

        // update data
        _value[key32].data = data;

        // update metadata
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;
        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        // create log entry
        // solhint-disable-next-line avoid-tx-origin
        emit LogInfoUpdated(key32.toObjectType(), key32.toKeyId(), state, updatedBy, tx.origin, lastUpdatedIn);
    }

    function updateState(Key32 key32, StateId state)
        internal
    {
        if (state.eqz()) {
            revert ErrorKeyValueStoreStateZero(key32);
        }

        Metadata storage metadata = _value[key32].metadata;
        StateId stateOld = metadata.state;
        if (stateOld.eqz()) {
            revert ErrorKeyValueStoreNotExisting(key32);
        }

        // ensure state transistion is valid
        checkTransition(metadata.objectType, stateOld, state);

        // update metadata (and state)
        address updatedBy = msg.sender;
        Blocknumber lastUpdatedIn = metadata.updatedIn;
        metadata.state = state;
        metadata.updatedBy = updatedBy;
        metadata.updatedIn = blockBlocknumber();

        // create log entry
        // solhint-disable-next-line avoid-tx-origin
        emit LogStateUpdated(key32.toObjectType(), key32.toKeyId(), stateOld, state, updatedBy, tx.origin, lastUpdatedIn);
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

    function toKey32(ObjectType objectType, KeyId id) external pure override returns(Key32) {
        return Key32Lib.toKey32(objectType, id);
    }
}
