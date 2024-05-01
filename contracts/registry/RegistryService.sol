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
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, COMPONENT, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE, STAKING, PRICE} from "../../contracts/type/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/type/StateId.sol";
import {NftId, NftIdLib} from "../../contracts/type/NftId.sol";
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
        (
            address registryAddress,
            address initialAuthority
        ) = abi.decode(data, (address, address));

        initializeService(registryAddress, initialAuthority, owner);
        registerInterface(type(IRegistryService).interfaceId);
    }


    function registerStaking(IRegisterable staking, address owner)
        external
        virtual
        restricted
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
        restricted
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        if(!instance.supportsInterface(type(IInstance).interfaceId)) {
            revert NotInstance();
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
            revert NotProduct();
        }

        info = _getAndVerifyContractInfo(product, PRODUCT(), owner);
        info.nftId = getRegistry().register(info);
    }

    function registerComponent(
        IComponent component, 
        ObjectType objectType,
        address initialOwner
    )
        external
        restricted
        returns(
            IRegistry.ObjectInfo memory info
        ) 
    {
        // CAN revert if no ERC165 support -> will revert with empty message 
        if(!component.supportsInterface(type(IComponent).interfaceId)) {
            revert NotComponent();
        }

        info = _getAndVerifyContractInfo(component, objectType, initialOwner);
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
            revert NotPool();
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
            revert NotDistribution();
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

    // from IRegisterable

    function getFunctionConfigs()
        external
        pure
        returns(
            FunctionConfig[] memory config
        )
    {
        config = new FunctionConfig[](11);

        // order of service registrations MUST be reverse to this array 
        /*config[-1].serviceDomain = STAKE();
        config[-1].selector = RegistryService.registerStake.selector;*/


        config[0].serviceDomain = POLICY();
        config[0].authorizedSelectors = new bytes4[](0);

        config[1].serviceDomain = APPLICATION();
        config[1].authorizedSelectors = new bytes4[](1);
        config[1].authorizedSelectors[0] = RegistryService.registerPolicy.selector;

        config[2].serviceDomain = CLAIM();
        config[2].authorizedSelectors = new bytes4[](0);

        config[3].serviceDomain = PRODUCT();
        config[3].authorizedSelectors = new bytes4[](1);
        config[3].authorizedSelectors[0] = RegistryService.registerProduct.selector;

        config[4].serviceDomain = POOL();
        config[4].authorizedSelectors = new bytes4[](1);
        config[4].authorizedSelectors[0] = RegistryService.registerPool.selector;

        // registration of bundle service must preceed registration of pool service
        config[5].serviceDomain = BUNDLE();
        config[5].authorizedSelectors = new bytes4[](1);
        config[5].authorizedSelectors[0] = RegistryService.registerBundle.selector;

        // registration of pricing service must preceed registration of application service
        config[6].serviceDomain = PRICE();
        config[6].authorizedSelectors = new bytes4[](0);

        // registration of distribution service must preceed registration of pricing service
        config[7].serviceDomain = DISTRIBUTION();
        config[7].authorizedSelectors = new bytes4[](2);
        config[7].authorizedSelectors[0] = RegistryService.registerDistribution.selector;
        config[7].authorizedSelectors[1] = RegistryService.registerDistributor.selector;

        config[8].serviceDomain = COMPONENT();
        config[8].authorizedSelectors = new bytes4[](1);
        config[8].authorizedSelectors[0] = RegistryService.registerComponent.selector;

        config[9].serviceDomain = INSTANCE();
        config[9].authorizedSelectors = new bytes4[](1);
        config[9].authorizedSelectors[0] = RegistryService.registerInstance.selector;

        config[10].serviceDomain = STAKING();
        config[10].authorizedSelectors = new bytes4[](1);
        config[10].authorizedSelectors[0] = RegistryService.registerStaking.selector;
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
            revert UnexpectedRegisterableType(expectedType, info.objectType);
        }

        address owner = info.initialOwner;

        if(owner != expectedOwner) { // registerable owner protection
            revert NotRegisterableOwner(expectedOwner);
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
    }
}