// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {INftOwnable} from "./INftOwnable.sol";
import {IRegistry} from "../registry/IRegistry.sol";

interface IRegisterable is IERC165, INftOwnable {

    function getInitialInfo() 
        external 
        view
        returns (IRegistry.ObjectInfo memory, bytes memory data);
}