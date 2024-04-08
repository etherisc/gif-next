// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {ClaimId} from "../types/ClaimId.sol";
import {DistributorType} from "../types/DistributorType.sol";
import {PayoutId} from "../types/PayoutId.sol";
import {NftId} from "../types/NftId.sol";
import {StateId} from "../types/StateId.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId} from "../types/RiskId.sol";
import {VersionPart} from "../types/Version.sol";
import {Key32} from "../types/Key32.sol";

import {IRegisterable} from "../shared/IRegisterable.sol";

import {ITransferInterceptor} from "../registry/ITransferInterceptor.sol";

import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {BundleManager} from "./BundleManager.sol";
import {InstanceReader} from "./InstanceReader.sol";

import {IBundle} from "./module/IBundle.sol";
import {IBundleService} from "./service/IBundleService.sol";
import {IComponents} from "./module/IComponents.sol";
import {InstanceAccessManager} from "./InstanceAccessManager.sol";
import {IKeyValueStore} from "./base/IKeyValueStore.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IRisk} from "./module/IRisk.sol";
import {ISetup} from "./module/ISetup.sol";



interface IInstance is 
    IRegisterable, 
    ITransferInterceptor, 
    IAccessManaged, 
    IKeyValueStore 
{
    error ErrorInstanceInstanceAccessManagerAlreadySet(address instanceAccessManager);
    error ErrorInstanceInstanceAccessManagerAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceBundleManagerAlreadySet(address instanceBundleManager);
    error ErrorInstanceBundleManagerInstanceMismatch(address instance);
    error ErrorInstanceBundleManagerAuthorityMismatch(address instanceAuthority);

    error ErrorInstanceInstanceReaderInstanceMismatch(address instanceAuthority);

    function createDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup) external;
    function updateDistributionSetup(NftId distributionNftId, ISetup.DistributionSetupInfo memory setup, StateId newState) external;
    function updateDistributionSetupState(NftId distributionNftId, StateId newState) external;

    function createPoolSetup(NftId poolNftId, IComponents.ComponentInfo memory info) external;
    function updatePoolSetup(NftId poolNftId, IComponents.ComponentInfo memory info, StateId newState) external;
    function updatePoolSetupState(NftId poolNftId, StateId newState) external;

    function createBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle) external;
    function updateBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle, StateId newState) external;
    function updateBundleState(NftId bundleNftId, StateId newState) external;

    function createProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup) external;
    function updateProductSetup(NftId productNftId, ISetup.ProductSetupInfo memory setup, StateId newState) external;
    function updateProductSetupState(NftId productNftId, StateId newState) external;

    function createDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info) external;
    function updateDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info, StateId newState) external;
    function updateDistributorTypeState(DistributorType distributorType, StateId newState) external;

    function createDistributor(NftId nftId, IDistribution.DistributorInfo memory info) external;
    function updateDistributor(NftId nftId, IDistribution.DistributorInfo memory info, StateId newState) external;
    function updateDistributorState(NftId nftId, StateId newState) external;

    function createReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo) external;
    function updateReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo, StateId newState) external;
    function updateReferralState(ReferralId referralId, StateId newState) external;

    function createRisk(RiskId riskId, IRisk.RiskInfo memory risk) external;
    function updateRisk(RiskId riskId, IRisk.RiskInfo memory risk, StateId newState) external;
    function updateRiskState(RiskId riskId, StateId newState) external;

    function createApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy) external;
    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;
    function updateApplicationState(NftId applicationNftId, StateId newState) external;

    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;
    function updatePolicyClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external;
    function updatePolicyState(NftId policyNftId, StateId newState) external;

    function createClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim) external;
    function updateClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim, StateId newState) external;
    function updateClaimState(NftId policyNftId, ClaimId claimId, StateId newState) external;

    function createPayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory claim) external;
    function updatePayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory claim, StateId newState) external;
    function updatePayoutState(NftId policyNftId, PayoutId payoutId, StateId newState) external;

    function getMajorVersion() external pure returns (VersionPart majorVersion);
    function getInstanceReader() external view returns (InstanceReader);
    function getBundleManager() external view returns (BundleManager);
    function getInstanceAccessManager() external view returns (InstanceAccessManager);
}