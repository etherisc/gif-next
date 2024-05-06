// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId} from "../type/NftId.sol";

contract NftIdSetManager {

    error ErrorNftIdSetManagerNotOwner(address owner, address sender);
    error ErrorNftIdSetManagerOwnerAlreadySet(address owner);
    error ErrorNftIdSetManagerNftIdInvalid(NftId objectNftId);
    error ErrorNftIdSetManagerAlreadyAdded(NftId objectNftId);

    LibNftIdSet.Set private _allObjects;
    LibNftIdSet.Set private _activeObjects;
    address private _owner;

    modifier onlyOwner() {
        if(msg.sender != _owner) {
            revert ErrorNftIdSetManagerNotOwner(_owner, msg.sender);
        }
        _;
    }

    function setOwner(address owner) external {
        if(_owner != address(0)) {
            revert ErrorNftIdSetManagerOwnerAlreadySet(_owner);
        }

        _owner = owner;
    }

    function add(NftId objectNftId) external onlyOwner {
        LibNftIdSet.add(_allObjects, objectNftId);
        LibNftIdSet.add(_activeObjects, objectNftId);
    }

    function activate(NftId componentNftId, NftId objectNftId) external onlyOwner {
        LibNftIdSet.add(_activeObjects, objectNftId);
    }

    function deactivate(NftId componentNftId, NftId objectNftId) external onlyOwner {
        LibNftIdSet.remove(_activeObjects, objectNftId);
    }

    function nftIds() external view returns (uint256 ids) {
        return LibNftIdSet.size(_allObjects);
    }

    function getNftId(uint256 idx) external view returns (NftId) {
        return LibNftIdSet.getElementAt(_allObjects, idx);
    }

    function exists(NftId objectNftId) external view returns (bool) {
        return LibNftIdSet.contains(_allObjects, objectNftId);
    }

    function activeNftIds() external view returns (uint256 ids) {
        return LibNftIdSet.size(_activeObjects);
    }

    function getActiveNftId(uint256 idx) external view returns (NftId) {
        return LibNftIdSet.getElementAt(_activeObjects, idx);
    }

    function isActive(NftId objectNftId) external view returns (bool) {
        return LibNftIdSet.contains(_activeObjects, objectNftId);
    }
}
