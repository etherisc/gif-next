// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {InstanceReader} from "./InstanceReader.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IBundle} from "./module/IBundle.sol";
import {ISetup} from "./module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {StateId} from "../types/StateId.sol";

interface IInstance is IERC165 {

    function getComponentOwnerService() external view returns (IComponentOwnerService);
    function getDistributionService() external view returns (IDistributionService);
    function getProductService() external view returns (IProductService);
    function getPoolService() external view returns (IPoolService);

    function createDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup) external;
    function updateDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup, StateId newState) external;
    function updateDistributionSetupState(NftId distributionNftId, StateId newState) external;

    function createPoolSetup(NftId poolNftId, ISetup.PoolSetupInfo memory setup) external;
    function updatePoolSetup(NftId poolNftId, ISetup.PoolSetupInfo memory setup, StateId newState) external;
    function updatePoolSetupState(NftId poolNftId, StateId newState) external;

    function createBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle) external;
    function updateBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle, StateId newState) external;
    function updateBundleState(NftId bundleNftId, StateId newState) external;

    function createProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup) external;
    function updateProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup, StateId newState) external;
    function updateProductSetupState(NftId productNftId, StateId newState) external;

    function getInstanceReader() external view returns (InstanceReader);
}