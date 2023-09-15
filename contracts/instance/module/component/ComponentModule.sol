// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RegistryLinked} from "../../../registry/Registry.sol";
import {IRegistry, IRegistryLinked} from "../../../registry/IRegistry.sol";
import {IAccessComponentTypeRoles, IAccessCheckRole} from "../access/IAccess.sol";
import {IInstance} from "../../IInstance.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {ITreasuryModule} from "../treasury/ITreasury.sol";
import {TreasuryModule} from "../treasury/TreasuryModule.sol";
import {IComponent, IComponentContract, IComponentModule} from "./IComponent.sol";
import {IComponentOwnerService} from "../../service/IComponentOwnerService.sol";
import {IProductComponent} from "../../../components/IProduct.sol";
import {IPoolComponent} from "../../../components/IPool.sol";
import {IPoolModule} from "../pool/IPoolModule.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../../types/NftId.sol";
import {Fee, zeroFee} from "../../../types/Fee.sol";

abstract contract ComponentModule is
    IRegistryLinked,
    IAccessComponentTypeRoles,
    IAccessCheckRole,
    IComponentModule
{
    using NftIdLib for NftId;

    mapping(NftId nftId => ComponentInfo info) private _componentInfo;
    mapping(address cAddress => NftId nftId) private _nftIdByAddress;
    NftId[] private _nftIds;

    mapping(ObjectType cType => bytes32 role) private _componentOwnerRole;

    // TODO maybe move this to Instance contract as internal variable?
    LifecycleModule private _lifecycleModule;
    TreasuryModule private _treasuryModule;
    IPoolModule private _poolModule;
    IComponentOwnerService private _componentOwnerService;

    modifier onlyComponentOwnerService() {
        require(
            address(_componentOwnerService) == msg.sender,
            "ERROR:CMP-001:NOT_OWNER_SERVICE"
        );
        _;
    }

    constructor(address componentOwnerService) {
        address componentAddress = address(this);
        _lifecycleModule = LifecycleModule(componentAddress);
        _treasuryModule = TreasuryModule(componentAddress);
        _poolModule = IPoolModule(componentAddress);
        _componentOwnerService = IComponentOwnerService(componentOwnerService);
    }

    function registerComponent(
        IComponentContract component,
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

        _nftIdByAddress[address(component)] = nftId;
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

    function getComponentInfo(
        NftId nftId
    ) external view override returns (ComponentInfo memory) {
        return _componentInfo[nftId];
    }

    function getComponentId(
        address componentAddress
    ) external view returns (NftId componentNftId) {
        return _nftIdByAddress[componentAddress];
    }

    function getComponentId(
        uint256 idx
    ) external view override returns (NftId componentNftId) {
        return _nftIds[idx];
    }

    function components()
        external
        view
        override
        returns (uint256 numberOfCompnents)
    {
        return _nftIds.length;
    }

    function getRoleForType(
        ObjectType cType
    ) public view override returns (bytes32 role) {
        if (cType == PRODUCT()) {
            return this.PRODUCT_OWNER_ROLE();
        }
        if (cType == POOL()) {
            return this.POOL_OWNER_ROLE();
        }
        if (cType == ORACLE()) {
            return this.ORACLE_OWNER_ROLE();
        }
    }
}
