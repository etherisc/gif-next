// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../../types/NftId.sol";
import {RISK} from "../../../types/ObjectType.sol";
import {RiskId} from "../../../types/RiskId.sol";
import {StateId} from "../../../types/StateId.sol";

import {IKeyValueStore} from "../../base/IKeyValueStore.sol";
import {IRiskModule} from "./IRisk.sol";
import {ModuleBase} from "../../base/ModuleBase.sol";

contract RiskModule is
    ModuleBase,
    IRiskModule
{
    function initializeRiskModule(IKeyValueStore keyValueStore) internal {
        _initialize(keyValueStore);
    }

    function createRisk(
        RiskId riskId,
        NftId productNftId,
        bytes memory data
    ) external override {
        RiskInfo memory info = RiskInfo(
            productNftId,
            data
        );

        _create(RISK(), riskId.toKey32(), abi.encode(info));
    }

    function setRiskInfo(
        RiskId riskId, 
        RiskInfo memory info
    )
        external
        override
    {

    }

    function updateRiskState(
        RiskId riskId, 
        StateId state
    )
        external
        override
    {

    }

    function getRiskInfo(RiskId riskId)
        external
        view
        override
        returns (RiskInfo memory info)
    {

    }

    function getRiskState(RiskId riskId)
        external
        view
        returns (StateId state)
    {

    }
}