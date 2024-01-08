// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {INftOwnable} from "../shared/INftOwnable.sol";
import {IVersionable} from "../shared/IVersionable.sol";
import {IRegisterable} from "../shared/IRegisterable.sol";
import {RoleId} from "../types/RoleId.sol";

import {IAccessModule} from "./module/access/IAccess.sol";
import {IBundleModule} from "./module/bundle/IBundle.sol";
import {IDistributionModule} from "./module/distribution/IDistribution.sol";
import {IComponentModule} from "./module/component/IComponent.sol";
import {IPolicyModule} from "./module/policy/IPolicy.sol";
import {IPoolModule} from "./module/pool/IPoolModule.sol";
import {IRiskModule} from "./module/risk/IRisk.sol";
import {ITreasuryModule} from "./module/treasury/ITreasury.sol";

import {IKeyValueStore} from "./base/IKeyValueStore.sol";
import {IRegistry} from "../registry/IRegistry.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IInstanceBase} from "./base/IInstanceBase.sol";

// solhint-disable-next-line no-empty-blocks
interface IInstance is
    IERC165,
    IVersionable,
    IRegisterable,
    IAccessModule,
    IPolicyModule,
    IPoolModule,
    IRiskModule,
    IBundleModule,
    IComponentModule,
    ITreasuryModule,
    IDistributionModule,
    IInstanceBase
{
    function getRegistry() external view override (INftOwnable) returns (IRegistry registry);
    function getOwner() external view override (IAccessModule, INftOwnable) returns(address owner);

    function getKeyValueStore() external view override (IInstanceBase) returns (IKeyValueStore keyValueStore);

    function getComponentOwnerService() external view override (IInstanceBase, IComponentModule, IPoolModule, ITreasuryModule) returns(IComponentOwnerService);
    function getDistributionService() external view override returns(IDistributionService);
    function getProductService() external view override (IInstanceBase, IBundleModule, IPolicyModule) returns(IProductService);
    function getPoolService() external view override (IInstanceBase, IBundleModule, IPoolModule) returns(IPoolService);

}
