// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../module/IRisk.sol";
import {IService} from "../../shared/IService.sol";

import {NftId} from "../../types/NftId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";
import {UFixed} from "../../types/UFixed.sol";
import {Fee} from "../../types/Fee.sol";

interface IProductService is IService {

    error ErrorIProductServiceInsufficientAllowance(address customer, address tokenHandlerAddress, uint256 amount);
    
    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    ) external;

    function createRisk(
        RiskId riskId,
        bytes memory data
    ) external;


    function updateRisk(
        RiskId riskId,
        bytes memory data
    ) external;


    function updateRiskState(
        RiskId riskId,
        StateId newState
    ) external;
}
