// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../types/Fee.sol";
import {IComponentBase} from "./IComponentBase.sol";

interface IPoolBase is IComponentBase {
    function getStakingFee() external view returns (Fee memory stakingFee);

    function getPerformanceFee()
        external
        view
        returns (Fee memory performanceFee);
}
