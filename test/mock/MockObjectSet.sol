// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../../contracts/instance/IInstance.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {ObjectTypeLib} from "../../contracts/type/ObjectType.sol";
import {ObjectSet} from "../../contracts/instance/base/ObjectSet.sol";

contract MockObjectSet is ObjectSet {

    function initialize(address authority, address registry, address instanceAddress) 
        external
        initializer()
    {
        _instanceAddress = instanceAddress;
        __Cloneable_init(authority, registry);
        
        emit LogObjectSetInitialized(instanceAddress);
    }

    function add(NftId componentNftId, NftId objectNftId) external {
        _add(componentNftId, objectNftId.toKey32(ObjectTypeLib.zero()));
    }

    function activate(NftId componentNftId, NftId objectNftId) external {
        _activate(componentNftId, objectNftId.toKey32(ObjectTypeLib.zero()));
    }

    function deactivate(NftId componentNftId, NftId objectNftId) external {
        _deactivate(componentNftId, objectNftId.toKey32(ObjectTypeLib.zero()));
    }

    function objects(NftId componentNftId) external view returns (uint256) {
        return _objects(componentNftId);
    }

    function contains(NftId componentNftId, NftId objectNftId) external view returns (bool) {
        return _contains(componentNftId, objectNftId.toKey32(ObjectTypeLib.zero()));
    }

    function getObject(NftId componentNftId, uint256 idx) external view returns (NftId) {
        return NftIdLib.toNftId(_getObject(componentNftId, idx).toKeyId());
    }

    function activeObjects(NftId componentNftId) external view returns (uint256) {
        return _activeObjs(componentNftId);
    }

    function isActive(NftId componentNftId, NftId objectNftId) external view returns (bool) {
        return _isActive(componentNftId, objectNftId.toKey32(ObjectTypeLib.zero()));
    }

    function getActiveObject(NftId componentNftId, uint256 idx) external view returns (NftId) {
        return NftIdLib.toNftId(_getActiveObject(componentNftId, idx).toKeyId());
    }
}
