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
    ObjectType private _type;

    function _initialize(IKeyValueStore keyValueStore, ObjectType objectType) internal {
        _store = keyValueStore;
        _type = objectType;
    }

    function _create(NftId nftId, bytes memory data) internal {
        _store.create(
            _toKey32(nftId), 
            _type,
            data);
    }

    function _updateData(NftId nftId, bytes memory data) internal {
        _store.updateData(_toKey32(nftId), data);
    }

    function _updateState(NftId nftId, StateId state) internal {
        _store.updateState(_toKey32(nftId), state);
    }

    function _getData(NftId nftId) internal view returns(bytes memory data) {
        return _store.getData(_toKey32(nftId));
    }

    function _getState(NftId nftId) internal view returns(StateId) {
        return _store.getState(_toKey32(nftId));
    }

    function _toKey32(NftId nftId) internal view returns (Key32 key32) {
        return nftId.toKey32(_type);
    } 
}