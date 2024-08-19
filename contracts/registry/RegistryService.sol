// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IComponent} from "../../contracts/shared/IComponent.sol";
import {IDistributionComponent} from "../../contracts/distribution/IDistributionComponent.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPoolComponent} from "../../contracts/pool/IPoolComponent.sol";
import {IProductComponent} from "../../contracts/product/IProductComponent.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegistry} from "./IRegistry.sol";
import {IRegistryService} from "./IRegistryService.sol";

import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE} from "../../contracts/type/ObjectType.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
import {Service} from "../shared/Service.sol";

contract RegistryService is
    Service,
    IRegistryService
{
    // TODO update to real hash when registry is stable
    bytes32 public constant REGISTRY_CREATION_CODE_HASH = bytes32(0);

    // from Versionable

    /// @dev top level initializer
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        virtual override
        initializer()
    {
        (
            address authority,
            address registry
        ) = abi.decode(data, (address, address));

        __Service_init(authority, registry, owner);
        _registerInterface(type(IRegistryService).interfaceId);
    }


    function registerStaking(IRegisterable staking, address owner)
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        )
    {
        info = _getAndVerifyContractInfo(staking, STAKING(), owner);
        info.nftId = getRegistry().register(info);
    }


    function registerInstance(IRegisterable instance, address owner)
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        if(!instance.supportsInterface(type(IInstance).interfaceId)) {
            revert ErrorRegistryServiceNotInstance(address(instance));
        }

        info = _getAndVerifyContractInfo(instance, INSTANCE(), owner);
        info.nftId = getRegistry().register(info);

        instance.linkToRegisteredNftId(); // asume safe
    }

    function registerProduct(
        IComponent product, 
        address initialOwner
    )
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        if(!product.supportsInterface(type(IProductComponent).interfaceId)) {
            revert ErrorRegistryServiceNotProduct(address(product));
        }

        info = _getAndVerifyContractInfo(product, PRODUCT(), initialOwner);
        info.nftId = getRegistry().register(info);
    }

    function registerProductLinkedComponent(
        IComponent component, 
        ObjectType objectType,
        address initialOwner
    )
        external
        virtual
        restricted()
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        // CAN revert if no ERC165 support -> will revert with empty message 
        if(!component.supportsInterface(type(IComponent).interfaceId)) {
            revert ErrorRegistryServiceNotComponent(address(component));
        }

        if (!(objectType == DISTRIBUTION() || objectType == ORACLE() || objectType == POOL())) {
            revert ErrorRegistryServiceNotProductLinkedComponent(address(component));
        }

        info = _getAndVerifyContractInfo(component, objectType, initialOwner);
        info.nftId = getRegistry().register(info);
    }

    function registerDistributor(IRegistry.ObjectInfo memory info)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, DISTRIBUTOR());
        nftId = getRegistry().register(info);
    }

    function registerPolicy(IRegistry.ObjectInfo memory info)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, POLICY());
        nftId = getRegistry().register(info);
    }

    function registerBundle(IRegistry.ObjectInfo memory info)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, BUNDLE());
        nftId = getRegistry().register(info);
    }

    function registerStake(IRegistry.ObjectInfo memory info)
        external
        virtual
        restricted()
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, STAKE());
        nftId = getRegistry().register(info);
    }

    // Internal

    function _getAndVerifyContractInfo(
        IRegisterable registerable,
        ObjectType expectedType, // assume can be valid only
        address expectedOwner // assume can be 0 when given by other service
    )
        internal
        virtual
        view
        returns(
            IRegistry.ObjectInfo memory info 
        )
    {
        info = registerable.getInitialInfo();

        if(info.objectAddress != address(registerable)) {
            revert ErrorRegistryServiceRegisterableAddressInvalid(registerable, info.objectAddress);
        }

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert ErrorRegistryServiceRegisterableTypeInvalid(registerable, expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert ErrorRegistryServiceRegisterableOwnerInvalid(registerable, expectedOwner, owner);
        }

        if(owner == address(registerable)) {
            revert ErrorRegistryServiceRegisterableSelfRegistration(registerable);
        }

        if(owner == address(0)) {
            revert ErrorRegistryServiceRegisterableOwnerZero(registerable);
        }
        
        if(getRegistry().isRegistered(owner)) { 
            revert ErrorRegistryServiceRegisterableOwnerRegistered(registerable, owner);
        }
    }

    function _verifyObjectInfo(
        IRegistry.ObjectInfo memory info,
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

        address owner = info.initialOwner;

        if(owner == address(0)) {
            revert ErrorRegistryServiceObjectOwnerZero(info.objectType);
        }

        if(owner == msg.sender) {
            revert ErrorRegistryServiceInvalidInitialOwner(owner);
        }

        if(getRegistry().isRegistered(owner)) {
            ObjectType ownerType = getRegistry().getObjectInfo(owner).objectType;
            if(ownerType == REGISTRY() || ownerType == STAKING() || ownerType == SERVICE() || ownerType == INSTANCE()) {
                revert ErrorRegistryServiceObjectOwnerRegistered(info.objectType, owner);
            }
        }
    }

    // From IService
    function _getDomain() internal override pure returns(ObjectType serviceDomain) {
        return REGISTRY(); 
    }
}