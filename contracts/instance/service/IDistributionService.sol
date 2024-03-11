// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {IService} from "../../shared/IService.sol";
import {UFixed} from "../../types/UFixed.sol";
import {DistributorType} from "../../types/DistributorType.sol";
import {ReferralId} from "../../types/Referral.sol";
import {Timestamp} from "../../types/Timestamp.sol";


interface IDistributionService is IService {
    error ErrorIDistributionServiceInvalidReferralId(ReferralId referralId);

    function setFees(
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

    function updateDistributorType(
        NftId distributorNftId,
        DistributorType distributorType,
        bytes memory data
    ) external;

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
        ReferralId referralId,
        uint256 premiumAmount
    ) external;

    function calculateFeeAmount(
        ReferralId referralId,
        uint256 premiumAmount
    ) external view returns (uint256 feeAmount);
}
