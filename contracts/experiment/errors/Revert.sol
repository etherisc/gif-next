// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IRevert {
    error AsmallerThanB_S();
    error AsmallerThanB_M(uint a);
    error AsmallerThanB_L(uint a, uint b);
    error Error001AsmallerThanB_S();
    error Error002AsmallerThanB_M(uint a);
    error Error003AsmallerThanB_L(uint a, uint b);
}

contract Revert is IRevert {
    
    uint256 private _b;

    constructor() {
        _b = 42;
    }

    function isAlargerThanBRevert_S(
        uint a
    ) external view returns (bool isLarger) {
        if (a <= _b) {
            revert Error001AsmallerThanB_S();
        }

        return true;
    }

    function isAlargerThanBRevert_M(
        uint a
    ) external view returns (bool isLarger) {
        if (a == 0) {
            revert Error002AsmallerThanB_M(0);
        }
        if (a <= _b) {
            revert Error002AsmallerThanB_M(a);
        }

        return true;
    }

    function isAlargerThanBRevert_L(
        uint a
    ) external view returns (bool isLarger) {
        if (a <= _b) {
            revert Error003AsmallerThanB_L(a, _b);
        }

        return true;
    }
}
