// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IInstance} from "./IInstance.sol";
import {IPolicy} from "./module/IPolicy.sol";

import {BalanceStore} from "./base/BalanceStore.sol";
import {BaseStore} from "./BaseStore.sol";
import {Blocknumber} from "../type/Blocknumber.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectCounter} from "./base/ObjectCounter.sol";
import {ObjectLifecycle} from "./base/ObjectLifecycle.sol";
import {ObjectType, POLICY} from "../type/ObjectType.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {StateId} from "../type/StateId.sol";


contract ProductStore is
    AccessManagedUpgradeable, 
    BalanceStore,
    BaseStore,
    ObjectCounter,
    ObjectLifecycle
{
    event LogProductStorePolicyInfoCreated(NftId policyNftId, StateId state, address createdBy, address txOrigin);
    event LogProductStorePolicyInfoUpdated(NftId policyNftId, StateId oldState, StateId newState, address updatedBy, address txOrigin, Blocknumber lastUpdatedIn);

    mapping(Key32 key32 => IPolicy.PolicyInfo) private _policies;


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
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        StateId oldState = getState(key);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(applicationNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updateApplicationState(NftId applicationNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(applicationNftId, POLICY());
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        StateId oldState = getState(key);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(applicationNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    //--- Policy ------------------------------------------------------------//
    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        StateId oldState = getState(key);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updatePolicyClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        StateId oldState = getState(key);
        _policies[key] = policy;
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        Blocknumber lastUpdatedIn = _updateState(key, newState);
        StateId oldState = getState(key);
        // solhint-disable-next-line avoid-tx-origin
        emit LogProductStorePolicyInfoUpdated(policyNftId, oldState, newState, msg.sender, tx.origin, lastUpdatedIn);
    }

    function getPolicy(NftId policyNftId) external view returns (IPolicy.PolicyInfo memory policy) {
        return _policies[_toNftKey32(policyNftId, POLICY())];
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