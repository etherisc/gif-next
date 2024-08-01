// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Cloneable} from "./Cloneable.sol";

import {IInstance} from "../IInstance.sol";
import {InstanceReader} from "../InstanceReader.sol";
import {IRegistry} from "../../registry/IRegistry.sol";
import {LibRiskIdSet} from "../../type/RiskIdSet.sol";
import {RiskId} from "../../type/RiskId.sol";
import {NftId} from "../../type/NftId.sol";

contract RiskSetBase is
    Cloneable
{

    event LogRiskSetInitialized(address instance);

    error ErrorRiskSetNftIdInvalid(RiskId instanceNftId);

    mapping(NftId compnentNftId => LibRiskIdSet.Set objects) internal _activeRisks;
    mapping(NftId compnentNftId => LibRiskIdSet.Set objects) internal _allRisks;
    IInstance internal _instance; // store instance address -> more flexible, instance may not be registered during RiskSet initialization

    /// @dev This initializer needs to be called from the instance itself.
    function initialize() 
        external
        initializer()
    {
        _instance = IInstance(msg.sender);
        __Cloneable_init(_instance.authority(), address(_instance.getRegistry()));
        
        emit LogRiskSetInitialized(address(_instance));
    }

    function getInstance() external view returns (IInstance) {
        return _instance;
    }

    function _add(NftId componentNftId, RiskId riskId) internal {
        LibRiskIdSet.Set storage allSet = _allRisks[componentNftId];
        LibRiskIdSet.Set storage activeSet = _activeRisks[componentNftId];

        LibRiskIdSet.add(allSet, riskId);
        LibRiskIdSet.add(activeSet, riskId);
    }

    function _activate(NftId componentNftId, RiskId riskId) internal {
        LibRiskIdSet.add(_activeRisks[componentNftId], riskId);
    }

    function _deactivate(NftId componentNftId, RiskId riskId) internal {
        LibRiskIdSet.remove(_activeRisks[componentNftId], riskId);
    }

    function _risks(NftId componentNftId) internal view returns (uint256) {
        return LibRiskIdSet.size(_allRisks[componentNftId]);
    }

    function _contains(NftId componentNftId, RiskId riskId) internal view returns (bool) {
        return LibRiskIdSet.contains(_allRisks[componentNftId], riskId);
    }

    function _getRisk(NftId componentNftId, uint256 idx) internal view returns (RiskId) {
        return LibRiskIdSet.getElementAt(_allRisks[componentNftId], idx);
    }

    function _activeRsks(NftId componentNftId) internal view returns (uint256)  {
        return LibRiskIdSet.size(_activeRisks[componentNftId]);
    }

    function _isActive(NftId componentNftId, RiskId riskId) internal view returns (bool) {
        return LibRiskIdSet.contains(_activeRisks[componentNftId], riskId);
    }

    function _getActiveRisk(NftId componentNftId, uint256 idx) internal view returns (RiskId) {
        return LibRiskIdSet.getElementAt(_activeRisks[componentNftId], idx);
    }
}
