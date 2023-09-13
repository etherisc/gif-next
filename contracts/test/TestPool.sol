// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Fee, zeroFee} from "../../contracts/types/Fee.sol";
import {Pool} from "../../contracts/components/Pool.sol";


contract TestPool is Pool {

    constructor(address registry, address instance, address token)
        // feeless pool (no staking fee, no performance fee)
        Pool(registry, instance, token, zeroFee(), zeroFee())
    // solhint-disable-next-line no-empty-blocks
    {}

}