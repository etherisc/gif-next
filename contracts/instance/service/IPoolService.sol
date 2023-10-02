// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {IService} from "../base/IService.sol";

interface IPoolService is IService {
    function setFees(
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;

    function createBundle(
        address owner,
        uint256 amount,
        uint256 lifetime, 
        bytes calldata filter
    ) external returns(NftId bundleNftId);

    // function fundBundle(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    // function defundBundle(NftId bundleNftId, uint256 amount) external returns(uint256 netAmount);

    // function lockBundle(NftId bundleNftId) external;

    // function unlockBundle(NftId bundleNftId) external;

    // function closeBundle(NftId bundleNftId) external;
}
