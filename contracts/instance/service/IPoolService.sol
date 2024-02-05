// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../types/NftId.sol";
import {Fee} from "../../types/Fee.sol";
import {StateId} from "../../types/StateId.sol";
import {IService} from "../../shared/IService.sol";
import {IBundle} from "../module/IBundle.sol";
import {IInstance} from "../../instance/IInstance.sol";

interface IPoolService is IService {

    function register(address poolAddress) external returns(NftId);

    function setFees(
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    ) external;
}
