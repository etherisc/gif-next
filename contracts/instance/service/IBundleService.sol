// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Amount} from "../../types/Amount.sol";
import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {IService} from "../../shared/IService.sol";
import {IBundle} from "../module/IBundle.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {Seconds} from "../../types/Seconds.sol";
import {StateId} from "../../types/StateId.sol";
import {Timestamp} from "../../types/Timestamp.sol";

interface IBundleService is IService {

    event LogBundleServiceBundleActivated(NftId bundleNftId);
    event LogBundleServiceBundleLocked(NftId bundleNftId);
    event LogBundleServiceBundleClosed(NftId bundleNftId);

    error ErrorBundleServiceInsufficientAllowance(address bundleOwner, address tokenHandlerAddress, uint256 amount);
    error ErrorBundleServiceBundleNotOpen(NftId bundleNftId, StateId state, Timestamp expiredAt);
    error ErrorBundleServiceCapacityInsufficient(NftId bundleNftId, uint capacityAmount, uint collateralAmount);
    error ErrorBundleServiceBundleWithOpenPolicies(NftId bundleNftId, uint256 openPoliciesCount);

    /// @dev create a new bundle for the specified attributes
    /// may only be called by registered and unlocked pool components
    function create(
        address owner, // initial bundle owner
        Fee memory fee, // fees deducted from premium that go to bundle owner
        Amount stakingAmount, // staking amount - staking fees result in initial bundle capital
        Seconds lifetime, // initial duration for which new policies are covered
        bytes calldata filter // optional use case specific criteria that define if a policy may be covered by this bundle
    )
        external 
        returns(NftId bundleNftId); // the nft id of the newly created bundle

    /// @dev set bundle fee to provided value
    /// may only be called by registered and unlocked pool components
    function setFee(
        NftId bundleNftId,
        Fee memory fee
    ) external;


    function lockCollateral(
        IInstance instanceNftId, 
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount, 
        uint256 netPremium
    ) external;


    function releaseCollateral(
        IInstance instance, 
        NftId policyNftId, 
        NftId bundleNftId, 
        uint256 collateralAmount
    ) external;

    function increaseBalance(IInstance instance, NftId bundleNftId,  uint256 amount) external;

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
    function close(NftId bundleNftId) external;
}
