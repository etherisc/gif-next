// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IRegistry} from "./IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {ContractDeployerLib} from "../shared/ContractDeployerLib.sol";
import {IComponent} from "../../contracts/components/IComponent.sol";
import {IPoolComponent} from "../../contracts/components/IPoolComponent.sol";
import {IProductComponent} from "../../contracts/components/IProductComponent.sol";
import {IDistributionComponent} from "../../contracts/components/IDistributionComponent.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {Registerable} from "../../contracts/shared/Registerable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../contracts/types/RoleId.sol";
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, DISTRIBUTION, POLICY, BUNDLE, STAKE} from "../../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";

import {Service} from "../shared/Service.sol";
import {IService} from "../shared/IService.sol";
import {IRegistryService} from "./IRegistryService.sol";
import {Registry} from "./Registry.sol";

contract RegistryService is
    AccessManagedUpgradeable,
    Service,
    IRegistryService
{
    using NftIdLib for NftId;

    // TODO update to real hash when registry is stable
    bytes32 public constant REGISTRY_CREATION_CODE_HASH = bytes32(0);

    address public constant NFT_LOCK_ADDRESS = address(0x1);


    function registerInstance(IRegisterable instance)
        external
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(!instance.supportsInterface(type(IInstance).interfaceId)) {
            revert NotInstance();
        }

        (info, data) = _getAndVerifyContractInfo(instance, INSTANCE(), msg.sender);

        info.nftId = _registry.register(info);
        instance.linkToRegisteredNftId(); // asume safe
        
        return (info, data);
    }

    function registerProduct(IComponent product, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        // CAN revert if no ERC165 support -> will revert with empty message 
        if(!product.supportsInterface(type(IProductComponent).interfaceId)) {
            revert NotProduct();
        }

        (info, data) = _getAndVerifyContractInfo(product, PRODUCT(), owner);

        info.nftId = _registry.register(info);

        return (info, data);  
    }

    function registerPool(IComponent pool, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(!pool.supportsInterface(type(IPoolComponent).interfaceId)) {
            revert NotPool();
        }

        (info, data) = _getAndVerifyContractInfo(pool, POOL(), owner);

        info.nftId = _registry.register(info);

        return (info, data);  
    }

    function registerDistribution(IComponent distribution, address owner)
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) 
    {
        if(!distribution.supportsInterface(type(IDistributionComponent).interfaceId)) {
            revert NotDistribution();
        }

        (info, data) = _getAndVerifyContractInfo(distribution, DISTRIBUTION(), owner);

        info.nftId = _registry.register(info);

        return (info, data);  
    }

    function registerPolicy(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, POLICY());

        nftId = _registry.register(info);
    }

    function registerBundle(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, BUNDLE());

        nftId = _registry.register(info);
    }

    function registerStake(IRegistry.ObjectInfo memory info)
        external
        restricted 
        returns(NftId nftId) 
    {
        _verifyObjectInfo(info, STAKE());

        nftId = _registry.register(info);
    }

    // From IService
    function getDomain() public pure override(IService, Service) returns(ObjectType serviceDomain) {
        return REGISTRY(); 
    }

    // from Versionable

    /// @dev top level initializer
    function _initialize(
        address owner, 
        bytes memory data
    )
        internal
        initializer
        virtual override
    {
        (
            address initialAuthority,
            address registry
        ) = abi.decode(data, (address, address));

        __AccessManaged_init(initialAuthority);

        _initializeService(address(registry), owner);

        _registerInterface(type(IRegistryService).interfaceId);
    }

    // from IRegisterable

    function getInitialInfo() 
        public 
        view
        virtual override(IRegisterable, Registerable)
        returns (IRegistry.ObjectInfo memory info, bytes memory data)
    {
        (info , data) = super.getInitialInfo();

        FunctionConfig[] memory config = new FunctionConfig[](6);

        // order of service registrations MUST be reverse to this array 
        /*config[-1].serviceDomain = STAKE();
        config[-1].selector = RegistryService.registerStake.selector;*/

        config[0].serviceDomain = POLICY();
        config[0].selector = RegistryService.registerPolicy.selector;

        config[1].serviceDomain = BUNDLE();
        config[1].selector = RegistryService.registerBundle.selector;

        config[2].serviceDomain = PRODUCT();
        config[2].selector = RegistryService.registerProduct.selector;

        config[3].serviceDomain = POOL();
        config[3].selector = RegistryService.registerPool.selector;

        config[4].serviceDomain = DISTRIBUTION();
        config[4].selector = RegistryService.registerDistribution.selector;

        // registerInstance() have no restriction
        config[5].serviceDomain = INSTANCE();
        config[5].selector = RegistryService.registerInstance.selector;

        data = abi.encode(config);
    }

    // Internal

    function _getAndVerifyContractInfo(
        IRegisterable registerable,
        ObjectType expectedType, // assume can be valid only
        address expectedOwner // assume can be 0 when given by other service
    )
        internal
        view
        returns(
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        )
    {
        (
            info, 
            data
        ) = registerable.getInitialInfo();
        info.objectAddress = address(registerable);

        if(info.objectType != expectedType) {// type is checked in registry anyway...but service logic may depend on expected value
            revert UnexpectedRegisterableType(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        // solhint-disable-next-line 
        if(expectedType == INSTANCE()) { 
            // any address may create a new instance via instance service
        } else {
            if(owner != expectedOwner) { // registerable owner protection
                revert NotRegisterableOwner(expectedOwner);
            }
        }

        if(owner == address(registerable)) {
            revert SelfRegistration();
        }

        if(owner == address(0)) {
            revert RegisterableOwnerIsZero();
        }
        
        if(getRegistry().isRegistered(owner)) { 
            revert RegisterableOwnerIsRegistered();
        }

        /*NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(parentNftId);

        if(parentInfo.objectType != parentType) { // parent registration + type
            revert InvalidParent(parentNftId);
        }*/

        return(info, data);
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
            revert UnexpectedRegisterableType(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner == address(0)) {
            revert RegisterableOwnerIsZero();
        }

        if(getRegistry().isRegistered(owner)) { 
            revert RegisterableOwnerIsRegistered();
        }

        // can catch all 3 if check that initialOwner is not registered
        /*if(info.initialOwner == msg.sender) {
            revert InitialOwnerIsParent();
        }

        if(info.initialOwner == address(this)) {
            revert InitialOwnerIsService();
        }

        if(info.initialOwner == address(getRegistry())) {
            revert InitialOwnerIsRegistry();
        }*/

        /*NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory parentInfo = getRegistry().getObjectInfo(parentNftId);

        if(parentInfo.objectType != parentType) { // parent registration + type
            revert InvalidParent(parentNftId);
        }*/        
    }
}
