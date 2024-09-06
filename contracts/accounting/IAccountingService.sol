// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


import {Amount} from "../type/Amount.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {UFixed} from "../type/UFixed.sol";

/// @dev component base class
/// component examples are staking, product, distribution, pool and oracle
interface IAccountingService is 
    IService
{
    event LogAccountingServiceUpdateFee(
        NftId nftId, 
        string feeName, 
        UFixed previousFractionalFee, 
        Amount previousFixedFee,
        UFixed newFractionalFee, 
        Amount newFixedFee
    );

    function decreaseComponentFees(InstanceStore instanceStore, NftId componentNftId, Amount feeAmount) external;

    function increaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;
    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;

    function increaseProductFeesForPool(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;

    function increaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;

    function increaseDistributorBalance(InstanceStore instanceStore, NftId distributorNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributorBalance(InstanceStore instanceStore, NftId distributorNftId, Amount amount, Amount feeAmount) external;

    function increasePoolBalance(InstanceStore instanceStore, NftId poolNftId, Amount amount, Amount feeAmount) external;
    function decreasePoolBalance(InstanceStore instanceStore, NftId poolNftId, Amount amount, Amount feeAmount) external;

    function increaseBundleBalance(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;
    function decreaseBundleBalance(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;

    function increaseBundleBalanceForPool(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;
    function decreaseBundleBalanceForPool(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;

}