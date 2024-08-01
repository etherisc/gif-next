// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IInstance} from "./IInstance.sol";
import {INSTANCE} from "../type/ObjectType.sol";
import {InstanceReader} from "./InstanceReader.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {LibRiskIdSet} from "../type/RiskIdSet.sol";
import {NftId} from "../type/NftId.sol";
import {TimestampLib} from "../type/Timestamp.sol";
import {RiskId} from "../type/RiskId.sol";

import {RiskSetBase} from "./base/RiskSetBase.sol";

contract RiskSet is 
    RiskSetBase
{

    event LogRiskSetPolicyLinked(RiskId riskId, NftId policyNftId);
    //event LogRiskSetPolicyUnlinked(RiskId riskId, NftId policyNftId); can not unlink a policy from a risk

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
        if (!_isActive(productNftId, riskId)) {
            revert ErrorRiskSetRiskLocked(riskId, policyNftId);
        }

        LibNftIdSet.add(_activePolicies[riskId], policyNftId);
        emit LogRiskSetPolicyLinked(riskId, policyNftId);
    }

/*
    /// @dev unlinks a policy from its risk
    // to unlink a policy it must closable, ie. meet one of the following criterias
    // - the policy MUST be past its expiry period and it MUST NOT have any open claims
    // - the policy's payoutAmount MUST be equal to its sumInsuredAmount and MUST NOT have any open claims
    function unlinkPolicy(NftId policyNftId) external restricted() {
        IPolicy.PolicyInfo memory policyInfo = _instance.getInstanceReader().getPolicyInfo(policyNftId);

       //  RiskId riskId = policyInfo.bundleNftId;
        // decision will likely depend on the decision what to check here and what in the service
        //NftId productNftId = _instance.getInstanceReader().getBundleInfo(bundleNftId).productNftId;

        RiskId riskId = policyInfo.riskId;
        NftId productNftId = policyInfo.productNftId;

        // ensure bundle is registered with this instance
        if (!_contains(productNftId, riskId)) {
            revert ErrorRiskSetRiskUnknown(riskId);
        }

        LibNftIdSet.remove(_activePolicies[riskId], policyNftId);
        emit LogRiskSetPolicyUnlinked(riskId, policyNftId);
    }
*/

    /// @dev add a new risk to a product registered with this instance
    // the corresponding product is fetched via instance reader
    function add(RiskId riskId) external restricted() {
        NftId productNftId = _instance.getInstanceReader().getRiskInfo(riskId).productNftId;

        // ensure product is registered with instance
        if(productNftId.eqz()) {
            revert ErrorRiskSetRiskNotRegistered(riskId);
        }

        _add(productNftId, riskId);
        emit LogRiskSetRiskAdded(productNftId, riskId);
    }


    /// @dev active risks are available to ....
    function activate(RiskId riskId) external restricted() {
        NftId productNftId = _instance.getInstanceReader().getRiskInfo(riskId).productNftId;
        _activate(productNftId, riskId);
        emit LogRiskSetRiskActive(productNftId, riskId);
    }

    /// @dev paused (deactivated) risks may not ...
    function pause(RiskId riskId) external restricted() {
        NftId productNftId = _instance.getInstanceReader().getRiskInfo(riskId).productNftId;
        _deactivate(productNftId, riskId);
        emit LogRiskSetRiskPaused(productNftId, riskId);
    }

    function risks(NftId productNftId) external view returns(uint256) {
        return _risks(productNftId);
    }

    function getRiskId(NftId productNftId, uint256 idx) external view returns(RiskId riskId) {
        return _getRisk(productNftId, idx);
    }
    
    function activeRisks(NftId productNftId) external view returns(uint256) {
        return _activeRsks(productNftId);
    }

    function getActiveRiskId(NftId productNftId, uint256 idx) external view returns(RiskId riskId) {
        return _getActiveRisk(productNftId, idx);
    }

    function activePolicies(RiskId riskId) external view returns(uint256) {
        return LibNftIdSet.size(_activePolicies[riskId]);
    }

    function getActivePolicy(RiskId riskId, uint256 idx) external view returns(NftId policyNftId) {
        return LibNftIdSet.getElementAt(_activePolicies[riskId], idx);
    }
}