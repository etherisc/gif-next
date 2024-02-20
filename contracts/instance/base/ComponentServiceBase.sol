// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

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

abstract contract ComponentServiceBase is Service {

    error ErrorComponentServiceBaseComponentLocked(address componentAddress);
    error ExpectedRoleMissing(RoleId expected, address caller);
    error ComponentTypeInvalid(ObjectType componentType);


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

        InstanceAccessManager accessManager = InstanceAccessManager(instance.authority());
        if (accessManager.isTargetLocked(info.objectAddress)) {
            revert IAccess.ErrorIAccessTargetLocked(info.objectAddress);
        }
    }
}
