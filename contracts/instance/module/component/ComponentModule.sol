// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../../registry/IRegistry.sol";

import {IProductService} from "../../service/IProductService.sol";
import {IPoolService} from "../../service/IPoolService.sol";

import {NftId} from "../../../types/NftId.sol";
import {Key32, KeyId} from "../../../types/Key32.sol";
import {LibNftIdSet} from "../../../types/NftIdSet.sol";
import {ObjectType, COMPONENT, PRODUCT, ORACLE, POOL, BUNDLE, POLICY} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED, ARCHIVED, CLOSED, APPLIED, REVOKED, DECLINED} from "../../../types/StateId.sol";
import {Timestamp, blockTimestamp, zeroTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

import {IComponentModule} from "./IComponent.sol";

abstract contract ComponentModule is 
    ModuleBase,
    IComponentModule
{

    NftId[] private _nftIds;

    modifier onlyComponentOwnerService() {
        require(
            msg.sender == address(this.getComponentOwnerService()),
            "ERROR:CMP-001:NOT_OWNER_SERVICE"
        );
        _;
    }

    function initializeComponentModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore, COMPONENT());
    }

    function registerComponent(
        NftId nftId,
        ObjectType, // objectType,
        IERC20Metadata token
    )
        external
        onlyComponentOwnerService
        override
    {
        ComponentInfo memory info = ComponentInfo(
            nftId,
            token
        );

        _nftIds.push(nftId);

        _create(nftId, abi.encode(info));
    }

    function setComponentInfo(ComponentInfo memory info)
        external
        override
        onlyComponentOwnerService
    {
        _updateData(info.nftId, abi.encode(info));
    }

    function updateComponentState(NftId nftId, StateId state)
        external
        override
        onlyComponentOwnerService
    {
        _updateState(nftId, state);
    }

    function getComponentCount()
        external
        view
        override
        returns (uint256 numberOfCompnents)
    {
        return _nftIds.length;
    }

    function getComponentId(
        uint256 idx
    ) external view override returns (NftId componentNftId) {
        return _nftIds[idx];
    }

    function getComponentInfo(NftId nftId) external view override returns(ComponentInfo memory info) {
        return abi.decode(_getData(nftId), (ComponentInfo));
    }

    function getComponentState(NftId nftId) external view returns (StateId state) {
        return _getState(nftId);
    }

    function toComponentKey32(NftId nftId) external view override returns (Key32 key32) {
        return _toKey32(nftId);
    } 
}