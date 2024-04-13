// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../type/Fee.sol";
import {IComponent} from "../shared/IComponent.sol";
import {ISetup} from "../instance/module/ISetup.sol";
import {ReferralId, ReferralStatus} from "../type/Referral.sol";
import {NftId} from "../type/NftId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {UFixed} from "../type/UFixed.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IDistributionComponent is IComponent {

    event LogDistributorUpdated(address to, address caller);

    function getSetupInfo() external view returns (ISetup.DistributionSetupInfo memory setupInfo);

    function setFees(
        Fee memory minDistributionOwnerFee,
        Fee memory distributionFee
    ) external;

    function createDistributorType(
        string memory name,
        UFixed minDiscountPercentage,
        UFixed maxDiscountPercentage,
        UFixed commissionPercentage,
        uint32 maxReferralCount,
        uint32 maxReferralLifetime,
        bool allowSelfReferrals,
        bool allowRenewals,
        bytes memory data
    ) external returns (DistributorType distributorType);

    function createDistributor(
        address distributor,
        DistributorType distributorType,
        bytes memory data
    ) external returns(NftId distributorNftId);

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    ) external;

    function calculateRenewalFeeAmount(
        ReferralId referralId,
        uint256 netPremiumAmount
    ) external view returns (uint256 feeAmount);

    /// @dev callback from product service when a policy is renews for a specific referralId
    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    ) external;

    function getDiscountPercentage(
        string memory referralCode
    ) external view returns (UFixed discountPercentage, ReferralStatus status);

    function getDistributionFee() external view returns (Fee memory distibutionFee);

    function getReferralId(
        string memory referralCode
    ) external returns (ReferralId referralId);

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying);
}
