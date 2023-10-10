// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../types/Fee.sol";
import {NftId} from "../types/NftId.sol";
import {ReferralId} from "../types/ReferralId.sol";
import {RiskId} from "../types/RiskId.sol";

import {IBaseComponent} from "./IBaseComponent.sol";

interface IDistributionComponent is IBaseComponent {

    function calculateFeeAmount(
        ReferralId referralId,
        uint256 netPremiumAmount
    ) external view returns (uint256 feeAmount);

    function calculateRenewalFeeAmount(
        ReferralId referralId,
        uint256 netPremiumAmount
    ) external view returns (uint256 feeAmount);

    /// @dev callback from product service when selling a policy for a specific referralId
    /// the used referral id and the collected fee are provided as parameters
    /// the component implementation can then process this information accordingly
    function processSale(
        ReferralId referralId,
        uint256 feeAmount
    ) external;

    /// @dev callback from product service when a policy is renews for a specific referralId
    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    ) external;

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying);
}
