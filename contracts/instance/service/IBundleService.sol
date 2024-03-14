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
    error ErrorIBundleServiceInsufficientAllowance(address bundleOwner, address tokenHandlerAddress, uint256 amount);

    function createBundle(
        address owner,
        Fee memory fee, 
        uint256 amount,
        Seconds lifetime, 
        bytes calldata filter
    ) external returns(NftId bundleNftId);

    function setBundleFee(
        NftId bundleNftId,
        Fee memory fee
    ) external;

    function updateBundle(NftId instanceNftId, NftId bundleNftId, IBundle.BundleInfo memory bundleInfo, StateId state) external;

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

    // function fundBundle(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    // function defundBundle(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    function lockBundle(NftId bundleNftId) external;

    function unlockBundle(NftId bundleNftId) external;

    // function closeBundle(NftId bundleNftId) external;
}
