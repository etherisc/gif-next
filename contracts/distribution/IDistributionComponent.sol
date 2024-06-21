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

    error ErrorDistributionNotDistributor(address distributor);
    error ErrorDistributionAlreadyDistributor(address distributor, NftId distributorNftId);

    event LogDistributorUpdated(address to, address caller);

    // TODO cleanup
    // function setFees(
    //     Fee memory distributionFee,
    //     Fee memory minDistributionOwnerFee
    // ) external;

    // function createDistributorType(
    //     string memory name,
    //     UFixed minDiscountPercentage,
    //     UFixed maxDiscountPercentage,
    //     UFixed commissionPercentage,
    //     uint32 maxReferralCount,
    //     uint32 maxReferralLifetime,
    //     bool allowSelfReferrals,
    //     bool allowRenewals,
    //     bytes memory data
    // ) external returns (DistributorType distributorType);

    // function createDistributor(
    //     address distributor,
    //     DistributorType distributorType,
    //     bytes memory data
    // ) external returns(NftId distributorNftId);

    // function updateDistributorType(
    //     NftId distributorNftId,
    //     DistributorType distributorType,
    //     bytes memory data
    // ) external;

    /// @dev Returns true iff the provided address is registered as a distributor with this distribution component.
    function isDistributor(address candidate) external view returns (bool);

    /// @dev Returns the distributor Nft Id for the provided address
    function getDistributorNftId(address distributor) external view returns (NftId distributorNftId);

    function getDiscountPercentage(
        string memory referralCode
    ) external view returns (UFixed discountPercentage, ReferralStatus status);

    function getReferralId(
        string memory referralCode
    ) external returns (ReferralId referralId);

    function calculateRenewalFeeAmount(
        ReferralId referralId,
        uint256 netPremiumAmount
    ) external view returns (uint256 feeAmount);

    /// @dev Callback function to process a renewal of a policy.
    /// The default implementation is empty.
    /// Overwrite this function to implement a use case specific behaviour.
    function processRenewal(
        ReferralId referralId,
        uint256 feeAmount
    ) external;

    /// @dev Returns true to ensure component is called when transferring distributor Nft Ids.
    function isVerifying() external view returns (bool verifying);
}
