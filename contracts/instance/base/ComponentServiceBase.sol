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

    mapping (ObjectType => RoleId) internal _objectTypeToExpectedRole;

    /// @dev modifier to check if caller has a role on the instance the component is registered in
    modifier onlyComponentOwnerRole(address componentAddress) {
        BaseComponent component = BaseComponent(componentAddress);
        ObjectType objectType = _getObjectType(component);
        RoleId expectedRole = _objectTypeToExpectedRole[objectType];

        address componentOwner = msg.sender;
        INftOwnable nftOwnable = INftOwnable(address(component.getInstance()));
        if(! getInstanceService().hasRole(componentOwner, expectedRole, nftOwnable.getNftId())) {
            revert ExpectedRoleMissing(expectedRole, componentOwner);
        }
        _;
    }

    /// @dev modifier to check if caller is a registered service
    modifier onlyService() {
        address caller = msg.sender;
        require(getRegistry().isRegisteredService(caller), "ERROR_NOT_SERVICE");
        _;
    }

    function _initializeService(
        address registry, 
        address initialOwner
    )
        internal
        override
    {
        super._initializeService(registry, initialOwner);
        _objectTypeToExpectedRole[PRODUCT()] = PRODUCT_OWNER_ROLE();
        _objectTypeToExpectedRole[POOL()] = POOL_OWNER_ROLE();
        _objectTypeToExpectedRole[DISTRIBUTION()] = DISTRIBUTION_OWNER_ROLE();
        _objectTypeToExpectedRole[ORACLE()] = ORACLE_OWNER_ROLE();
    }

    function getInstanceService() public view returns (InstanceService) {
        return InstanceService(getRegistry().getServiceAddress(INSTANCE(), getMajorVersion()));
    }

    function register(address componentAddress) 
        external 
        onlyComponentOwnerRole(componentAddress)
        returns (NftId componentNftId)
    {
        address componentOwner = msg.sender;
        BaseComponent component = BaseComponent(componentAddress);
        ObjectType objectType = _getObjectType(component);
        IRegistryService registryService = getRegistryService();

        IRegistry.ObjectInfo memory objInfo;
        bytes memory initialObjData;

        if (objectType == DISTRIBUTION()) {
            (objInfo, initialObjData) = registryService.registerDistribution(component, componentOwner);
        } else if (objectType == PRODUCT()) {
            (objInfo, initialObjData) = registryService.registerProduct(component, componentOwner);
        } else if (objectType == POOL()) {
            (objInfo, initialObjData) = registryService.registerPool(component, componentOwner);
        // TODO: implement this for oracle - currently missing in registry
        // } else if (objectType == ORACLE()) {
        //     (objInfo, initialObjData) = registryService.registerOracle(component, componentOwner);
        } else {
            revert ComponentTypeInvalid(objectType);
        }

        componentNftId = objInfo.nftId;
        {
            IInstance instance = _getInstance(objInfo);
            _finalizeComponentRegistration(componentNftId, initialObjData, instance);
        }
    }

    function _finalizeComponentRegistration(NftId componentNftId, bytes memory initialObjData, IInstance instance) internal virtual;

    function _getObjectType(BaseComponent component) internal view returns (ObjectType) {
        (IRegistry.ObjectInfo memory compInitialInfo, )  = component.getInitialInfo();
        return compInitialInfo.objectType;
    }
    
    function _getInstance(IRegistry.ObjectInfo memory compObjInfo) internal view returns (IInstance) {
        IRegistry registry = getRegistry();
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(compObjInfo.parentNftId);
        return IInstance(instanceInfo.objectAddress);
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
        address service = getRegistry().getServiceAddress(SERVICE(), getMajorVersion());
        return IRegistryService(service);
    }
}
