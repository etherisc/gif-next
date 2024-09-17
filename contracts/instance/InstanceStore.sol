// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IBundle} from "./module/IBundle.sol";
import {IComponents} from "./module/IComponents.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IInstance} from "./IInstance.sol";
import {IOracle} from "../oracle/IOracle.sol";

import {Amount} from "../type/Amount.sol";
import {BaseStore} from "./BaseStore.sol";
import {Blocknumber} from "../type/Blocknumber.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {ObjectType, BUNDLE, POOL, COMPONENT, DISTRIBUTOR} from "../type/ObjectType.sol";
import {RequestId} from "../type/RequestId.sol";
import {StateId} from "../type/StateId.sol";
import {ReferralId} from "../type/Referral.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {BalanceStore} from "./base/BalanceStore.sol";
import {ObjectCounter} from "./base/ObjectCounter.sol";
import {ObjectLifecycle} from "./base/ObjectLifecycle.sol";


contract InstanceStore is
    AccessManagedUpgradeable, 
    BalanceStore,
    ObjectCounter,
    ObjectLifecycle,
    BaseStore
{

    event LogProductStoreComponentInfoCreated(NftId componentNftId, StateId state, address createdby, address txOrigin);
    event LogProductStoreComponentInfoUpdated(NftId componentNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStorePoolInfoCreated(NftId poolNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStorePoolInfoUpdated(NftId poolNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreDistributorTypeInfoCreated(DistributorType distributorType, StateId state, address createdBy, address txOrigin);
    event LogProductStoreDistributorTypeInfoUpdated(DistributorType distributorType, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreDistributorInfoCreated(NftId distributorNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreDistributorInfoUpdated(NftId distributorNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreReferralInfoCreated(ReferralId referralId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreReferralInfoUpdated(ReferralId referralId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreBundleInfoCreated(NftId bundleNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreBundleInfoUpdated(NftId bundleNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreRequestInfoCreated(RequestId requestId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreRequestInfoUpdated(RequestId requestId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);


    mapping(Key32 => IComponents.ComponentInfo) private _components;
    mapping(Key32 => IComponents.PoolInfo) private _pools;
    mapping(Key32 => IDistribution.DistributorTypeInfo) private _distributorTypes;
    mapping(Key32 => IDistribution.DistributorInfo) private _distributors;
    mapping(Key32 => IDistribution.ReferralInfo) private _referrals;
    mapping(Key32 => IBundle.BundleInfo) private _bundles;
    mapping(Key32 => IOracle.RequestInfo) private _requests;


    /// @dev This initializer needs to be called from the instance itself.
    function initialize()
        public 
        initializer()
    {
        address instance = msg.sender;
        address authority = IInstance(instance).authority();

        __AccessManaged_init(authority);
        // double initialization, safe
        _initializeLifecycle();
    }

    //--- Component ---------------------------------------------------------//

    function createComponent(
        NftId componentNftId, 
        IComponents.ComponentInfo memory componentInfo
    )
        external 
        restricted()
    {
        _registerBalanceTarget(componentNftId);
        // _create(_toNftKey32(componentNftId, COMPONENT()), abi.encode(componentInfo));
        Key32 key = _toNftKey32(componentNftId, COMPONENT());
        _createMetadata(key);
        _components[key] = componentInfo;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreComponentInfoCreated(componentNftId, getState(key), msg.sender, tx.origin);
    }

    function updateComponent(
        NftId componentNftId, 
        IComponents.ComponentInfo memory componentInfo,
        StateId newState
    )
        external 
        restricted()
    {
        // _update(_toNftKey32(componentNftId, COMPONENT()), abi.encode(componentInfo), newState);
        Key32 key = _toNftKey32(componentNftId, COMPONENT());
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _components[key] = componentInfo;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreComponentInfoUpdated(componentNftId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getComponentInfo(NftId componentNftId) external view returns (IComponents.ComponentInfo memory componentInfo) {
        return _components[_toNftKey32(componentNftId, COMPONENT())];
    }

    //--- Pool --------------------------------------------------------------//

    function createPool(
        NftId poolNftId, 
        IComponents.PoolInfo memory info
    )
        external 
        restricted()
    {
        Key32 key = _toNftKey32(poolNftId, POOL());
        _createMetadata(key);
        _pools[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePoolInfoCreated(poolNftId, getState(key), msg.sender, tx.origin);
    }

    function updatePool(NftId poolNftId, IComponents.PoolInfo memory info, StateId newState) external restricted() {
        Key32 key = _toNftKey32(poolNftId, POOL());
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _pools[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePoolInfoUpdated(poolNftId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getPoolInfo(NftId poolNftId) external view returns (IComponents.PoolInfo memory info) {
        return _pools[_toNftKey32(poolNftId, POOL())];
    }

    //--- DistributorType ---------------------------------------------------//
    function createDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info) external restricted() {
        Key32 key = distributorType.toKey32();
        _createMetadata(key);
        _distributorTypes[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreDistributorTypeInfoCreated(distributorType, getState(key), msg.sender, tx.origin);
    }

    function updateDistributorType(DistributorType distributorType, IDistribution.DistributorTypeInfo memory info, StateId newState) external restricted() {
        Key32 key = distributorType.toKey32();
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _distributorTypes[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreDistributorTypeInfoUpdated(distributorType, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function updateDistributorTypeState(DistributorType distributorType, StateId newState) external restricted() {
        Key32 key = distributorType.toKey32();
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreDistributorTypeInfoUpdated(distributorType, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getDistributorTypeInfo(DistributorType distributorType) external view returns (IDistribution.DistributorTypeInfo memory info) {
        return _distributorTypes[distributorType.toKey32()];
    }

    //--- Distributor -------------------------------------------------------//
    function createDistributor(NftId distributorNftId, IDistribution.DistributorInfo memory info) external restricted() {
        _registerBalanceTarget(distributorNftId);
        Key32 key = _toNftKey32(distributorNftId, DISTRIBUTOR());
        _createMetadata(key);
        _distributors[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreDistributorInfoCreated(distributorNftId, getState(key), msg.sender, tx.origin);
    }

    function updateDistributor(NftId distributorNftId, IDistribution.DistributorInfo memory info, StateId newState) external restricted() {
        Key32 key = _toNftKey32(distributorNftId, DISTRIBUTOR());
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _distributors[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreDistributorInfoUpdated(distributorNftId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function updateDistributorState(NftId distributorNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(distributorNftId, DISTRIBUTOR());
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreDistributorInfoUpdated(distributorNftId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getDistributorInfo(NftId distributorNftId) external view returns (IDistribution.DistributorInfo memory info) {
        return _distributors[_toNftKey32(distributorNftId, DISTRIBUTOR())];
    }

    //--- Referral ----------------------------------------------------------//
    function createReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo) external restricted() {
        Key32 key = referralId.toKey32();
        _createMetadata(key);
        _referrals[key] = referralInfo;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreReferralInfoCreated(referralId, getState(key), msg.sender, tx.origin);
    }

    function updateReferral(ReferralId referralId, IDistribution.ReferralInfo memory referralInfo, StateId newState) external restricted() {
        Key32 key = referralId.toKey32();
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _referrals[key] = referralInfo;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreReferralInfoUpdated(referralId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function updateReferralState(ReferralId referralId, StateId newState) external restricted() {
        Key32 key = referralId.toKey32();
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreReferralInfoUpdated(referralId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getReferralInfo(ReferralId referralId) external view returns (IDistribution.ReferralInfo memory referralInfo) {
        return _referrals[referralId.toKey32()];
    }

    //--- Bundle ------------------------------------------------------------//
    function createBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle) external restricted() {
        _registerBalanceTarget(bundleNftId);
        Key32 key = _toNftKey32(bundleNftId, BUNDLE());
        _createMetadata(key);
        _bundles[key] = bundle;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreBundleInfoCreated(bundleNftId, getState(key), msg.sender, tx.origin);
    }

    function updateBundle(NftId bundleNftId, IBundle.BundleInfo memory bundle, StateId newState) external restricted() {
        Key32 key = _toNftKey32(bundleNftId, BUNDLE());
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _bundles[key] = bundle;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreBundleInfoUpdated(bundleNftId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function updateBundleState(NftId bundleNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(bundleNftId, BUNDLE());
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreBundleInfoUpdated(bundleNftId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getBundleInfo(NftId bundleNftId) external view returns (IBundle.BundleInfo memory bundle) {
        return _bundles[_toNftKey32(bundleNftId, BUNDLE())];
    }
    
    //--- Request -----------------------------------------------------------//

    function createRequest(IOracle.RequestInfo memory request) external restricted() returns (RequestId requestId) {
        requestId = _createNextRequestId();
        Key32 key = requestId.toKey32();
        _createMetadata(key);
        _requests[key] = request;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreRequestInfoCreated(requestId, getState(key), msg.sender, tx.origin);
    }

    function updateRequest(RequestId requestId, IOracle.RequestInfo memory request, StateId newState) external restricted() {
        Key32 key = requestId.toKey32();
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        _requests[key] = request;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreRequestInfoUpdated(requestId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function updateRequestState(RequestId requestId, StateId newState) external restricted() {
        Key32 key = requestId.toKey32();
        (Blocknumber updatedIn, StateId oldState) = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreRequestInfoUpdated(requestId, oldState, newState, msg.sender, tx.origin, updatedIn);
    }

    function getRequestInfo(RequestId requestId) external view returns (IOracle.RequestInfo memory request) {
        return _requests[requestId.toKey32()];
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