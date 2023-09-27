// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";

import {LifecycleModule} from "../module/lifecycle/LifecycleModule.sol";
import {ITreasuryModule} from "../module/treasury/ITreasury.sol";
import {TreasuryModule} from "../module/treasury/TreasuryModule.sol";
import {IComponent, IComponentModule} from "../module/component/IComponent.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";

import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../types/RoleId.sol";
import {ObjectType, PRODUCT, ORACLE, POOL} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee, zeroFee} from "../../types/Fee.sol";
import {Version, toVersion, toVersionPart} from "../../types/Version.sol";

import {IProductComponent} from "../../components/IProductComponent.sol";
import {ServiceBase} from "./ServiceBase.sol";
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
        return toVersion(
            toVersionPart(3),
            toVersionPart(0),
            toVersionPart(0));
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

    function register(
        IBaseComponent component
    ) external override returns (NftId nftId) {
        address initialOwner = component.getOwner();
        require(
            msg.sender == address(component),
            "ERROR:COS-003:NOT_COMPONENT"
        );

        IInstance instance = component.getInstance();
        ObjectType objectType = component.getType();
        RoleId typeRole = getRoleForType(objectType);
        require(
            instance.hasRole(typeRole, initialOwner),
            "ERROR:CMP-004:TYPE_ROLE_MISSING"
        );

        nftId = _registry.register(address(component));
        IERC20Metadata token = component.getToken();

        instance.registerComponent(
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
            instance.registerPool(
                nftId,
                pool.isVerifying(),
                pool.getCollateralizationLevel());

            // register with tresury
            instance.registerPool(
                nftId,
                wallet,
                pool.getStakingFee(),
                pool.getPerformanceFee());
        }
        // TODO add distribution
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
}
