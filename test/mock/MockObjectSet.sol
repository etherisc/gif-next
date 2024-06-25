// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "../../contracts/instance/IInstance.sol";
import {NftId} from "../../contracts/type/NftId.sol";
import {ObjectSet} from "../../contracts/instance/base/ObjectSet.sol";

contract MockObjectSet is ObjectSet {

    function initialize(address instance)
        external
        initializer()
    {
        _instance = IInstance(instance);
        __Cloneable_init(_instance.authority(), address(_instance.getRegistry()));
        
        emit LogObjectSetInitialized(instance);
    }

    function add(NftId componentNftId, NftId objectNftId) external {
        _add(componentNftId, objectNftId);
    }

    function activate(NftId componentNftId, NftId objectNftId) external {
        _activate(componentNftId, objectNftId);
    }

    function deactivate(NftId componentNftId, NftId objectNftId) external {
        _deactivate(componentNftId, objectNftId);
    }

    function objects(NftId componentNftId) external view returns (uint256) {
        return _objects(componentNftId);
    }

    function contains(NftId componentNftId, NftId objectNftId) external view returns (bool) {
        return _contains(componentNftId, objectNftId);
    }

    function getObject(NftId componentNftId, uint256 idx) external view returns (NftId) {
        return _getObject(componentNftId, idx);
    }

    function activeObjects(NftId componentNftId) external view returns (uint256) {
        return _activeObjs(componentNftId);
    }

    function isActive(NftId componentNftId, NftId objectNftId) external view returns (bool) {
        return _isActive(componentNftId, objectNftId);
    }

    function getActiveObject(NftId componentNftId, uint256 idx) external view returns (NftId) {
        return _getActiveObject(componentNftId, idx);
    }
}
