// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount} from "../type/Amount.sol";
import {Fee} from "../type/Fee.sol";
import {NftId} from "../type/NftId.sol";
import {PayoutId} from "../type/PayoutId.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IInstance} from "../instance/IInstance.sol";
import {IPolicy} from "../instance/module/IPolicy.sol";
import {IService} from "../shared/IService.sol";
import {RoleId} from "../type/RoleId.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId} from "../type/StateId.sol";

interface IPoolService is IService {

    event LogPoolServiceMaxCapitalAmountUpdated(NftId poolNftId, Amount previousMaxCapitalAmount, Amount currentMaxCapitalAmount);
    event LogPoolServiceBundleOwnerRoleSet(NftId poolNftId, RoleId bundleOwnerRole);

    event LogPoolServiceBundleCreated(NftId instanceNftId, NftId poolNftId, NftId bundleNftId);
    event LogPoolServiceBundleClosed(NftId instanceNftId, NftId poolNftId, NftId bundleNftId);

    error ErrorPoolServiceBundleOwnerRoleAlreadySet(NftId poolNftId);
    error ErrorPoolServiceBundlePoolMismatch(NftId bundlePoolNftId, NftId productPoolNftId);
    error ErrorPoolServiceInvalidTransferAmount(Amount expectedAmount, Amount actualAmount);

    /// @dev registers a new pool with the registry service
    function register(address poolAddress) external returns(NftId);

    /// @dev defines the required role for bundle owners for the calling pool
    /// default implementation returns PUBLIC ROLE
    function setBundleOwnerRole(RoleId bundleOwnerRole) external;

    /// @dev sets the max capital amount for the calling pool
    function setMaxCapitalAmount(Amount maxCapitalAmount) external;

    /// @dev set pool sepecific fees
    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;


    /// @dev locks required collateral to cover the specified application (and turn it into a policy)
    /// - retention level == 1: the full collateral amount will be locked by the specified bundle
    /// - retention level < 1: a part of the coverage is provided by the specified bundle, the rest by the pool component
    /// in which case the pool component might hold a re-insurance policy
    /// may only be called by the policy service for unlocked pool components
    function lockCollateral(
        IInstance instance, 
        NftId productNftId,
        NftId applicationNftId,
        IPolicy.PolicyInfo memory applicationInfo,
        Amount premiumAmount
    ) external;


    /// @dev releases the remaining collateral linked to the specified policy
    /// may only be called by the policy service for unlocked pool components
    function releaseCollateral(
        IInstance instance, 
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo
    ) external;


    /// @dev reduces the locked collateral in the bundle associated with the specified policy
    /// every payout of a policy reduces the collateral by the payout amount
    /// may only be called by the claim service for unlocked pool components
    function reduceCollateral(
        IInstance instance, 
        NftId policyNftId, 
        IPolicy.PolicyInfo memory policyInfo,
        Amount payoutAmount
    ) external;


    /// @dev create a new bundle for the provided parameters
    /// staking fees will be deducted by the pool service from the staking amount
    /// may only be called by registered and unlocked pool components
    function createBundle(
        address owner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Amount stakingAmount, // staking amount - staking fees result in initial bundle capital
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        returns(NftId bundleNftId); // the nft id of the newly created bundle


    /// @dev closes the specified bundle
    /// only open bundles (active or locked) may be closed
    /// to close a bundle it may not have any non-closed polices attached to it
    /// bundle fees and remaining capital (after deduction of the performance fee) will be transferred to the bundle owner
    /// may only be called by registered and unlocked pool components
    function closeBundle(NftId bundleNftId) external;

    /// @dev processes the sale of a bundle and track the pool fee and bundle fee amounts
    function processSale(NftId bundleNftId, IPolicy.Premium memory premium, Amount actualAmountTransferred) external;

    /// @dev increase stakes for bundle
    /// staking fees will be deducted by the pool service from the staking amount
    /// may only be called by registered and unlocked pool components
    // function stake(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);


    /// @dev decrease stakes for bundle
    /// performance fees will be deducted by the pool service from the staking amount
    /// may only be called by registered and unlocked pool components
    // function unstake(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);
}
