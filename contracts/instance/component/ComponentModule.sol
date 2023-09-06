// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {RegistryLinked} from "../../registry/Registry.sol";
import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IAccessComponentTypeRoles, IAccessCheckRole} from "../access/IAccess.sol";
import {IInstance} from "../IInstance.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {IComponent, IComponentContract, IComponentModule, IComponentOwnerService} from "./IComponent.sol";
import {IProductComponent} from "../../components/IProduct.sol";
import {IPoolModule} from "../pool/IPoolModule.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";

abstract contract ComponentModule is 
    IRegistryLinked,
    IAccessComponentTypeRoles,
    IAccessCheckRole,
    IComponentModule
{
    using NftIdLib for NftId;

    mapping(NftId nftId => ComponentInfo info) private _componentInfo;
    mapping(NftId nftId => NftId poolNftId) private _poolNftIdForProduct;
    mapping(address cAddress => NftId nftId) private _nftIdByAddress;
    NftId[] private _nftIds;

    mapping(ObjectType cType => bytes32 role) private _componentOwnerRole;

    // TODO maybe move this to Instance contract as internal variable?
    LifecycleModule private _lifecycleModule;
    IComponentOwnerService private _componentOwnerService;

    modifier onlyComponentOwnerService() {
        require(address(_componentOwnerService) == msg.sender, "ERROR:CMP-001:NOT_OWNER_SERVICE");
        _;
    }

    constructor(address componentOwnerService) {
        _lifecycleModule = LifecycleModule(address(this));
        _componentOwnerService = ComponentOwnerService(componentOwnerService);
    }

    function registerComponent(IComponentContract component)
        external
        override
        onlyComponentOwnerService
        returns(NftId nftId)
    {
        ObjectType objectType = component.getType();
        bytes32 typeRole = getRoleForType(objectType);
        require(
            this.hasRole(typeRole, component.getInitialOwner()),
            "ERROR:CMP-004:TYPE_ROLE_MISSING");
        
        nftId = this.getRegistry().register(address(component));

        _componentInfo[nftId] = ComponentInfo(
            nftId,
            _lifecycleModule.getInitialState(objectType));

        // special case product -> persist product - pool assignment
        if(component.getType() == PRODUCT()) {
            IProductComponent product = IProductComponent(address(component));
            NftId poolNftId = product.getPoolNftId();
            require(poolNftId.gtz(), "ERROR:CMP-005:POOL_UNKNOWN");
            // add more validation (type, token, ...)

            _poolNftIdForProduct[nftId] = poolNftId;

            // add creation of productInfo
        }
        else if(component.getType() == POOL()) {
            IPoolModule poolModule = IPoolModule(address(this));
            poolModule.createPoolInfo(
                nftId,
                address(component), // set pool as its wallet
                address(0) // don't deal with token yet
            );
        }

        _nftIdByAddress[address(component)] = nftId;
        _nftIds.push(nftId);

        // add logging
    }

    function getPoolNftId(NftId productNftId)
        external
        view
        override
        returns(NftId poolNftId)
    {
        poolNftId = _poolNftIdForProduct[productNftId];
    }


    function getComponentOwnerService()
        external
        override
        view
        returns(IComponentOwnerService)
    {
        return _componentOwnerService;
    }

    function setComponentInfo(ComponentInfo memory info)
        external
        onlyComponentOwnerService
        returns(NftId nftId)
    {
        nftId = info.nftId;
        require(
            nftId.gtz() && _componentInfo[nftId].nftId.eq(nftId),
            "ERROR:CMP-006:COMPONENT_UNKNOWN");

        // TODO decide if state changes should have explicit functions and not
        // just a generic setXYZInfo and implicit state transitions
        ObjectType objectType = this.getRegistry().getInfo(nftId).objectType;
        _lifecycleModule.checkAndLogTransition(nftId, objectType, _componentInfo[nftId].state, info.state);
        _componentInfo[nftId] = info;
    }

    function getComponentInfo(NftId nftId)
        external
        override
        view
        returns(ComponentInfo memory)
    {
        return _componentInfo[nftId];
    }

    function getComponentOwner(NftId nftId)
        external
        view
        returns(address owner)
    {

    }

    function getComponentId(address componentAddress)
        external
        view
        returns(NftId componentNftId)
    {
        return _nftIdByAddress[componentAddress];
    }


    function getComponentId(uint256 idx)
        external
        override
        view
        returns(NftId componentNftId)
    {
        return _nftIds[idx];
    }


    function components()
        external
        override
        view
        returns(uint256 numberOfCompnents)
    {
        return _nftIds.length;
    }

    function getRoleForType(ObjectType cType)
        public
        view
        returns(bytes32 role)
    {
        if(cType == PRODUCT()) {
            return this.PRODUCT_OWNER_ROLE();
        }
        if(cType == POOL()) {
            return this.POOL_OWNER_ROLE();
        }
        if(cType == ORACLE()) {
            return this.ORACLE_OWNER_ROLE();
        }

    }
}


// this is actually the component owner service
contract ComponentOwnerService is
    RegistryLinked,
    IComponent,
    IComponentOwnerService
{
    using NftIdLib for NftId;

    modifier onlyComponentOwner(IComponentContract component) {
        NftId nftId = _registry.getNftId(address(component));
        require(
            nftId.gtz(), 
            "ERROR:COS-001:COMPONENT_UNKNOWN");
        require(
            msg.sender == _registry.getOwner(nftId),
            "ERROR:COS-002:NOT_OWNER"
        );
        _;
    }

    constructor(address registry)
        RegistryLinked(registry)
    { }

    function register(IComponentContract component)
        external
        override
        returns(NftId nftId)
    {
        require(
            msg.sender == component.getInitialOwner(), 
            "ERROR:COS-003:NOT_OWNER");

        IInstance instance = component.getInstance();
        nftId = instance.registerComponent(component);
    }


    function lock(IComponentContract component)
        external
        override
        onlyComponentOwner(component)
    {
        IInstance instance = component.getInstance();
        ComponentInfo memory info = instance.getComponentInfo(component.getNftId());
        require(info.nftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info.state = PAUSED();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }


    function unlock(IComponentContract component)
        external
        override
        onlyComponentOwner(component)
    {
        IInstance instance = component.getInstance();
        ComponentInfo memory info = instance.getComponentInfo(component.getNftId());
        require(info.nftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info.state = ACTIVE();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }

}