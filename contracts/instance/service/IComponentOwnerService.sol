// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {ObjectType} from "../../types/ObjectType.sol";
import {RoleId} from "../../types/RoleId.sol";
import {IBaseComponent} from "../../components/IBaseComponent.sol";
import {IService} from "./IService.sol";

// TODO rename to registry service
interface IComponentOwnerService is IService {

    function register(IBaseComponent component) external returns(NftId componentNftId);

    // TODO move to product/pool services
    function lock(IBaseComponent component) external;

    // TODO move to product/pool services
    function unlock(IBaseComponent component) external;

    function getRoleForType(ObjectType cType) external pure returns (RoleId role);
}
