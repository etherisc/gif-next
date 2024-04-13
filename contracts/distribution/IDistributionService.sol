// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {Fee} from "../type/Fee.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IService} from "../shared/IService.sol";
import {UFixed} from "../type/UFixed.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {ReferralId} from "../type/Referral.sol";
import {Timestamp} from "../type/Timestamp.sol";


interface IDistributionService is IService {
    error ErrorDistributionServiceCallerNotRegistered(address caller);
    error ErrorIDistributionServiceParentNftIdNotInstance(NftId nftId, NftId parentNftId);
    error ErrorIDistributionServiceCallerNotDistributor(address caller);
    error ErrorIDistributionServiceInvalidReferralId(ReferralId referralId);
    error ErrorIDistributionServiceMaxReferralsExceeded(uint256 maxReferrals);
    error ErrorIDistributionServiceDiscountTooLow(uint256 minDiscountPercentage, uint256 discountPercentage);
    error ErrorIDistributionServiceDiscountTooHigh(uint256 maxDiscountPercentage, uint256 discountPercentage);
    error ErrorIDistributionServiceExpiryTooLong(uint256 maxReferralLifetime, uint256 expiryAt);
    error ErrorIDistributionServiceInvalidReferral(string code);
    error ErrorIDistributionServiceExpirationInvalid(Timestamp expiryAt);
    error ErrorIDistributionServiceCommissionTooHigh(uint256 commissionPercentage, uint256 maxCommissionPercentage);
    error ErrorIDistributionServiceMinFeeTooHigh(uint256 minFee, uint256 limit);
    error ErrorIDistributionServiceMaxDiscountTooHigh(uint256 maxDiscountPercentage, uint256 limit);
    error ErrorIDistributionServiceReferralInvalid(NftId distributionNftId, ReferralId referralId);
    error ErrorDistributionServiceInvalidFeeTransferred(Amount transferredDistributionFeeAmount, Amount expectedDistributionFeeAmount);

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
    )
        external
        returns (DistributorType distributorType);

    function createDistributor(
        address distributor,
        DistributorType distributorType,
        bytes memory data
    ) external returns (NftId distributorNftId);

    // TODO re-enable and reorganize (service contract too large)
    // function updateDistributorType(
    //     NftId distributorNftId,
    //     DistributorType distributorType,
    //     bytes memory data
    // ) external;

    function createReferral(
        NftId distributorNftId,
        string memory code,
        UFixed discountPercentage,
        uint32 maxReferrals,
        Timestamp expiryAt,
        bytes memory data
    )
        external
        returns (ReferralId referralId);

    /// @dev callback from product service when selling a policy for a specific referralId
    function processSale(
        NftId distributionNftId,
        ReferralId referralId,
        IPolicy.Premium memory premium,
        Amount transferredDistributionFeeAmount
    ) external;

    function referralIsValid(
        NftId distributorNftId,
        ReferralId referralId
    ) external view returns (bool isValid);
}