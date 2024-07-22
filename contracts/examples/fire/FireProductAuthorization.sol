// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {BasicProductAuthorization} from "../../product/BasicProductAuthorization.sol";


contract FireProductAuthorization
    is BasicProductAuthorization
{

    constructor(string memory poolName)
        BasicProductAuthorization(poolName)
    {}

}

