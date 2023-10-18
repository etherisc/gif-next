// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";

import {Blocknumber, blockNumber} from "../../types/Blocknumber.sol";
import {Key32, KeyId} from "../../types/Key32.sol";
import {LibNftIdSet} from "../../types/NftIdSet.sol";
import {NftId} from "../../types/NftId.sol";
import {ObjectType, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../types/Timestamp.sol";

import {IKeyValueStore} from "./IKeyValueStore.sol";

abstract contract ModuleBase {

    IKeyValueStore private _store;

    function _initialize(IKeyValueStore keyValueStore) internal {
        _store = keyValueStore;
    }

    function _create(ObjectType objectType, Key32 key, bytes memory data) internal {
        _store.create(
            key, 
            objectType,
            data);
    }

    function _create(ObjectType objectType, NftId nftId, bytes memory data) internal {
        _store.create(
            nftId.toKey32(objectType), 
            objectType,
            data);
    }

    function _updateData(ObjectType objectType, NftId nftId, bytes memory data) internal {
        _store.updateData(nftId.toKey32(objectType), data);
    }

    function _updateState(ObjectType objectType, NftId nftId, StateId state) internal {
        _store.updateState(nftId.toKey32(objectType), state);
    }

    function _exists(ObjectType objectType, NftId nftId) internal view returns (bool hasData) {
        return _store.exists(nftId.toKey32(objectType));
    }

    function _getData(ObjectType objectType, NftId nftId) internal view returns(bytes memory data) {
        return _store.getData(nftId.toKey32(objectType));
    }

    function _getState(ObjectType objectType, NftId nftId) internal view returns(StateId) {
        return _store.getState(nftId.toKey32(objectType));
    }
}