// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Seconds} from "../../types/Seconds.sol";
import {NftId} from "../../types/NftId.sol";
import {ReferralId} from "../../types/Referral.sol";
import {RiskId} from "../../types/RiskId.sol";
import {Amount} from "../../types/Amount.sol";

import {IService} from "./IApplicationService.sol";
import {IPolicy} from "../module/IPolicy.sol";

interface IPricingService is IService
{
    error ErrorIPricingServiceBundlePoolMismatch(NftId bundleNftId, NftId bundlePoolNftId, NftId poolNftId);
    error ErrorIPricingServiceFeeCalculationMismatch(
                uint256 distributionFeeFixAmount,
                uint256 distributionFeeVarAmount,
                uint256 distributionOwnerFeeFixAmount,
                uint256 distributionOwnerFeeVarAmount,
                uint256 commissionAmount,
                uint256 discountAmount
            );

    function calculatePremium(
        NftId productNftId,
        RiskId riskId,
        Amount sumInsuredAmount,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    )
        external
        view
        returns (IPolicy.Premium memory premium);
}