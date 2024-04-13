// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IRisk} from "../instance/module/IRisk.sol";
import {IService} from "../shared/IService.sol";

import {NftId} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";
import {Fee} from "../type/Fee.sol";

interface IProductService is IService {
    
    function register(address productAddress) external returns(NftId);

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