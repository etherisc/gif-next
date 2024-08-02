// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Seconds} from "../type/Seconds.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Amount} from "../type/Amount.sol";

import {IService} from "./IApplicationService.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";

interface IPricingService is IService
{

    error ErrorPricingServiceTargetWalletAmountsMismatch();
    error ErrorPricingServiceBundlePoolMismatch(NftId bundleNftId, NftId bundlePoolNftId, NftId poolNftId);
    error ErrorPricingServiceFeeCalculationMismatch(
        Amount distributionFeeFixAmount,
        Amount distributionFeeVarAmount,
        Amount distributionOwnerFeeFixAmount,
        Amount distributionOwnerFeeVarAmount,
        Amount commissionAmount,
        Amount discountAmount
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
        returns (IPolicy.PremiumInfo memory premium);
}