// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin5/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IInstance} from "../IInstance.sol";

import {ITreasuryModule} from "../module/treasury/ITreasury.sol";
import {TreasuryModule} from "../module/treasury/TreasuryModule.sol";
import {IComponent, IComponentModule} from "../module/component/IComponent.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IKeyValueStore} from "../../instance/base/IKeyValueStore.sol";
import {IVersionable} from "../../shared/IVersionable.sol";
import {Versionable} from "../../shared/Versionable.sol";

import {RoleId, PRODUCT_OWNER_ROLE, POOL_OWNER_ROLE, DISTRIBUTION_OWNER_ROLE, ORACLE_OWNER_ROLE} from "../../types/RoleId.sol";
import {ObjectType, COMPONENT, PRODUCT, ORACLE, POOL, DISTRIBUTION} from "../../types/ObjectType.sol";
import {StateId, ACTIVE, PAUSED} from "../../types/StateId.sol";
import {Key32} from "../../types/Key32.sol";
import {NftId, NftIdLib, zeroNftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {Version, VersionLib} from "../../types/Version.sol";

import {IDistributionComponent} from "../../components/IDistributionComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
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
        if (cType == DISTRIBUTION()) {
            return DISTRIBUTION_OWNER_ROLE();
        }
        if (cType == ORACLE()) {
            return ORACLE_OWNER_ROLE();
        }
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
}
