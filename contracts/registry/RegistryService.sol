// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IRegistry} from "./IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {IComponent} from "../../contracts/shared/IComponent.sol";
import {IPoolComponent} from "../../contracts/pool/IPoolComponent.sol";
import {IProductComponent} from "../../contracts/product/IProductComponent.sol";
import {IDistributionComponent} from "../../contracts/distribution/IDistributionComponent.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../contracts/type/RoleId.sol";
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, PRICE} from "../../contracts/type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/type/NftId.sol";
import {Fee, FeeLib} from "../../contracts/type/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/type/Version.sol";

import {Service} from "../shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {Registry} from "./Registry.sol";

contract RegistryService is
    Service,
    IRegistryService
{
    using NftIdLib for NftId;

    // TODO update to real hash when registry is stable
    bytes32 public constant REGISTRY_CREATION_CODE_HASH = bytes32(0);

    // From IService
    function getDomain() public pure override returns(ObjectType serviceDomain) {
        return REGISTRY(); 
    }

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
        address initialOwner;
        address registryAddress;
        address authority;
        (registryAddress, initialOwner, authority) = abi.decode(data, (address, address, address));

        initializeService(registryAddress, authority, owner);
        registerInterface(type(IRegistryService).interfaceId);
    }

    function registerInstance(IRegisterable instance, address owner)
        external
        restricted
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

    function registerProduct(IComponent product, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        // CAN revert if no ERC165 support -> will revert with empty message 
        if(!product.supportsInterface(type(IProductComponent).interfaceId)) {
            revert ErrorRegistryServiceNotProduct(address(product));
        }

        info = _getAndVerifyContractInfo(product, PRODUCT(), owner);
        info.nftId = getRegistry().register(info);
    }

    function registerPool(IComponent pool, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        if(!pool.supportsInterface(type(IPoolComponent).interfaceId)) {
            revert ErrorRegistryServiceNotPool(address(pool));
        }

        info = _getAndVerifyContractInfo(pool, POOL(), owner);
        info.nftId = getRegistry().register(info);
    }

    function registerDistribution(IComponent distribution, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        if(!distribution.supportsInterface(type(IDistributionComponent).interfaceId)) {
            revert ErrorRegistryServiceNotDistribution(address(distribution));
        }

        info = _getAndVerifyContractInfo(distribution, DISTRIBUTION(), owner);
        info.nftId = getRegistry().register(info);
    }

    function registerDistributor(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, DISTRIBUTOR());
        nftId = getRegistry().register(info);
    }

    function registerPolicy(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, POLICY());
        nftId = getRegistry().register(info);
    }

    function registerBundle(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, BUNDLE());
        nftId = getRegistry().register(info);
    }

    function registerStake(IRegistry.ObjectInfo memory info)
        external
        restricted 
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
        // view
        returns(
            IRegistry.ObjectInfo memory info 
        )
    {
        info = registerable.getInitialInfo();
        info.objectAddress = address(registerable);

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
        view
    {
        // enforce instead of check
        info.objectAddress = address(0);

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert ErrorRegistryServiceObjectTypeInvalid(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner == address(0)) {
            revert ErrorRegistryServiceObjectOwnerZero(info.objectType);
        }

        if(getRegistry().isRegistered(owner)) { 
            revert ErrorRegistryServiceObjectOwnerRegistered(info.objectType, owner);
        }
    }
}
