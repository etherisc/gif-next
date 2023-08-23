// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {RegistryLinked} from "../../registry/Registry.sol";
import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IAccessComponentTypeRoles, IAccessCheckRole} from "../access/IAccess.sol";
import {IInstance} from "../IInstance.sol";

import {IComponent, IComponentContract, IComponentModule, IComponentOwnerService} from "./IComponent.sol";


abstract contract ComponentModule is 
    IRegistryLinked,
    IAccessComponentTypeRoles,
    IAccessCheckRole,
    IComponentModule
{

    mapping(uint256 id => ComponentInfo info) private _info;
    mapping(address cAddress => uint256 id) private _idByAddress;
    uint256 [] private _ids;

    mapping(uint256 cType => bytes32 role) private _componentOwnerRole;

    IComponentOwnerService private _componentOwnerService;

    modifier onlyComponentOwnerService() {
        require(address(_componentOwnerService) == msg.sender, "ERROR:CMP-001:NOT_OWNER_SERVICE");
        _;
    }

    constructor(address componentOwnerService) {
        _componentOwnerService = ComponentOwnerService(componentOwnerService);
    }

    function registerComponent(IComponentContract component)
        external
        override
        onlyComponentOwnerService
        returns(uint256 nftId)
    {
        bytes32 typeRole = getRoleForType(component.getType());
        require(
            this.hasRole(typeRole, component.getInitialOwner()),
            "ERROR:CMP-004:TYPE_ROLE_MISSING");
        
        nftId = this.getRegistry().register(address(component));

        _info[nftId] = ComponentInfo(
            nftId,
            CState.Active);

        _idByAddress[address(component)] = nftId;
        _ids.push(nftId);

        // add logging
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
        returns(uint256 nftId)
    {
        uint256 id = info.nftId;
        require(
            id > 0 && _info[id].nftId == id,
            "ERROR:CMP-005:COMPONENT_UNKNOWN");

        _info[id] = info;

        // add logging
    }

    function getComponentInfo(uint256 id)
        external
        override
        view
        returns(ComponentInfo memory)
    {
        return _info[id];
    }

    function getComponentOwner(uint256 id)
        external
        view
        returns(address owner)
    {

    }

    function getComponentId(address componentAddress)
        external
        view
        returns(uint256 id)
    {
        return _idByAddress[componentAddress];
    }


    function getComponentId(uint256 idx)
        external
        override
        view
        returns(uint256 id)
    {
        return _ids[idx];
    }


    function components()
        external
        override
        view
        returns(uint256 numberOfCompnents)
    {
        return _ids.length;
    }

    function getRoleForType(uint256 cType)
        public
        view
        returns(bytes32 role)
    {
        if(cType == this.getRegistry().PRODUCT()) {
            return this.PRODUCT_OWNER_ROLE();
        }
        if(cType == this.getRegistry().POOL()) {
            return this.POOL_OWNER_ROLE();
        }
        if(cType == this.getRegistry().ORACLE()) {
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

    modifier onlyComponentOwner(IComponentContract component) {
        uint256 nftId = _registry.getNftId(address(component));
        require(
            nftId > 0, 
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


    // modifier onlyComponentOwnerRole(IComponentContract component) {
    //     IInstance instance = component.getInstance();
    //     // TODO add set/getComponentOwnerRole to IComonentModule
    //     bytes32 typeRole = instance.getComponentTypeRole(component.getType());
    //     require(
    //         instance.hasRole(typeRole, msg.sender),
    //         "ERROR:COS-003:COMPONENT_ROLE_MISSING"
    //     );
    //     _;
    // }


    function register(IComponentContract component)
        external
        override
        returns(uint256 nftId)
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
        require(info.nftId > 0, "ERROR_COMPONENT_UNKNOWN");
        // TODO add state change validation

        info.state = CState.Locked;
        instance.setComponentInfo(info);
    }


    function unlock(IComponentContract component)
        external
        override
        onlyComponentOwner(component)
    {
        IInstance instance = component.getInstance();
        ComponentInfo memory info = instance.getComponentInfo(component.getNftId());
        require(info.nftId > 0, "ERROR_COMPONENT_UNKNOWN");
        // TODO state change validation

        info.state = CState.Active;
        instance.setComponentInfo(info);
    }

}