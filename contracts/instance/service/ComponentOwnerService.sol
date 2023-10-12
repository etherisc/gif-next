// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";

import {ITreasury, ITreasuryModule} from "../module/treasury/ITreasury.sol";
import {TreasuryModule} from "../module/treasury/TreasuryModule.sol";
import {IComponent, IComponentModule} from "../module/component/IComponent.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";
import {IRegisterable} from "../../shared/IRegisterable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../types/RoleId.sol";
import {ObjectType, REGISTRY, PRODUCT, ORACLE, POOL, TOKEN, INSTANCE} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IProductComponent} from "../../components/IProductComponent.sol";
import {ServiceBase} from "../base/ServiceBase.sol";
import {IComponentOwnerService} from "./IComponentOwnerService.sol";

contract ComponentOwnerService is
    ServiceBase,
    IComponentOwnerService
{
    using NftIdLib for NftId;

    string public constant NAME = "ComponentOwnerService";

    modifier onlyRegisteredComponent(IBaseComponent component) {
        NftId nftId = _registry.getNftId(address(component));
        require(nftId.gtz(), "ERROR:COS-001:COMPONENT_UNKNOWN");
        _;
    }

    constructor(
        address registry,
        NftId registryNftId
    ) ServiceBase(registry, registryNftId) // solhint-disable-next-line no-empty-blocks
    {

    }

    function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return VersionLib.toVersion(3,0,0);
    }

    function getName() external pure override returns(string memory name) {
        return NAME;
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

        // TODO check product version / code
        // TODO check interface 

        (IRegistry.ObjectInfo memory info,
        ITreasury.ProductSetup memory setup) = product.getInitialProductInfo();

        require(info.initialOwner == msg.sender, "ERROR:COS-002:NOT_OWNER");// owner protection
        require(info.objectAddress == address(product), "ERROR:COS-003:WRONG_ADDRESS");
        require(info.objectType == PRODUCT(), "ERROR:COS-004:NOT_PRODUCT");
        // instance is registered
        NftId instanceNftId = info.parentNftId;
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        require(instanceInfo.objectType == INSTANCE(), "ERROR:COS-005:UNKNOWN_INSTANCE");
        //.data
        
        // TODO check instance code / version  -> valid if registered?
    
        nftId = _registry.registerFrom(msg.sender, info);

        _registerProduct(
            nftId, 
            instanceNftId,
            IInstance(instanceInfo.objectAddress),
            setup
        );
    }
    function registerPool(IPoolComponent pool)
        external 
        returns(NftId nftId)
    {
        // self registration not allowed
        require(msg.sender != address(pool));

        // TODO check pool version / code
        // TODO check interface      

        (IRegistry.ObjectInfo memory info,
        IComponent.PoolComponentInfo memory poolInfo) = pool.getInitialPoolInfo();

        require(info.initialOwner == msg.sender, "ERROR:COS-007:NOT_OWNER");// owner protection 
        require(info.objectAddress == address(pool), "ERROR:COS-008:WRONG_ADDRESS");
        require(info.objectType == POOL(), "ERROR:COS-009:NOT_POOL");
        // instance is registered
        NftId instanceNftId = info.parentNftId;
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
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
    //function registerInstance(IInstance instance) // TODO IInstance brakes the tests 
    function registerInstance(IRegisterable instance) 
        external 
        returns(NftId nftId) 
    {
        // TODO create new Instance
        // TODO check interface 

        IRegistry.ObjectInfo memory info = instance.getInitialInfo();

        require(info.initialOwner == msg.sender);// owner protection
        require(info.objectAddress == address(instance));
        require(info.objectType == INSTANCE());
        IRegistry.ObjectInfo memory registryInfo = _registry.getObjectInfo(info.parentNftId);
        require(registryInfo.objectType == REGISTRY(), "ERROR:COS-011:UNKNOWN_REGISTRY"); 

        nftId = _registry.registerFrom(msg.sender, info);      
    }

    function lock(
        IBaseComponent component
    ) external override onlyRegisteredComponent(component) {
        IInstance instance = component.getInstance();
        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            component.getNftId()
        );
        require(info.nftId.gtz(), "ERROR:COS-012:ERROR_COMPONENT_UNKNOWN");

        info.state = PAUSED();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }

    function unlock(
        IBaseComponent component
    ) external override onlyRegisteredComponent(component) {
        IInstance instance = component.getInstance();
        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            component.getNftId()
        );
        require(info.nftId.gtz(), "ERROR:COS-013:ERROR_COMPONENT_UNKNOWN");

        info.state = ACTIVE();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }

    function _registerProduct(
        NftId nftId, 
        NftId instanceNftId,
        IInstance instance,
        ITreasury.ProductSetup memory setup
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

        // check product setup
        // token is registered -> TODO instance can whitelist tokens too?
        IRegistry.ObjectInfo memory tokenInfo = _registry.getObjectInfo(address(setup.token));
        require(tokenInfo.objectType == TOKEN(), "ERROR:COS-015:UNKNOWN_TOKEN"); 
        // pool is registered
        IRegistry.ObjectInfo memory poolInfo = _registry.getObjectInfo(setup.poolNftId);
        require(poolInfo.objectType == POOL(), "ERROR:COS-016:UNKNOW_POOL"); 
        // pool is on the same instance
        require(poolInfo.parentNftId == instanceNftId, "ERROR:COS-017:POOL_INSTANCE_MISMATCH");
        // pool have the same token
        ITreasury.PoolSetup memory poolSetup = instance.getPoolSetup(setup.poolNftId);
        require(tokenInfo.objectAddress == address(poolSetup.token), "ERROR:COS-018:PRODUCT_POOL_TOKEN_MISMATCH");
        // TODO pool have the same owner?
        //require(_registry.ownerOf(poolNftId) == msg.sender, "NOT_POOL_OWNER");
        // TODO pool is not attached to another product

        // component module
        instance.registerComponent(
            nftId,
            PRODUCT()
        );
        // treasury module
        setup.nftId = nftId;
        instance.registerProduct(setup);
    }

    function _registerPool(
        NftId nftId,
        NftId instanceNftId,
        IInstance instance,
        IComponent.PoolComponentInfo memory pool
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

        // check pool setup and info
        // token is registered -> TODO instance can personaly whitelist tokens too?
        address tokenAddress = address(pool.setup.token);
        ObjectType tokenType = _registry.getObjectInfo(tokenAddress).objectType;
        require(tokenType == TOKEN(), "ERROR:COS-020:UNKNOWN_TOKEN");  
        // TODO add more validations

        // component module
        instance.registerComponent(
            nftId,
            POOL()
        ); 
        // treasury module
        pool.setup.nftId = nftId;
        instance.registerPool(pool.setup);

        // pool module
        pool.info.nftId = nftId;
        instance.registerPool(pool.info);
    }  
}
