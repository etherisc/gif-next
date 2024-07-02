// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Amount} from "../type/Amount.sol";
import {NftId} from "../type/NftId.sol";
import {Fee} from "../type/Fee.sol";
import {IService} from "../shared/IService.sol";
import {IBundle} from "../instance/module/IBundle.sol";
import {IInstance} from "../instance/IInstance.sol";
import {Seconds} from "../type/Seconds.sol";
import {StateId} from "../type/StateId.sol";
import {Timestamp} from "../type/Timestamp.sol";

interface IBundleService is IService {

    event LogBundleServiceBundleActivated(NftId bundleNftId);
    event LogBundleServiceBundleLocked(NftId bundleNftId);

    error ErrorBundleServiceInsufficientAllowance(address bundleOwner, address tokenHandlerAddress, Amount amount);
    error ErrorBundleServiceBundleNotOpen(NftId bundleNftId, StateId state, Timestamp expiredAt);
    error ErrorBundleServiceCapacityInsufficient(NftId bundleNftId, Amount capacityAmount, Amount collateralAmount);
    error ErrorBundleServiceBundleWithOpenPolicies(NftId bundleNftId, uint256 openPoliciesCount);

    error ErrorBundleServiceBundleUnknown(NftId bundleNftId);
    error ErrorBundleServiceBundlePoolMismatch(NftId bundleNftId, NftId expectedPool, NftId actualPool);

    error ErrorBundleServicePolicyNotCloseable(NftId policyNftId);

    // error ErrorBundleServiceBundleNotActive(NftId distributorNftId);
    error ErrorBundleServiceFeesWithdrawAmountExceedsLimit(Amount amount, Amount limit);
    error ErrorBundleServiceFeesWithdrawAmountIsZero();
    error ErrorBundleServiceWalletAllowanceTooSmall(address wallet, address tokenHandler, uint256 allowance, uint256 amount);

    event LogBundleServiceFeesWithdrawn(NftId bundleNftId, address recipient, address tokenAddress, Amount amount);

    /// @dev create a new bundle for the specified attributes
    /// may only be called by pool service
    function create(
        IInstance instance, // instance relevant for bundle
        NftId poolNftId, // the pool the bundle will be linked to
        address owner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Amount stakingAmount, // staking amount - staking fees result in initial bundle capital
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        returns(NftId bundleNftId); // the nft id of the newly created bundle


    /// @dev increase bundle stakes by the specified amount
    /// may only be called by the bundle owner
    // function stake(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    // function unstake(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    /// @dev locks the specified bundle, locked bundles are not available to collateralize new policies
    /// only active bundles may be locked
    /// may only be called by registered and unlocked pool components
    function lock(NftId bundleNftId) external;

    /// @dev activates the specified bundle
    /// only locked bundles may be unlocked
    /// may only be called by registered and unlocked pool components
    function unlock(NftId bundleNftId) external;

    /// @dev closes the specified bundle
    /// only open bundles (active or locked) may be closed
    /// to close a bundle it may not have any non-closed polices attached to it
    /// may only be called by registered and unlocked pool components
    function close(
        IInstance instance, 
        NftId bundleNftId
    ) external;

    /// @dev set bundle fee to provided value
    /// may only be called by registered and unlocked pool components
    function setFee(
        NftId bundleNftId,
        Fee memory fee
    ) external;


    /// @dev locks the specified collateral in the bundle
    /// the locked collateral is added to the bundle locked capital
    /// the bundles' fees are updated with the fees for this premium
    /// the premium (minus bundle fee) is added to the bundle capital
    /// may only be called by pool service
    function lockCollateral(
        IInstance instance, 
        NftId policyNftId, 
        NftId bundleNftId, 
        Amount collateralAmount
    ) external;


    /// @dev releases the specified collateral in the bundle
    /// may only be called by pool service
    function releaseCollateral(
        IInstance instance, 
        NftId policyNftId, 
        NftId bundleNftId, 
        Amount collateralAmount
    ) external;

    /// @dev unlink policy from bundle
    /// policy may only be unlinked if policy is closeable
    /// may only be called by pool service
    function unlinkPolicy(
        IInstance instance, 
        NftId policyNftId
    ) external;

    /// @dev Withdraw bundle feeds for the given bundle
    /// @param bundleNftId the bundle Nft Id
    /// @param amount the amount to withdraw. If set to AMOUNT_MAX, the full commission available is withdrawn
    /// @return withdrawnAmount the effective withdrawn amount
    function withdrawBundleFees(NftId bundleNftId, Amount amount) external returns (Amount withdrawnAmount);

}
