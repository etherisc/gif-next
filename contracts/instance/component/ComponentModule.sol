// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RegistryLinked} from "../../registry/Registry.sol";
import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IAccessComponentTypeRoles, IAccessCheckRole} from "../access/IAccess.sol";
import {IInstance} from "../IInstance.sol";

import {LifecycleModule} from "../lifecycle/LifecycleModule.sol";
import {ITreasuryModule} from "../treasury/ITreasury.sol";
import {TreasuryModule} from "../treasury/TreasuryModule.sol";
import {IComponent, IComponentContract, IComponentModule, IComponentOwnerService} from "./IComponent.sol";
import {IProductComponent} from "../../components/IProduct.sol";
import {IPoolComponent} from "../../components/IPool.sol";
import {IPoolModule} from "../pool/IPoolModule.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, zeroFee} from "../../types/Fee.sol";

abstract contract ComponentModule is
    IRegistryLinked,
    IAccessComponentTypeRoles,
    IAccessCheckRole,
    IComponentModule
{
    using NftIdLib for NftId;

    mapping(NftId nftId => ComponentInfo info) private _componentInfo;
    mapping(address cAddress => NftId nftId) private _nftIdByAddress;
    NftId[] private _nftIds;

    mapping(ObjectType cType => bytes32 role) private _componentOwnerRole;

    // TODO maybe move this to Instance contract as internal variable?
    LifecycleModule private _lifecycleModule;
    TreasuryModule private _treasuryModule;
    IPoolModule private _poolModule;
    IComponentOwnerService private _componentOwnerService;

    modifier onlyComponentOwnerService() {
        require(
            address(_componentOwnerService) == msg.sender,
            "ERROR:CMP-001:NOT_OWNER_SERVICE"
        );
        _;
    }

    constructor(address componentOwnerService) {
        address componentAddress = address(this);
        _lifecycleModule = LifecycleModule(componentAddress);
        _treasuryModule = TreasuryModule(componentAddress);
        _poolModule = IPoolModule(componentAddress);
        _componentOwnerService = ComponentOwnerService(componentOwnerService);
    }

    function registerComponent(
        IComponentContract component,
        NftId nftId,
        ObjectType objectType,
        IERC20Metadata token
    ) external override onlyComponentOwnerService {

        // create component info
        _componentInfo[nftId] = ComponentInfo(
            nftId,
            _lifecycleModule.getInitialState(objectType),
            token
        );

        _nftIdByAddress[address(component)] = nftId;
        _nftIds.push(nftId);

        // TODO add logging
    }

    function getComponentOwnerService()
        external
        view
        override
        returns (IComponentOwnerService)
    {
        return _componentOwnerService;
    }

    function setComponentInfo(
        ComponentInfo memory info
    ) external onlyComponentOwnerService returns (NftId nftId) {
        nftId = info.nftId;
        require(
            nftId.gtz() && _componentInfo[nftId].nftId.eq(nftId),
            "ERROR:CMP-006:COMPONENT_UNKNOWN"
        );

        // TODO decide if state changes should have explicit functions and not
        // just a generic setXYZInfo and implicit state transitions
        // when in doubt go for the explicit approach ...
        ObjectType objectType = this.getRegistry().getInfo(nftId).objectType;
        _lifecycleModule.checkAndLogTransition(
            nftId,
            objectType,
            _componentInfo[nftId].state,
            info.state
        );
        _componentInfo[nftId] = info;
    }

    function getComponentInfo(
        NftId nftId
    ) external view override returns (ComponentInfo memory) {
        return _componentInfo[nftId];
    }

    function getComponentId(
        address componentAddress
    ) external view returns (NftId componentNftId) {
        return _nftIdByAddress[componentAddress];
    }

    function getComponentId(
        uint256 idx
    ) external view override returns (NftId componentNftId) {
        return _nftIds[idx];
    }

    function components()
        external
        view
        override
        returns (uint256 numberOfCompnents)
    {
        return _nftIds.length;
    }

    function getRoleForType(
        ObjectType cType
    ) public view override returns (bytes32 role) {
        if (cType == PRODUCT()) {
            return this.PRODUCT_OWNER_ROLE();
        }
        if (cType == POOL()) {
            return this.POOL_OWNER_ROLE();
        }
        if (cType == ORACLE()) {
            return this.ORACLE_OWNER_ROLE();
        }
    }
}

// this is actually the component owner service
contract ComponentOwnerService is
    RegistryLinked,
    IComponent,
    IComponentOwnerService
{
    using NftIdLib for NftId;

    modifier onlyRegisteredComponent(IComponentContract component) {
        NftId nftId = _registry.getNftId(address(component));
        require(nftId.gtz(), "ERROR:COS-001:COMPONENT_UNKNOWN");
        _;
    }

    constructor(
        address registry
    ) RegistryLinked(registry) // solhint-disable-next-line no-empty-blocks
    {

    }

    function register(
        IComponentContract component
    ) external override returns (NftId nftId) {
        address initialOwner = component.getInitialOwner();
        require(
            msg.sender == initialOwner,
            "ERROR:COS-003:NOT_OWNER"
        );

        IInstance instance = component.getInstance();
        ObjectType objectType = component.getType();
        bytes32 typeRole = instance.getRoleForType(objectType);
        require(
            instance.hasRole(typeRole, initialOwner),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );

        nftId = _registry.register(address(component));
        IERC20Metadata token = component.getToken();

        instance.registerComponent(
            component,
            nftId,
            objectType,
            token);

        address wallet = component.getWallet();

        // component type specific registration actions
        if (component.getType() == PRODUCT()) {
            IProductComponent product = IProductComponent(address(component));
            NftId poolNftId = product.getPoolNftId();
            require(poolNftId.gtz(), "ERROR:CMP-005:POOL_UNKNOWN");
            // validate pool token and product token are same

            // register with tresury
            // implement and add validation
            NftId distributorNftId = zeroNftId();
            instance.registerProduct(
                nftId,
                distributorNftId,
                poolNftId,
                token,
                wallet,
                product.getPolicyFee(),
                product.getProcessingFee()
            );
        } else if (component.getType() == POOL()) {
            IPoolComponent pool = IPoolComponent(address(component));

            // register with pool
            instance.registerPool(nftId);

            // register with tresury
            instance.registerPool(
                nftId,
                wallet,
                pool.getStakingFee(),
                pool.getPerformanceFee()
            );
        }
        // TODO add distribution
    }

    function lock(
        IComponentContract component
    ) external override onlyRegisteredComponent(component) {
        IInstance instance = component.getInstance();
        ComponentInfo memory info = instance.getComponentInfo(
            component.getNftId()
        );
        require(info.nftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info.state = PAUSED();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }

    function unlock(
        IComponentContract component
    ) external override onlyRegisteredComponent(component) {
        IInstance instance = component.getInstance();
        ComponentInfo memory info = instance.getComponentInfo(
            component.getNftId()
        );
        require(info.nftId.gtz(), "ERROR_COMPONENT_UNKNOWN");

        info.state = ACTIVE();
        // setComponentInfo checks for valid state changes
        instance.setComponentInfo(info);
    }

    function setProductFees(
        IComponentContract product,
        Fee memory policyFee,
        Fee memory processingFee
    ) external override onlyRegisteredComponent(product) {
        require(product.getType() == PRODUCT(), "ERROR_NOT_PRODUCT");

        address instanceAddress = address(product.getInstance());
        ITreasuryModule treasuryModule = ITreasuryModule(instanceAddress);
        treasuryModule.setProductFees(
            product.getNftId(),
            policyFee,
            processingFee
        );
    }
}
