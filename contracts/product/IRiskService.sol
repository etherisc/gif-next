// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IService} from "../shared/IService.sol";

import {NftId} from "../type/NftId.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";

interface IRiskService is IService {

    event LogRiskServiceRiskCreated(NftId productNftId, RiskId riskId);
    event LogRiskServiceRiskUpdated(NftId productNftId, RiskId riskId);
    event LogRiskServiceRiskStateUpdated(NftId productNftId, RiskId riskId, StateId newState);

    error ErrorRiskServiceRiskProductMismatch(RiskId riskId, NftId riskProductNftId, NftId productNftId);

    /// @dev Create a new risk with the given id and provided data. 
    /// The key of the risk derived from the risk id in comination with the product NftId. 
    /// Risk data is stored in the instance store. 
    function createRisk(
        bytes32 id,
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
