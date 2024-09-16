// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IBaseStore} from "./IBaseStore.sol";

import {Blocknumber, BlocknumberLib} from "../type/Blocknumber.sol";
import {Key32, KeyId, Key32Lib} from "../type/Key32.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {StateId, KEEP_STATE} from "../type/StateId.sol";
import {Lifecycle} from "../shared/Lifecycle.sol";

abstract contract BaseStore is
    Lifecycle, 
    IBaseStore
{

    mapping(Key32 key32 => IBaseStore.Metadata metadata) private _metadata;

    function _createMetadata(
        Key32 key32
    )
        internal
    {
        ObjectType objectType = key32.toObjectType();
        if (objectType.eqz()) {
            revert ErrorBaseStoreTypeUndefined(objectType);
        }

        Metadata storage metadata = _metadata[key32];
        if (metadata.updatedIn.gtz()) {
            revert ErrorBaseStoreAlreadyCreated(key32, objectType);
        }

        if(!hasLifecycle(objectType)) {
            revert ErrorBaseStoreNoLifecycle(objectType);
        }

        Blocknumber blocknumber = BlocknumberLib.current();
        StateId initialState = getInitialState(objectType);

        // set metadata
        metadata.objectType = objectType;
        metadata.state = initialState;
        metadata.updatedIn = blocknumber;
        
        // solhint-disable-next-line avoid-tx-origin
        emit LogBaseStoreMetadataCreated(key32.toObjectType(), key32.toKeyId(), initialState, msg.sender, tx.origin);
    }

    function _updateState(
        Key32 key32, 
        StateId state
    )
        internal
        returns (Blocknumber lastUpdatedIn)
    {
        if (state.eqz()) {
            revert ErrorBaseStoreStateZero(key32);
        }

        Metadata storage metadata = _metadata[key32];
        StateId stateOld = metadata.state;
        lastUpdatedIn = metadata.updatedIn;

        if (stateOld.eqz()) {
            revert ErrorBaseStoreNotExisting(key32);
        }

        // update state 
        if(state != KEEP_STATE()) {
            checkTransition(stateOld, metadata.objectType, stateOld, state);
            metadata.state = state;

            // solhint-disable-next-line avoid-tx-origin
            emit LogBaseStoreStateUpdated(key32.toObjectType(), key32.toKeyId(), stateOld, state, msg.sender, tx.origin, lastUpdatedIn);
        }

        // update metadata
        metadata.updatedIn = BlocknumberLib.current();
    }

    function exists(Key32 key32) public view returns (bool) {
        return _metadata[key32].state.gtz();
    }

    function getMetadata(Key32 key32) public view returns (Metadata memory metadata) {
        return _metadata[key32];
    }

    function getState(Key32 key32) public view returns (StateId state) {
        return _metadata[key32].state;
    }

    function toKey32(ObjectType objectType, KeyId id) external pure override returns(Key32) {
        return Key32Lib.toKey32(objectType, id);
    }
}
