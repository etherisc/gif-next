// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../types/Fee.sol";
import {NftId} from "../types/NftId.sol";
import {ReferralId} from "../types/ReferralId.sol";
import {RiskId} from "../types/RiskId.sol";

import {IBaseComponent} from "./IBaseComponent.sol";

interface IProductComponent is IBaseComponent {
    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    ) external;

    function calculatePremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
        bytes memory applicationData,
        ReferralId referralId,
        NftId bundleNftId
    ) external view returns (uint256 premiumAmount);

    function calculateNetPremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
        bytes memory applicationData
    ) external view returns (uint256 netPremiumAmount);    

    function getProductFee() external view returns (Fee memory productFee);
    function getProcessingFee() external view returns (Fee memory processingFee);

    function getPoolNftId() external view returns (NftId poolNftId);
    function getDistributionNftId() external view returns (NftId distributionNftId);
}
