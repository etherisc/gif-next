// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;


import {NftId} from "../../types/NftId.sol";

import {IRegistry} from "../../registry/IRegistry.sol";
import {IService} from "./IService.sol";
import {IInstance} from "../IInstance.sol";

import {IProductBase} from "../../components/IProductBase.sol";
import {IPoolBase} from "../../components/IPoolBase.sol";

interface IRegistryService is IService 
{
    function registerProduct(IProductBase product, IRegistry registry) external returns(NftId nftId);
    function registerPool(IPoolBase pool, IRegistry registry) external returns(NftId nftId);
    function registerInstance(IInstance instance, IRegistry registry) external returns(NftId nftId); 
    //function registerPolicy(IRegistry registry, PolicyInfo memory policy) external returns(NftId nftId);
    //function registerBundle(IRegistry registry, BundleInfo memory bundle) external returns(NftId nftId); 
}
