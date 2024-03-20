// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {IService} from "../../shared/IService.sol";
import {IBundle} from "../module/IBundle.sol";
import {IInstance} from "../../instance/IInstance.sol";
import {Seconds} from "../../types/Seconds.sol";
import {StateId} from "../../types/StateId.sol";

interface IBundleService is IService {

    event LogBundleServiceBundleActivated(NftId bundleNftId);
    event LogBundleServiceBundleLocked(NftId bundleNftId);
    event LogBundleServiceBundleClosed(NftId bundleNftId);

    error ErrorBundleServiceInsufficientAllowance(address bundleOwner, address tokenHandlerAddress, uint256 amount);
    error ErrorBundleServiceBundleNotOpen(NftId bundleNftId, StateId state);
    error ErrorBundleServiceBundleWithOpenPolicies(NftId bundleNftId, uint256 openPoliciesCount);

    function create(
        address owner,
        Fee memory fee, 
        uint256 amount,
        Seconds lifetime, 
        bytes calldata filter
    ) external returns(NftId bundleNftId);


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
    )
        external
        returns (
            IBundle.BundleInfo memory bundleInfo
        );

    function increaseBalance(IInstance instance, NftId bundleNftId,  uint256 amount) external;

    function closePolicy(IInstance instance, NftId policyNftId, NftId bundleNftId, uint256 collateralAmount) external;

    // function stake(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    // function unstake(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    function lock(NftId bundleNftId) external;

    function unlock(NftId bundleNftId) external;

    function close(NftId bundleNftId) external;
}
