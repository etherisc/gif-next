// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../../contracts/types/NftId.sol";
import {ObjectType} from "../../contracts/types/ObjectType.sol";
import {RoleId} from "../../contracts/types/RoleId.sol";
import {IBaseComponent} from "../../contracts/components/IBaseComponent.sol";
import {IService} from "../../contracts/instance/base/IService.sol";

import {IProductComponent} from "../../contracts/components/IProductComponent.sol";
import {IPoolComponent} from "../../contracts/components/IPoolComponent.sol";
import {IDistributionComponent} from "../../contracts/components/IDistributionComponent.sol";

// TODO rename to registry service
interface IRegistryService is IService {

    function registerProduct(IProductComponent product) external returns(NftId nftId);

    function registerPool(IPoolComponent pool) external returns(NftId nftId);

    function registerDistribution(IDistributionComponent distribution) external returns(NftId nftId);
    // TODO not here?
    function getRoleForType(ObjectType cType) external pure returns (RoleId role);
}

