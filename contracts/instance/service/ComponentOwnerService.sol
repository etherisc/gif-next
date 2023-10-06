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
         IComponent.ProductComponentInfo memory productInfo) = product.getInitialProductInfo();

        require(info.initialOwner == msg.sender, "NOT_OWNER");// owner protection
        require(info.objectAddress == address(product), "WRONG_ADDRESS");
        require(info.objectType == PRODUCT(), "NOT_PRODUCT");
        // instance is registered
        NftId parentNftId = info.parentNftId;
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(parentNftId);
        require(instanceInfo.objectType == INSTANCE(), "UNKNOWN_INSTANCE");
        //.data
        
        // TODO check instance code / version  -> valid if registered?
    
        info.nftId = _registry.registerFrom(msg.sender, info);

        // "callstack is too deep" with this version
        //_registerProduct(parentNftId, productInfo);
        // using this instead
        _registerProduct(
            info.nftId,   // TODO ignores productInfo.nftId
            parentNftId,  // TODO ignores productInfo.parentNftId
            productInfo.distributorNftId, 
            productInfo.poolNftId,
            productInfo.token,
            productInfo.wallet,
            productInfo.policyFee,
            productInfo.processingFee       
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

        // check ObjectInfo
        require(info.objectAddress == address(pool), "WRONG_ADDRESS");
        require(info.initialOwner == msg.sender, "WRONG_OWNER");// owner protection 
        require(info.objectType == POOL(), "NOT_POOL");
        // instance is registered
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(info.parentNftId);
        require(instanceInfo.objectType == INSTANCE(), "UNKNOW_INSTANCE"); 
        //.data

        nftId = _registry.registerFrom(msg.sender, info);   

        poolInfo.nftId = nftId;
        _registerPool(info.parentNftId, poolInfo);
    }
    //function registerInstance(IInstance instance) // TODO IInstance brakes the tests 
    function registerInstance(IRegisterable instance) 
        external 
        returns(NftId nftId) 
    {
        // TODO create new Instance
        // TODO check interface 

        IRegistry.ObjectInfo memory info = instance.getInitialInfo();

        require(info.objectAddress == address(instance));
        require(info.initialOwner == msg.sender);// owner protection
        require(info.objectType == INSTANCE());
        IRegistry.ObjectInfo memory registryInfo = _registry.getObjectInfo(info.parentNftId);
        require(registryInfo.objectType == REGISTRY(), "WRONG_PARENT"); 

        nftId = _registry.registerFrom(msg.sender, info);      
    }

    function lock(
        IBaseComponent component
    ) external override onlyRegisteredComponent(component) {
        IInstance instance = component.getInstance();
        IComponent.ComponentInfo memory info = instance.getComponentInfo(
            component.getNftId()
        );
        require(info.nftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

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
        require(info.nftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info.state = ACTIVE();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }

    function _registerProduct(
        NftId nftId, 
        NftId instanceNftId,
        NftId distributorNftId,
        NftId poolNftId,
        IERC20Metadata token,
        address wallet,
        Fee memory policyFee,
        Fee memory processingFee
    )
        internal
    {
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        IInstance instance = IInstance(instanceInfo.objectAddress);

        // only product's owner with role
        require(_registry.ownerOf(nftId) == msg.sender);
        RoleId typeRole = getRoleForType(PRODUCT());
        require(
            instance.hasRole(typeRole, msg.sender),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );  

        // check ProductInfo
        // token is registered -> TODO instance can whitelist tokens too?
        IRegistry.ObjectInfo memory tokenInfo = _registry.getObjectInfo(address(token));
        require(tokenInfo.objectType == TOKEN(), "UNKNOWN_TOKEN"); 
        // pool is registered
        IRegistry.ObjectInfo memory poolInfo = _registry.getObjectInfo(poolNftId);
        require(poolInfo.objectType == POOL(), "UNKNOW_POOL"); 
        // pool is on the same instance
        require(poolInfo.parentNftId == instanceNftId, "POOL_INSTANCE_MISMATCH");
        // pool and product have the same token
        ITreasury.PoolSetup memory poolSetup = instance.getPoolSetup(poolNftId);
        require(tokenInfo.objectAddress == address(poolSetup.token), "PRODUCT_POOL_TOKEN_MISMATCH");
        // TODO pool and product have the same owner?
        //require(_registry.ownerOf(poolNftId) == msg.sender, "NOT_POOL_OWNER");
        // TODO pool is not attached to another product

        // component module
        instance.registerComponent(
            nftId,
            PRODUCT()
        );
        // treasury module
        instance.registerProduct(
            nftId,
            distributorNftId, 
            poolNftId,
            token,
            wallet,
            policyFee,
            processingFee
        );
    }
    function _registerPool(NftId instanceNftId, IComponent.PoolComponentInfo memory info)
        internal
    {
        NftId nftId = info.nftId;
        IRegistry.ObjectInfo memory instanceInfo = _registry.getObjectInfo(instanceNftId);
        IInstance instance = IInstance(instanceInfo.objectAddress);
    
        // pool's owner with role
        require(_registry.ownerOf(nftId) == msg.sender);
        RoleId typeRole = getRoleForType(POOL());
        require(
            instance.hasRole(typeRole, msg.sender),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );  

        // check PoolInfo
        // token is registered -> TODO instance can personaly whitelist tokens too?
        ObjectType tokenType = _registry.getObjectInfo( address(info.token) ).objectType;
        require(tokenType == TOKEN(), "UNKNOWN_TOKEN");  
        // TODO add more validations

        // component module
        instance.registerComponent(
            info.nftId,
            POOL()
        ); 
        // treasury module
        instance.registerPool(
            info.nftId,
            info.token,
            info.wallet, 
            info.stackingFee,
            info.perfomanceFee
        );  
        // pool module
        instance.registerPool(
            info.nftId,
            info.isVerifying,
            info.collateralizationLevel
        );
    }  
}
