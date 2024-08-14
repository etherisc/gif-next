// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Cloneable} from "./Cloneable.sol";

import {IInstance} from "../IInstance.sol";
import {LibKey32Set} from "../../type/Key32Set.sol";
import {NftId} from "../../type/NftId.sol";
import {Key32} from "../../type/Key32.sol";

contract ObjectSet is
    Cloneable
{
    using LibKey32Set for LibKey32Set.Set;

    event LogObjectSetInitialized(address instance);

    error ErrorObjectSetNftIdInvalid(NftId instanceNftId);

    mapping(NftId compnentNftId => LibKey32Set.Set objects) internal _activeObjects;
    mapping(NftId compnentNftId => LibKey32Set.Set objects) internal _allObjects;
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

    function _add(NftId componentNftId, Key32 key) internal {
        LibKey32Set.Set storage allSet = _allObjects[componentNftId];
        LibKey32Set.Set storage activeSet = _activeObjects[componentNftId];

        allSet.add(key);
        activeSet.add(key);
    }

    function _activate(NftId componentNftId, Key32 key) internal {
        _activeObjects[componentNftId].add(key);
    }

    function _deactivate(NftId componentNftId, Key32 key) internal {
        _activeObjects[componentNftId].remove(key);
    }

    function _objects(NftId componentNftId) internal view returns (uint256) {
        return _allObjects[componentNftId].size();
    }

    function _contains(NftId componentNftId, Key32 key) internal view returns (bool) {
        return _allObjects[componentNftId].contains(key);
    }

    function _getObject(NftId componentNftId, uint256 idx) internal view returns (Key32) {
        return _allObjects[componentNftId].getElementAt(idx);
    }

    function _activeObjs(NftId componentNftId) internal view returns (uint256)  {
        return _activeObjects[componentNftId].size();
    }

    function _isActive(NftId componentNftId, Key32 key) internal view returns (bool) {
        return _activeObjects[componentNftId].contains(key);
    }

    function _getActiveObject(NftId componentNftId, uint256 idx) internal view returns (Key32) {
        return _activeObjects[componentNftId].getElementAt(idx);
    }
}
