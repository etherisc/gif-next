// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ISharedA} from "./IA.sol";
import {IB} from "./IB.sol";
import {IC} from "./IC.sol";

abstract contract C is ISharedA, IC {

    uint256 private _x;

    constructor() {
        _x = 2;
    }

    // access own state
    function getC() external view override returns(uint256) { return _x; }
    function setC(uint256 newA) external override { _x = newA; }

    // access state from parent contract A
    function getAfromC() external view override returns(uint256) { return this.getA(); }

    // access state from other module B
    function getBfromC() external view override returns(uint256) {
        IB b = IB(address(this));
        return b.getB();
    }
}
