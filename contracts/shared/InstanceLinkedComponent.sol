// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Amount} from "../type/Amount.sol";
import {Component} from "./Component.sol";
import {IComponentService} from "./IComponentService.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {IAuthorization} from "../authorization/IAuthorization.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, INSTANCE, PRODUCT} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {IAccess} from "../authorization/IAccess.sol";
import {TokenHandler} from "../shared/TokenHandler.sol";
import {VersionPart} from "../type/Version.sol";

// then add (Distribution|Pool|Product)Upradeable that also intherit from Versionable
// same pattern as for Service which is also upgradeable
abstract contract InstanceLinkedComponent is
    Component,
    IInstanceLinkedComponent
{
    // keccak256(abi.encode(uint256(keccak256("gif-next.contracts.component.Component.sol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant INSTANCE_LINKED_COMPONENT_LOCATION_V1 = 0xffe3d4462bded26a47154f4b8f6db494d2f772496965791d25bd456e342b7f00;

    struct InstanceLinkedComponentStorage {
        IInstance _instance; // instance for this component
        InstanceReader _instanceReader; // instance reader for this component
        IAuthorization _initialAuthorization;
        IComponentService _componentService;
    }

    /// @inheritdoc IInstanceLinkedComponent
    function withdrawFees(Amount amount)
        external
        virtual
        restricted()
        onlyOwner()
        returns (Amount withdrawnAmount)
    {
        return _withdrawFees(amount);
    }

    /// @inheritdoc IInstanceLinkedComponent
    function getInstance() public view virtual override returns (IInstance instance) {
        return _getInstanceLinkedComponentStorage()._instance;
    }

    /// @inheritdoc IInstanceLinkedComponent
    function getAuthorization() external view virtual returns (IAuthorization authorization) {
        return _getInstanceLinkedComponentStorage()._initialAuthorization;
    }

    function _getInstanceLinkedComponentStorage() private pure returns (InstanceLinkedComponentStorage storage $) {
        assembly {
            $.slot := INSTANCE_LINKED_COMPONENT_LOCATION_V1
        }
    }

    function __InstanceLinkedComponent_init(
        address registry,
        NftId parentNftId,
        string memory name,
        ObjectType componentType,
        IAuthorization authorization,
        bool isInterceptor,
        address initialOwner,
        bytes memory componentData // data that will saved with the component info in the instance store
    )
        internal
        virtual
        onlyInitializing()
    {
        // validate registry, nft ids and get parent nft id
        NftId instanceNftId = _checkAndGetInstanceNftId(
            registry, 
            parentNftId, 
            componentType);

        // set and check linked instance
        InstanceLinkedComponentStorage storage $ = _getInstanceLinkedComponentStorage();
        $._instance = IInstance(
            IRegistry(registry).getObjectAddress(instanceNftId));

        // set component specific parameters
        __Component_init(
            $._instance.authority(), // instance linked components need to point to instance admin
            registry, 
            parentNftId, 
            name, 
            componentType, 
            isInterceptor, 
            initialOwner, 
            "", // registry data
            componentData);

        // set instance linked specific parameters
        $._instanceReader = $._instance.getInstanceReader();
        $._initialAuthorization = authorization;
        $._componentService = IComponentService(_getServiceAddress(COMPONENT())); 

        // register interfaces
        _registerInterface(type(IInstanceLinkedComponent).interfaceId);
    }


    function _checkAndGetInstanceNftId(
        address registryAddress,
        NftId parentNftId,
        ObjectType componentType
    )
        internal
        view
        returns (NftId instanceNftId)
    {
        // if product, then parent is already instance
        if (componentType == PRODUCT()) {
            _checkAndGetRegistry(registryAddress, parentNftId, INSTANCE());
            return parentNftId;
        }

        // if not product parent is product, and parent of product is instance
        IRegistry registry = _checkAndGetRegistry(registryAddress, parentNftId, PRODUCT());
        return registry.getParentNftId(parentNftId);
    }

    /// @dev checks the and gets registry.
    /// validates registry using a provided nft id and expected object type.
    function _checkAndGetRegistry(
        address registryAddress,
        NftId objectNftId,
        ObjectType requiredType
    )
        internal
        view
        returns (IRegistry registry)
    {
        registry = IRegistry(registryAddress);
        IRegistry.ObjectInfo memory info = registry.getObjectInfo(objectNftId);

        if (info.objectType != requiredType) {
            revert ErrorInstanceLinkedComponentTypeMismatch(requiredType, info.objectType);
        }
    }


    /// @dev for instance linked components the wallet address stored in the instance store.
    /// updating needs to go throug component service
    function _setWallet(address newWallet) internal virtual override onlyOwner {
        IComponentService(_getServiceAddress(COMPONENT())).setWallet(newWallet);
    }


    function _getComponentInfo() internal virtual override view returns (IComponents.ComponentInfo memory info) {
        NftId componentNftId = getRegistry().getNftIdForAddress(address(this));

        // if registered, attempt to return component info via instance reader
        if (componentNftId.gtz()) {
            // component registerd with registry
            info = _getInstanceReader().getComponentInfo(getNftId());

            // check if also registered with instance
            if (address(info.tokenHandler) != address(0)) {
                return info;
            }
        }

        // return data from component contract if not yet registered
        return super._getComponentInfo();
    }


    /// @dev returns reader for linked instance
    function _getInstanceReader() internal view returns (InstanceReader reader) {
        return _getInstanceLinkedComponentStorage()._instanceReader;
    }

    function _withdrawFees(Amount amount)
        internal
        returns (Amount withdrawnAmount)
    {
        return _getInstanceLinkedComponentStorage()._componentService.withdrawFees(amount);
    }
}