// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IPolicy} from "../instance/module/IPolicy.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId} from "../type/NftId.sol";
import {RiskIdLib, RiskId} from "../type/RiskId.sol";

import {ObjectSet} from "./base/ObjectSet.sol";

contract RiskSet is 
    ObjectSet
{
    using RiskIdLib for RiskId;
    using LibNftIdSet for LibNftIdSet.Set;

    event LogRiskSetPolicyLinked(RiskId riskId, NftId policyNftId);
    event LogRiskSetPolicyUnlinked(RiskId riskId, NftId policyNftId);

    event LogRiskSetRiskAdded(NftId productNftId, RiskId riskId);
    event LogRiskSetRiskActive(NftId poolNftId,  RiskId riskId);
    event LogRiskSetRiskPaused(NftId poolNftId,  RiskId riskId);
    event LogRiskSetRiskArchived(NftId poolNftId,  RiskId riskId);

    error ErrorRiskSetRiskLocked(RiskId riskId, NftId policyNftId); 
    error ErrorRiskSetRiskUnknown(RiskId riskId);
    error ErrorRiskSetRiskNotRegistered(RiskId riskId);

    mapping(RiskId riskId => LibNftIdSet.Set policies) internal _activePolicies;

    /// @dev links a policy to its bundle
    // to link a policy it MUST NOT yet have been linked
    function linkPolicy(NftId policyNftId) external restricted() {
        IPolicy.PolicyInfo memory policyInfo = _instance.getInstanceReader().getPolicyInfo(policyNftId);
        RiskId riskId = policyInfo.riskId;
        NftId productNftId = policyInfo.productNftId;

        // ensure risk is active (in active set) and registered with this instance
        if (!_isActive(productNftId, riskId.toKey32())) {
            revert ErrorRiskSetRiskLocked(riskId, policyNftId);
        }

        _activePolicies[riskId].add(policyNftId);
        emit LogRiskSetPolicyLinked(riskId, policyNftId);
    }

    /// @dev unlinks a policy from its risk
    // to unlink a policy it must closable, ie. meet one of the following criterias
    // - the policy MUST be past its expiry period and it MUST NOT have any open claims
    // - the policy's payoutAmount MUST be equal to its sumInsuredAmount and MUST NOT have any open claims
    function unlinkPolicy(NftId policyNftId) external restricted() {
        IPolicy.PolicyInfo memory policyInfo = _instance.getInstanceReader().getPolicyInfo(policyNftId);

        // TODO check policy is closable

        RiskId riskId = policyInfo.riskId;
        NftId productNftId = policyInfo.productNftId;

        // ensure risk is registered with this instance
        if (!_contains(productNftId, riskId.toKey32())) {
            revert ErrorRiskSetRiskUnknown(riskId);
        }

        _activePolicies[riskId].remove(policyNftId);
        emit LogRiskSetPolicyUnlinked(riskId, policyNftId);
    }

    /// @dev add a new risk to a product registered with this instance
    // the corresponding product is fetched via instance reader
    function add(RiskId riskId) external restricted() {
        NftId productNftId = _instance.getInstanceReader().getRiskInfo(riskId).productNftId;

        // ensure product is registered with instance
        if(productNftId.eqz()) {
            revert ErrorRiskSetRiskNotRegistered(riskId);
        }

        _add(productNftId, riskId.toKey32());
        emit LogRiskSetRiskAdded(productNftId, riskId);
    }


    /// @dev active risks are available to ....
    function activate(RiskId riskId) external restricted() {
        NftId productNftId = _instance.getInstanceReader().getRiskInfo(riskId).productNftId;
        _activate(productNftId, riskId.toKey32());
        emit LogRiskSetRiskActive(productNftId, riskId);
    }

    /// @dev paused (deactivated) risks may not ...
    function pause(RiskId riskId) external restricted() {
        NftId productNftId = _instance.getInstanceReader().getRiskInfo(riskId).productNftId;
        _deactivate(productNftId, riskId.toKey32());
        emit LogRiskSetRiskPaused(productNftId, riskId);
    }

    function risks(NftId productNftId) external view returns(uint256) {
        return _objects(productNftId);
    }

    function getRiskId(NftId productNftId, uint256 idx) external view returns(RiskId riskId) {
        return RiskIdLib.toRiskId(_getObject(productNftId, idx).toKeyId());
    }
    
    function activeRisks(NftId productNftId) external view returns(uint256) {
        return _activeObjs(productNftId);
    }

    function getActiveRiskId(NftId productNftId, uint256 idx) external view returns(RiskId riskId) {
        return RiskIdLib.toRiskId(_getActiveObject(productNftId, idx).toKeyId());
    }

    function activePolicies(RiskId riskId) external view returns(uint256) {
        return _activePolicies[riskId].size();
    }

    function getActivePolicy(RiskId riskId, uint256 idx) external view returns(NftId policyNftId) {
        return _activePolicies[riskId].getElementAt(idx);
    }
}