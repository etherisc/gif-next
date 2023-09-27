// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Version, VersionPart, toVersion, toVersionPart} from "../../types/Version.sol";
import {ObjectType, PROTOCOL, REGISTRY, TOKEN, SERVICE, INSTANCE, STAKE, PRODUCT, DISTRIBUTOR, ORACLE, POOL, POLICY, BUNDLE} from "../../types/ObjectType.sol";
import {NftId, toNftId, zeroNftId, NftIdLib} from "../../types/NftId.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {IInstance} from "../IInstance.sol";
import {ServiceBase} from "./ServiceBase.sol";
import {IRegistry} from "../../registry/IRegistry.sol";

import {IProductBase} from "../../components/IProductBase.sol";
import {IPoolBase} from "../../components/IPoolBase.sol";

contract RegistryService is 
    ServiceBase // do service base needs a registry??? -> make registry agnostic??? -> do this service needs to be registered??
{
    using NftIdLib for NftId;

    string public constant NAME = "RegisterService";

    // TODO init in initialize()...
    /*ObjectInfo constant info = (
        // no nftId
        // no parent
        SERVICE,
        this, // address is not known...
        0,
        "";
    );*/

    /*modifier onlyOwnerWithRole(IRegistry registry, IInstance instance, address owner) { // to heavy
        ObjectType instanceType = registry.getObjectInfo(address(instance)).objectType;
        require(instanceType == INSTANCE(), "ERROR:RS-001:INSTANCE_UNKNOWN");

        require(
            instance.hasRole(PRODUCT(), initialOwner),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );
        _;
    }*/
    modifier onlyInstance(IRegistry registry) {
        ObjectType senderType = registry.getObjectInfo(msg.sender).objectType;
        require(senderType == INSTANCE(), "ERROR:RS-001:INSTANCE_UNKNOWN");
        _;
    }
    modifier onlyNonRegisteredInstance(IRegistry registry) {
        NftId nftId = registry.getObjectInfo(msg.sender).nftId;
        require(nftId.eqz(), "ERROR:RS-002:ALREADY_REGISTRED");
        _;
    }

    constructor(
        address registry, 
        NftId registryNftId// derive from registry?
    ) ServiceBase(registry, registryNftId) // solhint-disable-next-line no-empty-blocks
    {

    }

    // msg.sender -> never registred contract
    // msg.sender -> component owner -> if and only if msg.sender == info.initialOwner -> NOT USING
    // msg.sender -> component itself -> derive initialOwner from component
    function registerProduct(IProductBase product, IRegistry registry) public returns(NftId nftId)
    //onlyOwnerWithRole(instance)
    //onlyForRegistredInstance(registry)
    //onlyWithRegistredToken(registry)
    {
        IProductBase.ProductInfo memory productInfo = product.getProductInfo();
        //IRegistry.ObjectInfo memory info = product.getInfo(); 
        
        // instance is registred -> also done in registry... -> nope -> registry checks that msg.sender is not a registred contract 
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(productInfo.instanceNftId);
        require(instanceInfo.objectType == INSTANCE(), "UNKNOW_INSTANCE"); 
        // token is registred
        IRegistry.ObjectInfo memory tokenInfo = registry.getObjectInfo(productInfo.tokenNftId);
        require(tokenInfo.objectType == TOKEN(), "UNKNOWN_TOKEN"); 

        // owner has role from instance
        address initialOwner = productInfo.forRegistry.initialOwner;
        IInstance instance = IInstance(productInfo.forRegistry.objectAddress);
        bytes32 typeRole = instance.getRoleForType(PRODUCT());
        require(
            instance.hasRole(typeRole, initialOwner),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );

        productInfo.forRegistry.objectType = PRODUCT();

        nftId = registry.registerFor(initialOwner, address(product), productInfo.forRegistry);   

        // TODO read ObjectInfo from registry to be 100% consistent or do not use productInfo.forRegistry in instance ???
        productInfo.forRegistry = registry.getObjectInfo(nftId);

        // component registration inside
        /*instance.registerProduct(
            nftId,
            productInfo
        ); */  
    }
    function registerPool(IPoolBase pool, IRegistry registry) public returns(NftId nftId)
    //onlyOwnerWithRole(instance)
    //onlyForRegisteredInstance(registry, instance)
    //onlyWithRegisteredToken(registry, token)
    {
        IPoolBase.PoolInfo memory poolInfo = pool.getPoolInfo();
        //IRegistry.ObjectInfo memory info = pool.getInfo(); 

        // instance is registred -> also done in registry... -> nope -> registry checks that msg.sender is not a registred contract 
        IRegistry.ObjectInfo memory instanceInfo = registry.getObjectInfo(poolInfo.instanceNftId);
        require(instanceInfo.objectType == INSTANCE(), "UNKNOW_INSTANCE"); 
        // token is registred
        IRegistry.ObjectInfo memory tokenInfo = registry.getObjectInfo(poolInfo.tokenNftId);
        require(tokenInfo.objectType == TOKEN(), "UNKNOWN_TOKEN"); 

        // owner has role from instance
        address initialOwner = poolInfo.forRegistry.initialOwner;
        IInstance instance = IInstance(poolInfo.forRegistry.objectAddress);
        bytes32 typeRole = instance.getRoleForType(POOL());
        require(
            instance.hasRole(typeRole, initialOwner),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );

        poolInfo.forRegistry.objectType = POOL();

        nftId = registry.registerFor(initialOwner, address(pool), poolInfo.forRegistry);   

        // TODO read ObjectInfo from registry to be 100% consistent or do not use productInfo.forRegistry in instance ???
        poolInfo.forRegistry = registry.getObjectInfo(nftId);

        // component registration inside
        /*instance.registerPool(
            nftId,
            poolInfo
        );*/   
    }
    // anyone can register any Instance in any Registry
    function registerInstance(IInstance instance, IRegistry registry) 
        public 
        //onlyNonRegisteredInstance(registry)// but registry will cover that address(instance) is not registred
        returns(NftId nftId) 
    {
        IRegistry.ObjectInfo memory info = instance.getInfo();
        address initialOwner = info.initialOwner;

        info.objectType = INSTANCE();

        nftId = registry.registerFor(initialOwner, address(instance), info);      

        // TODO read ObjectInfo from registry to be 100% consistent???    
    }
    // TODO move to ProductService?
    // msg.sender -> is always registered contract
    // lock collateral and transfer premium here ???
    /*function registerPolicy(IRegistry registry, PolicyInfo memory policy)
        public 
        OnlyInstance(registry)
        returns(NftId nftId)
    {
        // intialize all state related to policy
        // only registred msg.sender can do
        // register can check that msg.sender instance??? -> then call to instance is not here? -> no registry allows only to registry service?
        nftId = registry.registerFor(msg.sender, policy.info);  

        IInstance instance = IInstance(msg.sender); 
        instance.createApplication(nftId, policy);// ???
    }
    // TODO move to PoolService?
    function registerBundle(IRegistry registry, BundleInfo memory bundle) 
        public 
        OnlyInstance(registry)
        returns(NftId nftId)
    {
        // intialize all state related to bundle
        // only registred msg.sender can do -> duplicate check with OnlyInstance
        nftId = registry.registerFor(msg.sender, bundle.info); 

        IInstance instance = IInstance(msg.sender);
        instance.createBundle(nftId, bundle);// ???
    }*/

    // IService
    function getName() external pure returns(string memory name) { return NAME; }
    //function getMajorVersion() external view returns(VersionPart majorVersion) { require(msg.sender == 0); }

    // IVersionable
        function getVersion()
        public 
        pure 
        virtual override (IVersionable, Versionable)
        returns(Version)
    {
        return toVersion(
            toVersionPart(3),
            toVersionPart(0),
            toVersionPart(0));
    }

}
