// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../../types/NftId.sol";
import {RiskId} from "../../../types/RiskId.sol";
import {StateId} from "../../../types/StateId.sol";

interface IRisk {
    struct RiskInfo {
        NftId productNftId;
        bytes data;
    }
}

interface IRiskModule is IRisk {
    function createRisk(
        RiskId riskId,
        NftId productNftId,
        bytes memory data
    ) external;

    function setRiskInfo(RiskId riskId, RiskInfo memory info) external;
    function updateRiskState(RiskId riskId, StateId state) external;

    function getRiskInfo(RiskId riskId) external view returns (RiskInfo memory info);
    function getRiskState(RiskId riskId) external view returns (StateId state);
}