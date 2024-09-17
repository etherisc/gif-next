// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IComponents} from "./module/IComponents.sol";
import {IInstance} from "./IInstance.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IRisk} from "./module/IRisk.sol";

import {BalanceStore} from "./base/BalanceStore.sol";
import {BaseStore} from "./BaseStore.sol";
import {Blocknumber} from "../type/Blocknumber.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectCounter} from "./base/ObjectCounter.sol";
import {ObjectLifecycle} from "./base/ObjectLifecycle.sol";
import {ObjectType, FEE, POLICY, PREMIUM, PRODUCT} from "../type/ObjectType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId, KEEP_STATE} from "../type/StateId.sol";


contract ProductStore is
    AccessManagedUpgradeable, 
    BalanceStore,
    BaseStore,
    ObjectCounter,
    ObjectLifecycle
{
    event LogProductStoreProductInfoCreated(NftId productNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreProductInfoUpdated(NftId productNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreFeeInfoCreated(NftId productNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreFeeInfoUpdated(NftId productNftId, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreRiskInfoCreated(RiskId riskId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreRiskInfoUpdated(RiskId riskId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStorePolicyInfoCreated(NftId policyNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStorePolicyInfoUpdated(NftId policyNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStorePremiumInfoCreated(NftId policyNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStorePremiumInfoUpdated(NftId policyNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStoreClaimInfoCreated(NftId policyNftId, ClaimId claimId, StateId state, address createdBy, address txOrigin);
    event LogProductStoreClaimInfoUpdated(NftId policyNftId, ClaimId claimId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);
    event LogProductStorePayoutInfoCreated(NftId policyNftId, PayoutId payoutId, StateId state, address createdBy, address txOrigin);
    event LogProductStorePayoutInfoUpdated(NftId policyNftId, PayoutId payoutId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);

    mapping(Key32 key32 => IComponents.ProductInfo) private _products;
    mapping(Key32 key32 => IComponents.FeeInfo) private _fees;
    mapping(Key32 key32 => IRisk.RiskInfo) private _risks;
    mapping(Key32 key32 => IPolicy.PolicyInfo) private _policies;
    mapping(Key32 key32 => IPolicy.PremiumInfo) private _premiums;
    mapping(Key32 key32 => IPolicy.ClaimInfo) private _claims;
    mapping(Key32 key32 => IPolicy.PayoutInfo) private _payouts;


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


    //--- Product -----------------------------------------------------------//

    function createProduct(NftId productNftId, IComponents.ProductInfo memory info) external restricted() {
        Key32 key = _toNftKey32(productNftId, PRODUCT());
        _createMetadata(key);
        _products[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreProductInfoCreated(productNftId, getState(key), msg.sender, tx.origin);
    }

    function updateProduct(NftId productNftId, IComponents.ProductInfo memory info, StateId newState) external restricted() {
        Key32 key = _toNftKey32(productNftId, PRODUCT());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _products[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreProductInfoUpdated(productNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getProductInfo(NftId productNftId) external view returns (IComponents.ProductInfo memory info) {
        return _products[_toNftKey32(productNftId, PRODUCT())];
    }

    //--- Fee -----------------------------------------------------------//

    function createFee(NftId productNftId, IComponents.FeeInfo memory info) external restricted() {
        Key32 key = _toNftKey32(productNftId, FEE());
        _createMetadata(key);
        _fees[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreFeeInfoCreated(productNftId, getState(key), msg.sender, tx.origin);
    }

    // Fee only has one state, so no change change possible
    function updateFee(NftId productNftId, IComponents.FeeInfo memory info) external restricted() {
        Key32 key = _toNftKey32(productNftId, FEE());
        Blocknumber lastUpdatedIn = _updateState(key, KEEP_STATE());
        _fees[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreFeeInfoUpdated(productNftId, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getFeeInfo(NftId productNftId) external view returns (IComponents.FeeInfo memory info) {
        return _fees[_toNftKey32(productNftId, FEE())];
    }

    //--- Risk --------------------------------------------------------------//
    function createRisk(RiskId riskId, IRisk.RiskInfo memory info) external restricted() {
        Key32 key = riskId.toKey32();
        _createMetadata(key);
        _risks[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreRiskInfoCreated(riskId, getState(key), msg.sender, tx.origin);
    }

    function updateRisk(RiskId riskId, IRisk.RiskInfo memory info, StateId newState) external restricted() {
        Key32 key = riskId.toKey32();
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _risks[key] = info;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreRiskInfoUpdated(riskId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updateRiskState(RiskId riskId, StateId newState) external restricted() {
        // _updateState(riskId.toKey32(), newState);
        Key32 key = riskId.toKey32();
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreRiskInfoUpdated(riskId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getRiskInfo(RiskId riskId) external view returns (IRisk.RiskInfo memory info) {
        return _risks[riskId.toKey32()];
    }

    //--- Application (Policy) ----------------------------------------------//

    function createApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy) external restricted() {
        _registerBalanceTarget(applicationNftId);
        Key32 key = _toNftKey32(applicationNftId, POLICY());
        _createMetadata(key);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoCreated(applicationNftId, getState(key), msg.sender, tx.origin);
    }

    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(applicationNftId, POLICY());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(applicationNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updateApplicationState(NftId applicationNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(applicationNftId, POLICY());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(applicationNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    //--- Policy ------------------------------------------------------------//

    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updatePolicyClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getPolicyInfo(NftId policyNftId) external view returns (IPolicy.PolicyInfo memory policy) {
        return _policies[_toNftKey32(policyNftId, POLICY())];
    }

    //--- Premium (Policy) ----------------------------------------------//

    function createPremium(NftId policyNftId, IPolicy.PremiumInfo memory premium) external restricted() {
        Key32 key = _toNftKey32(policyNftId, PREMIUM());
        _createMetadata(key);
        _premiums[key] = premium;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePremiumInfoCreated(policyNftId, getState(key), msg.sender, tx.origin);
    }

    function updatePremiumState(NftId policyNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, PREMIUM());
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePremiumInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getPremiumInfo(NftId policyNftId) external view returns (IPolicy.PremiumInfo memory premium) {
        return _premiums[_toNftKey32(policyNftId, PREMIUM())];
    }

    //--- Claim -------------------------------------------------------------//

    function createClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim) external restricted() {
        Key32 key = _toClaimKey32(policyNftId, claimId);
        _createMetadata(key);
        _claims[key] = claim;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreClaimInfoCreated(policyNftId, claimId, getState(key), msg.sender, tx.origin);
    }

    function updateClaim(NftId policyNftId, ClaimId claimId, IPolicy.ClaimInfo memory claim, StateId newState) external restricted() {
        Key32 key = _toClaimKey32(policyNftId, claimId);
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _claims[key] = claim;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreClaimInfoUpdated(policyNftId, claimId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updateClaimState(NftId policyNftId, ClaimId claimId, StateId newState) external restricted() {
        Key32 key = _toClaimKey32(policyNftId, claimId);
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStoreClaimInfoUpdated(policyNftId, claimId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getClaimInfo(NftId policyNftId, ClaimId claimId) external view returns (IPolicy.ClaimInfo memory claim) {
        return _claims[_toClaimKey32(policyNftId, claimId)];
    }

    //--- Payout ------------------------------------------------------------//

    function createPayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory payout) external restricted() {
        Key32 key = _toPayoutKey32(policyNftId, payoutId);
        _createMetadata(key);
        _payouts[key] = payout;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePayoutInfoCreated(policyNftId, payoutId, getState(key), msg.sender, tx.origin);
    }

    function updatePayout(NftId policyNftId, PayoutId payoutId, IPolicy.PayoutInfo memory payout, StateId newState) external restricted() {
        Key32 key = _toPayoutKey32(policyNftId, payoutId);
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        _payouts[key] = payout;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePayoutInfoUpdated(policyNftId, payoutId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updatePayoutState(NftId policyNftId, PayoutId payoutId, StateId newState) external restricted() {
        Key32 key = _toPayoutKey32(policyNftId, payoutId);
        StateId oldState = getState(key);
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePayoutInfoUpdated(policyNftId, payoutId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getPayoutInfo(NftId policyNftId, PayoutId payoutId) external view returns (IPolicy.PayoutInfo memory payout) {
        return _payouts[_toPayoutKey32(policyNftId, payoutId)];
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