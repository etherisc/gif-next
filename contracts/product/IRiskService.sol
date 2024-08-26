// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IService} from "../shared/IService.sol";

import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";

interface IRiskService is IService {

    function createRisk(
        string memory risk,
        bytes memory data
    ) external returns (RiskId riskId);


    function updateRisk(
        RiskId riskId,
        bytes memory data
    ) external;


    function updateRiskState(
        RiskId riskId,
        StateId newState
    ) external;
}
