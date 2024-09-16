// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {Amount} from "../type/Amount.sol";
import {Key32} from "../type/Key32.sol";
import {NftId} from "../type/NftId.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {IKeyValueStore} from "../shared/IKeyValueStore.sol";
import {ObjectType, BUNDLE, POLICY, POOL, PREMIUM, PRODUCT, COMPONENT, DISTRIBUTOR, FEE} from "../type/ObjectType.sol";
import {RequestId} from "../type/RequestId.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId, KEEP_STATE} from "../type/StateId.sol";
import {ReferralId} from "../type/Referral.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {PayoutId} from "../type/PayoutId.sol";

import {BalanceStore} from "./base/BalanceStore.sol";
import {BaseStore} from "./BaseStore.sol";
import {IInstance} from "./IInstance.sol";
import {KeyValueStore} from "../shared/KeyValueStore.sol";
import {ObjectCounter} from "./base/ObjectCounter.sol";

import {IBundle} from "./module/IBundle.sol";
import {IComponents} from "./module/IComponents.sol";
import {IDistribution} from "./module/IDistribution.sol";
import {IPolicy} from "./module/IPolicy.sol";
import {IOracle} from "../oracle/IOracle.sol";
import {IRisk} from "./module/IRisk.sol";

import {ObjectLifecycle} from "./base/ObjectLifecycle.sol";


contract ProductStore is
    AccessManagedUpgradeable, 
    BalanceStore,
    BaseStore,
    ObjectCounter,
    ObjectLifecycle
{
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
    }

    function updateApplication(NftId applicationNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(applicationNftId, POLICY());
        _updateState(key, newState);
        _policies[key] = policy;
    }

    function updateApplicationState(NftId applicationNftId, StateId newState) external restricted() {
        _updateState(_toNftKey32(applicationNftId, POLICY()), newState);
    }

    function getPolicy(NftId policyNftId) external view returns (IPolicy.PolicyInfo memory policy) {
        return _policies[_toNftKey32(policyNftId, POLICY())];
    }

    //--- Policy ------------------------------------------------------------//
    function updatePolicy(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        _updateState(key, newState);
        _policies[key] = policy;
    }

    function updatePolicyClaims(NftId policyNftId, IPolicy.PolicyInfo memory policy, StateId newState) external restricted() {
        Key32 key = _toNftKey32(policyNftId, POLICY());
        _updateState(key, newState);
        _policies[key] = policy;
    }

    function updatePolicyState(NftId policyNftId, StateId newState) external restricted() {
        _updateState(_toNftKey32(policyNftId, POLICY()), newState);
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