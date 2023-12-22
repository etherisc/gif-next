// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";

import {ITreasury, ITreasuryModule} from "../module/treasury/ITreasury.sol";
import {TreasuryModule} from "../module/treasury/TreasuryModule.sol";
import {IComponent, IComponentModule} from "../module/component/IComponent.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IKeyValueStore} from "../../instance/base/IKeyValueStore.sol";
import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../types/RoleId.sol";
import {ObjectType, TOKEN, COMPONENT, PRODUCT, ORACLE, POOL, DISTRIBUTION} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {Key32} from "../../types/Key32.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";
import {UFixed, UFixedMathLib} from "../../types/UFixed.sol";

import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {IService} from "../base/IService.sol";
import {IComponentOwnerService} from "./IComponentOwnerService.sol";
import {ServiceBase} from "../base/ServiceBase.sol";
import {IPool, IPoolModule} from "../module/pool/IPoolModule.sol";

import {IRegistryService} from "../../registry/IRegistryService.sol";

contract ComponentOwnerService is
    ServiceBase,
    IComponentOwnerService
{
    using NftIdLib for NftId;

    error MissingTypeRole();
    error WalletIsZero();
    error InvalidToken();
    error InvalidPool();
    error InvalidDistribution();
    error InvalidPoolsInstance();
    error InvalidDistributionsInstance();

    error CollateralizationLevelIsZero();

    string public constant NAME = "ComponentOwnerService";

    modifier onlyRegisteredComponent(IBaseComponent component) {
        NftId nftId = getRegistry().getNftId(address(component));
        require(nftId.gtz(), "ERROR:COS-001:COMPONENT_UNKNOWN");
        _;
    }

    constructor(
        address registry,
        NftId registryNftId,
        address initialOwner
    )
    {
        _initializeServiceBase(registry, registryNftId, initialOwner);
        _registerInterface(type(IComponentOwnerService).interfaceId);
    }

    function getName() public pure override(IService, ServiceBase) returns(string memory name) {
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
        if (cType == DISTRIBUTION()) {
            return DISTRIBUTION_OWNER_ROLE();
        }
        if (cType == ORACLE()) {
            return ORACLE_OWNER_ROLE();
        }
    }

    function getRegistryService() public view virtual returns (IRegistryService) {
        address service = getRegistry().getServiceAddress("RegistryService", getMajorVersion());
        return IRegistryService(service);
    }

    // TODO if user passes type BUNDLE??? -> registerComponent() must catch this
    function register(	
        IBaseComponent component,
        ObjectType componentType 	
    ) external returns (NftId nftId) {	

        // TODO some info parameters from component and from register may differ -> getObjectInfo() after registration?
        (
            IRegistry.ObjectInfo memory info,
            bytes memory data
        ) = getRegistryService().registerComponent(
            component, 
            componentType, 
            msg.sender);	

        NftId instanceNftId = info.parentNftId;
        address instancAddress = getRegistry().getObjectInfo(instanceNftId).objectAddress;
        IInstance instance = IInstance(instancAddress);

        RoleId typeRole = getRoleForType(componentType);
        if(instance.hasRole(typeRole, msg.sender) == false) {
            revert MissingTypeRole();
        } 

        // component type specific registration actions	
        if (componentType == PRODUCT()) {	
            _registerProduct(
                    info.nftId, 
                    instanceNftId,
                    instance,
                    data
            );
        } else if (componentType == POOL()) {	
            _registerPool(
                info.nftId,
                instanceNftId,
                instance,
                data
            );
        }	
        // TODO add distribution and oracle	
    }

    function lock(
        IBaseComponent component
    ) external override onlyRegisteredComponent(component) {
        // TODO use msg.sender to get component and get instance via registered parent nft id
        IInstance instance = component.getInstance();
        NftId nftId = component.getNftId();
        Key32 key = nftId.toKey32(COMPONENT());
        instance.updateState(key, PAUSED());
    }

    function unlock(
        IBaseComponent component
    ) external override onlyRegisteredComponent(component) {
        // TODO use msg.sender to get component and get instance via registered parent nft id
        IInstance instance = component.getInstance();
        NftId nftId = component.getNftId();
        Key32 key = nftId.toKey32(COMPONENT());
        instance.updateState(key, ACTIVE());
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
        (
            ITreasury.TreasuryInfo memory info,
            address wallet
        )  = abi.decode(data, (ITreasury.TreasuryInfo, address));

        IRegistry _registry = getRegistry();

        if(wallet == address(0)) {
            revert WalletIsZero();
        }

        IRegistry.ObjectInfo memory tokenInfo = _registry.getObjectInfo(address(info.token));

        if(tokenInfo.objectType != TOKEN()) {
            revert InvalidToken();
        } 

        IRegistry.ObjectInfo memory poolInfo = _registry.getObjectInfo(info.poolNftId);

        if(poolInfo.objectType != POOL()) {
            revert InvalidPool();
        }

        if(poolInfo.parentNftId != instanceNftId) {
            revert InvalidPoolsInstance();
        }
        // TODO pool have the same token
        //ITreasury.PoolSetup memory poolSetup = instance.getPoolSetup(info.poolNftId);
        //require(tokenInfo.objectAddress == address(poolSetup.token), "ERROR:COS-018:PRODUCT_POOL_TOKEN_MISMATCH");
        // TODO pool is not linked

        IRegistry.ObjectInfo memory distributionInfo = _registry.getObjectInfo(info.distributionNftId);

        if(distributionInfo.objectType != DISTRIBUTION()) {
            revert  InvalidDistribution();
        } 

        if(distributionInfo.parentNftId != instanceNftId) {
            revert InvalidDistributionsInstance();
        }
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
        (
            IPool.PoolInfo memory info,
            address wallet,
            IERC20Metadata token,
            /*poolFee*/,
            /*stakingFee*/,
            /*performanceFee*/
        )  = abi.decode(data, (IPool.PoolInfo, address, IERC20Metadata, Fee, Fee, Fee));

        IRegistry _registry = getRegistry();

        if(wallet == address(0)) {
            revert WalletIsZero();
        }

        ObjectType tokenType = _registry.getObjectInfo(address(token)).objectType;

        if(tokenType != TOKEN()) {
            revert InvalidToken();
        } 

        if(UFixedMathLib.eqz(info.collateralizationLevel)) { 
            revert CollateralizationLevelIsZero();
        }

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
}