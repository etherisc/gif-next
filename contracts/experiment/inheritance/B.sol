// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ISharedA} from "./IA.sol";
import {IB} from "./IB.sol";

abstract contract B is ISharedA, IB {

    // names of private variables can be re-used in inheritance
    uint256 private _x;

    constructor() {
        _x = 1;
    }

    // access own state
    function getB() external view override returns(uint256) { return _x; }
    function setB(uint256 newB) external override { _x = newB; }

    // access state from parent contract A
    function getAfromB() external view override returns(uint256) { return this.getA(); }

}
