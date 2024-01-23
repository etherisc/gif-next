// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRegistry} from "../../registry/IRegistry.sol";
import {IRegistryService} from "../../registry/IRegistryService.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {ObjectType, INSTANCE, PRODUCT, POOL} from "../../types/ObjectType.sol";
import {NftId, NftIdLib} from "../../types/NftId.sol";
import {RoleId} from "../../types/RoleId.sol";
import {BaseComponent} from "../../components/BaseComponent.sol";

import {INftOwnable} from "../../shared/INftOwnable.sol";
import {Service} from "../../shared/Service.sol";
import {InstanceService} from "../InstanceService.sol";
import {Version, VersionPart, VersionLib} from "../../types/Version.sol";

abstract contract ComponentServiceBase is Service {

    error InvalidRole(RoleId expected, address caller);

    /// @dev modifier to check if caller has a role on the instance the component is registered in
    modifier onlyInstanceRole(RoleId role, address componentAddress) {
        address componentOwner = msg.sender;
        BaseComponent component = BaseComponent(componentAddress);
        INftOwnable nftOwnable = INftOwnable(address(component.getInstance()));
        if(! getInstanceService().hasRole(componentOwner, role, nftOwnable.getNftId())) {
            revert InvalidRole(role, componentOwner);
        }
        _;
    }

    function getInstanceService() public view returns (InstanceService) {
        return InstanceService(getRegistry().getServiceAddress("InstanceService", getMajorVersion()));
    }

    function _getAndVerifyComponentInfoAndInstance(
        ObjectType objectType
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            IInstance instance
        )
    {
        NftId componentNftId = _registry.getNftId(msg.sender);
        require(componentNftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info = getRegistry().getObjectInfo(componentNftId);
        require(info.objectType == objectType, "OBJECT_TYPE_INVALID");

        address instanceAddress = getRegistry().getObjectInfo(info.parentNftId).objectAddress;
        instance = IInstance(instanceAddress);
    }

    function getRegistryService() public view virtual returns (IRegistryService) {
        address service = getRegistry().getServiceAddress("RegistryService", getMajorVersion());
        return IRegistryService(service);
    }
}
