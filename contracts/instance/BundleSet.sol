// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IPolicy} from "../instance/module/IPolicy.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId, NftIdLib} from "../type/NftId.sol";
import {Key32} from "../type/Key32.sol";
import {BUNDLE} from "../type/ObjectType.sol";

import {ObjectSet} from "./base/ObjectSet.sol";

contract BundleSet is 
    ObjectSet
{
    using LibNftIdSet for LibNftIdSet.Set;

    event LogBundleSetPolicyLinked(NftId bundleNftId, NftId policyNftId);
    event LogBundleSetPolicyUnlinked(NftId bundleNftId, NftId policyNftId);

    event LogBundleSetBundleAdded(NftId poolNftId, NftId bundleNftId);
    event LogBundleSetBundleUnlocked(NftId poolNftId, NftId bundleNftId);
    event LogBundleSetBundleLocked(NftId poolNftId, NftId bundleNftId);
    event LogBundleSetBundleClosed(NftId poolNftId, NftId bundleNftId);

    error ErrorBundleSetPolicyAlreadyActivated(NftId policyNftId);
    error ErrorBundleSetBundleLocked(NftId bundleNftId, NftId policyNftId);
    error ErrorBundleSetPolicyWithOpenClaims(NftId policyNftId, uint256 openClaimsCount);
    error ErrorBundleSetPolicyNotCloseable(NftId policyNftId);
    error ErrorBundleSetBundleUnknown(NftId bundleNftId);
    error ErrorBundleSetBundleNotRegistered(NftId bundleNftId);

    mapping(NftId bundleNftId => LibNftIdSet.Set policies) internal _activePolicies;

    /// @dev links a policy to its bundle
    function linkPolicy(NftId poolNftId, NftId bundleNftId, NftId policyNftId) external restricted() {

        // ensure bundle is unlocked (in active set) and registered with this instance
        if (!_isActive(poolNftId, _toBundleKey32(bundleNftId))) {
            revert ErrorBundleSetBundleLocked(bundleNftId, policyNftId);
        }

        _activePolicies[bundleNftId].add(policyNftId);
        emit LogBundleSetPolicyLinked(bundleNftId, policyNftId);
    }


    /// @dev unlinks a policy from its bundle
    function unlinkPolicy(NftId poolNftId, NftId bundleNftId, NftId policyNftId) external restricted() {

        // ensure bundle is registered with this instance
        if (!_contains(poolNftId, _toBundleKey32(bundleNftId))) {
            revert ErrorBundleSetBundleUnknown(bundleNftId);
        }

        _activePolicies[bundleNftId].remove(policyNftId);
        emit LogBundleSetPolicyUnlinked(bundleNftId, policyNftId);
    }


    /// @dev add a new bundle to a pool registerd with this instance
    // the corresponding pool is fetched via instance reader
    function add(NftId bundleNftId) external restricted() {
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;

        // ensure pool is registered with instance
        if(poolNftId.eqz()) {
            revert ErrorBundleSetBundleNotRegistered(bundleNftId);
        }

        _add(poolNftId, _toBundleKey32(bundleNftId));
        emit LogBundleSetBundleAdded(poolNftId, bundleNftId);
    }


    /// @dev unlocked (active) bundles are available to collateralize new policies
    function unlock(NftId bundleNftId) external restricted() {
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;
        _activate(poolNftId, _toBundleKey32(bundleNftId));
        emit LogBundleSetBundleUnlocked(poolNftId, bundleNftId);
    }

    /// @dev locked (deactivated) bundles may not collateralize any new policies
    function lock(NftId bundleNftId) external restricted() {
        NftId poolNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).poolNftId;
        _deactivate(poolNftId, _toBundleKey32(bundleNftId));
        emit LogBundleSetBundleLocked(poolNftId, bundleNftId);
    }


    function checkBundle(NftId productNftId, NftId bundleId)
        public
        view 
        returns (bool exists, bool active)
    {
        Key32 bundleKey32 = bundleId.toKey32(BUNDLE());
        exists = _contains(productNftId, bundleKey32);

        if (exists) {
            active = _isActive(productNftId, bundleKey32);
        }
    }

    function bundles(NftId poolNftId) external view returns(uint256) {
        return _objects(poolNftId);
    }

    function getBundleNftId(NftId poolNftId, uint256 idx) external view returns(NftId) {
        return NftIdLib.toNftId(_getObject(poolNftId, idx).toKeyId());
    }

    function activeBundles(NftId poolNftId) external view returns(uint256) {
        return _activeObjs(poolNftId);
    }

    function getActiveBundleNftId(NftId poolNftId, uint256 idx) external view returns(NftId) {
        return NftIdLib.toNftId(_getActiveObject(poolNftId, idx).toKeyId());
    }

    function activePolicies(NftId bundleNftId) external view returns(uint256) {
        return _activePolicies[bundleNftId].size();
    }

    function getActivePolicy(NftId bundleNftId, uint256 idx) external view returns(NftId policyNftId) {
        return _activePolicies[bundleNftId].getElementAt(idx);
    }

    function _toBundleKey32(NftId nftId) private pure returns (Key32) {
        return nftId.toKey32(BUNDLE());
    }
}