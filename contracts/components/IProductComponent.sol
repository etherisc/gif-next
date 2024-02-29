// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../types/Fee.sol";
import {IComponent} from "./IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {NftId} from "../types/NftId.sol";
import {ReferralId} from "../types/Referral.sol";
import {RiskId} from "../types/RiskId.sol";

interface IProductComponent is IComponent {

    function getSetupInfo() external view returns (ISetup.ProductSetupInfo memory setupInfo);

    function setFees(
        Fee memory productFee,
        Fee memory processingFee
    ) external;

    function calculatePremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) external view returns (uint256 premiumAmount);

    function calculateNetPremium(
        uint256 sumInsuredAmount,
        RiskId riskId,
        uint256 lifetime,
        bytes memory applicationData
    ) external view returns (uint256 netPremiumAmount);    

    
    function getPoolNftId() external view returns (NftId poolNftId);
    function getDistributionNftId() external view returns (NftId distributionNftId);
}
