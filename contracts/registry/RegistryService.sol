// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

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
import {ObjectType, REGISTRY, SERVICE, PRODUCT, ORACLE, POOL, INSTANCE, DISTRIBUTION, DISTRIBUTOR, APPLICATION, POLICY, CLAIM, BUNDLE, STAKE} from "../../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {Version, VersionPart, VersionLib} from "../../contracts/types/Version.sol";

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

    function registerInstance(IRegisterable instance, address owner)
        external
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
        config = new FunctionConfig[](8);

        // order of service registrations MUST be reverse to this array 
        /*config[-1].serviceDomain = STAKE();
        config[-1].selector = RegistryService.registerStake.selector;*/

        config[0].serviceDomain = POLICY();
        config[0].selectors = new bytes4[](0);

        config[1].serviceDomain = APPLICATION();
        config[1].selectors = new bytes4[](1);
        config[1].selectors[0] = RegistryService.registerPolicy.selector;

        config[2].serviceDomain = CLAIM();
        config[2].selectors = new bytes4[](0);

        config[3].serviceDomain = PRODUCT();
        config[3].selectors = new bytes4[](1);
        config[3].selectors[0] = RegistryService.registerProduct.selector;

        config[4].serviceDomain = POOL();
        config[4].selectors = new bytes4[](1);
        config[4].selectors[0] = RegistryService.registerPool.selector;

        // registration of bundle service must preceed registration of pool service
        config[5].serviceDomain = BUNDLE();
        config[5].selectors = new bytes4[](1);
        config[5].selectors[0] = RegistryService.registerBundle.selector;

        config[6].serviceDomain = DISTRIBUTION();
        config[6].selectors = new bytes4[](2);
        config[6].selectors[0] = RegistryService.registerDistribution.selector;
        config[6].selectors[1] = RegistryService.registerDistributor.selector;

        // registerInstance() have no restriction
        config[7].serviceDomain = INSTANCE();
        config[7].selectors = new bytes4[](1);
        config[7].selectors[0] = RegistryService.registerInstance.selector;
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
