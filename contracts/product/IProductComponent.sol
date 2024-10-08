// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {ClaimId} from "../type/ClaimId.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {IComponents} from "../instance/module/IComponents.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {ReferralId} from "../type/Referral.sol";
import {RiskId} from "../type/RiskId.sol";
import {Seconds} from "../type/Seconds.sol";

interface IProductComponent is
    IInstanceLinkedComponent
{

    // @dev register a new component for this product cluster.
    function registerComponent(address component)
        external
        returns (NftId componentNftId);

    /// @dev Callback function to inform product compnent about arrival of funding for a claim.
    /// The callback is called by the pool service after the corresponding pool triggers this function.
    /// The callback is only called when the product's property isProcessingFundedClaims is set.
    function processFundedClaim(
        NftId policyNftId, 
        ClaimId claimId, 
        Amount availableAmount
    ) external;


    /// @dev Calculates the premium amount for the provided application data.
    /// The returned premium amounts takes into account potential discounts and fees.
    function calculatePremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData,
        NftId bundleNftId,
        ReferralId referralId
    ) external view returns (Amount premiumAmount);


    /// @dev Calculates the net premium amount for the provided application data.
    /// The returned net premium amounts only covers the cost of collateralizing the application.
    /// This amount purely depends on the use case specific risk and does not include any fees/commission.
    function calculateNetPremium(
        Amount sumInsuredAmount,
        RiskId riskId,
        Seconds lifetime,
        bytes memory applicationData
    ) external view returns (Amount netPremiumAmount);    


    /// @dev returns initial product specific infos 
    function getInitialProductInfo() external view returns (IComponents.ProductInfo memory info);

    /// @dev returns initial fee infos
    function getInitialFeeInfo() external view returns (IComponents.FeeInfo memory info);
    
}
