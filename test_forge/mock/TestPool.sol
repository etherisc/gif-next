// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Pool} from "../../contracts/components/Pool.sol";


contract TestPool is Pool {

    constructor(address registry, address instance)
        Pool(registry, instance)
    {}

}