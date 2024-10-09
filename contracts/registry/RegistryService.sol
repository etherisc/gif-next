// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IDistributionComponent} from "../../contracts/distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IInstanceLinkedComponent} from "../../contracts/shared/IInstanceLinkedComponent.sol";
import {IPoolComponent} from "../../contracts/pool/IPoolComponent.sol";
import {IProductComponent} from "../../contracts/product/IProductComponent.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {IStaking} from "../../contracts/staking/IStaking.sol";

import {ContractLib} from "../shared/ContractLib.sol";
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, POLICY, BUNDLE, STAKE, STAKING} from "../../contracts/type/ObjectType.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Service} from "../shared/Service.sol";

contract RegistryService is
    Service,
    IRegistryService
{
    // TODO update to real hash when registry is stable
    bytes32 public constant REGISTRY_CREATION_CODE_HASH = bytes32(0);

    /// @dev top level initializer
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        onlyInitializing
    {
        (
            address authority
        ) = abi.decode(data, (address));

        __Service_init(authority, owner);
        _registerInterface(type(IRegistryService).interfaceId);
    }

    // TODO register have no combos with STAKING; decide on parentNftId arg
    function registerStaking(IRegisterable staking, address expectedOwner)
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        )
    {
        _checkInterface(staking, type(IStaking).interfaceId);

        address owner;
        bytes memory data;
        (info, owner, data) = _getAndVerifyContractInfo(staking, NftIdLib.zero(), STAKING(), expectedOwner);
        info.nftId = _getRegistry().register(info, owner, data);
    }


    function registerInstance(IRegisterable instance, address expectedOwner)
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        _checkInterface(instance, type(IInstance).interfaceId);

        address owner;
        bytes memory data;
        (info, owner, data) = _getAndVerifyContractInfo(instance, _getRegistry().getNftId(), INSTANCE(), expectedOwner);
        info.nftId = _getRegistry().register(info, owner, data);

        instance.linkToRegisteredNftId(); // asume safe
    }

    function registerComponent(
        IRegisterable component, 
        NftId expectedParentNftId, 
        ObjectType expectedType, 
        address expectedOwner
    )
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        _checkInterface(
            component, 
            type(IInstanceLinkedComponent).interfaceId);

        address owner;
        bytes memory data;
        (info, owner, data) = _getAndVerifyContractInfo(component, expectedParentNftId, expectedType, expectedOwner);
        info.nftId = _getRegistry().register(info, owner, data);
    }

    function registerDistributor(IRegistry.ObjectInfo memory info, address owner, bytes memory data)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, owner, DISTRIBUTOR());
        nftId = _getRegistry().register(info, owner, data);
    }

    function registerPolicy(IRegistry.ObjectInfo memory info, address owner, bytes memory data)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, owner, POLICY());
        nftId = _getRegistry().register(info, owner, data);
    }

    function registerBundle(IRegistry.ObjectInfo memory info, address owner, bytes memory data)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, owner, BUNDLE());
        nftId = _getRegistry().register(info, owner, data);
    }

    function registerStake(IRegistry.ObjectInfo memory info, address owner, bytes memory data)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, owner, STAKE());
        nftId = _getRegistry().register(info, owner, data);
    }

    // Internal

    function _checkInterface(IRegisterable registerable, bytes4 interfaceId) internal view
    {
        if(!ContractLib.supportsInterface(address(registerable), interfaceId)) {
            revert ErrorRegistryServiceInterfaceNotSupported(address(registerable), interfaceId);
        }
    }

    /// @dev Based on the provided component address, parent, type and owner this function reverts iff:
    /// - the component address does not match with address stored in component's initial info
    /// - the component type does not match with the required type
    /// - the component parent does not match with the required parent (when required parent is not zero)
    /// - the component initialOwner does not match with the required owner (when required owner is not zero)
    /// - the component initialOwner is zero (redundant, consider deleting)
    /// - the component initialOwner is already registered
    function _getAndVerifyContractInfo(
        IRegisterable registerable,
        NftId expectedParent,
        ObjectType expectedType, // assume can be valid only
        address expectedOwner // assume can be 0 when given by other service
    )
        internal
        virtual
        view
        returns(
            IRegistry.ObjectInfo memory info,
            address initialOwner,
            bytes memory data
        )
    {
        info = registerable.getInitialInfo();
        data = registerable.getInitialData();
        initialOwner = registerable.getOwner();

        if(info.objectAddress != address(registerable)) {
            revert ErrorRegistryServiceRegisterableAddressInvalid(registerable, info.objectAddress);
        }

        if(expectedType != COMPONENT()) {
            // exact match
            if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
                revert ErrorRegistryServiceRegisterableTypeInvalid(registerable, expectedType, info.objectType);
            }
        } else {
            // match any component except product
            if(!(info.objectType == DISTRIBUTION() || info.objectType == ORACLE() || info.objectType == POOL())) {
                revert ErrorRegistryServiceRegisterableTypeInvalid(registerable, expectedType, info.objectType);
            }
        }

        if(expectedParent.gtz()) {
            // exact parent is important
            if(info.parentNftId != expectedParent) {
                revert ErrorRegistryServiceRegisterableParentInvalid(registerable, expectedParent, info.parentNftId);
            }
        }

        if(expectedOwner > address(0)) {
            // exact owner is important
            if(initialOwner != expectedOwner) { // registerable owner protection
                revert ErrorRegistryServiceRegisterableOwnerInvalid(registerable, expectedOwner, initialOwner);
            }
        }

        if(initialOwner == address(registerable)) {
            revert ErrorRegistryServiceRegisterableSelfRegistration(registerable);
        }

        // redundant, checked by chainNft
        if(initialOwner == address(0)) {
            revert ErrorRegistryServiceRegisterableOwnerZero(registerable);
        }
        
        if(_getRegistry().isRegistered(initialOwner)) { 
            revert ErrorRegistryServiceRegisterableOwnerRegistered(registerable, initialOwner);
        }
    }

    function _verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
        address initialOwner,
        ObjectType expectedType
    )
        internal
        virtual
        view
    {
        if(info.objectAddress > address(0)) {
            revert ErrorRegistryServiceObjectAddressNotZero(info.objectType);
        }

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert ErrorRegistryServiceObjectTypeInvalid(expectedType, info.objectType);
        }

        if(initialOwner == address(0)) {
            revert ErrorRegistryServiceObjectOwnerZero(info.objectType);
        }

        if(initialOwner == msg.sender) {
            revert ErrorRegistryServiceInvalidInitialOwner(initialOwner);
        }

        if(_getRegistry().isRegistered(initialOwner)) {
            ObjectType ownerType = _getRegistry().getObjectInfo(initialOwner).objectType;
            if(ownerType == REGISTRY() || ownerType == STAKING() || ownerType == SERVICE() || ownerType == INSTANCE()) {
                revert ErrorRegistryServiceObjectOwnerRegistered(info.objectType, initialOwner);
            }
        }
    }

    // From IService
    function _getDomain() internal override pure returns(ObjectType serviceDomain) {
        return REGISTRY(); 
    }
}