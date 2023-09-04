// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

contract Revert {
    error AsmallerThanB_S();
    error AsmallerThanB_M(uint a);
    error AsmallerThanB_L(uint a, uint b);

    uint256 private _b;

    constructor() {
        _b = 42;
    }

    function isAlargerThanBRevert_S(
        uint a
    ) external view returns (bool isLarger) {
        if (a <= _b) {
            revert AsmallerThanB_S();
        }

        return true;
    }

    function isAlargerThanBRevert_M(
        uint a
    ) external view returns (bool isLarger) {
        if (a <= _b) {
            revert AsmallerThanB_M(a);
        }

        return true;
    }

    function isAlargerThanBRevert_L(
        uint a
    ) external view returns (bool isLarger) {
        if (a <= _b) {
            revert AsmallerThanB_L(a, _b);
        }

        return true;
    }
}
