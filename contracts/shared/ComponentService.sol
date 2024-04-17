// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistryService} from "../registry/IRegistryService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IAccess} from "../instance/module/IAccess.sol";
import {ObjectType, INSTANCE, REGISTRY} from "../type/ObjectType.sol";
import {NftId} from "../type/NftId.sol";
import {RoleId} from "../type/RoleId.sol";

import {Service} from "../shared/Service.sol";
import {InstanceService} from "../instance/InstanceService.sol";
import {InstanceAccessManager} from "../instance/InstanceAccessManager.sol";

abstract contract ComponentService is
    Service
{

    error ErrorComponentServiceNotComponent(address component);
    error ErrorComponentServiceInvalidType(address component, ObjectType requiredType, ObjectType componentType);
    error ErrorComponentServiceSenderNotOwner(address component, address initialOwner, address sender);
    error ErrorComponentServiceExpectedRoleMissing(NftId instanceNftId, RoleId requiredRole, address sender);
    error ErrorComponentServiceComponentLocked(address component);
    error ErrorComponentServiceSenderNotService(address sender);
    error ErrorComponentServiceComponentTypeInvalid(address component, ObjectType expectedType, ObjectType foundType);

    // view functions

    function getRegistryService() public view virtual returns (IRegistryService) {
        return IRegistryService(_getServiceAddress(REGISTRY()));
    }

    function getInstanceService() public view returns (InstanceService) {
        return InstanceService(_getServiceAddress(INSTANCE()));
    }

    // internal functions
    function _checkComponentForRegistration(
        address componentAddress,
        ObjectType requiredType,
        RoleId requiredRole
    )
        internal
        view
        returns (
            IInstanceLinkedComponent component,
            address owner,
            IInstance instance,
            NftId instanceNftId
        )
    {
        // component may only be registerd by initial owner of component
        owner = msg.sender;

        // check this is a component
        component = IInstanceLinkedComponent(componentAddress);
        if(!component.supportsInterface(type(IInstanceLinkedComponent).interfaceId)) {
            revert ErrorComponentServiceNotComponent(componentAddress);
        }

        // check component is of required type
        IRegistry.ObjectInfo memory componentInfo = component.getInitialInfo();
        if(componentInfo.objectType != requiredType) {
            revert ErrorComponentServiceInvalidType(componentAddress, requiredType, componentInfo.objectType);
        }

        // check msg.sender is component owner
        address initialOwner = componentInfo.initialOwner;
        if(owner != initialOwner) {
            revert ErrorComponentServiceSenderNotOwner(componentAddress, componentInfo.initialOwner, owner);
        }

        // check instance has assigned required role to owner
        instanceNftId = componentInfo.parentNftId;
        instance = _getInstance(instanceNftId);
        if(!instance.getInstanceAccessManager().hasRole(requiredRole, owner)) {
            revert ErrorComponentServiceExpectedRoleMissing(instanceNftId, requiredRole, owner);
        }
    }

    // internal view functions
    function _getAndVerifyCallingComponentAndInstance(
        ObjectType expectedType // assume always of `component` type
    )
        internal
        view
        returns(
            NftId componentNftId,
            IRegistry.ObjectInfo memory componentInfo, 
            IInstance instance
        )
    {
        componentNftId = getRegistry().getNftId(msg.sender);
        (componentInfo, instance) = _getAndVerifyComponentInfoAndInstance(componentNftId, expectedType);

        // locked component can not call services
        if (instance.getInstanceAccessManager().isTargetLocked(componentInfo.objectAddress)) {
            revert IAccess.ErrorIAccessTargetLocked(componentInfo.objectAddress);
        }
    }

    function _getAndVerifyComponentInfoAndInstance(
        NftId componentNftId,
        ObjectType expectedType // assume always of `component` type
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory componentInfo, 
            IInstance instance
        )
    {
        componentInfo = getRegistry().getObjectInfo(componentNftId);
        if(componentInfo.objectType != expectedType) {
            revert ErrorComponentServiceComponentTypeInvalid(
                componentInfo.objectAddress, 
                expectedType, 
                componentInfo.objectType);
        }

        instance = _getInstance(componentInfo.parentNftId);
    }
    // assume componentNftId is always of `instance` type
    function _getInstance(NftId instanceNftId) internal view returns (IInstance) {
        return IInstance(
            getRegistry().getObjectInfo(
                instanceNftId).objectAddress);
    }
    // assume componentNftId is always of `component` type
    /*function _getInstanceForComponent(NftId componentNftId) internal view returns (IInstance) {
        NftId instanceNftId = getRegistry().getObjectInfo(componentNftId).parentNftId;
        address instanceAddress = getRegistry().getObjectInfo(instanceNftId).objectAddress;
        return IInstance(instanceAddress);
    }*/

    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return getRegistry().getServiceAddress(domain, getVersion().toMajorPart());
    }
}