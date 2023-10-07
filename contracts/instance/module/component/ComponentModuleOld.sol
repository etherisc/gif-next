// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../../registry/IRegistry.sol";
import {IInstance} from "../../IInstance.sol";

import {IComponent, IComponentModuleOld} from "./IComponent.sol";
import {IComponentOwnerService} from "../../service/IComponentOwnerService.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../../types/NftId.sol";
import {Fee} from "../../../types/Fee.sol";

abstract contract ComponentModuleOld is
    IComponentModuleOld
{
    using NftIdLib for NftId;

    mapping(NftId nftId => ComponentInfoOld info) private _ComponentInfoOld;
    NftId[] private _nftIds;

    mapping(ObjectType cType => bytes32 role) private _componentOwnerRole;

    modifier onlyComponentOwnerService() {
        require(
            msg.sender == address(this.getComponentOwnerService()),
            "ERROR:CMP-001:NOT_OWNER_SERVICE"
        );
        _;
    }

    function registerComponent(
        NftId nftId,
        ObjectType, // objectType,
        IERC20Metadata token
    ) external override onlyComponentOwnerService {

        // create component info
        _ComponentInfoOld[nftId] = ComponentInfoOld(
            nftId,
            // _lifecycleModule.getInitialState(objectType),
            ACTIVE(),
            token
        );

        _nftIds.push(nftId);

        // TODO add logging
    }

    function setComponentInfoOld(
        ComponentInfoOld memory info
    ) external onlyComponentOwnerService returns (NftId nftId) {
        nftId = info.nftId;
        require(
            nftId.gtz() && _ComponentInfoOld[nftId].nftId.eq(nftId),
            "ERROR:CMP-006:COMPONENT_UNKNOWN"
        );

        // TODO decide if state changes should have explicit functions and not
        // just a generic setXYZInfo and implicit state transitions
        // when in doubt go for the explicit approach ...
        // ObjectType objectType = this.getRegistry().getObjectInfo(nftId).objectType;
        // _lifecycleModule.checkAndLogTransition(
        //     nftId,
        //     objectType,
        //     _ComponentInfoOld[nftId].state,
        //     info.state
        // );
        _ComponentInfoOld[nftId] = info;
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
    ) external view override returns (ComponentInfoOld memory) {
        return _ComponentInfoOld[nftId];
    }
}
