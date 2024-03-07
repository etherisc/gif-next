// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";

interface IRegisterable is
    INftOwnable
{

    function getInitialInfo() 
        external 
        view
        returns (IRegistry.ObjectInfo memory);
}