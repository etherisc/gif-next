// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../registry/IRegistry.sol";
import {IInstance} from "../instance/IInstance.sol";

import {ITreasury, ITreasuryModule} from "../../contracts/instance/module/treasury/ITreasury.sol";
import {TreasuryModule} from "../../contracts/instance/module/treasury/TreasuryModule.sol";
import {IComponent, IComponentModule} from "../../contracts/instance/module/component/IComponent.sol";
import {IPool} from "../../contracts/instance/module/pool/IPoolModule.sol";
import {IBaseComponent} from "../../contracts/components/IBaseComponent.sol";
import {IPoolComponent} from "../../contracts/components/IPoolComponent.sol";
import {IProductComponent} from "../../contracts/components/IProductComponent.sol";
import {IDistributionComponent} from "../../contracts/components/IDistributionComponent.sol";

import {IVersionable} from "../../contracts/shared/IVersionable.sol";
import {Versionable} from "../../contracts/shared/Versionable.sol";
import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../contracts/types/RoleId.sol";
import {ObjectType, REGISTRY, PRODUCT, ORACLE, POOL, TOKEN, INSTANCE, DISTRIBUTION} from "../../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";
import {UFixed, UFixedMathLib} from "../../contracts/types/UFixed.sol";


import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";
import {IRegistryService} from "./IRegistryService.sol";

