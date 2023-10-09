// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {RoleId} from "../../types/RoleId.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IService} from "../base/IService.sol";
import {IProductComponent} from "../../components/IProductComponent.sol";
import {IPoolComponent} from "../../components/IPoolComponent.sol";
import {IRegisterable} from "../../shared/IRegisterable.sol";

// TODO rename to registry service
interface IComponentOwnerService is IService {

    function registerPool(IPoolComponent pool) external returns(NftId nftId);

    function registerProduct(IProductComponent product) external returns(NftId nftId);
    // TODO move into InstanceService
    function registerInstance(IRegisterable instance) external returns(NftId nftId);

    // TODO move to product/pool services
    function lock(IBaseComponent component) external;

    // TODO move to product/pool services
    function unlock(IBaseComponent component) external;

    function getRoleForType(ObjectType cType) external pure returns (RoleId role);
}
