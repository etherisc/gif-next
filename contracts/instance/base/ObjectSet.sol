// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Cloneable} from "./Cloneable.sol";

import {IInstance} from "../IInstance.sol";
import {INSTANCE} from "../../type/ObjectType.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {LibNftIdSet} from "../../type/NftIdSet.sol";
import {NftId} from "../../type/NftId.sol";

contract ObjectSet is
    Cloneable
{

    event LogObjectSetInitialized(address instance);

    error ErrorObjectSetNftIdInvalid(NftId instanceNftId);

    mapping(NftId compnentNftId => LibNftIdSet.Set objects) internal _activeObjects;
    mapping(NftId compnentNftId => LibNftIdSet.Set objects) internal _allObjects;
    IInstance internal _instance; // store instance address -> more flexible, instance may not be registered during ObjectSet initialization

    /// @dev This initializer needs to be called from the instance itself.
    function initialize() 
        external
        initializer()
    {
        _instance = IInstance(msg.sender);
        __Cloneable_init(_instance.authority(), address(_instance.getRegistry()));
        
        emit LogObjectSetInitialized(address(_instance));
    }

    function getInstance() external view returns (IInstance) {
        return _instance;
    }

    function _add(NftId componentNftId, NftId objectNftId) internal {
        LibNftIdSet.Set storage allSet = _allObjects[componentNftId];
        LibNftIdSet.Set storage activeSet = _activeObjects[componentNftId];

        LibNftIdSet.add(allSet, objectNftId);
        LibNftIdSet.add(activeSet, objectNftId);
    }

    function _activate(NftId componentNftId, NftId objectNftId) internal {
        LibNftIdSet.add(_activeObjects[componentNftId], objectNftId);
    }

    function _deactivate(NftId componentNftId, NftId objectNftId) internal {
        LibNftIdSet.remove(_activeObjects[componentNftId], objectNftId);
    }

    function _objects(NftId componentNftId) internal view returns (uint256) {
        return LibNftIdSet.size(_allObjects[componentNftId]);
    }

    function _contains(NftId componentNftId, NftId objectNftId) internal view returns (bool) {
        return LibNftIdSet.contains(_allObjects[componentNftId], objectNftId);
    }

    function _getObject(NftId componentNftId, uint256 idx) internal view returns (NftId) {
        return LibNftIdSet.getElementAt(_allObjects[componentNftId], idx);
    }

    function _activeObjs(NftId componentNftId) internal view returns (uint256)  {
        return LibNftIdSet.size(_activeObjects[componentNftId]);
    }

    function _isActive(NftId componentNftId, NftId objectNftId) internal view returns (bool) {
        return LibNftIdSet.contains(_activeObjects[componentNftId], objectNftId);
    }

    function _getActiveObject(NftId componentNftId, uint256 idx) internal view returns (NftId) {
        return LibNftIdSet.getElementAt(_activeObjects[componentNftId], idx);
    }
}