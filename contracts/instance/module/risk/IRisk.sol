// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../../types/NftId.sol";
import {RiskId} from "../../../types/RiskId.sol";
import {StateId} from "../../../types/StateId.sol";
import {Timestamp} from "../../../types/Timestamp.sol";
import {Blocknumber} from "../../../types/Blocknumber.sol";

interface IRisk {

    struct RiskInfo {
        RiskId id; // derived from hash over project specific data
        StateId state; // active, paused, closed
        bytes specification; // project specific risk attributes
        Timestamp createdAt;
        Blocknumber updatedIn;
    }
}

interface IRiskModule is IRisk {

    function createRisk(
        bytes memory specification
    )
        external
        returns (RiskId id);
    
    function setRiskInfo(RiskInfo memory riskInfo) external;

    function calculateRiskId(bytes memory specification) external pure returns (RiskId riskId);
    function getRiskInfo(RiskId riskId) external view returns (RiskInfo memory riskInfo);

    function getRiskCount() external view returns (uint256 riskCount);
    function getRiskId(uint256 index) external view returns (RiskId riskId);

    // function getActivePolicyCount(RiskId riskId) external view returns (uint256 riskCount);
    // function getActivePolicyNftId(RiskId riskId, uint256 index) external view returns (NftId policyNftId);
}