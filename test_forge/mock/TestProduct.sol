// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Product} from "../../contracts/components/Product.sol";


contract TestProduct is Product {

    constructor(address instance) Product(instance) {}

}