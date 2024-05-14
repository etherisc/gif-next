// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Fee} from "../type/Fee.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {ReferralId, ReferralStatus} from "../type/Referral.sol";
import {NftId} from "../type/NftId.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {UFixed} from "../type/UFixed.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IDistributionComponent is IInstanceLinkedComponent {

    event LogDistributorUpdated(address to, address caller);

    function setFees(
        Fee memory distributionFee,
        Fee memory minDistributionOwnerFee
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

    function getReferralId(
        string memory referralCode
    ) external returns (ReferralId referralId);

    /// @dev returns true iff the component needs to be called when selling/renewing policis
    function isVerifying() external view returns (bool verifying);
}
