// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {IComponent, IComponentModule} from "./IComponent.sol";
import {IComponentOwnerService} from "../../service/IComponentOwnerService.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../../types/NftId.sol";
import {Fee} from "../../../types/Fee.sol";

abstract contract ComponentModule is
    IComponentModule
{
    using NftIdLib for NftId;

    mapping(NftId nftId => ComponentInfo info) private _componentInfo;
    NftId[] private _nftIds;

    mapping(ObjectType cType => bytes32 role) private _componentOwnerRole;

    // TODO maybe move this to Instance contract as internal variable?
    LifecycleModule private _lifecycleModule;

    modifier onlyComponentOwnerService() {
        require(
            msg.sender == address(this.getComponentOwnerService()),
            "ERROR:CMP-001:NOT_OWNER_SERVICE"
        );
        _;
    }

    constructor() {
        address componentAddress = address(this);
        _lifecycleModule = LifecycleModule(componentAddress);
    }

    function registerComponent(
        NftId nftId,
        ObjectType objectType,
        IERC20Metadata token
    ) external override onlyComponentOwnerService {

        // create component info
        _componentInfo[nftId] = ComponentInfo(
            nftId,
            _lifecycleModule.getInitialState(objectType),
            token
        );

        _nftIds.push(nftId);

        // TODO add logging
    }

    function setComponentInfo(
        ComponentInfo memory info
    ) external onlyComponentOwnerService returns (NftId nftId) {
        nftId = info.nftId;
        require(
            nftId.gtz() && _componentInfo[nftId].nftId.eq(nftId),
            "ERROR:CMP-006:COMPONENT_UNKNOWN"
        );

        // TODO decide if state changes should have explicit functions and not
        // just a generic setXYZInfo and implicit state transitions
        // when in doubt go for the explicit approach ...
        ObjectType objectType = this.getRegistry().getObjectInfo(nftId).objectType;
        _lifecycleModule.checkAndLogTransition(
            nftId,
            objectType,
            _componentInfo[nftId].state,
            info.state
        );
        _componentInfo[nftId] = info;
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

    function getComponentInfo(
        NftId nftId
    ) external view override returns (ComponentInfo memory) {
        return _componentInfo[nftId];
    }
}
