// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IProductService} from "../service/IProductService.sol";

interface IProductModule is
    IOwnable, 
    IRegistryLinked
{
}
