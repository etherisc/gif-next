// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {BundleManager} from "./BundleManager.sol";
import {InstanceReader} from "./InstanceReader.sol";

import {IComponentOwnerService} from "./service/IComponentOwnerService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IBundleService} from "./service/IBundleService.sol";
import {IBundle} from "./module/IBundle.sol";
import {ISetup} from "./module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {StateId} from "../types/StateId.sol";
import {RiskId} from "../types/RiskId.sol";
import {IRisk} from "./module/IRisk.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IKeyValueStore} from "./base/IKeyValueStore.sol";


interface IInstance is IERC165, IKeyValueStore {

    function getComponentOwnerService() external view returns (IComponentOwnerService);
    function getDistributionService() external view returns (IDistributionService);
    function getProductService() external view returns (IProductService);
    function getPoolService() external view returns (IPoolService);
    function getPolicyService() external view returns (IPolicyService);
    function getBundleService() external view returns (IBundleService);

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

    function createRisk(RiskId riskId, IRisk.RiskInfo memory risk) external;
    function updateRisk(RiskId riskId, IRisk.RiskInfo memory risk, StateId newState) external;
    function updateRiskState(RiskId riskId, StateId newState) external;

    function createPolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy) external;
    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;
    function updatePolicyState(NftId policyNftId, StateId newState) external;

    function getInstanceReader() external view returns (InstanceReader);
    function getBundleManager() external view returns (BundleManager);
}