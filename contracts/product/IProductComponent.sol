// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {IComponent} from "../shared/IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";

interface IProductComponent is IComponent {

    function getSetupInfo() external view returns (ISetup.ProductSetupInfo memory setupInfo);

    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    ) external;

    function calculatePremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) external view returns (Amount premiumAmount);

    function calculateNetPremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData
    ) external view returns (Amount netPremiumAmount);    

    
    function getPoolNftId() external view returns (NftId poolNftId);
    function getDistributionNftId() external view returns (NftId distributionNftId);
}
