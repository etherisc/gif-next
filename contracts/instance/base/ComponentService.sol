// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IComponent} from "../../components/IComponent.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {IAccess} from "../module/IAccess.sol";
import {ObjectType, INSTANCE, REGISTRY} from "../../types/ObjectType.sol";
import {NftId} from "../../types/NftId.sol";
import {RoleId} from "../../types/RoleId.sol";

import {Service} from "../../shared/Service.sol";
import {InstanceService} from "../InstanceService.sol";
import {InstanceAccessManager} from "../InstanceAccessManager.sol";

abstract contract ComponentService is Service {

    error ErrorComponentServiceAlreadyRegistered(address component, NftId nftId);
    error ErrorComponentServiceNotComponent(address component);
    error ErrorComponentServiceInvalidType(address component, ObjectType requiredType, ObjectType componentType);
    error ErrorComponentServiceSenderNotOwner(address component, address initialOwner, address sender);
    error ErrorComponentServiceExpectedRoleMissing(NftId instanceNftId, RoleId requiredRole, address sender);
    error ErrorComponentServiceComponentLocked(address component);

    /// @dev modifier to check if caller is a registered service
    modifier onlyService() {
        address caller = msg.sender;
        require(getRegistry().isRegisteredService(caller), "ERROR_NOT_SERVICE");
        _;
    }

    // view functions

    function getRegistryService() public view virtual returns (IRegistryService) {
        address service = getRegistry().getServiceAddress(REGISTRY(), getMajorVersion());
        return IRegistryService(service);
    }

    function getInstanceService() public view returns (InstanceService) {
        address service = getRegistry().getServiceAddress(INSTANCE(), getMajorVersion());
        return InstanceService(service);
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
            IComponent component,
            address owner,
            IInstance instance,
            NftId instanceNftId
        )
    {
        // component may only be registerd by initial owner of component
        owner = msg.sender;

        // check component has not already been registerd
        NftId compoentNftId = getRegistry().getNftId(componentAddress);
        if(compoentNftId.gtz()) {
            revert ErrorComponentServiceAlreadyRegistered(componentAddress, compoentNftId);
        }

        // check this is a component
        component = IComponent(componentAddress);
        if(!component.supportsInterface(type(IComponent).interfaceId)) {
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
        InstanceAccessManager accessManager = instance.getInstanceAccessManager();
        bool hasRole = accessManager.hasRole(
            requiredRole,
            owner);

        if(!hasRole) {
            revert ErrorComponentServiceExpectedRoleMissing(instanceNftId, requiredRole, owner);
        }
    }

    // internal view functions

    function _getInstance(NftId instanceNftId) internal view returns (IInstance) {
        IRegistry.ObjectInfo memory instanceInfo = getRegistry().getObjectInfo(instanceNftId);
        return IInstance(instanceInfo.objectAddress);
    }

    function _getAndVerifyComponentInfoAndInstance(
        //address component,
        ObjectType expectedType
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        IRegistry registry = getRegistry();
        //TODO redundant check -> just check type
        //NftId componentNftId = registry.getNftId(component); 
        //require(componentNftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info = registry.getObjectInfo(msg.sender);
        require(info.objectType == expectedType, "OBJECT_TYPE_INVALID");

        address instanceAddress = registry.getObjectInfo(info.parentNftId).objectAddress;
        instance = IInstance(instanceAddress);

        InstanceAccessManager accessManager = instance.getInstanceAccessManager();
        if (accessManager.isTargetLocked(info.objectAddress)) {
            revert IAccess.ErrorIAccessTargetLocked(info.objectAddress);
        }
    }
}
