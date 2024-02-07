// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {ObjectType, SERVICE, INSTANCE, PRODUCT, POOL, DISTRIBUTION, ORACLE} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../types/RoleId.sol";

import {BaseComponent} from "../../components/BaseComponent.sol";
import {Product} from "../../components/Product.sol";
import {INftOwnable} from "../../shared/INftOwnable.sol";
import {Service} from "../../shared/Service.sol";
import {InstanceService} from "../InstanceService.sol";
import {Version, VersionPart, VersionLib} from "../../types/Version.sol";

abstract contract ComponentServiceBase is Service {

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
        address service = getRegistry().getServiceAddress(SERVICE(), getMajorVersion());
        return IRegistryService(service);
    }

    function getInstanceService() public view returns (InstanceService) {
        return InstanceService(getRegistry().getServiceAddress(INSTANCE(), getMajorVersion()));
    }

    // internal view functions

    function _getInstance(IRegistry.ObjectInfo memory compObjInfo) internal view returns (IInstance) {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(compObjInfo.parentNftId);
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
    }
}
