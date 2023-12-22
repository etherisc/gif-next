// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NftId} from "../../contracts/types/NftId.sol";
import {UFixed} from "../../contracts/types/UFixed.sol";
import {Fee} from "../../contracts/types/Fee.sol";
import {Pool} from "../../contracts/components/Pool.sol";


contract TestPool is Pool {

    constructor(
        address registry,
        NftId instanceNftid,
        address token,
        bool isVerifying,
        UFixed collateralizationLevel,
        Fee memory poolFee,
        Fee memory stakingFee,
        Fee memory performanceFee
    )
        Pool(registry, instanceNftid, token, isVerifying, collateralizationLevel, poolFee, stakingFee, performanceFee)
    // solhint-disable-next-line no-empty-blocks
    {}
}