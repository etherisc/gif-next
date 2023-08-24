// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IB} from "./IB.sol";
import {IC} from "./IC.sol";

interface ISharedA {

    function getA() external view returns(uint256);
    function setA(uint256 newA) external;
}

interface IA is
    ISharedA,
    IB,
    IC
{
}
