// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Amount} from "../type/Amount.sol";
import {Key32, KeyId, Key32Lib} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {ObjectType, BUNDLE, DISTRIBUTION, FEE, INSTANCE, POLICY, POOL, ROLE, PRODUCT, TARGET, COMPONENT, DISTRIBUTOR, DISTRIBUTOR_TYPE} from "../type/ObjectType.sol";
import {RiskId, RiskIdLib} from "../type/RiskId.sol";
import {RoleId, RoleIdLib, INSTANCE_ROLE, INSTANCE_OWNER_ROLE} from "../type/RoleId.sol";
import {StateId, ACTIVE} from "../type/StateId.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {VersionPart, VersionPartLib} from "../type/Version.sol";
import {ReferralId} from "../type/Referral.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {PayoutId} from "../type/PayoutId.sol";

import {BalanceStore} from "./base/BalanceStore.sol";
import {IInstance} from "./IInstance.sol";
import {KeyValueStore} from "./base/KeyValueStore.sol";
import {IKeyValueStore} from "./base/KeyValueStore.sol";

import {IBundle} from "./module/IBundle.sol";
import {IComponents} from "./module/IComponents.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";


contract InstanceStore is
    AccessManagedUpgradeable, 
    KeyValueStore,
    BalanceStore
{
    function initialize(address instance)
        public 
        initializer()
    {
        address authority = IInstance(instance).authority();
        __AccessManaged_init(authority);
        initializeLifecycle();
    }

    //--- Component ---------------------------------------------------------//
    function createComponent(
        NftId componentNftId, 
        IComponents.ComponentInfo memory componentInfo
    )
        external 
        restricted()
    {
        _registerTarget(componentNftId);
        create(_toNftKey32(componentNftId, COMPONENT()), abi.encode(componentInfo));
    }

    function updateComponent(
        NftId componentNftId, 
        IComponents.ComponentInfo memory componentInfo,
        StateId newState
    )
        external 
        restricted()
    {
        update(_toNftKey32(componentNftId, COMPONENT()), abi.encode(componentInfo), newState);
    }

    //--- ProductSetup ------------------------------------------------------//

    function createProduct(NftId productNftId, IComponents.ProductInfo memory info) external restricted() {
        create(_toNftKey32(productNftId, PRODUCT()), abi.encode(info));
    }

    function updateProduct(NftId productNftId, IComponents.ProductInfo memory info, StateId newState) external restricted() {
        update(_toNftKey32(productNftId, PRODUCT()), abi.encode(info), newState);
    }

    function updateProductSetupState(NftId productNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(productNftId, PRODUCT()), newState);
    }

    //--- PoolSetup ------------------------------------------------------//

    function createPool(
        NftId poolNftId, 
        IComponents.PoolInfo memory info
    )
        external 
        restricted()
    {
        create(_toNftKey32(poolNftId, POOL()), abi.encode(info));
    }

    function updatePool(NftId poolNftId, IComponents.PoolInfo memory info, StateId newState) external restricted() {
        update(_toNftKey32(poolNftId, POOL()), abi.encode(info), newState);
    }

    function updatePoolState(NftId poolNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(poolNftId, POOL()), newState);
    }

    //--- DistributorType -------------------------------------------------------//
    function createDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info) external restricted() {
        create(distributorType.toKey32(), abi.encode(info));
    }

    function updateDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info, StateId newState) external restricted() {
        update(distributorType.toKey32(), abi.encode(info), newState);
    }

    function updateDistributorTypeState(DistributorType distributorType, StateId newState) external restricted() {
        updateState(distributorType.toKey32(), newState);
    }

    //--- Distributor -------------------------------------------------------//
    function createDistributor(NftId distributorNftId, IDistribution.DistributorInfo memory info) external restricted() {
        create(_toNftKey32(distributorNftId, DISTRIBUTOR()), abi.encode(info));
    }

    function updateDistributor(NftId distributorNftId, IDistribution.DistributorInfo memory info, StateId newState) external restricted() {
        update(_toNftKey32(distributorNftId, DISTRIBUTOR()), abi.encode(info), newState);
    }

    function updateDistributorState(NftId distributorNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(distributorNftId, DISTRIBUTOR()), newState);
    }

    //--- Referral ----------------------------------------------------------//
    function createReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo) external restricted() {
        create(referralId.toKey32(), abi.encode(referralInfo));
    }

    function updateReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo, StateId newState) external restricted() {
        update(referralId.toKey32(), abi.encode(referralInfo), newState);
    }

    function updateReferralState(ReferralId referralId, StateId newState) external restricted() {
        updateState(referralId.toKey32(), newState);
    }

    //--- Bundle ------------------------------------------------------------//
    function createBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle) external restricted() {
        _registerTarget(bundleNftId);
        create(_toNftKey32(bundleNftId, BUNDLE()), abi.encode(bundle));
    }

    function updateBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle, StateId newState) external restricted() {
        update(_toNftKey32(bundleNftId, BUNDLE()), abi.encode(bundle), newState);
    }

    function updateBundleState(NftId bundleNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(bundleNftId, BUNDLE()), newState);
    }

    //--- Risk --------------------------------------------------------------//
    function createRisk(RiskId riskId, IRisk.RiskInfo memory risk) external restricted() {
        create(riskId.toKey32(), abi.encode(risk));
    }

    function updateRisk(RiskId riskId, IRisk.RiskInfo memory risk, StateId newState) external restricted() {
        update(riskId.toKey32(), abi.encode(risk), newState);
    }

    function updateRiskState(RiskId riskId, StateId newState) external restricted() {
        updateState(riskId.toKey32(), newState);
    }

    //--- Application (Policy) ----------------------------------------------//
    function createApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy) external restricted() {
        create(_toNftKey32(applicationNftId, POLICY()), abi.encode(policy));
    }

    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(_toNftKey32(applicationNftId, POLICY()), abi.encode(policy), newState);
    }

    function updateApplicationState(NftId applicationNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(applicationNftId, POLICY()), newState);
    }

    //--- Policy ------------------------------------------------------------//
    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(_toNftKey32(policyNftId, POLICY()), abi.encode(policy), newState);
    }

    function updatePolicyClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        update(_toNftKey32(policyNftId, POLICY()), abi.encode(policy), newState);
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        updateState(_toNftKey32(policyNftId, POLICY()), newState);
    }

    //--- Claim -------------------------------------------------------------//
    function createClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim) external restricted() {
        create(_toClaimKey32(policyNftId, claimId), abi.encode(claim));
    }

    function updateClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim, StateId newState) external restricted() {
        update(_toClaimKey32(policyNftId, claimId), abi.encode(claim), newState);
    }

    function updateClaimState(NftId policyNftId, ClaimId claimId, StateId newState) external restricted() {
        updateState(_toClaimKey32(policyNftId, claimId), newState);
    }

    //--- Payout ------------------------------------------------------------//
    function createPayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        create(_toPayoutKey32(policyNftId, payoutId), abi.encode(payout));
    }

    function updatePayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        update(_toPayoutKey32(policyNftId, payoutId), abi.encode(payout), newState);
    }

    function updatePayoutState(NftId policyNftId, PayoutId payoutId, StateId newState) external restricted() {
        updateState(_toPayoutKey32(policyNftId, payoutId), newState);
    }

    //--- balance and fee management functions ------------------------------//

    function increaseBalance(NftId targetNftId, Amount amount) external restricted() returns (Amount newBalance) {
        return _increaseBalance(targetNftId, amount);
    }

    function decreaseBalance(NftId targetNftId, Amount amount) external restricted() returns (Amount newBalance) {
        return _decreaseBalance(targetNftId, amount);
    }

    function increaseFees(NftId targetNftId, Amount amount) external restricted() returns (Amount newFeeBalance) {
        return _increaseFees(targetNftId, amount);
    }

    function decreaseFees(NftId targetNftId, Amount amount) external restricted() returns (Amount newFeeBalance) {
        return _decreaseFees(targetNftId, amount);
    }

    function increaseLocked(NftId targetNftId, Amount amount) external restricted() returns (Amount newBalance) {
        return _increaseLocked(targetNftId, amount);
    }

    function decreaseLocked(NftId targetNftId, Amount amount) external restricted() returns (Amount newBalance) {
        return _decreaseLocked(targetNftId, amount);
    }

    //--- internal view/pure functions --------------------------------------//
    function _toNftKey32(NftId nftId, ObjectType objectType) private pure returns (Key32) {
        return nftId.toKey32(objectType);
    }

    function _toClaimKey32(NftId policyNftId, ClaimId claimId) private pure returns (Key32) {
        return claimId.toKey32(policyNftId);
    }

    function _toPayoutKey32(NftId policyNftId, PayoutId payoutId) private pure returns (Key32) {
        return payoutId.toKey32(policyNftId);
    }
}