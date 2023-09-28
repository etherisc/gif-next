// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../../types/NftId.sol";
import {RiskId, toRiskId} from "../../../types/RiskId.sol";
import {StateId, ACTIVE} from "../../../types/StateId.sol";
import {Timestamp, blockTimestamp} from "../../../types/Timestamp.sol";
import {Blocknumber, blockNumber} from "../../../types/Blocknumber.sol";
import {IRiskModule} from "./IRisk.sol";

contract RiskModule is IRiskModule {

    mapping(RiskId id => RiskInfo info) private _info;
    RiskId[] private _riskIds;

    function createRisk(
        bytes memory specification
    )
        external
        returns (RiskId riskId)
    {
        riskId = toRiskId(specification);
        require(_info[riskId].createdAt.eqz(), "ERROR:RSK-010:RISK_ALREADY_EXISTS");

        _info[riskId] = RiskInfo(
            riskId,
            ACTIVE(),
            specification,
            blockTimestamp(), // createdAt
            blockNumber()); // updatedIn
    }
    
    function setRiskInfo(RiskInfo memory riskInfo) external {
        _info[riskInfo.id] = riskInfo;
    }

    function calculateRiskId(bytes memory specification) external pure returns (RiskId riskId) {
        return toRiskId(specification);
    }

    function getRiskInfo(RiskId riskId) external view returns (RiskInfo memory riskInfo) {
        return _info[riskId];
    }

    function getRiskCount() external view returns (uint256 riskCount) {
        return _riskIds.length;
    }

    function getRiskId(uint256 index) external view returns (RiskId riskId) {
        return _riskIds[index];
    }

    // function getActivePolicyCount(RiskId riskId) external view returns (uint256 riskCount);
    // function getActivePolicyNftId(RiskId riskId, uint256 index) external view returns (NftId policyNftId);
}