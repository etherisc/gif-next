// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee} from "../types/Fee.sol";
import {IComponentContract} from "../instance/module/component/IComponent.sol";

// just marker interface for now
interface IPoolComponent is IComponentContract {
    function getStakingFee() external view returns (Fee memory stakingFee);

    function getPerformanceFee()
        external
        view
        returns (Fee memory performanceFee);
}
