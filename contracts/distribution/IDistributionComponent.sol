// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {IInstanceLinkedComponent} from "../shared/IInstanceLinkedComponent.sol";
import {NftId} from "../type/NftId.sol";
import {ReferralId, ReferralStatus} from "../type/Referral.sol";
import {UFixed} from "../type/UFixed.sol";

interface IDistributionComponent is IInstanceLinkedComponent {

    event LogDistributorUpdated(address to, address operator);

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

    /// @dev Withdraw commission for the distributor
    /// @param distributorNftId the distributor Nft Id
    /// @param amount the amount to withdraw. If set to AMOUNT_MAX, the full commission available is withdrawn
    /// @return withdrawnAmount the effective withdrawn amount
    function withdrawCommission(NftId distributorNftId, Amount amount) external returns (Amount withdrawnAmount);
}
