// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IA, ISharedA} from "./IA.sol";
import {B} from "./B.sol";
import {C} from "./C.sol";

/* 

# dependency graph

   B <...+
   ^     |
   |     |
   A --> C

   - A is the main contract
   - A provides functionality implemented by modules B and C
   - B and C rely on functionality shared by A
   - C accesses functionality of module B

# chisel session

import {A} from "./contracts/experiment/A.sol";
A a = new A();
uint(a.getA())
uint(a.getB()))
uint(a.getC())
uint(a.getAfromB())
uint(a.getAfromC())
uint(a.getBfromC())
a.setA(100);
a.setB(10);
a.setC(20);
 */

contract AShared is ISharedA {

    uint256 private _x;

    constructor() {
        _x = 42;
    }

    function getA() external view override returns(uint256) { return _x; }
    function setA(uint256 newA) external override { _x = newA; }
}

contract A is
    AShared,
    B,
    C,
    IA
{

}