contract RegistryService is
    ServiceBase,
    IRegistryService
{
    using NftIdLib for NftId;

    string public constant NAME = "RegistryService";

    // IMPORTANT: MUST NOT call component (untrusted contract) inbetween calls to registry/instance (trusted contracts)
    // motivation: registry/instance state may change during external call
    function registerProduct(IProductComponent product)
        external 
        returns(NftId nftId)
    {
        // self registration is not allowed
        require(msg.sender != address(product));

        require(
            product.supportsInterface(type(IProductComponent).interfaceId),
            "ERROR:RS-001:NOT_PRODUCT"
        );

        (
            IInstance instance,
            NftId instanceNftId, 
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _verifyComponent(product, PRODUCT());

        nftId = getRegistry().registerFrom(msg.sender, info);

        _registerProduct(
            nftId, 
            instanceNftId,
            instance,
            data
        );
    }

    function registerPool(IPoolComponent pool)
        external 
        returns(NftId nftId)
    {
        // self registration is not allowed
        require(msg.sender != address(pool));

        require(
            pool.supportsInterface(type(IPoolComponent).interfaceId),
            "ERROR:RS-025:NOT_POOL"
        );

        (
            IInstance instance,
            NftId instanceNftId, 
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _verifyComponent(pool, POOL());

        nftId = getRegistry().registerFrom(msg.sender, info);   

        _registerPool(
            nftId, 
            instanceNftId,
            instance,
            data
        );
    }

    function registerDistribution(IDistributionComponent distribution) 
        external 
        returns(NftId nftId)
    {
        // self registration not allowed
        require(msg.sender != address(distribution));

        require(
            distribution.supportsInterface(type(IDistributionComponent).interfaceId),
            "ERROR:RS-026:NOT_DISTRIBUTION"
        );   
        
        (
            IInstance instance,
            NftId instanceNftId, 
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = _verifyComponent(distribution, DISTRIBUTION());

        nftId = getRegistry().registerFrom(msg.sender, info); 

        //_registerDistribution();
    }

    function registerInstance(IRegisterable instance)
        external 
        returns(NftId nftId) 
    {
        require(
            instance.supportsInterface(type(IInstance).interfaceId),
            "ERROR:RS-031:NOT_INSTANCE"
        ); 

        (
            IRegistry.ObjectInfo memory info, 
            //bytes memory data
        ) = _verifyInstance(instance);

        nftId = getRegistry().registerFrom(msg.sender, info);     
        
        // instance after registration
        // TODO tell instance about its nftId 
        // TODO tell every registerable about its parantNftId
    }

    function getRoleForType(
        ObjectType cType
    ) public pure override returns (RoleId role) {
        if (cType == PRODUCT()) {
            return PRODUCT_OWNER_ROLE();
        }
        if (cType == POOL()) {
            return POOL_OWNER_ROLE();
        }
        if (cType == ORACLE()) {
            return ORACLE_OWNER_ROLE();
        }
    }

    // From IService
    function getName() external pure returns(string memory) {
        return NAME;
    }

    // From Versionable

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    } 

    // from Versionable

    // top level initializer
    function _initialize(bytes memory data) 
        internal
        onlyInitializing // TODO better to use initialier?
        virtual override
    {
        (address registry,
        NftId registryNftId,
        address initialOwner) = abi.decode(data, (address, NftId, address));

        _initializeServiceBase(registry, registryNftId, initialOwner);

        _registerInterface(type(IRegistryService).interfaceId);
    }

    // Internals

    function _registerProduct(
        NftId nftId, 
        NftId instanceNftId,
        IInstance instance,
        bytes memory data
    )
        internal
    {
        // only product's owner with role
        RoleId typeRole = getRoleForType(PRODUCT());
        require(
            instance.hasRole(typeRole, msg.sender),
            "ERROR:RS-014:TYPE_ROLE_MISSING"
        ); 

        (
            ITreasury.TreasuryInfo memory info,
            address wallet
        )  = abi.decode(data, (ITreasury.TreasuryInfo, address));

        IRegistry _registry = getRegistry();

        require(
            wallet > address(0), 
            "ERROR:RS-015:ZERO_WALLET"
        );

        IRegistry.ObjectInfo memory tokenInfo = _registry.getObjectInfo(address(info.token));

        require(
            tokenInfo.objectType == TOKEN(),
            "ERROR:RS-016:UNKNOWN_TOKEN"
        ); 

        IRegistry.ObjectInfo memory poolInfo = _registry.getObjectInfo(info.poolNftId);

        require(
            poolInfo.objectType == POOL(),
            "ERROR:RS-017:UNKNOWN_POOL"
        ); 

        require(
            poolInfo.parentNftId == instanceNftId, 
            "ERROR:RS-018:POOL_INSTANCE_MISMATCH"
        );
        // TODO pool have the same token
        //ITreasury.PoolSetup memory poolSetup = instance.getPoolSetup(info.poolNftId);
        //require(tokenInfo.objectAddress == address(poolSetup.token), "ERROR:COS-018:PRODUCT_POOL_TOKEN_MISMATCH");
        // TODO pool is not linked

        IRegistry.ObjectInfo memory distributionInfo = _registry.getObjectInfo(info.distributionNftId);

        require(
            distributionInfo.objectType == DISTRIBUTION(), 
            "ERROR:RS-019:UNKNOWN_DISTRIBUTION"
        ); 

        require(
            distributionInfo.parentNftId == instanceNftId, 
            "ERROR:RS-020:DISTRIBUTION_INSTANCE_MISMATCH"
        );
        // TODO distribution have the same token
        // TODO distribution is not linked

        // component module
        instance.registerComponent(
            nftId,
            info.token,
            wallet // TODO move wallet into TreasuryInfo?
        );
        // treasury module
        instance.registerProductSetup(
            nftId, 
            info
        );
    }

    function _registerPool(
        NftId nftId,
        NftId instanceNftId,
        IInstance instance,
        bytes memory data
    )
        internal
    {
        // pool's owner with role
        RoleId typeRole = getRoleForType(POOL());
        require(
            instance.hasRole(typeRole, msg.sender),
            "ERROR:RS-021:TYPE_ROLE_MISSING"
        );  

        (
            IPool.PoolInfo memory info,
            address wallet,
            IERC20Metadata token,
            /*poolFee*/,
            /*stakingFee*/,
            /*performanceFee*/
        )  = abi.decode(data, (IPool.PoolInfo, address, IERC20Metadata, Fee, Fee, Fee));

        IRegistry _registry = getRegistry();

        require(
            wallet > address(0),
            "ERROR:RS-022:ZERO_WALLET"
        );

        ObjectType tokenType = _registry.getObjectInfo(address(token)).objectType;

        require(
            tokenType == TOKEN(), 
            "ERROR:RS-023:UNKNOWN_TOKEN"
        );  

        require(
            UFixedMathLib.gtz(info.collateralizationLevel), 
            "ERROR:RS-024:ZERO_COLLATERALIZATION"
        );

        // TODO add more validations

        // component module
        instance.registerComponent(
            nftId,
            token,
            wallet
        ); 

        // pool module
        instance.registerPool(
            nftId, 
            info
        );
    } 

    function _verifyComponent(IRegisterable component, ObjectType componentType)
        internal
        returns(
            IInstance,
            NftId, 
            IRegistry.ObjectInfo memory, 
            bytes memory)
    {
        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = component.getInitialInfo();

        require(// owner protection
            info.initialOwner == msg.sender, 
            "ERROR:RS-002:NOT_OWNER"
        );

        require(
            info.objectAddress == address(component),
            "ERROR:RS-003:WRONG_ADDRESS"
        );

        require(
            info.objectType == componentType, 
            "ERROR:RS-004:OBJECT_TYPE_INVALID"
        );

        NftId instanceNftId = info.parentNftId;
        IRegistry.ObjectInfo memory instanceInfo = getRegistry().getObjectInfo(instanceNftId);

        require(
            instanceInfo.objectType == INSTANCE(), 
            "ERROR:RS-005:UNKNOWN_INSTANCE"
        );

        //.data

        return(
            IInstance(instanceInfo.objectAddress),
            instanceNftId,
            info, // MUST explicitly return this vars!
            data
        );
    }

    function _verifyInstance(IRegisterable instance)
        internal
        returns(
            IRegistry.ObjectInfo memory, 
            bytes memory)
    {
        (
            IRegistry.ObjectInfo memory info, 
            bytes memory data
        ) = instance.getInitialInfo();

        require(// owner protection
            info.initialOwner == msg.sender, 
            "ERROR:RS-032:NOT_OWNER"
        );

        require(
            info.objectAddress == address(instance), 
            "ERROR:RS-033:WRONG_ADDRESS"
        );

        require(
            info.objectType == INSTANCE(), 
            "ERROR:RS-034:NOT_INSTANCE"
        );

        IRegistry.ObjectInfo memory registryInfo = getRegistry().getObjectInfo(info.parentNftId);

        require(
            registryInfo.objectType == REGISTRY(), 
            "ERROR:RS-013:UNKNOWN_REGISTRY"
        ); 

        //.data

        return (info, data); // MUST explicitly return this vars!
    }
}