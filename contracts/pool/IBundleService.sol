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

    event LogBundleServiceBundleCreated(NftId bundleNftId, NftId poolNftId);
    event LogBundleServiceBundleActivated(NftId bundleNftId);
    event LogBundleServiceBundleLocked(NftId bundleNftId);

    error ErrorBundleServiceInsufficientAllowance(address bundleOwner, address tokenHandlerAddress, Amount amount);
    error ErrorBundleServiceBundleNotOpen(NftId bundleNftId, StateId state, Timestamp expiredAt);
    error ErrorBundleServiceCapacityInsufficient(NftId bundleNftId, Amount capacityAmount, Amount collateralAmount);
    error ErrorBundleServiceBundleWithOpenPolicies(NftId bundleNftId, uint256 openPoliciesCount);

    error ErrorBundleServiceBundleUnknown(NftId bundleNftId);
    error ErrorBundleServiceBundlePoolMismatch(NftId bundleNftId, NftId expectedPool, NftId actualPool);

    error ErrorBundleServicePolicyNotCloseable(NftId policyNftId);

    error ErrorBundleServiceFeesWithdrawAmountExceedsLimit(Amount amount, Amount limit);
    
    error ErrorBundleServiceUnstakeAmountExceedsLimit(Amount amount, Amount limit);

    error ErrorBundleServiceExtensionLifetimeIsZero();

    event LogBundleServiceFeesWithdrawn(NftId bundleNftId, address recipient, address tokenAddress, Amount amount);
    event LogBundleServiceBundleExtended(NftId bundleNftId, Seconds lifetimeExtension, Timestamp extendedExpiredAt);

    /// @dev Create a new bundle for the specified attributes.
    function create(
        address owner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        returns(NftId bundleNftId); // the nft id of the newly created bundle


    /// @dev increase bundle stakes by the specified amount. bundle must not be expired or closed
    /// may only be called by the pool service
    function stake(IInstance instance, NftId bundleNftId, Amount amount) external;

    /// @dev decrease bundle stakes by the specified amount
    /// may only be called by the pool service
    /// @param instance the instance relevant for the bundle
    /// @param bundleNftId the bundle nft id
    /// @param amount the amount to unstake (set to AmountLib.max() to unstake all available stakes)
    /// @return unstakedAmount the effective unstaked amount
    function unstake(IInstance instance, NftId bundleNftId, Amount amount) external returns (Amount unstakedAmount);

    /// @dev extend the lifetime of the bundle by the specified time in seconds
    function extend(NftId bundleNftId, Seconds lifetimeExtension) external returns (Timestamp extendedExpiredAt);

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
    /// @return balanceAmount the unstaked amount that was remaining in the bundle
    /// @return feeAmount the fee amount that was remaining for the bundle
    function close(
        IInstance instance, 
        NftId bundleNftId
    ) external returns (Amount balanceAmount, Amount feeAmount);

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

    // FIXME: move to pool service
    /// @dev Withdraw bundle feeds for the given bundle
    /// @param bundleNftId the bundle Nft Id
    /// @param amount the amount to withdraw. If set to AMOUNT_MAX, the full commission available is withdrawn
    /// @return withdrawnAmount the effective withdrawn amount
    function withdrawBundleFees(NftId bundleNftId, Amount amount) external returns (Amount withdrawnAmount);
}
