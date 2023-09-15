// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RegistryLinked} from "../../registry/Registry.sol";
import {IRegistry, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IAccessComponentTypeRoles, IAccessCheckRole} from "../module/access/IAccess.sol";
import {IInstance} from "../IInstance.sol";

import {LifecycleModule} from "../module/lifecycle/LifecycleModule.sol";
import {ITreasuryModule} from "../module/treasury/ITreasury.sol";
import {TreasuryModule} from "../module/treasury/TreasuryModule.sol";
import {IComponent, IComponentContract, IComponentModule} from "../module/component/IComponent.sol";
import {IProductComponent} from "../../components/IProduct.sol";
import {IPoolComponent} from "../../components/IPool.sol";
import {IPoolModule} from "../module/pool/IPoolModule.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, zeroFee} from "../../types/Fee.sol";

import {IComponentOwnerService} from "./IComponentOwnerService.sol";

contract ComponentOwnerService is
    RegistryLinked,
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
}
