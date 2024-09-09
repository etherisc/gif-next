// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Key32} from "../type/Key32.sol";
import {LibNftIdSet} from "../type/NftIdSet.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectSet} from "./base/ObjectSet.sol";
import {ObjectSetHelperLib} from "./base/ObjectSetHelperLib.sol";
import {RiskIdLib, RiskId} from "../type/RiskId.sol";

/// @dev RiskSet manages the risks and its active policies per product.
contract RiskSet is
    ObjectSet
{

    event LogRiskSetPolicyLinked(RiskId riskId, NftId policyNftId);
    event LogRiskSetPolicyUnlinked(RiskId riskId, NftId policyNftId);

    event LogRiskSetRiskAdded(NftId productNftId, RiskId riskId);
    event LogRiskSetRiskActive(NftId poolNftId,  RiskId riskId);
    event LogRiskSetRiskPaused(NftId poolNftId,  RiskId riskId);

    error ErrorRiskSetRiskLocked(RiskId riskId, NftId policyNftId); 
    error ErrorRiskSetRiskUnknown(RiskId riskId);
    error ErrorRiskSetRiskNotRegistered(RiskId riskId);

    mapping(RiskId riskId => LibNftIdSet.Set policies) internal _activePolicies;

    /// @dev links a policy to its bundle
    function linkPolicy(NftId productNftId, RiskId riskId, NftId policyNftId) external restricted() {

        // ensure risk is active (in active set) and registered with this instance
        if (!_isActive(productNftId, riskId.toKey32())) {
            revert ErrorRiskSetRiskLocked(riskId, policyNftId);
        }

        LibNftIdSet.add(_activePolicies[riskId], policyNftId);
        emit LogRiskSetPolicyLinked(riskId, policyNftId);
    }

    /// @dev Unlinks a policy from its risk.
    function unlinkPolicy(NftId productNftId, RiskId riskId, NftId policyNftId) external restricted() {

        // ensure risk is registered with this instance
        if (!_contains(productNftId, riskId.toKey32())) {
            revert ErrorRiskSetRiskUnknown(riskId);
        }

        LibNftIdSet.remove(_activePolicies[riskId], policyNftId);
        emit LogRiskSetPolicyUnlinked(riskId, policyNftId);
    }

    /// @dev add a new risk to a product registered with this instance
    // the corresponding product is fetched via instance reader
    function add(RiskId riskId) external restricted() {
        NftId productNftId = ObjectSetHelperLib.getProductNftId(_instanceAddress, riskId);

        // ensure product is registered with instance
        if(productNftId.eqz()) {
            revert ErrorRiskSetRiskNotRegistered(riskId);
        }

        _add(productNftId, riskId.toKey32());
        emit LogRiskSetRiskAdded(productNftId, riskId);
    }

    /// @dev Applications linked to active risks may be underwritten
    function activate(RiskId riskId) external restricted() {
        NftId productNftId = ObjectSetHelperLib.getProductNftId(_instanceAddress, riskId);
        _activate(productNftId, riskId.toKey32());
        emit LogRiskSetRiskActive(productNftId, riskId);
    }

    /// @dev Applications linked to paused/archived risks may not be underwritten
    function deactivate(RiskId riskId) external restricted() {
        NftId productNftId = ObjectSetHelperLib.getProductNftId(_instanceAddress, riskId);
        _deactivate(productNftId, riskId.toKey32());
        emit LogRiskSetRiskPaused(productNftId, riskId);
    }

    function checkRisk(NftId productNftId, RiskId riskId)
        public
        view 
        returns (bool exists, bool active)
    {
        Key32 riskKey32 = riskId.toKey32();
        exists = _contains(productNftId, riskKey32);

        if (exists) {
            active = _isActive(productNftId, riskKey32);
        }
    }

    function hasRisk(NftId productNftId, RiskId riskId)
        public
        view 
        returns (bool)
    {
        Key32 riskKey32 = riskId.toKey32();
        return _contains(productNftId, riskKey32);
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

    function linkedPolicies(RiskId riskId) external view returns(uint256) {
        return LibNftIdSet.size(_activePolicies[riskId]);
    }

    function getLinkedPolicyNftId(RiskId riskId, uint256 idx) external view returns(NftId policyNftId) {
        return LibNftIdSet.getElementAt(_activePolicies[riskId], idx);
    }
}