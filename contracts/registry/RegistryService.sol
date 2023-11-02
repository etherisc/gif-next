// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

//import {IRegistry} from "../registry/IRegistry.sol";
import {IRegistry_new} from "../registry/IRegistry_new.sol";
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
//import {IRegisterable} from "../../contracts/shared/IRegisterable.sol";
import {IRegisterable_new} from "../../contracts/shared/IRegisterable_new.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../contracts/types/RoleId.sol";
import {ObjectType, REGISTRY, PRODUCT, ORACLE, POOL, TOKEN, INSTANCE, DISTRIBUTION} from "../../contracts/types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../contracts/types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../contracts/types/NftId.sol";
import {Fee, FeeLib} from "../../contracts/types/Fee.sol";
import {Version, VersionLib} from "../../contracts/types/Version.sol";


import {ServiceBase} from "../../contracts/instance/base/ServiceBase.sol";
import {IRegistryService} from "./IRegistryService.sol";

contract RegistryService is
    ServiceBase,
    IRegistryService
{
    using NftIdLib for NftId;

    string public constant NAME = "ComponentOwnerService";

    modifier onlyRegisteredComponent(IBaseComponent component) {
        NftId nftId = getRegistry().getNftId(address(component));
        require(nftId.gtz(), "ERROR:COS-001:COMPONENT_UNKNOWN");
        _;
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

    function registerProduct(IProductComponent product)
        external 
        returns(NftId nftId)
    {
        // self registration not allowed
        require(msg.sender != address(product));

        // TODO check interface 

        (IRegistry_new.ObjectInfo memory info,
        IProductComponent.ProductComponentInfo memory productInfo) = product.getInitialProductInfo();

        // TODO read pool and distribution fees then start calls to trusted contracts -> "atomic" procedure
        // motivation: registry/instance state may change during state transition

        IRegistry_new _registry = getRegistry();

        require(info.initialOwner == msg.sender, "ERROR:COS-002:NOT_OWNER");// owner protection
        require(info.objectAddress == address(product), "ERROR:COS-003:WRONG_ADDRESS");
        require(info.objectType == PRODUCT(), "ERROR:COS-004:UNKNOWN_PRODUCT");
        // instance is registered
        NftId instanceNftId = info.parentNftId;
        IRegistry_new.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        require(instanceInfo.objectType == INSTANCE(), "ERROR:COS-005:UNKNOWN_INSTANCE");
        //.data
    
        nftId = _registry.registerFrom(msg.sender, info);

        _registerProduct(
            nftId, 
            instanceNftId,
            IInstance(instanceInfo.objectAddress),
            productInfo
        );
    }

    function registerPool(IPoolComponent pool)
        external 
        returns(NftId nftId)
    {
        // self registration not allowed
        require(msg.sender != address(pool));

        // TODO check interface      

        (IRegistry_new.ObjectInfo memory info,
        IPoolComponent.PoolComponentInfo memory poolInfo) = pool.getInitialPoolInfo();

        IRegistry_new _registry = getRegistry();

        require(info.initialOwner == msg.sender, "ERROR:COS-007:NOT_OWNER");// owner protection 
        require(info.objectAddress == address(pool), "ERROR:COS-008:WRONG_ADDRESS");
        require(info.objectType == POOL(), "ERROR:COS-009:UNKNOWN_POOL");
        // instance is registered
        NftId instanceNftId = info.parentNftId;
        IRegistry_new.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        require(instanceInfo.objectType == INSTANCE(), "ERROR:COS-010:UNKNOW_INSTANCE"); 
        //.data

        nftId = _registry.registerFrom(msg.sender, info);   

        _registerPool(
            nftId, 
            instanceNftId,
            IInstance(instanceInfo.objectAddress),
            poolInfo
        );
    }

    function registerDistribution(IDistributionComponent distribution) 
        external 
        returns(NftId nftId)
    {
        // self registration not allowed
        require(msg.sender != address(distribution));

        // TODO check interface      

        (IRegistry_new.ObjectInfo memory info,
        IDistributionComponent.DistributionComponentInfo memory distributionInfo) = distribution.getInitialDistributionInfo();

        IRegistry_new _registry = getRegistry();

        require(info.initialOwner == msg.sender, "ERROR:COS-007:NOT_OWNER");// owner protection 
        require(info.objectAddress == address(distribution), "ERROR:COS-008:WRONG_ADDRESS");
        require(info.objectType == DISTRIBUTION(), "ERROR:COS-009:UNKNOWN_POOL");
        // instance is registered
        NftId instanceNftId = info.parentNftId;
        IRegistry_new.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        require(instanceInfo.objectType == INSTANCE(), "ERROR:COS-010:UNKNOW_INSTANCE"); 

        nftId = _registry.registerFrom(msg.sender, info);  

        //_registerDistribution();
    }


    //function registerInstance(IInstance instance) // TODO IInstance brakes the tests 
    function registerInstance(IRegisterable_new instance) 
        external 
        returns(NftId nftId) 
    {
        // TODO check interface 

        IRegistry_new.ObjectInfo memory info = instance.getInitialInfo();

        IRegistry_new _registry = getRegistry();

        require(info.initialOwner == msg.sender);// owner protection
        require(info.objectAddress == address(instance));
        require(info.objectType == INSTANCE());
        IRegistry_new.ObjectInfo memory registryInfo = _registry.getObjectInfo(info.parentNftId);
        require(registryInfo.objectType == REGISTRY(), "ERROR:COS-011:UNKNOWN_REGISTRY"); 

        nftId = _registry.registerFrom(msg.sender, info);      
    }

    function _registerProduct(
        NftId nftId, 
        NftId instanceNftId,
        IInstance instance,
        IProductComponent.ProductComponentInfo memory info
    )
        internal
    {
        // only product's owner with role
        //require(_registry.ownerOf(nftId) == msg.sender);
        RoleId typeRole = getRoleForType(PRODUCT());
        require(
            instance.hasRole(typeRole, msg.sender),
            "ERROR:COS-014:TYPE_ROLE_MISSING"
        );  

        IRegistry_new _registry = getRegistry();

        // token is registered -> TODO instance can whitelist tokens too?
        IRegistry_new.ObjectInfo memory tokenInfo = _registry.getObjectInfo(address(info.token));
        require(tokenInfo.objectType == TOKEN(), "ERROR:COS-015:UNKNOWN_TOKEN"); 

        // pool is registered
        IRegistry_new.ObjectInfo memory poolInfo = _registry.getObjectInfo(info.poolNftId);
        require(poolInfo.objectType == POOL(), "ERROR:COS-016:UNKNOW_POOL"); 
        // pool is on the same instance
        require(poolInfo.parentNftId == instanceNftId, "ERROR:COS-017:POOL_INSTANCE_MISMATCH");
        // pool have the same token
        //ITreasury.PoolSetup memory poolSetup = instance.getPoolSetup(info.poolNftId);
        //require(tokenInfo.objectAddress == address(poolSetup.token), "ERROR:COS-018:PRODUCT_POOL_TOKEN_MISMATCH");
        // TODO pool have the same owner?
        //require(_registry.ownerOf(poolNftId) == msg.sender, "NOT_POOL_OWNER");

        // distribution is registered
        IRegistry_new.ObjectInfo memory distributionInfo = _registry.getObjectInfo(info.distributionNftId);
        require(distributionInfo.objectType == DISTRIBUTION(), "ERROR:COS-016:UNKNOW_DISTRIBUTION"); 
        // distribution is on the same instance
        require(distributionInfo.parentNftId == instanceNftId, "ERROR:COS-017:DISTRIBUTION_INSTANCE_MISMATCH");
        // TODO distribution have the same owner?
        //require(_registry.ownerOf(distributionNftId) == msg.sender, "NOT_DISTRIBUTION_OWNER");

        // component module
        instance.registerComponent(
            nftId,
            info.token,
            info.wallet
        );
        // treasury module
        instance.registerProductSetup(
            nftId, 
            ITreasury.TreasuryInfo(
                info.poolNftId,
                info.distributionNftId,
                info.token,
                info.productFee,
                info.processingFee,
                FeeLib.zeroFee(),//pool.getPoolFee(),
                FeeLib.zeroFee(),//pool.getStakingFee(),
                FeeLib.zeroFee(),//pool.getPerformanceFee(),
                FeeLib.zeroFee()//distribution.getDistributionFee()
            )
        );
    }

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(1,0,0);
    } 

    // Internals

    function _registerPool(
        NftId nftId,
        NftId instanceNftId,
        IInstance instance,
        IPoolComponent.PoolComponentInfo memory info
    )
        internal
    {

        // pool's owner with role
        //require(_registry.ownerOf(nftId) == msg.sender);
        RoleId typeRole = getRoleForType(POOL());
        require(
            instance.hasRole(typeRole, msg.sender),
            "ERROR:COS-019:TYPE_ROLE_MISSING"
        );  

        IRegistry_new _registry = getRegistry();

        // check pool setup and info
        // token is registered -> TODO instance can personaly whitelist tokens too?
        address tokenAddress = address(info.token);
        ObjectType tokenType = _registry.getObjectInfo(tokenAddress).objectType;
        require(tokenType == TOKEN(), "ERROR:COS-020:UNKNOWN_TOKEN");  
        // TODO add more validations

        // component module
        instance.registerComponent(
            nftId,
            info.token,
            info.wallet
        ); 
        // treasury module
        //instance.registerPool(nftId, pool.setup);

        // pool module
        instance.registerPool(
            nftId, 
            IPool.PoolInfo(
                info.isVerifying,
                info.collateralizationLevel  
            )  
        );
    } 

    // from Versionable

    // top level initializer
    function _initialize(bytes memory data) 
        internal
        onlyInitializing
        virtual override
    {
        (address registry,
        NftId registryNftId) = abi.decode(data, (address, NftId));

        _initializeServiceBase(registry, registryNftId);

        _registerInterface(type(IRegistryService).interfaceId);
    }
}