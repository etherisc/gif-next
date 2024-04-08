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
        return IRegistryService(_getServiceAddress(REGISTRY()));
    }

    function getInstanceService() public view returns (InstanceService) {
        return InstanceService(_getServiceAddress(INSTANCE()));
    }

    function _getServiceAddress(ObjectType domain) internal view returns (address) {
        return getRegistry().getServiceAddress(domain, getVersion().toMajorPart());
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
        if(!instance.getInstanceAccessManager().hasRole(requiredRole, owner)) {
            revert ErrorComponentServiceExpectedRoleMissing(instanceNftId, requiredRole, owner);
        }
    }

    // internal view functions

    function _getAndVerifyComponentInfoAndInstance(
        ObjectType expectedType
    )
        internal
        view
        returns(
            NftId nftId,
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        IRegistry registry = getRegistry();

        info = registry.getObjectInfo(msg.sender);
        require(info.objectType == expectedType, "OBJECT_TYPE_INVALID");

        nftId = info.nftId;
        instance = _getInstance(info.parentNftId);

        if (instance.getInstanceAccessManager().isTargetLocked(info.objectAddress)) {
            revert IAccess.ErrorIAccessTargetLocked(info.objectAddress);
        }
    }

    function _getInstance(NftId instanceNftId) internal view returns (IInstance) {
        return IInstance(
            getRegistry().getObjectInfo(
                instanceNftId).objectAddress);
    }
}
