// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {NftId} from "../types/NftId.sol";
import {StateId} from "../types/StateId.sol";
import {RiskId} from "../types/RiskId.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";

import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceReader} from "./InstanceReader.sol";

import {IBundle} from "./module/IBundle.sol";
import {IBundleService} from "./service/IBundleService.sol";
import {IDistributionService} from "./service/IDistributionService.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {IKeyValueStore} from "./base/IKeyValueStore.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IPoolService} from "./service/IPoolService.sol";
import {IProductService} from "./service/IProductService.sol";
import {IPolicyService} from "./service/IPolicyService.sol";
import {IBundleService} from "./service/IBundleService.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {RiskId} from "../types/RiskId.sol";
import {StateId} from "../types/StateId.sol";
import {VersionPart} from "../types/Version.sol";
import {Key32} from "../types/Key32.sol";




interface IInstance is IRegisterable, IKeyValueStore, IAccessManaged {

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

    function createDistributorType(Key32 distributorKey, IDistribution.DistributorTypeInfo memory info) external;
    function updateDistributorType(Key32 distributorKey, IDistribution.DistributorTypeInfo memory info, StateId newState) external;
    function updateDistributorTypeState(Key32 distributorKey, StateId newState) external;

    function createDistributor(NftId nftId, IDistribution.DistributorInfo memory info) external;
    function updateDistributor(NftId nftId, IDistribution.DistributorInfo memory info, StateId newState) external;
    function updateDistributorState(NftId nftId, StateId newState) external;

    function createReferral(Key32 referralKey, IDistribution.ReferralInfo memory referralInfo) external;
    function updateReferral(Key32 referralKey, IDistribution.ReferralInfo memory referralInfo, StateId newState) external;
    function updateReferralState(Key32 referralKey, StateId newState) external;

    function createRisk(RiskId riskId, IRisk.RiskInfo memory risk) external;
    function updateRisk(RiskId riskId, IRisk.RiskInfo memory risk, StateId newState) external;
    function updateRiskState(RiskId riskId, StateId newState) external;

    function createApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy) external;
    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;
    function updateApplicationState(NftId applicationNftId, StateId newState) external;

    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;
    function updatePolicyState(NftId policyNftId, StateId newState) external;

    // TODO add claims/payouts function to instance
    // function updateClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;

    function getMajorVersion() external pure returns (VersionPart majorVersion);
    function getInstanceReader() external view returns (InstanceReader);
    function getBundleManager() external view returns (BundleManager);
}