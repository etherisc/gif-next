// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {NftId} from "../types/NftId.sol";
import {ObjectType} from "../types/ObjectType.sol";
import {RoleId} from "../types/RoleId.sol";
import {IService} from "../shared/IService.sol";
import {IRegistry} from "./IRegistry.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";
import {IBaseComponent} from "../components/IBaseComponent.sol";

interface IRegistryService is IService {

    function registerService(IService service)  external returns(IRegistry.ObjectInfo memory info, bytes memory data);

    function registerInstance(IRegisterable instance)
        external returns(IRegistry.ObjectInfo memory info, bytes memory data); 

    function registerProduct(IBaseComponent product, address owner)
         external returns(IRegistry.ObjectInfo memory info, bytes memory data);

    function registerPool(IBaseComponent pool, address owner)
         external returns(IRegistry.ObjectInfo memory info, bytes memory data);

    function registerDistribution(IBaseComponent distribution, address owner)
         external returns(IRegistry.ObjectInfo memory info, bytes memory data);

    function registerPolicy(IRegistry.ObjectInfo memory info) external returns(NftId nftId); // -> easy to upgrade

    function registerBundle(IRegistry.ObjectInfo memory info) external returns(NftId nftId); 
}

