// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IPolicy} from "../instance/module/IPolicy.sol";
import {IService} from "../shared/IService.sol";

import {Amount} from "../type/Amount.sol";
import {DistributorType} from "../type/DistributorType.sol";
import {InstanceReader} from "../instance/InstanceReader.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId, ReferralStatus} from "../type/Referral.sol";
import {Seconds} from "../type/Seconds.sol";
import {Timestamp} from "../type/Timestamp.sol";
import {UFixed} from "../type/UFixed.sol";


interface IDistributionService is IService {
    error ErrorDistributionServiceCallerNotRegistered(address caller);
    error ErrorDistributionServiceParentNftIdNotInstance(NftId nftId, NftId parentNftId);
    error ErrorDistributionServiceCallerNotDistributor(address caller);
    error ErrorDistributionServiceInvalidReferralId(ReferralId referralId);
    error ErrorDistributionServiceMaxReferralsExceeded(uint256 maxReferrals);
    error ErrorDistributionServiceDiscountTooLow(uint256 minDiscountPercentage, uint256 discountPercentage);
    error ErrorDistributionServiceDiscountTooHigh(uint256 maxDiscountPercentage, uint256 discountPercentage);
    error ErrorDistributionServiceExpiryTooLong(Seconds maxReferralLifetime, Timestamp expiryAt);
    error ErrorDistributionServiceInvalidReferral(string code);
    error ErrorDistributionServiceExpirationInvalid(Timestamp expiryAt);
    error ErrorDistributionServiceCommissionTooHigh(uint256 commissionPercentage, uint256 maxCommissionPercentage);
    error ErrorDistributionServiceMinFeeTooHigh(uint256 minFee, uint256 limit);
    error ErrorDistributionServiceDistributorTypeDistributionMismatch(DistributorType distributorType, NftId distributorTypeDistributionNftId, NftId distributionNftId);
    error ErrorDistributionServiceDistributorDistributionMismatch(NftId distributorNftId, NftId distributorDistributionNftId, NftId distributionNftId);

    error ErrorDistributionServiceCommissionWithdrawAmountExceedsLimit(Amount amount, Amount limit);
    
    error ErrorDistributionServiceVariableFeesTooHight(uint256 maxDiscountPercentage, uint256 limit);
    error ErrorDistributionServiceMaxDiscountTooHigh(uint256 maxDiscountPercentage, uint256 limit);

    error ErrorDistributionServiceReferralInvalid(NftId distributionNftId, ReferralId referralId);
    error ErrorDistributionServiceInvalidFeeTransferred(Amount transferredDistributionFeeAmount, Amount expectedDistributionFeeAmount);
    error ErrorDistributionServiceReferralDistributionMismatch(ReferralId referralId, NftId referralDistributionNft, NftId distributionNftId);

    event LogDistributionServiceCommissionWithdrawn(NftId distributorNftId, address recipient, address tokenAddress, Amount amount);

    function createDistributorType(
        string memory name,
        UFixed minDiscountPercentage,
        UFixed maxDiscountPercentage,
        UFixed commissionPercentage,
        uint32 maxReferralCount,
        Seconds maxReferralLifetime,
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

    function changeDistributorType(
        NftId distributorNftId,
        DistributorType newDistributorType,
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

    /// @dev callback from product service when a referral is used. 
    /// Calling this will increment the referral usage counter. 
    function processReferral(
        NftId distributionNftId, 
        ReferralId referralId
    ) external;

    /// @dev callback from product service when selling a policy for a specific referralId
    function processSale(
        NftId distributionNftId,
        ReferralId referralId,
        IPolicy.PremiumInfo memory premium
    ) external;

    function referralIsValid(
        NftId distributorNftId,
        ReferralId referralId
    ) external view returns (bool isValid);

    /// @dev Withdraw commission for the distributor
    /// @param distributorNftId the distributor Nft Id
    /// @param amount the amount to withdraw. If set to AMOUNT_MAX, the full commission available is withdrawn
    /// @return withdrawnAmount the effective withdrawn amount
    function withdrawCommission(NftId distributorNftId, Amount amount) external returns (Amount withdrawnAmount);

    /// @dev Returns the discount percentage for the provided referral code.
    /// The function retuns both the percentage and the status of the referral code.
    function getDiscountPercentage(InstanceReader instanceReader, ReferralId referralId) external view returns (UFixed discountPercentage, ReferralStatus status);
}