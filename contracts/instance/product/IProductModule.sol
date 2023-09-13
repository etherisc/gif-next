// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOwnable, IRegistryLinked} from "../../registry/IRegistry.sol";
import {IProductService} from "../services/IProductService.sol";

interface IProductModule is
    IOwnable, 
    IRegistryLinked
{
    function getProductService() external view returns (IProductService);
}
