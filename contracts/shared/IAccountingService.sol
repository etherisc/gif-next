// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {InstanceStore} from "../instance/InstanceStore.sol";
import {IService} from "../shared/IService.sol";
import {NftId} from "../type/NftId.sol";
import {ObjectType} from "../type/ObjectType.sol";
import {UFixed} from "../type/UFixed.sol";
import {VersionPart} from "../type/Version.sol";

/// @dev component base class
/// component examples are staking, product, distribution, pool and oracle
interface IAccountingService is 
    IService
{
    event LogComponentServiceUpdateFee(
        NftId nftId, 
        string feeName, 
        UFixed previousFractionalFee, 
        uint256 previousFixedFee,
        UFixed newFractionalFee, 
        uint256 newFixedFee
    );

    function increaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;
    function decreaseProductFees(InstanceStore instanceStore, NftId productNftId, Amount feeAmount) external;

    function increaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributionBalance(InstanceStore instanceStore, NftId distributionNftId, Amount amount, Amount feeAmount) external;

    function increaseDistributorBalance(InstanceStore instanceStore, NftId distributorNftId, Amount amount, Amount feeAmount) external;
    function decreaseDistributorBalance(InstanceStore instanceStore, NftId distributorNftId, Amount amount, Amount feeAmount) external;

    function increasePoolBalance(InstanceStore instanceStore, NftId poolNftId, Amount amount, Amount feeAmount) external;
    function decreasePoolBalance(InstanceStore instanceStore, NftId poolNftId, Amount amount, Amount feeAmount) external;

    function increaseBundleBalance(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;
    function decreaseBundleBalance(InstanceStore instanceStore, NftId bundleNftId, Amount amount, Amount feeAmount) external;

}