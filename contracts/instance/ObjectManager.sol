// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Cloneable} from "./Cloneable.sol";

import {IInstance} from "./IInstance.sol";
import {INSTANCE} from "../types/ObjectType.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {LibNftIdSet} from "../types/NftIdSet.sol";
import {NftId} from "../types/NftId.sol";

contract ObjectManager is
    Cloneable
{

    event LogObjectManagerInitialized(NftId instanceNftId, address instanceReader);

    error ErrorObjectManagerNftIdInvalid(NftId instanceNftId);
    error ErrorObjectManagerAlreadyAdded(NftId componentNftId, NftId objectNftId);

    mapping(NftId compnentNftId => LibNftIdSet.Set objects) internal _activeObjects;
    mapping(NftId compnentNftId => LibNftIdSet.Set objects) internal _allObjects;
    NftId internal _instanceNftId;
    InstanceReader internal _instanceReader;

    constructor() Cloneable() {
        _instanceReader = InstanceReader(address(0));
    }

    /// @dev call to initialize MUST be made in the same transaction as cloning of the contract
    function initialize(
        address authority,
        address registry,
        NftId instanceNftId
    )
        external 
    {
        initialize(authority, registry);

        // check/handle instance nft id/instance reader
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        if (instanceInfo.objectType != INSTANCE()) {
            revert ErrorObjectManagerNftIdInvalid(instanceNftId);
        }

        IInstance instance = IInstance(instanceInfo.objectAddress);
        _instanceReader = instance.getInstanceReader();
        _instanceNftId = instanceNftId;
        
        emit LogObjectManagerInitialized(instanceNftId, address(_instanceReader));
    }

    function getInstanceReader() external view returns (InstanceReader) {
        return _instanceReader;
    }

    function getInstanceNftId() external view returns (NftId) {
        return _instanceNftId;
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
