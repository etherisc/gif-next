// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "./IInstance.sol";
import {INSTANCE} from "../types/ObjectType.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {LibNftIdSet} from "../types/NftIdSet.sol";
import {NftId} from "../types/NftId.sol";
import {TimestampLib} from "../types/Timestamp.sol";

import {ObjectManager} from "./ObjectManager.sol";

contract BundleManager is 
    ObjectManager
{

    event LogBundleManagerPolicyLinked(NftId bundleNftId, NftId policyNftId);
    event LogBundleManagerPolicyUnlinked(NftId bundleNftId, NftId policyNftId);

    event LogBundleManagerBundleAdded(NftId poolNftId, NftId bundleNftId);
    event LogBundleManagerBundleUnlocked(NftId poolNftId, NftId bundleNftId);
    event LogBundleManagerBundleLocked(NftId poolNftId, NftId bundleNftId);

    error ErrorBundleManagerErrorPolicyAlreadyActivated(NftId policyNftId);
    error ErrorBundleManagerErrorBundleLocked(NftId bundleNftId, NftId policyNftId);
    error ErrorBundleManagerPolicyWithOpenClaims(NftId policyNftId, uint256 openClaimsCount);
    error ErrorBundleManagerPolicyNotCloseable(NftId policyNftId);
    error ErrorBundleManagerBundleUnknown(NftId bundleNftId);
    error ErrorBundleManagerBundleNotRegistered(NftId bundleNftId);

    mapping(NftId bundleNftId => LibNftIdSet.Set policies) internal _activePolicies;

    /// @dev links a policy with its bundle
    // to link a policy it MUST NOT yet have been activated
    // the bundle MUST be unlocked (active) for linking (underwriting) and registered with this instance
    function linkPolicy(NftId policyNftId) external restricted() {
        NftId bundleNftId = _instance.getInstanceReader().getPolicyInfo(policyNftId).bundleNftId;
        // decision will likely depend on the decision what to check here and what in the service
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;

        // ensure bundle is unlocked (in active set) and registered with this instance
        if (!_isActive(poolNftId, bundleNftId)) {
            revert ErrorBundleManagerErrorBundleLocked(bundleNftId, policyNftId);
        }

        LibNftIdSet.add(_activePolicies[bundleNftId], policyNftId);
        emit LogBundleManagerPolicyLinked(bundleNftId, policyNftId);
    }


    /// @dev unlinks a policy from its bundle
    // to unlink a policy it must closable, ie. meet one of the following criterias
    // - the policy MUST be past its expiry period and it MUST NOT have any open claims
    // - the policy's payoutAmount MUST be equal to its sumInsuredAmount and MUST NOT have any open claims
    function unlinkPolicy(NftId policyNftId) external restricted() {
        IPolicy.PolicyInfo memory policyInfo = _instance.getInstanceReader().getPolicyInfo(policyNftId);

        NftId bundleNftId = policyInfo.bundleNftId;
        // decision will likely depend on the decision what to check here and what in the service
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;

        // ensure bundle is registered with this instance
        if (!_contains(poolNftId, bundleNftId)) {
            revert ErrorBundleManagerBundleUnknown(bundleNftId);
        }

        LibNftIdSet.remove(_activePolicies[bundleNftId], policyNftId);
        emit LogBundleManagerPolicyUnlinked(policyInfo.bundleNftId, policyNftId);
    }


    /// @dev add a new bundle to a pool registerd with this instance
    // the corresponding pool is fetched via instance reader
    function add(NftId bundleNftId) external restricted() {
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;

        // ensure pool is registered with instance
        if(poolNftId.eqz()) {
            revert ErrorBundleManagerBundleNotRegistered(bundleNftId);
        }

        _add(poolNftId, bundleNftId);
        emit LogBundleManagerBundleAdded(poolNftId, bundleNftId);
    }

    /// @dev unlocked (active) bundles are available to underwrite new policies
    function unlock(NftId bundleNftId) external restricted() {
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;
        _activate(poolNftId, bundleNftId);
        emit LogBundleManagerBundleUnlocked(poolNftId, bundleNftId);
    }

    /// @dev locked (deactivated) bundles may not underwrite any new policies
    function lock(NftId bundleNftId) external restricted() {
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;
        _deactivate(poolNftId, bundleNftId);
        emit LogBundleManagerBundleLocked(poolNftId, bundleNftId);
    }

    function bundles(NftId poolNftId) external view returns(uint256) {
        return _objects(poolNftId);
    }

    function getBundleNftId(NftId poolNftId, uint256 idx) external view returns(NftId bundleNftId) {
        return _getObject(poolNftId, idx);
    }

    function activeBundles(NftId poolNftId) external view returns(uint256) {
        return _activeObjs(poolNftId);
    }

    function getActiveBundleNftId(NftId poolNftId, uint256 idx) external view returns(NftId bundleNftId) {
        return _getActiveObject(poolNftId, idx);
    }

    function activePolicies(NftId bundleNftId) external view returns(uint256) {
        return LibNftIdSet.size(_activePolicies[bundleNftId]);
    }

    function getActivePolicy(NftId bundleNftId, uint256 idx) external view returns(NftId policyNftId) {
        return LibNftIdSet.getElementAt(_activePolicies[bundleNftId], idx);
    }
}