// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Component} from "./Component.sol";
import {IComponentService} from "./IComponentService.sol";
import {IInstanceLinkedComponent} from "./IInstanceLinkedComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {IInstanceService} from "../instance/IInstanceService.sol";
import {IInstance} from "../instance/IInstance.sol";
import {InstanceAccessManager} from "../instance/InstanceAccessManager.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType, COMPONENT, INSTANCE} from "../type/ObjectType.sol";
import {VersionPart} from "../type/Version.sol";
import {Registerable} from "../shared/Registerable.sol";
import {RoleId, RoleIdLib} from "../type/RoleId.sol";
import {IAccess} from "../instance/module/IAccess.sol";
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
    }

    function _getInstanceLinkedComponentStorage() private pure returns (InstanceLinkedComponentStorage storage $) {
        assembly {
            $.slot := INSTANCE_LINKED_COMPONENT_LOCATION_V1
        }
    }

    function initializeInstanceLinkedComponent(
        address registry,
        NftId instanceNftId,
        string memory name,
        address token,
        ObjectType componentType,
        bool isInterceptor,
        address initialOwner,
        bytes memory registryData, // writeonly data that will saved in the object info record of the registry
        bytes memory componentData // data that will saved with the component info in the instance store
    )
        public
        virtual
        onlyInitializing()
    {
        // set and check linked instance
        InstanceLinkedComponentStorage storage $ = _getInstanceLinkedComponentStorage();
        $._instance = IInstance(
            IRegistry(registry).getObjectInfo(
                instanceNftId).objectAddress);

        if(!$._instance.supportsInterface(type(IInstance).interfaceId)) {
            revert ErrorComponentNotInstance(instanceNftId);
        }

        initializeComponent(
            $._instance.authority(), 
            registry, 
            instanceNftId, 
            name, 
            token,
            componentType, 
            isInterceptor, 
            initialOwner, 
            registryData,
            componentData);

        // set component state
        $._instanceReader = $._instance.getInstanceReader();

        registerInterface(type(IAccessManaged).interfaceId);
        registerInterface(type(IInstanceLinkedComponent).interfaceId);
    }

    /// @dev for instance linked components the wallet address stored in the instance store.
    /// updating needs to go throug component service
    function _setWallet(address newWallet) internal virtual override onlyOwner {
        IComponentService(_getServiceAddress(COMPONENT())).setWallet(newWallet);
    }

    function lock() external onlyOwner {
        IInstanceService(_getServiceAddress(INSTANCE())).setComponentLocked(true);
    }
    
    function unlock() external onlyOwner {
        IInstanceService(_getServiceAddress(INSTANCE())).setComponentLocked(false);
    }

    function getInstance() public view override returns (IInstance instance) {
        return _getInstanceLinkedComponentStorage()._instance;
    }

    function getProductNftId() public view override returns (NftId productNftId) {
        return getComponentInfo().productNftId;
    }


    function _getComponentInfo() internal virtual override view returns (IComponents.ComponentInfo memory info) {
        NftId componentNftId = getRegistry().getNftId(address(this));

        // if registered, attempt to return component info via instance reader
        if (componentNftId.gtz()) {
            // component registerd with registry
            info = _getInstanceReader().getComponentInfo(getNftId());

            // check if also registered with instance
            if (info.wallet != address(0)) {
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


    /// @dev returns the service address for the specified domain
    /// gets address via lookup from registry using the major version form the linked instance
    function _getServiceAddress(ObjectType domain) internal view returns (address service) {
        VersionPart majorVersion = _getInstanceLinkedComponentStorage()._instance.getMajorVersion();
        return getRegistry().getServiceAddress(domain, majorVersion);
    }
}